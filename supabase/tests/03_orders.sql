-- get_availability, place_order, get_public_order, post_customer_message:
-- PLAN section 12 cases 5-7, sections 6.1, 6.3 and 7.3.
begin;

do $$
declare
  a record;
  day_a date := pg_temp.manila_day(5);
  day_b date := pg_temp.manila_day(6);
  placed jsonb;
begin
  perform pg_temp.as_anon();

  -- case 5: availability reasons
  select * into a from get_availability(pg_temp.manila_day(1), pg_temp.manila_day(1));
  perform pg_temp.assert_eq(a.reason, 'TOO_SOON', 'case 5 too soon');
  perform pg_temp.assert_true(a.is_open = false, 'too soon is not open');

  select * into a from get_availability(pg_temp.manila_day(2), pg_temp.manila_day(2));
  perform pg_temp.assert_true(a.is_open, 'lead day exactly is open');
  perform pg_temp.assert_true(a.reason is null, 'open day has no reason');
  perform pg_temp.assert_true(a.pigs_left = 10 and a.kg_left = 50, 'default caps apply');

  select * into a from get_availability(pg_temp.manila_day(60), pg_temp.manila_day(60));
  perform pg_temp.assert_true(a.is_open, 'last booking day is open');
  select * into a from get_availability(pg_temp.manila_day(61), pg_temp.manila_day(61));
  perform pg_temp.assert_eq(a.reason, 'TOO_FAR', 'past booking window');

  perform pg_temp.assert_eq(
    (select count(*)::text from get_availability(pg_temp.manila_day(1), pg_temp.manila_day(62))), '62',
    '62 days allowed');
  perform pg_temp.assert_error(
    format('select * from get_availability(%L, %L)', pg_temp.manila_day(1), pg_temp.manila_day(63)),
    'INVALID_RANGE');

  perform pg_temp.as_owner();
  insert into daily_capacity (date, max_pigs, max_kg, is_closed) values (day_a, 5, 20, true);
  perform pg_temp.as_anon();
  select * into a from get_availability(day_a, day_a);
  perform pg_temp.assert_eq(a.reason, 'CLOSED', 'case 5 closed');

  perform pg_temp.as_owner();
  update daily_capacity set is_closed = false, max_pigs = 0, max_kg = 0 where date = day_a;
  perform pg_temp.as_anon();
  select * into a from get_availability(day_a, day_a);
  perform pg_temp.assert_eq(a.reason, 'FULL', 'no pigs and no kg is full');

  perform pg_temp.as_owner();
  update daily_capacity set max_pigs = 0, max_kg = 20 where date = day_a;
  perform pg_temp.as_anon();
  select * into a from get_availability(day_a, day_a);
  perform pg_temp.assert_true(a.is_open, 'kg left keeps the day open');

  -- case 5: orders use capacity, cancelling frees it
  placed := place_order(pg_temp.order_json('09170000001', day_b,
    jsonb_build_array(pg_temp.size_line('Large', 2), pg_temp.kg_line('Chopped Lechon', 3))));
  select * into a from get_availability(day_b, day_b);
  perform pg_temp.assert_true(a.pigs_left = 8 and a.kg_left = 47, 'case 5 caps reduce after order');

  perform pg_temp.as_owner();
  update orders set status = 'cancelled' where order_no = placed ->> 'order_no';
  perform pg_temp.as_anon();
  select * into a from get_availability(day_b, day_b);
  perform pg_temp.assert_true(a.pigs_left = 10 and a.kg_left = 50, 'case 5 cancel frees capacity');
end $$;

do $$
declare
  d date := pg_temp.manila_day(7);
  cart jsonb := jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1));
  placed jsonb;
  o orders;
  stmt text := 'select place_order(%L::jsonb)';
begin
  perform pg_temp.as_anon();

  -- case 6: a valid order, written with server prices
  placed := place_order(pg_temp.order_json('+639171234567', d, jsonb_build_array(
    pg_temp.size_line('Large', 1, array['Chopping service']), pg_temp.kg_line('Lechon Belly', 2)))
    || jsonb_build_object('note', 'Can I pay by GCash?', 'total', 1));
  perform pg_temp.assert_true(placed ->> 'order_no' like 'RJL-%', 'case 6 order number');
  perform pg_temp.assert_true((placed ->> 'total')::numeric = 13500, 'client total is ignored');
  perform pg_temp.assert_eq(placed ->> 'time_slot', '09:00-11:00', 'returns slot');
  perform pg_temp.assert_eq(placed ->> 'scheduled_date', d::text, 'returns date');

  perform pg_temp.as_owner();
  select * into o from orders where order_no = placed ->> 'order_no';
  perform pg_temp.assert_eq(o.customer_mobile, '09171234567', 'mobile normalised');
  perform pg_temp.assert_eq(o.status::text, 'new', 'status new');
  perform pg_temp.assert_true(o.pig_count = 1 and o.total_kg = 2, 'pig count and kg stored');
  perform pg_temp.assert_true(o.stock_reserved = false, 'stock not reserved at placement');
  perform pg_temp.assert_eq((select count(*)::text from order_items where order_id = o.id), '2', 'lines stored');
  perform pg_temp.assert_true(
    (select unit_price = 900 and kg = 2 and qty = 1 and size_id is null and line_total = 1800
     from order_items where order_id = o.id and product_name = 'Lechon Belly'), 'kilo line copied');
  perform pg_temp.assert_true(
    (select unit_price = 11500 and size_name = 'Large' and line_total = 11700 and add_ons -> 0 ->> 'name' = 'Chopping service'
     from order_items where order_id = o.id and size_id is not null), 'size line copied');
  perform pg_temp.assert_eq((select sum(qty)::text from order_freebies where order_id = o.id and item_name = 'Lechon sauce bottle'), '2.00', 'freebies stored');
  perform pg_temp.assert_true(
    (select from_status is null and to_status = 'new' from order_status_history where order_id = o.id), 'history row');
  perform pg_temp.assert_eq(
    (select sender::text || ':' || body from order_messages where order_id = o.id),
    'customer:Can I pay by GCash?', 'note becomes first message');

  -- prices copied at order time survive later edits
  update product_sizes set price = 99999 where name = 'Large';
  perform pg_temp.assert_true(
    (select unit_price = 11500 from order_items where order_id = o.id and size_id is not null), 'old order keeps old price');
  update product_sizes set price = 11500 where name = 'Large';

  -- case 6: rate limit, fourth order in an hour from the same mobile
  perform pg_temp.as_anon();
  perform place_order(pg_temp.order_json('09170000002', d, cart));
  perform place_order(pg_temp.order_json('09170000002', d, cart));
  perform place_order(pg_temp.order_json('09170000002', d, cart));
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000002', d, cart)), 'RATE_LIMIT');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('+639170000002', d, cart)), 'RATE_LIMIT');

  -- field checks
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('12345', d, cart)), 'INVALID_MOBILE');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('0917000000', d, cart)), 'INVALID_MOBILE');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"customer_name":"J"}'), 'INVALID_NAME');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"fulfillment":"drone"}'), 'INVALID_FULFILLMENT');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"fulfillment":"delivery"}'), 'ADDRESS_REQUIRED');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"fulfillment":"delivery","address":"   "}'), 'ADDRESS_REQUIRED');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"time_slot":"03:00-04:00"}'), 'INVALID_SLOT');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"scheduled_date":"soon"}'), 'DATE_UNAVAILABLE');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || '{"scheduled_date":"2026-13-45"}'), 'DATE_UNAVAILABLE');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', pg_temp.manila_day(1), cart)), 'DATE_UNAVAILABLE');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, cart) || jsonb_build_object('note', repeat('x', 1001))), 'INVALID_MESSAGE');
  perform pg_temp.assert_error(format(stmt, pg_temp.order_json('09170000003', d, '[]')), 'EMPTY_CART');

  -- delivery order stores the address
  placed := place_order(pg_temp.order_json('09170000003', d, cart)
    || '{"fulfillment":"delivery","address":"12 Rizal St","landmark":"Near the plaza"}');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(
    (select address || '/' || landmark from orders where order_no = placed ->> 'order_no'),
    '12 Rizal St/Near the plaza', 'address stored');
end $$;

do $$
declare
  d date := pg_temp.manila_day(8);
  stmt text := 'select place_order(%L::jsonb)';
begin
  -- case 6: capacity
  perform pg_temp.as_owner();
  insert into daily_capacity (date, max_pigs, max_kg) values (d, 1, 3);
  perform pg_temp.as_anon();
  perform place_order(pg_temp.order_json('09170000004', d, jsonb_build_array(pg_temp.size_line('Small', 1))));
  perform pg_temp.assert_error(
    format(stmt, pg_temp.order_json('09170000005', d, jsonb_build_array(pg_temp.size_line('Small', 1)))), 'CAPACITY_FULL');
  perform pg_temp.assert_error(
    format(stmt, pg_temp.order_json('09170000005', d, jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 3.5)))), 'CAPACITY_FULL');
  perform place_order(pg_temp.order_json('09170000005', d, jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 3))));
  perform pg_temp.assert_error(
    format(stmt, pg_temp.order_json('09170000006', d, jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1)))), 'CAPACITY_FULL');
end $$;

do $$
declare
  d date := pg_temp.manila_day(9);
  placed jsonb;
  order_no text;
  r jsonb;
  staff_id uuid;
  i int;
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);
  perform pg_temp.as_anon();
  placed := place_order(pg_temp.order_json('09170000007', d, jsonb_build_array(pg_temp.size_line('Large', 1)))
    || '{"note":"Hello"}');
  order_no := placed ->> 'order_no';

  -- case 7: lookups
  perform pg_temp.assert_true(get_public_order(order_no, '09179999999') is null, 'case 7 wrong mobile');
  perform pg_temp.assert_true(get_public_order('RJL-0', '09170000007') is null, 'unknown order');
  perform pg_temp.assert_true(get_public_order(order_no, 'nonsense') is null, 'bad mobile');

  perform pg_temp.as_owner();
  insert into order_messages (order_id, sender, staff_id, body, created_at)
  select id, 'staff', staff_id, 'Please send a downpayment', clock_timestamp()
  from orders where orders.order_no = placed ->> 'order_no';
  perform pg_temp.as_anon();

  r := get_public_order(order_no, '+639170000007');
  perform pg_temp.assert_eq(r ->> 'status', 'new', 'case 7 right mobile, +63 form');
  perform pg_temp.assert_true((r ->> 'total')::numeric = 11500, 'total shown');
  perform pg_temp.assert_true((r ->> 'balance_due')::numeric = 11500, 'balance shown');
  perform pg_temp.assert_eq(jsonb_array_length(r -> 'items')::text, '1', 'items shown');
  perform pg_temp.assert_eq(jsonb_array_length(r -> 'freebies')::text, '2', 'freebies shown');
  perform pg_temp.assert_eq(r -> 'status_history' -> 0 ->> 'status', 'new', 'history shown');
  perform pg_temp.assert_eq(jsonb_array_length(r -> 'messages')::text, '2', 'messages shown');
  perform pg_temp.assert_eq(r -> 'messages' -> 1 ->> 'sender', 'staff', 'messages in order');
  perform pg_temp.assert_true(r::text not like '%' || staff_id || '%', 'case 7 no staff id');
  perform pg_temp.assert_true(r::text not like '%staff_id%', 'case 7 no staff_id field');
  perform pg_temp.assert_true(r::text not like '%user_id%', 'no user ids in history');

  -- customer messages
  perform post_customer_message(order_no, '09170000007', '  Thanks!  ');
  perform pg_temp.assert_eq(get_public_order(order_no, '09170000007') -> 'messages' -> 2 ->> 'body', 'Thanks!', 'message posted');
  perform pg_temp.assert_error(format('select post_customer_message(%L, %L, %L)', order_no, '09179999999', 'hi'), 'ORDER_NOT_FOUND');
  perform pg_temp.assert_error(format('select post_customer_message(%L, %L, %L)', order_no, '09170000007', '   '), 'INVALID_MESSAGE');
  perform pg_temp.assert_error(format('select post_customer_message(%L, %L, %L)', order_no, '09170000007', repeat('x', 1001)), 'INVALID_MESSAGE');

  -- 30 customer messages a day; the checkout note and "Thanks!" count
  for i in 1..28 loop
    perform post_customer_message(order_no, '09170000007', 'Message ' || i);
  end loop;
  perform pg_temp.assert_error(format('select post_customer_message(%L, %L, %L)', order_no, '09170000007', 'one more'), 'RATE_LIMIT');

  perform pg_temp.as_owner();
  update orders set status = 'completed' where orders.order_no = placed ->> 'order_no';
  perform pg_temp.as_anon();
  perform pg_temp.assert_error(format('select post_customer_message(%L, %L, %L)', order_no, '09170000007', 'hi'), 'ORDER_CLOSED');

  -- internal helpers are not callable by customers
  perform pg_temp.assert_error('select manila_today()', 'permission denied');
end $$;

rollback;
