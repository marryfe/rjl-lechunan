-- set_order_status, record_payment, post_staff_message, get_prep_sheet:
-- PLAN section 12 cases 8-10, sections 6.2 and 7.4.
begin;

do $$
declare
  staff_id uuid;
  d date := pg_temp.manila_day(5);
  o uuid;
  large_cart jsonb := jsonb_build_array(pg_temp.size_line('Large', 1, array['Chopping service']));
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);
  o := pg_temp.new_order('09170000101', d, large_cart);

  -- case 8: confirm reserves pig and freebies
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '4/1', 'case 8 pig reserved');
  perform pg_temp.assert_eq(pg_temp.stock('Lechon sauce bottle'), '80/2', 'case 8 sauce reserved');
  perform pg_temp.assert_eq(pg_temp.stock('Puso tray'), '30/1', 'case 8 puso reserved');
  perform pg_temp.assert_true((select stock_reserved from orders where id = o), 'stock_reserved set');
  perform pg_temp.assert_eq(
    (select count(*)::text from stock_movements where order_id = o and reason = 'reserve' and user_id = staff_id),
    '3', 'one movement per item, with the user');
  perform pg_temp.assert_true(
    (select from_status = 'new' and to_status = 'confirmed' and user_id = staff_id
     from order_status_history where order_id = o and to_status = 'confirmed'), 'history row');

  -- case 8: complete needs the balance paid
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'roasting');
  perform set_order_status(o, 'ready');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''completed'')', o), 'BALANCE_DUE');

  -- case 8: complete after COD payment deducts stock
  perform record_payment(o, 'cod_balance', 11700, 'cash', null, null);
  perform set_order_status(o, 'completed');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '3/0', 'case 8 pig deducted');
  perform pg_temp.assert_eq(pg_temp.stock('Lechon sauce bottle'), '78/0', 'case 8 sauce deducted');
  perform pg_temp.assert_eq(pg_temp.stock('Puso tray'), '29/0', 'case 8 puso deducted');
  perform pg_temp.assert_true((select not stock_reserved from orders where id = o), 'stock_reserved cleared');
  perform pg_temp.assert_true(
    (select on_hand_change = -1 and reserved_change = -1 from stock_movements m
     join inventory_items i on i.id = m.item_id
     where m.order_id = o and m.reason = 'deduct' and i.name = 'Pig - Large (~25 kg)'), 'deduct movement');

  -- a finished order cannot move
  perform pg_temp.as_user(staff_id);
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'', ''x'')', o), 'BAD_TRANSITION');
  perform pg_temp.as_owner();
end $$;

do $$
declare
  staff_id uuid;
  d date := pg_temp.manila_day(6);
  o uuid;
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);

  -- case 8: not enough pigs, and nothing changes
  o := pg_temp.new_order('09170000102', d, jsonb_build_array(pg_temp.size_line('Jumbo', 3)));
  perform pg_temp.as_user(staff_id);
  perform pg_temp.assert_error(format('select set_order_status(%L, ''confirmed'')', o),
    'NOT_ENOUGH_STOCK: Pig - Jumbo (30 kg+) (need 3, have 2)');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Jumbo (30 kg+)'), '2/0', 'pig unchanged');
  perform pg_temp.assert_eq(pg_temp.stock('Lechon sauce bottle'), '78/0', 'sauce unchanged: all or nothing');
  perform pg_temp.assert_eq((select status::text from orders where id = o), 'new', 'status unchanged');
  perform pg_temp.assert_true((select not stock_reserved from orders where id = o), 'flag unchanged');
  perform pg_temp.assert_eq((select count(*)::text from stock_movements where order_id = o), '0', 'no movements');

  -- case 8: cancel after confirm releases stock and frees capacity
  o := pg_temp.new_order('09170000103', d, jsonb_build_array(pg_temp.size_line('Large', 2)));
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'')', o), 'REASON_REQUIRED');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'', ''   '')', o), 'REASON_REQUIRED');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '3/2', 'still reserved after refused cancel');
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'cancelled', 'Customer changed plans');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '3/0', 'case 8 cancel releases pigs');
  perform pg_temp.assert_eq(pg_temp.stock('Lechon sauce bottle'), '78/0', 'case 8 cancel releases freebies');
  perform pg_temp.assert_eq((select cancel_reason from orders where id = o), 'Customer changed plans', 'reason stored');
  perform pg_temp.assert_true((select not stock_reserved from orders where id = o), 'flag cleared on release');
  perform pg_temp.assert_eq(
    (select trim_scale(sum(reserved_change))::text from stock_movements where order_id = o), '0', 'movements balance');

  -- cancelling before confirm touches no stock
  o := pg_temp.new_order('09170000104', d, jsonb_build_array(pg_temp.size_line('Small', 1)));
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'cancelled', 'Duplicate');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq((select count(*)::text from stock_movements where order_id = o), '0', 'no stock moved');
end $$;

do $$
declare
  staff_id uuid;
  d date := pg_temp.manila_day(7);
  o uuid;
  chopping_item uuid;
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);

  -- add-ons with stock are reserved x qty
  update add_ons set inventory_item_id = (select id from inventory_items where name = 'Bilao packaging')
  where name = 'Chopping service';
  o := pg_temp.new_order('09170000105', d, jsonb_build_array(pg_temp.size_line('Small', 2, array['Chopping service'])));
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Bilao packaging'), '40/2', 'add-on stock reserved');

  -- catalog edits after confirming must not unbalance stock
  update add_ons set inventory_item_id = null where name = 'Chopping service';
  update product_sizes set inventory_item_id = null where name = 'Small';
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'cancelled', 'Test');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Bilao packaging'), '40/0', 'release uses what was reserved');
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Small (~15 kg)'), '6/0', 'release ignores catalog edits');
  update product_sizes set inventory_item_id = (select id from inventory_items where name = 'Pig - Small (~15 kg)')
  where name = 'Small';
end $$;

do $$
declare
  staff_id uuid;
  admin_id uuid;
  d date := pg_temp.manila_day(8);
  o uuid;
  cart jsonb := jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1));
  due timestamptz;
  order_no text;
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);
  admin_id := pg_temp.make_user('admin', true);

  -- bad transitions
  o := pg_temp.new_order('09170000106', d, cart);
  perform pg_temp.as_user(staff_id);
  perform pg_temp.assert_error(format('select set_order_status(%L, ''roasting'')', o), 'BAD_TRANSITION');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''ready'')', o), 'BAD_TRANSITION');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''completed'')', o), 'BAD_TRANSITION');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''new'')', o), 'BAD_TRANSITION');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''confirmed'')', gen_random_uuid()), 'ORDER_NOT_FOUND');

  -- downpayment deadline, shown to the customer, and extended by re-entering the state
  perform set_order_status(o, 'awaiting_downpayment');
  perform pg_temp.as_owner();
  select downpayment_due_at, orders.order_no into due, order_no from orders where id = o;
  perform pg_temp.assert_true(due = now() + interval '24 hours', 'deadline is 24 hours out');
  perform pg_temp.assert_true(get_public_order(order_no, '09170000106') ->> 'downpayment_due_at' is not null, 'customer sees deadline');
  update orders set downpayment_due_at = now() - interval '1 hour' where id = o;
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'awaiting_downpayment', 'Extended');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true((select downpayment_due_at from orders where id = o) = now() + interval '24 hours', 'deadline reset');

  -- roasting cannot be cancelled
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform set_order_status(o, 'roasting');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'', ''x'')', o), 'BAD_TRANSITION');

  -- ready: staff cannot cancel, admin can, and stock is released
  perform set_order_status(o, 'ready');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'', ''x'')', o), 'FORBIDDEN');
  perform pg_temp.as_user(admin_id);
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'')', o), 'REASON_REQUIRED');
  perform set_order_status(o, 'cancelled', 'Admin cancel');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq((select status::text from orders where id = o), 'cancelled', 'admin cancelled ready');

  -- pickup orders never go out for delivery
  o := pg_temp.new_order('09170000107', d, cart);
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform set_order_status(o, 'roasting');
  perform set_order_status(o, 'ready');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''out_for_delivery'')', o), 'BAD_TRANSITION');

  -- delivery: out, failed back to ready with a note, out again, delivered
  perform pg_temp.as_owner();
  o := pg_temp.new_order('09170000108', d, cart, '{"fulfillment":"delivery","address":"12 Rizal St"}');
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform set_order_status(o, 'roasting');
  perform set_order_status(o, 'ready');
  perform set_order_status(o, 'out_for_delivery');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''cancelled'', ''x'')', o), 'BAD_TRANSITION');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''ready'')', o), 'REASON_REQUIRED');
  perform set_order_status(o, 'ready', 'Nobody home');
  perform set_order_status(o, 'out_for_delivery');
  perform record_payment(o, 'cod_balance', 750, 'cash', null, null);
  perform set_order_status(o, 'completed');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq((select status::text from orders where id = o), 'completed', 'delivered');
end $$;

do $$
declare
  staff_id uuid;
  d date := pg_temp.manila_day(9);
  o uuid;
  cart jsonb := jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 2));
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);
  o := pg_temp.new_order('09170000109', d, cart);

  -- case 9: payments
  perform pg_temp.as_user(staff_id);
  perform record_payment(o, 'downpayment', 500, 'gcash', 'REF123', 'First payment');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true((select amount_paid = 500 and balance_due = 1000 from orders where id = o), 'payment added');
  perform pg_temp.assert_true(
    (select method = 'gcash' and reference_no = 'REF123' and received_by = staff_id from payments where order_id = o), 'payment stored');

  perform pg_temp.as_user(staff_id);
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 1000.01, ''cash'', null, null)', o), 'OVERPAY');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 0, ''cash'', null, null)', o), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', -5, ''cash'', null, null)', o), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 1.005, ''cash'', null, null)', o), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select record_payment(%L, ''refund'', 500.01, ''cash'', null, null)', o), 'REFUND_TOO_LARGE');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 1, ''cash'', null, null)', gen_random_uuid()), 'ORDER_NOT_FOUND');

  perform record_payment(o, 'refund', 200, 'cash', null, 'Partial refund');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true((select amount_paid = 300 from orders where id = o), 'case 9 refund reduces amount_paid');

  -- cancelled orders take refunds only
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'cancelled', 'Test');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 10, ''cash'', null, null)', o), 'ORDER_CLOSED');
  perform record_payment(o, 'refund', 300, 'gcash', 'REF456', null);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true((select amount_paid = 0 from orders where id = o), 'refund on cancelled allowed');
end $$;

do $$
declare
  staff_id uuid;
  inactive_id uuid;
  d date := pg_temp.manila_day(10);
  o uuid;
  o2 uuid;
  no text;
  sheet jsonb;
begin
  perform pg_temp.as_owner();
  staff_id := pg_temp.make_user('staff', true);
  inactive_id := pg_temp.make_user('staff', false);
  o := pg_temp.new_order('09170000110', d, jsonb_build_array(
    pg_temp.size_line('Large', 2, array['Chopping service']), pg_temp.kg_line('Chopped Lechon', 2.5)));
  o2 := pg_temp.new_order('09170000111', d, jsonb_build_array(pg_temp.size_line('Medium', 1)));
  no := (select order_no from orders where id = o);

  -- case 10: customers and inactive staff are locked out
  perform pg_temp.as_anon();
  perform pg_temp.assert_error('select * from orders', 'permission denied');
  perform pg_temp.assert_error(format('select set_order_status(%L, ''confirmed'')', o), 'permission denied');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 1, ''cash'', null, null)', o), 'permission denied');
  perform pg_temp.assert_error(format('select post_staff_message(%L, ''hi'')', o), 'permission denied');
  perform pg_temp.assert_error(format('select get_prep_sheet(%L)', d), 'permission denied');

  perform pg_temp.as_user(inactive_id);
  perform pg_temp.assert_error(format('select set_order_status(%L, ''confirmed'')', o), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select record_payment(%L, ''downpayment'', 1, ''cash'', null, null)', o), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select post_staff_message(%L, ''hi'')', o), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select get_prep_sheet(%L)', d), 'FORBIDDEN');
  perform pg_temp.assert_eq((select count(*)::text from orders), '0', 'inactive staff sees no orders');

  -- staff messages
  perform pg_temp.as_user(staff_id);
  perform post_staff_message(o, '  Please send a downpayment  ');
  perform pg_temp.assert_error(format('select post_staff_message(%L, ''   '')', o), 'INVALID_MESSAGE');
  perform pg_temp.assert_error(format('select post_staff_message(%L, ''hi'')', gen_random_uuid()), 'ORDER_NOT_FOUND');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    (select m.sender = 'staff' and m.staff_id is not null and m.body = 'Please send a downpayment'
     from order_messages m where m.order_id = o), 'staff message stored');

  -- prep sheet
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o2, 'cancelled', 'Test');
  sheet := get_prep_sheet(d);
  perform pg_temp.assert_eq(sheet -> 'pigs_by_size' -> 0 ->> 'size_name', 'Large', 'prep size');
  perform pg_temp.assert_eq(sheet -> 'pigs_by_size' -> 0 ->> 'count', '2', 'prep count');
  perform pg_temp.assert_eq(jsonb_array_length(sheet -> 'pigs_by_size')::text, '1', 'cancelled excluded');
  perform pg_temp.assert_true((sheet -> 'kg_by_product' -> 0 ->> 'kg')::numeric = 2.5, 'prep kg');
  perform pg_temp.assert_eq(sheet -> 'add_ons' -> 0 ->> 'name', 'Chopping service', 'prep add-on');
  perform pg_temp.assert_eq(sheet -> 'add_ons' -> 0 ->> 'qty', '2', 'prep add-on qty');
  perform pg_temp.assert_true(
    (select (f ->> 'qty')::numeric = 4 from jsonb_array_elements(sheet -> 'freebies') f
     where f ->> 'item_name' = 'Lechon sauce bottle'), 'prep freebies');
  perform pg_temp.assert_eq(jsonb_array_length(sheet -> 'orders')::text, '1', 'prep order list');
  perform pg_temp.assert_eq(sheet -> 'orders' -> 0 ->> 'order_no', no, 'prep order number');
  perform pg_temp.assert_true((sheet -> 'orders' -> 0 ->> 'balance_due')::numeric = 25275, 'prep balance');
  perform pg_temp.as_owner();
end $$;

rollback;
