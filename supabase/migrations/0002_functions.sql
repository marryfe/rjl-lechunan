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

-- @@FUNCTIONS@@

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

-- @@GRANTS@@

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
