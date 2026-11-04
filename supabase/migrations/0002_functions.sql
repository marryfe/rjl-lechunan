-- RJL Lechunan: business functions, permissions, storage and realtime.
-- Rules live in docs/PLAN.md sections 6 and 7. Error messages start with a code; src/lib/errors.ts
-- maps each code to friendly text, so keep the two in step.

-- ---------------------------------------------------------------- internal helpers
create or replace function manila_today() returns date
language sql stable set search_path = public as $$
  select (now() at time zone 'Asia/Manila')::date;
$$;

-- +639171234567 -> 09171234567. Spaces and dashes are dropped. Validity is checked by the caller.
create or replace function normalize_mobile(p_mobile text) returns text
language sql immutable set search_path = public as $$
  select regexp_replace(regexp_replace(coalesce(p_mobile, ''), '[\s-]', '', 'g'), '^\+63', '0');
$$;

-- These turn untrusted JSON text into values, returning null instead of a raw cast error.
create or replace function try_uuid(p_value text) returns uuid
language sql immutable set search_path = public as $$
  select case when p_value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then p_value::uuid end;
$$;

create or replace function try_numeric(p_value text) returns numeric
language sql immutable set search_path = public as $$
  select case when p_value ~ '^\d{1,6}(\.\d{1,6})?$' then p_value::numeric end;
$$;

create or replace function try_date(p_value text) returns date
language plpgsql immutable set search_path = public as $$
begin
  if p_value !~ '^\d{4}-\d{2}-\d{2}$' then
    return null;
  end if;
  return p_value::date;
exception when others then
  return null;
end $$;

-- ---------------------------------------------------------------- public: availability
create or replace function get_availability(p_from date, p_to date)
returns table (day date, pigs_left int, kg_left numeric, is_open boolean, reason text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_settings settings;
  v_today date := manila_today();
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from >= 62 then
    raise exception 'INVALID_RANGE: at most 62 days per call';
  end if;

  select * into v_settings from settings where id = 1;

  return query
  with days as (
    select g::date as d,
           coalesce(c.max_pigs, v_settings.default_max_pigs_per_day) as max_pigs,
           coalesce(c.max_kg, v_settings.default_max_kg_per_day) as max_kg,
           coalesce(c.is_closed, false) as is_closed,
           coalesce(b.pigs, 0) as booked_pigs,
           coalesce(b.kg, 0) as booked_kg
    from generate_series(p_from, p_to, interval '1 day') g
    left join daily_capacity c on c.date = g::date
    left join lateral (
      select sum(o.pig_count)::int as pigs, sum(o.total_kg) as kg
      from orders o
      where o.scheduled_date = g::date and o.status <> 'cancelled'
    ) b on true
  ), left_over as (
    select d, greatest(max_pigs - booked_pigs, 0) as pigs, greatest(max_kg - booked_kg, 0) as kg,
      case
        when is_closed then 'CLOSED'
        when d < v_today + v_settings.order_lead_days then 'TOO_SOON'
        when d > v_today + v_settings.booking_window_days then 'TOO_FAR'
        when max_pigs - booked_pigs <= 0 and max_kg - booked_kg <= 0 then 'FULL'
      end as why
    from days
  )
  select d, pigs, kg, why is null, why from left_over order by d;
end $$;

-- ---------------------------------------------------------------- public: cart pricing
create or replace function quote_cart(p_items jsonb, p_fulfillment fulfillment_type, p_date date default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_settings settings;
  v_item jsonb;
  v_product products;
  v_size product_sizes;
  v_qty numeric;
  v_kg numeric;
  v_add_ons jsonb;
  v_add_on_ids jsonb;
  v_add_on_total numeric;
  v_line_total numeric;
  v_lines jsonb := '[]'::jsonb;
  v_pig_count int := 0;
  v_total_kg numeric := 0;
  v_subtotal numeric := 0;
  v_delivery_fee numeric := 0;
  v_rule freebie_rules;
  v_multiplier numeric;
  v_freebies jsonb := '{}'::jsonb;  -- inventory item id -> freebie line
  v_skipped jsonb := '[]'::jsonb;
  v_current jsonb;
  v_need record;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART: the cart is empty';
  end if;

  select * into v_settings from settings where id = 1;

  if p_fulfillment = 'delivery' and not v_settings.delivery_enabled then
    raise exception 'DELIVERY_DISABLED: delivery is not available';
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    select * into v_product from products
    where id = try_uuid(v_item ->> 'product_id') and is_active;
    if not found then
      raise exception 'PRODUCT_UNAVAILABLE: product not found or not for sale';
    end if;

    if v_product.sell_type = 'by_size' then
      select * into v_size from product_sizes
      where id = try_uuid(v_item ->> 'size_id') and product_id = v_product.id;
      if not found then
        raise exception 'SIZE_MISMATCH: pick a size of this product';
      end if;
      if not v_size.is_active then
        raise exception 'PRODUCT_UNAVAILABLE: size not for sale';
      end if;

      v_qty := try_numeric(v_item ->> 'qty');
      if v_qty is null or v_qty <> trunc(v_qty) or v_qty < 1 or v_qty > 10 then
        raise exception 'INVALID_QTY: quantity must be 1 to 10';
      end if;

      v_add_on_ids := coalesce(v_item -> 'add_on_ids', '[]'::jsonb);
      if jsonb_typeof(v_add_on_ids) <> 'array' then
        raise exception 'ADDON_MISMATCH: add-ons must be a list';
      end if;

      if exists (
        select 1 from jsonb_array_elements_text(v_add_on_ids) t(id)
        where not exists (
          select 1 from add_ons a
          where a.id = try_uuid(t.id) and a.product_id = v_product.id and a.is_active)
      ) then
        raise exception 'ADDON_MISMATCH: add-on not available for this product';
      end if;

      select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'price', a.price)
                                order by a.name), '[]'::jsonb),
             coalesce(sum(a.price), 0)
      into v_add_ons, v_add_on_total
      from add_ons a
      where a.id in (select try_uuid(t.id) from jsonb_array_elements_text(v_add_on_ids) t(id));

      v_line_total := (v_size.price + v_add_on_total) * v_qty;
      v_pig_count := v_pig_count + v_qty::int;

      v_lines := v_lines || jsonb_build_object(
        'product_id', v_product.id, 'product_name', v_product.name,
        'size_id', v_size.id, 'size_name', v_size.name, 'kg', null, 'qty', v_qty::int,
        'unit_price', v_size.price, 'add_ons', v_add_ons, 'line_total', v_line_total);
    else
      if v_item ->> 'size_id' is not null then
        raise exception 'SIZE_MISMATCH: this product is sold by the kilo';
      end if;
      if jsonb_typeof(v_item -> 'add_on_ids') = 'array'
         and jsonb_array_length(v_item -> 'add_on_ids') > 0 then
        raise exception 'ADDON_MISMATCH: add-ons are not offered on kilo items';
      end if;

      v_kg := try_numeric(v_item ->> 'kg');
      if v_kg is null or v_kg < v_product.min_kg or v_kg > 50 or v_kg % v_product.kg_step <> 0 then
        raise exception 'INVALID_KG: minimum % kg, in steps of % kg, up to 50 kg',
          v_product.min_kg, v_product.kg_step;
      end if;

      v_line_total := round(v_product.price_per_kg * v_kg, 2);
      v_total_kg := v_total_kg + v_kg;

      v_lines := v_lines || jsonb_build_object(
        'product_id', v_product.id, 'product_name', v_product.name,
        'size_id', null, 'size_name', null, 'kg', v_kg, 'qty', 1,
        'unit_price', v_product.price_per_kg, 'add_ons', '[]'::jsonb, 'line_total', v_line_total);
    end if;

    v_subtotal := v_subtotal + v_line_total;
  end loop;

  if p_fulfillment = 'delivery' then
    v_delivery_fee := v_settings.delivery_fee;
  end if;

  -- Freebies. Rules run highest priority first, so when stock is short the best rule is served
  -- and later rules see what is left. A rule is given whole or skipped.
  for v_rule in
    select * from freebie_rules where is_active
    order by priority desc, created_at desc, id asc
  loop
    if v_rule.start_date is not null or v_rule.end_date is not null then
      continue when p_date is null;
      continue when p_date < coalesce(v_rule.start_date, p_date);
      continue when p_date > coalesce(v_rule.end_date, p_date);
    end if;

    v_multiplier := case v_rule.trigger
      when 'size' then (
        select coalesce(sum((l ->> 'qty')::numeric), 0) from jsonb_array_elements(v_lines) l
        where l ->> 'size_id' = v_rule.size_id::text)
      when 'kg_threshold' then case when v_total_kg >= v_rule.threshold then 1 else 0 end
      when 'order_amount' then case when v_subtotal >= v_rule.threshold then 1 else 0 end
      when 'promo_dates' then 1
    end;

    continue when v_multiplier = 0;

    if exists (
      select 1
      from freebie_rule_items ri
      join inventory_items i on i.id = ri.inventory_item_id
      where ri.rule_id = v_rule.id
      group by i.id
      having sum(ri.qty) * v_multiplier
             > max(i.on_hand - i.reserved)
               - coalesce((v_freebies -> i.id::text ->> 'qty')::numeric, 0)
    ) then
      v_skipped := v_skipped || jsonb_build_object('rule_name', v_rule.name, 'reason', 'OUT_OF_STOCK');
    else
      for v_need in
        select i.id, i.name, sum(ri.qty) * v_multiplier as qty
        from freebie_rule_items ri
        join inventory_items i on i.id = ri.inventory_item_id
        where ri.rule_id = v_rule.id
        group by i.id, i.name
      loop
        v_current := v_freebies -> v_need.id::text;
        v_freebies := v_freebies || jsonb_build_object(v_need.id::text,
          case when v_current is null then
            jsonb_build_object('rule_id', v_rule.id, 'rule_name', v_rule.name,
                               'inventory_item_id', v_need.id, 'item_name', v_need.name,
                               'qty', v_need.qty)
          else
            v_current || jsonb_build_object(
              'rule_id', null,
              'rule_name', (v_current ->> 'rule_name') || ', ' || v_rule.name,
              'qty', (v_current ->> 'qty')::numeric + v_need.qty)
          end);
      end loop;
    end if;

    -- Without stacking only the top fired rule counts, even if it was skipped for stock.
    exit when not v_settings.freebies_stack;
  end loop;

  return jsonb_build_object(
    'lines', v_lines,
    'freebies', (select coalesce(jsonb_agg(value order by value ->> 'item_name'), '[]'::jsonb)
                 from jsonb_each(v_freebies)),
    'skipped_freebies', v_skipped,
    'pig_count', v_pig_count,
    'total_kg', v_total_kg,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'total', v_subtotal + v_delivery_fee);
end $$;

-- ---------------------------------------------------------------- public: placing an order
create or replace function place_order(p_order jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_settings settings;
  v_name text := trim(p_order ->> 'customer_name');
  v_mobile text := normalize_mobile(p_order ->> 'customer_mobile');
  v_email text := nullif(trim(p_order ->> 'customer_email'), '');
  v_fulfillment_text text := p_order ->> 'fulfillment';
  v_fulfillment fulfillment_type;
  v_address text := nullif(trim(p_order ->> 'address'), '');
  v_landmark text := nullif(trim(p_order ->> 'landmark'), '');
  v_date date := try_date(p_order ->> 'scheduled_date');
  v_slot text := p_order ->> 'time_slot';
  v_note text := nullif(trim(p_order ->> 'note'), '');
  v_quote jsonb;
  v_day record;
  v_order orders;
begin
  select * into v_settings from settings where id = 1;

  if v_name is null or length(v_name) not between 2 and 80 then
    raise exception 'INVALID_NAME: name must be 2 to 80 characters';
  end if;
  if v_mobile !~ '^09\d{9}$' then
    raise exception 'INVALID_MOBILE: use 09XXXXXXXXX';
  end if;
  if v_fulfillment_text is null or v_fulfillment_text not in ('pickup', 'delivery') then
    raise exception 'INVALID_FULFILLMENT: choose pickup or delivery';
  end if;
  v_fulfillment := v_fulfillment_text::fulfillment_type;
  if v_fulfillment = 'delivery' and v_address is null then
    raise exception 'ADDRESS_REQUIRED: delivery needs an address';
  end if;
  if v_slot is null or not v_slot = any(v_settings.time_slots) then
    raise exception 'INVALID_SLOT: choose an available time slot';
  end if;
  if v_date is null then
    raise exception 'DATE_UNAVAILABLE: choose a valid date';
  end if;
  if length(v_note) > 1000 then
    raise exception 'INVALID_MESSAGE: message must be 1 to 1000 characters';
  end if;

  -- Serialised per mobile so parallel requests cannot slip past the limit.
  perform pg_advisory_xact_lock(hashtext('mobile:' || v_mobile));
  if (select count(*) from orders
      where customer_mobile = v_mobile and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'RATE_LIMIT: too many orders from this number, try again later';
  end if;

  -- Two customers must not be able to take the last slot of a day together.
  perform pg_advisory_xact_lock(hashtext('cap:' || v_date));

  v_quote := quote_cart(p_order -> 'items', v_fulfillment, v_date);

  select * into v_day from get_availability(v_date, v_date);
  if v_day.reason = 'FULL' then
    raise exception 'CAPACITY_FULL: this date is fully booked';
  end if;
  if not v_day.is_open then
    raise exception 'DATE_UNAVAILABLE: %', v_day.reason;
  end if;
  if v_day.pigs_left < (v_quote ->> 'pig_count')::int
     or v_day.kg_left < (v_quote ->> 'total_kg')::numeric then
    raise exception 'CAPACITY_FULL: not enough capacity left on this date';
  end if;

  insert into orders (customer_name, customer_mobile, customer_email, fulfillment, address, landmark,
                      scheduled_date, time_slot, pig_count, total_kg, subtotal, delivery_fee, total)
  values (v_name, v_mobile, v_email, v_fulfillment, v_address, v_landmark, v_date, v_slot,
          (v_quote ->> 'pig_count')::int, (v_quote ->> 'total_kg')::numeric,
          (v_quote ->> 'subtotal')::numeric, (v_quote ->> 'delivery_fee')::numeric,
          (v_quote ->> 'total')::numeric)
  returning * into v_order;

  insert into order_items (order_id, product_id, size_id, product_name, size_name, kg, qty,
                           unit_price, add_ons, line_total)
  select v_order.id, (l ->> 'product_id')::uuid, (l ->> 'size_id')::uuid, l ->> 'product_name',
         l ->> 'size_name', (l ->> 'kg')::numeric, (l ->> 'qty')::int,
         (l ->> 'unit_price')::numeric, l -> 'add_ons', (l ->> 'line_total')::numeric
  from jsonb_array_elements(v_quote -> 'lines') l;

  insert into order_freebies (order_id, rule_id, inventory_item_id, item_name, qty)
  select v_order.id, (f ->> 'rule_id')::uuid, (f ->> 'inventory_item_id')::uuid, f ->> 'item_name',
         (f ->> 'qty')::numeric
  from jsonb_array_elements(v_quote -> 'freebies') f;

  insert into order_status_history (order_id, from_status, to_status, created_at)
  values (v_order.id, null, 'new', clock_timestamp());

  if v_note is not null then
    insert into order_messages (order_id, sender, body, created_at)
    values (v_order.id, 'customer', v_note, clock_timestamp());
  end if;

  return jsonb_build_object('order_no', v_order.order_no, 'total', v_order.total,
                            'scheduled_date', v_order.scheduled_date, 'time_slot', v_order.time_slot);
end $$;

-- ---------------------------------------------------------------- public: tracking
create or replace function get_public_order(p_order_no text, p_mobile text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_order orders;
begin
  select * into v_order from orders
  where order_no = upper(trim(p_order_no)) and customer_mobile = normalize_mobile(p_mobile);
  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'order_no', v_order.order_no,
    'status', v_order.status,
    'scheduled_date', v_order.scheduled_date,
    'time_slot', v_order.time_slot,
    'fulfillment', v_order.fulfillment,
    'subtotal', v_order.subtotal,
    'delivery_fee', v_order.delivery_fee,
    'total', v_order.total,
    'amount_paid', v_order.amount_paid,
    'balance_due', v_order.balance_due,
    'downpayment_due_at', v_order.downpayment_due_at,
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'product_name', i.product_name, 'size_name', i.size_name, 'kg', i.kg, 'qty', i.qty,
               'unit_price', i.unit_price, 'add_ons', i.add_ons, 'line_total', i.line_total)),
             '[]'::jsonb)
      from order_items i where i.order_id = v_order.id),
    'freebies', (
      select coalesce(jsonb_agg(jsonb_build_object('item_name', f.item_name, 'qty', f.qty)
                                order by f.item_name), '[]'::jsonb)
      from order_freebies f where f.order_id = v_order.id),
    'status_history', (
      select coalesce(jsonb_agg(jsonb_build_object('status', h.to_status, 'created_at', h.created_at)
                                order by h.created_at), '[]'::jsonb)
      from order_status_history h where h.order_id = v_order.id),
    'messages', (
      select coalesce(jsonb_agg(jsonb_build_object('sender', m.sender, 'body', m.body,
                                                   'created_at', m.created_at)
                                order by m.created_at), '[]'::jsonb)
      from order_messages m where m.order_id = v_order.id));
end $$;

create or replace function post_customer_message(p_order_no text, p_mobile text, p_body text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_order orders;
  v_body text := trim(p_body);
begin
  select * into v_order from orders
  where order_no = upper(trim(p_order_no)) and customer_mobile = normalize_mobile(p_mobile)
  for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND: check the order number and mobile number';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'ORDER_CLOSED: this order is closed';
  end if;
  if v_body is null or length(v_body) not between 1 and 1000 then
    raise exception 'INVALID_MESSAGE: message must be 1 to 1000 characters';
  end if;
  if (select count(*) from order_messages
      where order_id = v_order.id and sender = 'customer'
        and (created_at at time zone 'Asia/Manila')::date = manila_today()) >= 30 then
    raise exception 'RATE_LIMIT: too many messages today, try again tomorrow';
  end if;

  insert into order_messages (order_id, sender, body, created_at)
  values (v_order.id, 'customer', v_body, clock_timestamp());
end $$;

-- ---------------------------------------------------------------- staff: stock for an order
-- What the order needs at confirm time: pig per size line, add-on items, freebies.
create or replace function reserve_order_stock(p_order_id uuid) returns void
language plpgsql set search_path = public as $$
declare
  v_short text;
begin
  create temp table order_needs on commit drop as
  select x.item_id, sum(x.qty) as qty
  from (
    select s.inventory_item_id as item_id, oi.qty::numeric as qty
    from order_items oi
    join product_sizes s on s.id = oi.size_id
    where oi.order_id = p_order_id and s.inventory_item_id is not null
    union all
    select a.inventory_item_id, oi.qty::numeric
    from order_items oi
    cross join lateral jsonb_array_elements(oi.add_ons) chosen
    join add_ons a on a.id = (chosen ->> 'id')::uuid
    where oi.order_id = p_order_id and a.inventory_item_id is not null
    union all
    select f.inventory_item_id, f.qty
    from order_freebies f
    where f.order_id = p_order_id
  ) x
  group by x.item_id;

  -- Locked in id order so two confirms cannot deadlock.
  perform 1 from inventory_items
  where id in (select item_id from order_needs)
  order by id
  for update;

  select string_agg(format('%s (need %s, have %s)', i.name, trim_scale(n.qty),
                           trim_scale(i.on_hand - i.reserved)), ', ' order by i.name)
  into v_short
  from order_needs n
  join inventory_items i on i.id = n.item_id
  where n.qty > i.on_hand - i.reserved;

  if v_short is not null then
    raise exception 'NOT_ENOUGH_STOCK: %', v_short;
  end if;

  update inventory_items i set reserved = i.reserved + n.qty
  from order_needs n where n.item_id = i.id;

  insert into stock_movements (item_id, reserved_change, reason, order_id, user_id)
  select n.item_id, n.qty, 'reserve', p_order_id, auth.uid() from order_needs n;

  drop table order_needs;
end $$;

-- Deduct or release works from what this order actually reserved, taken from stock_movements,
-- so editing the catalog after confirming cannot unbalance the stock.
create or replace function settle_order_stock(p_order_id uuid, p_reason movement_reason)
returns void
language plpgsql set search_path = public as $$
declare
  v_held record;
begin
  for v_held in
    select m.item_id, sum(m.reserved_change) as qty
    from stock_movements m
    where m.order_id = p_order_id
    group by m.item_id
    having sum(m.reserved_change) > 0
    order by m.item_id
  loop
    update inventory_items
    set reserved = reserved - v_held.qty,
        on_hand = on_hand - case when p_reason = 'deduct' then v_held.qty else 0 end
    where id = v_held.item_id;

    insert into stock_movements (item_id, on_hand_change, reserved_change, reason, order_id, user_id)
    values (v_held.item_id, case when p_reason = 'deduct' then -v_held.qty else 0 end, -v_held.qty,
            p_reason, p_order_id, auth.uid());
  end loop;
end $$;

-- ---------------------------------------------------------------- staff: order status
create or replace function set_order_status(p_order_id uuid, p_to order_status, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_order orders;
  v_from order_status;
  v_note text := nullif(trim(p_note), '');
  v_allowed boolean;
begin
  if not is_staff() then
    raise exception 'FORBIDDEN: staff only';
  end if;

  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND: no such order';
  end if;
  v_from := v_order.status;

  v_allowed := case p_to
    -- awaiting -> awaiting extends the deadline (PLAN 7.5, step 5).
    when 'awaiting_downpayment' then v_from in ('new', 'awaiting_downpayment')
    when 'confirmed' then v_from in ('new', 'awaiting_downpayment')
    when 'roasting' then v_from = 'confirmed'
    when 'ready' then v_from in ('roasting', 'out_for_delivery')
    when 'out_for_delivery' then v_from = 'ready' and v_order.fulfillment = 'delivery'
    when 'completed' then v_from in ('ready', 'out_for_delivery')
    when 'cancelled' then v_from in ('new', 'awaiting_downpayment', 'confirmed', 'ready')
    else false
  end;
  if not v_allowed then
    raise exception 'BAD_TRANSITION: % to %', v_from, p_to;
  end if;

  if p_to = 'cancelled' and v_from = 'ready' and not is_admin() then
    raise exception 'FORBIDDEN: only an admin can cancel a ready order';
  end if;
  if v_note is null and (p_to = 'cancelled' or (v_from = 'out_for_delivery' and p_to = 'ready')) then
    raise exception 'REASON_REQUIRED: add a note';
  end if;
  if p_to = 'completed' and v_order.balance_due > 0 then
    raise exception 'BALANCE_DUE: record the payment first';
  end if;

  if p_to = 'confirmed' then
    perform reserve_order_stock(p_order_id);
    v_order.stock_reserved := true;
  elsif p_to = 'completed' then
    perform settle_order_stock(p_order_id, 'deduct');
    v_order.stock_reserved := false;
  elsif p_to = 'cancelled' and v_order.stock_reserved then
    perform settle_order_stock(p_order_id, 'release');
    v_order.stock_reserved := false;
  end if;

  update orders
  set status = p_to,
      stock_reserved = v_order.stock_reserved,
      downpayment_due_at = case
        when p_to = 'awaiting_downpayment' then
          now() + make_interval(hours => (select downpayment_deadline_hours from settings where id = 1))
        else downpayment_due_at end,
      cancel_reason = case when p_to = 'cancelled' then v_note else cancel_reason end
  where id = p_order_id;

  insert into order_status_history (order_id, from_status, to_status, user_id, note, created_at)
  values (p_order_id, v_from, p_to, auth.uid(), v_note, clock_timestamp());
end $$;

-- ---------------------------------------------------------------- staff: payments and chat
create or replace function record_payment(p_order_id uuid, p_type payment_type, p_amount numeric,
                                          p_method payment_method, p_reference text default null,
                                          p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_order orders;
  v_paid numeric;
begin
  if not is_staff() then
    raise exception 'FORBIDDEN: staff only';
  end if;

  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND: no such order';
  end if;
  if v_order.status = 'cancelled' and p_type <> 'refund' then
    raise exception 'ORDER_CLOSED: a cancelled order takes refunds only';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT: enter an amount above zero';
  end if;

  v_paid := v_order.amount_paid + case when p_type = 'refund' then -p_amount else p_amount end;
  if v_paid > v_order.total then
    raise exception 'OVERPAY: payment is more than the balance';
  end if;
  if v_paid < 0 then
    raise exception 'REFUND_TOO_LARGE: refund is more than the amount paid';
  end if;

  insert into payments (order_id, type, amount, method, reference_no, note, received_by)
  values (p_order_id, p_type, p_amount, p_method, nullif(trim(p_reference), ''),
          nullif(trim(p_note), ''), auth.uid());

  update orders set amount_paid = v_paid where id = p_order_id;
end $$;

create or replace function post_staff_message(p_order_id uuid, p_body text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_body text := trim(p_body);
begin
  if not is_staff() then
    raise exception 'FORBIDDEN: staff only';
  end if;
  if not exists (select 1 from orders where id = p_order_id) then
    raise exception 'ORDER_NOT_FOUND: no such order';
  end if;
  if v_body is null or length(v_body) not between 1 and 1000 then
    raise exception 'INVALID_MESSAGE: message must be 1 to 1000 characters';
  end if;

  insert into order_messages (order_id, sender, staff_id, body, created_at)
  values (p_order_id, 'staff', auth.uid(), v_body, clock_timestamp());
end $$;

-- ---------------------------------------------------------------- staff: daily prep sheet
create or replace function get_prep_sheet(p_date date)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_staff() then
    raise exception 'FORBIDDEN: staff only';
  end if;

  return (
    with day_orders as (
      select * from orders where scheduled_date = p_date and status <> 'cancelled'
    ), day_items as (
      select i.* from order_items i join day_orders o on o.id = i.order_id
    )
    select jsonb_build_object(
      'date', p_date,
      'pigs_by_size', (
        select coalesce(jsonb_agg(jsonb_build_object('size_name', x.size_name, 'count', x.total)
                                  order by x.size_name), '[]'::jsonb)
        from (select size_name, sum(qty) as total from day_items
              where size_id is not null group by size_name) x),
      'kg_by_product', (
        select coalesce(jsonb_agg(jsonb_build_object('product_name', x.product_name, 'kg', x.total)
                                  order by x.product_name), '[]'::jsonb)
        from (select product_name, sum(kg) as total from day_items
              where kg is not null group by product_name) x),
      'add_ons', (
        select coalesce(jsonb_agg(jsonb_build_object('name', x.name, 'qty', x.total)
                                  order by x.name), '[]'::jsonb)
        from (select chosen ->> 'name' as name, sum(i.qty) as total
              from day_items i cross join lateral jsonb_array_elements(i.add_ons) chosen
              group by chosen ->> 'name') x),
      'freebies', (
        select coalesce(jsonb_agg(jsonb_build_object('item_name', x.item_name, 'qty', x.total)
                                  order by x.item_name), '[]'::jsonb)
        from (select f.item_name, sum(f.qty) as total
              from order_freebies f join day_orders o on o.id = f.order_id
              group by f.item_name) x),
      'orders', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'order_no', o.order_no, 'customer_name', o.customer_name,
                 'time_slot', o.time_slot, 'fulfillment', o.fulfillment, 'status', o.status,
                 'balance_due', o.balance_due) order by o.time_slot, o.order_no), '[]'::jsonb)
        from day_orders o))
  );
end $$;

-- ---------------------------------------------------------------- admin: stock
create or replace function adjust_stock(p_item_id uuid, p_change numeric, p_reason movement_reason,
                                        p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_item inventory_items;
begin
  if not is_admin() then
    raise exception 'FORBIDDEN: admin only';
  end if;
  if p_reason not in ('purchase', 'spoilage', 'adjustment') then
    raise exception 'INVALID_REASON: use purchase, spoilage or adjustment';
  end if;
  if p_change is null or p_change = 0
     or (p_reason = 'purchase' and p_change < 0)
     or (p_reason = 'spoilage' and p_change > 0) then
    raise exception 'INVALID_AMOUNT: purchase adds stock, spoilage removes it';
  end if;

  select * into v_item from inventory_items where id = p_item_id for update;
  if not found then
    raise exception 'ITEM_NOT_FOUND: no such item';
  end if;
  if v_item.on_hand + p_change < v_item.reserved then
    raise exception 'STOCK_BELOW_RESERVED: % reserved for orders', trim_scale(v_item.reserved);
  end if;

  update inventory_items set on_hand = on_hand + p_change where id = p_item_id;

  insert into stock_movements (item_id, on_hand_change, reason, user_id, note)
  values (p_item_id, p_change, p_reason, auth.uid(), nullif(trim(p_note), ''));
end $$;

create or replace function set_stock_count(p_item_id uuid, p_counted numeric, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_item inventory_items;
begin
  if not is_admin() then
    raise exception 'FORBIDDEN: admin only';
  end if;
  if p_counted is null or p_counted < 0 then
    raise exception 'INVALID_AMOUNT: enter the counted quantity';
  end if;

  select * into v_item from inventory_items where id = p_item_id for update;
  if not found then
    raise exception 'ITEM_NOT_FOUND: no such item';
  end if;
  if p_counted < v_item.reserved then
    raise exception 'STOCK_BELOW_RESERVED: % reserved for orders', trim_scale(v_item.reserved);
  end if;

  update inventory_items set on_hand = p_counted where id = p_item_id;

  insert into stock_movements (item_id, on_hand_change, reason, user_id, note)
  values (p_item_id, p_counted - v_item.on_hand, 'count', auth.uid(), nullif(trim(p_note), ''));
end $$;

-- ---------------------------------------------------------------- admin: reports
-- Completed orders with the Manila day they were completed. A sale counts on that day.
create or replace function completed_sales()
returns table (order_id uuid, total numeric, day date)
language sql stable set search_path = public as $$
  select o.id, o.total, (h.created_at at time zone 'Asia/Manila')::date
  from orders o
  join order_status_history h on h.order_id = o.id and h.to_status = 'completed'
  where o.status = 'completed';
$$;

create or replace function get_dashboard(p_date date)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_settings settings;
begin
  if not is_admin() then
    raise exception 'FORBIDDEN: admin only';
  end if;

  select * into v_settings from settings where id = 1;

  return jsonb_build_object(
    'date', p_date,
    'orders_by_status', (
      select coalesce(jsonb_object_agg(x.status, x.total), '{}'::jsonb)
      from (select status, count(*) as total from orders
            where scheduled_date = p_date group by status) x),
    'sales', (select coalesce(sum(c.total), 0) from completed_sales() c where c.day = p_date),
    'downpayments', (
      select coalesce(sum(p.amount), 0) from payments p
      where p.type = 'downpayment' and (p.paid_at at time zone 'Asia/Manila')::date = p_date),
    'overdue_downpayments', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', o.id, 'order_no', o.order_no, 'customer_name', o.customer_name,
               'customer_mobile', o.customer_mobile, 'downpayment_due_at', o.downpayment_due_at)
               order by o.downpayment_due_at), '[]'::jsonb)
      from orders o
      where o.status = 'awaiting_downpayment' and o.downpayment_due_at < now()),
    'low_stock', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', i.id, 'name', i.name, 'unit', i.unit, 'available', i.on_hand - i.reserved,
               'reorder_level', i.reorder_level) order by i.name), '[]'::jsonb)
      from inventory_items i
      where i.is_active and i.on_hand - i.reserved <= i.reorder_level),
    'capacity', (
      select jsonb_agg(jsonb_build_object(
               'day', g::date,
               'pigs_booked', coalesce(b.pigs, 0),
               'max_pigs', coalesce(c.max_pigs, v_settings.default_max_pigs_per_day),
               'kg_booked', coalesce(b.kg, 0),
               'max_kg', coalesce(c.max_kg, v_settings.default_max_kg_per_day),
               'is_closed', coalesce(c.is_closed, false)) order by g)
      from generate_series(p_date, p_date + 6, interval '1 day') g
      left join daily_capacity c on c.date = g::date
      left join lateral (
        select sum(o.pig_count) as pigs, sum(o.total_kg) as kg from orders o
        where o.scheduled_date = g::date and o.status <> 'cancelled'
      ) b on true));
end $$;

create or replace function report_sales(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'FORBIDDEN: admin only';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from >= 366 then
    raise exception 'INVALID_RANGE: at most 366 days per report';
  end if;

  return jsonb_build_object(
    'days', (
      select jsonb_agg(jsonb_build_object(
               'day', d.day,
               'orders', (select count(*) from orders o
                          where (o.created_at at time zone 'Asia/Manila')::date = d.day),
               'sales', (select coalesce(sum(c.total), 0) from completed_sales() c where c.day = d.day),
               'downpayments', pay.downpayments,
               'cod_collected', pay.cod_collected,
               'refunds', pay.refunds,
               'cancellations', (select count(*) from order_status_history h
                                 where h.to_status = 'cancelled'
                                   and (h.created_at at time zone 'Asia/Manila')::date = d.day))
               order by d.day)
      from (select g::date as day from generate_series(p_from, p_to, interval '1 day') g) d
      cross join lateral (
        select coalesce(sum(p.amount) filter (where p.type = 'downpayment'), 0) as downpayments,
               coalesce(sum(p.amount) filter (where p.type = 'cod_balance'), 0) as cod_collected,
               coalesce(sum(p.amount) filter (where p.type = 'refund'), 0) as refunds
        from payments p
        where (p.paid_at at time zone 'Asia/Manila')::date = d.day
      ) pay),
    'products', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'product_name', x.product_name, 'size_name', x.size_name, 'qty', x.qty, 'kg', x.kg,
               'revenue', x.revenue) order by x.revenue desc, x.product_name), '[]'::jsonb)
      from (
        select i.product_name, i.size_name,
               sum(i.qty) filter (where i.size_id is not null) as qty,
               sum(i.kg) as kg, sum(i.line_total) as revenue
        from order_items i
        join completed_sales() c on c.order_id = i.order_id
        where c.day between p_from and p_to
        group by i.product_name, i.size_name
      ) x));
end $$;

-- ---------------------------------------------------------------- admin: staff accounts
create or replace function set_staff(p_user_id uuid, p_full_name text, p_role user_role, p_is_active boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_name text := trim(p_full_name);
begin
  if not is_admin() then
    raise exception 'FORBIDDEN: admin only';
  end if;
  if p_user_id = auth.uid() and (p_role <> 'admin' or not p_is_active) then
    raise exception 'SELF_LOCKOUT: you cannot remove your own admin access';
  end if;
  if v_name is null or length(v_name) not between 2 and 80 then
    raise exception 'INVALID_NAME: name must be 2 to 80 characters';
  end if;

  update profiles set full_name = v_name, role = p_role, is_active = p_is_active
  where id = p_user_id;
  if not found then
    raise exception 'USER_NOT_FOUND: no such user';
  end if;
end $$;

-- ---------------------------------------------------------------- table permissions
-- Explicit, so behaviour does not depend on a project's "automatically expose new tables" setting.
-- RLS from 0001 still applies on top of every grant here.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant usage on schema public to anon, authenticated;

grant select on settings, categories, products, product_sizes, add_ons,
                freebie_rules, freebie_rule_items
  to anon, authenticated;

grant select on profiles, inventory_items, stock_movements, daily_capacity,
                orders, order_items, order_freebies, order_messages, payments, order_status_history
  to authenticated;

grant insert, update, delete on categories, products, product_sizes, add_ons,
                                freebie_rules, freebie_rule_items, daily_capacity
  to authenticated;
grant update on settings to authenticated;

-- Stock counts change only through functions, so on_hand and reserved are left out.
grant insert (name, kind, unit, reorder_level, is_active),
      update (name, kind, unit, reorder_level, is_active)
  on inventory_items to authenticated;
grant delete on inventory_items to authenticated;

-- ---------------------------------------------------------------- function permissions
revoke execute on all functions in schema public from public, anon, authenticated;

-- RLS policies call these as the signed-in or anonymous role.
grant execute on function is_staff(), is_admin() to anon, authenticated;

grant execute on function
  get_availability(date, date),
  quote_cart(jsonb, fulfillment_type, date),
  place_order(jsonb),
  get_public_order(text, text),
  post_customer_message(text, text, text)
to anon, authenticated;

grant execute on function
  set_order_status(uuid, order_status, text),
  record_payment(uuid, payment_type, numeric, payment_method, text, text),
  post_staff_message(uuid, text),
  get_prep_sheet(date)
to authenticated;

grant execute on function
  adjust_stock(uuid, numeric, movement_reason, text),
  set_stock_count(uuid, numeric, text),
  get_dashboard(date),
  report_sales(date, date),
  set_staff(uuid, text, user_role, boolean)
to authenticated;

-- ---------------------------------------------------------------- storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy product_photos_admin_read on storage.objects for select to authenticated
  using (bucket_id = 'product-photos' and public.is_admin());
create policy product_photos_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'product-photos' and public.is_admin());
create policy product_photos_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'product-photos' and public.is_admin())
  with check (bucket_id = 'product-photos' and public.is_admin());
create policy product_photos_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'product-photos' and public.is_admin());

-- ---------------------------------------------------------------- realtime
alter publication supabase_realtime add table orders, order_messages;
