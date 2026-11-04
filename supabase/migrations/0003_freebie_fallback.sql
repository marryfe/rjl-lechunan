-- Owner decision: with freebies_stack off, a rule that is out of stock no longer leaves the customer
-- with nothing. quote_cart moves on to the next fired rule that can actually be given.
-- Existing grants on the function are kept.

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
  v_given boolean := false;
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
        v_given := true;
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

    -- Without stacking the customer gets one rule: the best one that could actually be given.
    exit when v_given and not v_settings.freebies_stack;
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
