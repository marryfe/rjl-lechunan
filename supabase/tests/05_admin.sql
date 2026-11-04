-- adjust_stock, set_stock_count, get_dashboard, report_sales, set_staff: PLAN section 6.4.
begin;

do $$
declare
  admin_id uuid;
  staff_id uuid;
  pig uuid := (select id from inventory_items where name = 'Pig - Large (~25 kg)');
  o uuid;
begin
  perform pg_temp.as_owner();
  admin_id := pg_temp.make_user('admin', true);
  staff_id := pg_temp.make_user('staff', true);

  -- stock in, spoilage, adjustment
  perform pg_temp.as_user(admin_id);
  perform adjust_stock(pig, 3, 'purchase', 'Delivery from farm');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '7/0', 'purchase adds');
  perform pg_temp.assert_true(
    (select on_hand_change = 3 and reason = 'purchase' and user_id = admin_id and note = 'Delivery from farm'
     from stock_movements where item_id = pig), 'movement logged');

  perform pg_temp.as_user(admin_id);
  perform adjust_stock(pig, -1, 'spoilage', null);
  perform adjust_stock(pig, -1, 'adjustment', null);
  perform adjust_stock(pig, 1, 'adjustment', null);
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '6/0', 'spoilage and adjustment apply');

  -- wrong sign or reason
  perform pg_temp.as_user(admin_id);
  perform pg_temp.assert_error(format('select adjust_stock(%L, -1, ''purchase'', null)', pig), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select adjust_stock(%L, 1, ''spoilage'', null)', pig), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select adjust_stock(%L, 0, ''adjustment'', null)', pig), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select adjust_stock(%L, 1, ''reserve'', null)', pig), 'INVALID_REASON');
  perform pg_temp.assert_error(format('select adjust_stock(%L, 1, ''count'', null)', pig), 'INVALID_REASON');
  perform pg_temp.assert_error(format('select adjust_stock(%L, 1, ''purchase'', null)', gen_random_uuid()), 'ITEM_NOT_FOUND');

  -- stock can never drop below what is reserved
  perform pg_temp.as_owner();
  o := pg_temp.new_order('09170000201', pg_temp.manila_day(5), jsonb_build_array(pg_temp.size_line('Large', 2)));
  perform pg_temp.as_user(staff_id);
  perform set_order_status(o, 'confirmed');
  perform pg_temp.as_user(admin_id);
  perform pg_temp.assert_error(format('select adjust_stock(%L, -5, ''spoilage'', null)', pig), 'STOCK_BELOW_RESERVED');
  perform adjust_stock(pig, -4, 'spoilage', null);
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '2/2', 'can reach exactly reserved');

  -- physical count
  perform pg_temp.as_user(admin_id);
  perform pg_temp.assert_error(format('select set_stock_count(%L, 1, null)', pig), 'STOCK_BELOW_RESERVED');
  perform pg_temp.assert_error(format('select set_stock_count(%L, -1, null)', pig), 'INVALID_AMOUNT');
  perform pg_temp.assert_error(format('select set_stock_count(%L, 1, null)', gen_random_uuid()), 'ITEM_NOT_FOUND');
  perform set_stock_count(pig, 5, 'Monthly count');
  perform pg_temp.as_owner();
  perform pg_temp.assert_eq(pg_temp.stock('Pig - Large (~25 kg)'), '5/2', 'count sets on hand');
  perform pg_temp.assert_true(
    (select on_hand_change = 3 and note = 'Monthly count' from stock_movements
     where item_id = pig and reason = 'count'), 'count logs the difference');

  -- staff and customers are refused
  perform pg_temp.as_user(staff_id);
  perform pg_temp.assert_error(format('select adjust_stock(%L, 1, ''purchase'', null)', pig), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select set_stock_count(%L, 9, null)', pig), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select get_dashboard(%L)', pg_temp.manila_day(0)), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select report_sales(%L, %L)', pg_temp.manila_day(0), pg_temp.manila_day(0)), 'FORBIDDEN');
  perform pg_temp.assert_error(format('select set_staff(%L, ''Name'', ''admin'', true)', staff_id), 'FORBIDDEN');
  perform pg_temp.as_anon();
  perform pg_temp.assert_error(format('select adjust_stock(%L, 1, ''purchase'', null)', pig), 'permission denied');
  perform pg_temp.assert_error(format('select get_dashboard(%L)', pg_temp.manila_day(0)), 'permission denied');
  perform pg_temp.as_owner();
end $$;

do $$
declare
  admin_id uuid;
  staff_id uuid;
begin
  perform pg_temp.as_owner();
  admin_id := pg_temp.make_user('admin', true);
  staff_id := pg_temp.make_user('staff', false);

  -- activating and renaming staff
  perform pg_temp.as_user(admin_id);
  perform set_staff(staff_id, '  Maria  ', 'staff', true);
  perform pg_temp.assert_true(
    (select full_name = 'Maria' and role = 'staff' and is_active from profiles where id = staff_id), 'staff activated');
  perform set_staff(staff_id, 'Maria', 'admin', true);
  perform pg_temp.assert_eq((select role::text from profiles where id = staff_id), 'admin', 'staff promoted');

  -- an admin cannot lock themself out
  perform pg_temp.assert_error(format('select set_staff(%L, ''Me'', ''staff'', true)', admin_id), 'SELF_LOCKOUT');
  perform pg_temp.assert_error(format('select set_staff(%L, ''Me'', ''admin'', false)', admin_id), 'SELF_LOCKOUT');
  perform set_staff(admin_id, 'Owner', 'admin', true);
  perform pg_temp.assert_eq((select full_name from profiles where id = admin_id), 'Owner', 'admin renames self');

  perform pg_temp.assert_error(format('select set_staff(%L, ''Me'', ''staff'', true)', gen_random_uuid()), 'USER_NOT_FOUND');
  perform pg_temp.assert_error(format('select set_staff(%L, ''  '', ''staff'', true)', staff_id), 'INVALID_NAME');
  perform pg_temp.as_owner();
end $$;

do $$
declare
  admin_id uuid;
  today date := pg_temp.manila_day(0);
  o_done uuid;
  o_due uuid;
  o_gone uuid;
  dash jsonb;
  report jsonb;
  row_today jsonb;
begin
  perform pg_temp.as_owner();
  admin_id := pg_temp.make_user('admin', true);
  update settings set order_lead_days = 0;

  -- one sale: 300 down, 450 COD, chopped 1 kg = 750
  o_done := pg_temp.new_order('09170000301', today, jsonb_build_array(pg_temp.kg_line('Chopped Lechon', 1)));
  -- one overdue downpayment: Small = 7500
  o_due := pg_temp.new_order('09170000302', today, jsonb_build_array(pg_temp.size_line('Small', 1)));
  -- one cancelled with a refund
  o_gone := pg_temp.new_order('09170000303', today, jsonb_build_array(pg_temp.kg_line('Lechon Belly', 1)));

  perform pg_temp.as_user(admin_id);
  perform record_payment(o_done, 'downpayment', 300, 'gcash', 'REF', null);
  perform set_order_status(o_done, 'confirmed');
  perform set_order_status(o_done, 'roasting');
  perform set_order_status(o_done, 'ready');
  perform record_payment(o_done, 'cod_balance', 450, 'cash', null, null);
  perform set_order_status(o_done, 'completed');

  perform set_order_status(o_due, 'awaiting_downpayment');

  perform record_payment(o_gone, 'downpayment', 100, 'cash', null, null);
  perform set_order_status(o_gone, 'cancelled', 'Changed plans');
  perform record_payment(o_gone, 'refund', 100, 'cash', null, null);

  perform pg_temp.as_owner();
  update orders set downpayment_due_at = now() - interval '1 hour' where id = o_due;
  update inventory_items set on_hand = 1 where name = 'Pig - Jumbo (30 kg+)';

  -- dashboard
  perform pg_temp.as_user(admin_id);
  dash := get_dashboard(today);
  perform pg_temp.assert_eq(dash -> 'orders_by_status' ->> 'completed', '1', 'dashboard completed count');
  perform pg_temp.assert_eq(dash -> 'orders_by_status' ->> 'awaiting_downpayment', '1', 'dashboard awaiting count');
  perform pg_temp.assert_eq(dash -> 'orders_by_status' ->> 'cancelled', '1', 'dashboard cancelled count');
  perform pg_temp.assert_true((dash ->> 'sales')::numeric = 750, 'dashboard sales');
  perform pg_temp.assert_true((dash ->> 'downpayments')::numeric = 400, 'dashboard downpayments');
  perform pg_temp.assert_eq(jsonb_array_length(dash -> 'overdue_downpayments')::text, '1', 'one overdue');
  perform pg_temp.assert_eq(dash -> 'overdue_downpayments' -> 0 ->> 'id', o_due::text, 'overdue order');
  perform pg_temp.assert_true(
    exists (select 1 from jsonb_array_elements(dash -> 'low_stock') l
            where l ->> 'name' = 'Pig - Jumbo (30 kg+)'), 'low stock listed');
  perform pg_temp.assert_true(
    not exists (select 1 from jsonb_array_elements(dash -> 'low_stock') l
                where l ->> 'name' = 'Pig - Large (~25 kg)'), 'healthy stock not listed');
  perform pg_temp.assert_eq(jsonb_array_length(dash -> 'capacity')::text, '7', 'seven days of capacity');
  perform pg_temp.assert_eq(dash -> 'capacity' -> 0 ->> 'day', today::text, 'capacity starts on the date');
  perform pg_temp.assert_eq(dash -> 'capacity' -> 0 ->> 'pigs_booked', '1', 'pigs booked excludes cancelled');
  perform pg_temp.assert_true((dash -> 'capacity' -> 0 ->> 'kg_booked')::numeric = 1, 'kg booked excludes cancelled');
  perform pg_temp.assert_eq(dash -> 'capacity' -> 0 ->> 'max_pigs', '10', 'capacity max');

  -- report
  report := report_sales(today, today + 1);
  perform pg_temp.assert_eq(jsonb_array_length(report -> 'days')::text, '2', 'one row per day');
  row_today := report -> 'days' -> 0;
  -- 3 from this block plus the one placed in the first block of this file
  perform pg_temp.assert_eq(row_today ->> 'orders', '4', 'report orders placed');
  perform pg_temp.assert_true((row_today ->> 'sales')::numeric = 750, 'report completed sales');
  perform pg_temp.assert_true((row_today ->> 'downpayments')::numeric = 400, 'report downpayments');
  perform pg_temp.assert_true((row_today ->> 'cod_collected')::numeric = 450, 'report COD');
  perform pg_temp.assert_true((row_today ->> 'refunds')::numeric = 100, 'report refunds');
  perform pg_temp.assert_eq(row_today ->> 'cancellations', '1', 'report cancellations');
  perform pg_temp.assert_true((report -> 'days' -> 1 ->> 'sales')::numeric = 0, 'empty day is zero');

  perform pg_temp.assert_eq(jsonb_array_length(report -> 'products')::text, '1', 'only completed orders count');
  perform pg_temp.assert_eq(report -> 'products' -> 0 ->> 'product_name', 'Chopped Lechon', 'report product');
  perform pg_temp.assert_true((report -> 'products' -> 0 ->> 'kg')::numeric = 1, 'report kg');
  perform pg_temp.assert_true((report -> 'products' -> 0 ->> 'revenue')::numeric = 750, 'report revenue');

  perform pg_temp.assert_error(format('select report_sales(%L, %L)', today, today + 366), 'INVALID_RANGE');
  perform report_sales(today, today + 365);
  perform pg_temp.as_owner();
end $$;

rollback;
