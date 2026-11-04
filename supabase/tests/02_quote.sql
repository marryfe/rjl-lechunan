-- quote_cart: PLAN section 12 cases 1-4, section 7.1 and 7.2.
begin;

do $$
declare
  d date := pg_temp.manila_day(5);
  q jsonb;
begin
  perform pg_temp.as_anon();

  -- case 1: Large + Chopping service
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Large', 1, array['Chopping service'])), 'pickup', d);
  perform pg_temp.assert_true((q -> 'lines' -> 0 ->> 'line_total')::numeric = 11700, 'case 1 line total');
  perform pg_temp.assert_true((q -> 'lines' -> 0 ->> 'unit_price')::numeric = 11500, 'case 1 unit price');
  perform pg_temp.assert_eq(q -> 'lines' -> 0 ->> 'size_name', 'Large', 'case 1 size name');
  perform pg_temp.assert_eq(q -> 'lines' -> 0 -> 'add_ons' -> 0 ->> 'name', 'Chopping service', 'case 1 add-on');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 2, 'case 1 sauce');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 1, 'case 1 puso');
  perform pg_temp.assert_true((q ->> 'pig_count')::int = 1, 'case 1 pig count');
  perform pg_temp.assert_true((q ->> 'total')::numeric = 11700, 'case 1 total');

  -- qty multiplies size and add-ons, and size freebies
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Large', 2, array['Chopping service'])), 'pickup', d);
  perform pg_temp.assert_true((q ->> 'subtotal')::numeric = 23400, 'qty multiplies add-ons');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 4, 'qty multiplies freebies');

  -- case 2: kilo items and the 5 kg rule
  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 5)), 'pickup', d);
  perform pg_temp.assert_true((q ->> 'subtotal')::numeric = 3750, 'case 2 5 kg price');
  perform pg_temp.assert_true((q ->> 'total_kg')::numeric = 5, 'case 2 total kg');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 1, 'case 2 5 kg sauce');

  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 4.5)), 'pickup', d);
  perform pg_temp.assert_true(jsonb_array_length(q -> 'freebies') = 0, 'case 2 4.5 kg no freebie');

  perform pg_temp.assert_error(
    format('select quote_cart(%L::jsonb, ''pickup'', null)',
           jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1.25))), 'INVALID_KG');

  -- case 3: stacking
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Jumbo', 1), pg_temp.size_line('Large', 1)), 'pickup', d);
  perform pg_temp.assert_true((q ->> 'subtotal')::numeric = 25500, 'case 3 subtotal');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon paksiw pack') = 1, 'case 3 paksiw');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 4, 'case 3 sauce');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 2, 'case 3 puso');
  perform pg_temp.assert_eq(
    (select count(*)::text from jsonb_array_elements(q -> 'freebies') f
     where f ->> 'item_name' = 'Lechon sauce bottle'), '1', 'same item merges into one line');
  perform pg_temp.assert_true(
    (select f -> 'rule_id' = 'null'::jsonb from jsonb_array_elements(q -> 'freebies') f
     where f ->> 'item_name' = 'Lechon sauce bottle'), 'merged line has no single rule_id');
  perform pg_temp.assert_true(
    (select f ->> 'rule_id' is not null from jsonb_array_elements(q -> 'freebies') f
     where f ->> 'item_name' = 'Lechon paksiw pack'), 'single-rule line keeps rule_id');

  perform pg_temp.as_owner();
  update settings set freebies_stack = false;
  update freebie_rules set priority = 10 where name = 'PHP 15,000 and up';
  perform pg_temp.as_anon();
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Jumbo', 1), pg_temp.size_line('Large', 1)), 'pickup', d);
  perform pg_temp.assert_eq(jsonb_array_length(q -> 'freebies')::text, '1', 'case 3 no stacking keeps one');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon paksiw pack') = 1, 'case 3 highest priority wins');
  perform pg_temp.as_owner();
  update settings set freebies_stack = true;
  update freebie_rules set priority = 0;
end $$;

do $$
declare
  d date := pg_temp.manila_day(5);
  q jsonb;
begin
  -- case 4: no stock for a freebie
  perform pg_temp.as_owner();
  update inventory_items set on_hand = 0 where name = 'Lechon paksiw pack';
  perform pg_temp.as_anon();
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Jumbo', 2)), 'pickup', d);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon paksiw pack') = 0, 'case 4 freebie removed');
  perform pg_temp.assert_eq(q -> 'skipped_freebies' -> 0 ->> 'rule_name', 'PHP 15,000 and up', 'case 4 skipped rule');
  perform pg_temp.assert_eq(q -> 'skipped_freebies' -> 0 ->> 'reason', 'OUT_OF_STOCK', 'case 4 reason');

  -- reserved stock is not available
  perform pg_temp.as_owner();
  update inventory_items set on_hand = 5, reserved = 5 where name = 'Lechon paksiw pack';
  perform pg_temp.as_anon();
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Jumbo', 2)), 'pickup', d);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon paksiw pack') = 0, 'reserved stock not available');

  -- two rules share an item that only covers one: the second is skipped, whole rule at a time
  perform pg_temp.as_owner();
  update inventory_items set on_hand = 20, reserved = 0 where name = 'Lechon paksiw pack';
  update inventory_items set on_hand = 3, reserved = 0 where name = 'Lechon sauce bottle';
  perform pg_temp.as_anon();
  q := quote_cart(jsonb_build_array(pg_temp.size_line('Jumbo', 1), pg_temp.size_line('Large', 1)), 'pickup', d);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 2, 'shared stock never over-promised');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 1, 'skipped rule gives none of its items');
  perform pg_temp.assert_eq(jsonb_array_length(q -> 'skipped_freebies')::text, '1', 'one rule skipped');
  perform pg_temp.as_owner();
  update inventory_items set on_hand = 80 where name = 'Lechon sauce bottle';
  update inventory_items set on_hand = 20, reserved = 0 where name = 'Lechon paksiw pack';
end $$;

do $$
declare
  d date := pg_temp.manila_day(5);
  q jsonb;
  rule_id uuid;
begin
  -- date windows and promo rules
  perform pg_temp.as_owner();
  insert into freebie_rules (name, trigger, start_date, end_date)
  values ('Promo', 'promo_dates', d, d) returning id into rule_id;
  insert into freebie_rule_items (rule_id, inventory_item_id, qty)
  select rule_id, id, 1 from inventory_items where name = 'Puso tray';

  perform pg_temp.as_anon();
  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1)), 'pickup', d);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 1, 'promo fires on its date');
  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1)), 'pickup', d + 1);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 0, 'promo off outside its dates');
  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1)), 'pickup', null);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 0, 'dated rule waits for a date');

  -- delivery fee
  perform pg_temp.as_owner();
  update settings set delivery_fee = 150;
  perform pg_temp.as_anon();
  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 2)), 'delivery', d);
  perform pg_temp.assert_true((q ->> 'delivery_fee')::numeric = 150, 'delivery fee added');
  perform pg_temp.assert_true((q ->> 'total')::numeric = 1650, 'total includes fee');
  q := quote_cart(jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 2)), 'pickup', d);
  perform pg_temp.assert_true((q ->> 'delivery_fee')::numeric = 0, 'pickup has no fee');

  perform pg_temp.as_owner();
  update settings set delivery_enabled = false, delivery_fee = 0;
  perform pg_temp.as_anon();
  perform pg_temp.assert_error(
    format('select quote_cart(%L::jsonb, ''delivery'', null)',
           jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 2))), 'DELIVERY_DISABLED');
  perform pg_temp.as_owner();
  update settings set delivery_enabled = true;
end $$;

do $$
declare
  whole uuid := (select id from products where name = 'Whole Lechon');
  chopped uuid := (select id from products where name = 'Chopped Lechon');
  large uuid := (select id from product_sizes where name = 'Large');
  addon uuid := (select id from add_ons where name = 'Chopping service');
  stmt text := 'select quote_cart(%L::jsonb, ''pickup'', null)';
begin
  perform pg_temp.as_anon();
  -- validation errors
  perform pg_temp.assert_error(format(stmt, '[]'), 'EMPTY_CART');
  perform pg_temp.assert_error(format(stmt, '{"a":1}'), 'EMPTY_CART');
  perform pg_temp.assert_error(format(stmt, '[{"product_id":"not-a-uuid","kg":1}]'), 'PRODUCT_UNAVAILABLE');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', gen_random_uuid(), 'kg', 1))), 'PRODUCT_UNAVAILABLE');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', chopped, 'size_id', large, 'qty', 1))), 'SIZE_MISMATCH');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', gen_random_uuid(), 'qty', 1))), 'SIZE_MISMATCH');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'kg', 2))), 'SIZE_MISMATCH');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', large, 'qty', 0))), 'INVALID_QTY');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', large, 'qty', 11))), 'INVALID_QTY');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', large, 'qty', 1.5))), 'INVALID_QTY');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', large))), 'INVALID_QTY');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', chopped))), 'INVALID_KG');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', chopped, 'kg', 'abc'))), 'INVALID_KG');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', chopped, 'kg', 0.5))), 'INVALID_KG');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', chopped, 'kg', 50.5))), 'INVALID_KG');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', large, 'qty', 1, 'add_on_ids', jsonb_build_array(gen_random_uuid())))), 'ADDON_MISMATCH');
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(jsonb_build_object('product_id', chopped, 'kg', 2, 'add_on_ids', jsonb_build_array(addon)))), 'ADDON_MISMATCH');

  -- the same add-on sent twice is charged once
  perform pg_temp.assert_true(
    (quote_cart(jsonb_build_array(jsonb_build_object('product_id', whole, 'size_id', large, 'qty', 1,
      'add_on_ids', jsonb_build_array(addon, addon))), 'pickup', null) ->> 'subtotal')::numeric = 11700,
    'duplicate add-on charged once');

  -- inactive items cannot be sold
  perform pg_temp.as_owner();
  update product_sizes set is_active = false where id = large;
  perform pg_temp.as_anon();
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(pg_temp.size_line('Large', 1))), 'PRODUCT_UNAVAILABLE');
  perform pg_temp.as_owner();
  update product_sizes set is_active = true where id = large;
  update products set is_active = false where id = chopped;
  perform pg_temp.as_anon();
  perform pg_temp.assert_error(format(stmt, jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 2))), 'PRODUCT_UNAVAILABLE');
end $$;

do $$
declare
  d date := pg_temp.manila_day(20);
  q jsonb;
  cart jsonb := jsonb_build_array(pg_temp.size_line('Jumbo', 1), pg_temp.size_line('Large', 1));
begin
  -- stacking off: when the top rule is out of stock, the next rule with stock is given
  perform pg_temp.as_owner();
  update settings set freebies_stack = false;
  update freebie_rules set priority = 10 where name = 'PHP 15,000 and up';
  update freebie_rules set priority = 5 where name = 'Large/Jumbo bundle (Jumbo)';
  update inventory_items set on_hand = 0 where name = 'Lechon paksiw pack';
  perform pg_temp.as_anon();
  q := quote_cart(cart, 'pickup', d);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon paksiw pack') = 0, 'out of stock rule gives nothing');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 2, 'falls back to the next rule');
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Puso tray') = 1, 'next rule given whole, once');
  perform pg_temp.assert_eq(jsonb_array_length(q -> 'skipped_freebies')::text, '1', 'skipped rule still listed');

  -- a rule with no items does not count as the freebie
  perform pg_temp.as_owner();
  insert into freebie_rules (name, trigger, threshold, priority) values ('Empty rule', 'order_amount', 1, 20);
  perform pg_temp.as_anon();
  q := quote_cart(cart, 'pickup', d);
  perform pg_temp.assert_true(pg_temp.freebie_qty(q, 'Lechon sauce bottle') = 2, 'empty rule is passed over');

  -- nothing left anywhere: no freebie, and every rule is listed as skipped
  perform pg_temp.as_owner();
  update inventory_items set on_hand = 0 where name = 'Lechon sauce bottle';
  perform pg_temp.as_anon();
  q := quote_cart(cart, 'pickup', d);
  perform pg_temp.assert_eq(jsonb_array_length(q -> 'freebies')::text, '0', 'no stock anywhere gives nothing');
  perform pg_temp.assert_eq(jsonb_array_length(q -> 'skipped_freebies')::text, '3', 'all rules listed as skipped');
  perform pg_temp.as_owner();
end $$;

rollback;
