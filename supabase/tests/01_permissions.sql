-- Who may touch which table. Runs in a transaction and leaves nothing behind.
begin;

do $$
declare
  admin_id uuid := pg_temp.make_user('admin', true);
  staff_id uuid := pg_temp.make_user('staff', true);
  item_id uuid := (select id from inventory_items where name = 'Puso tray');
begin
  -- customers: catalog yes, everything else no
  perform pg_temp.as_anon();
  perform pg_temp.assert_eq((select store_name from settings), 'RJL Lechunan', 'anon reads settings');
  perform pg_temp.assert_eq((select count(*)::text from products), '3', 'anon reads products');
  perform pg_temp.assert_eq((select count(*)::text from product_sizes), '4', 'anon reads sizes');
  perform pg_temp.assert_error('select * from orders', 'permission denied');
  perform pg_temp.assert_error('select * from payments', 'permission denied');
  perform pg_temp.assert_error('select * from order_messages', 'permission denied');
  perform pg_temp.assert_error('select * from profiles', 'permission denied');
  perform pg_temp.assert_error('select * from inventory_items', 'permission denied');
  perform pg_temp.assert_error('select * from daily_capacity', 'permission denied');
  perform pg_temp.assert_error($q$update settings set store_name = 'x'$q$, 'permission denied');
  perform pg_temp.assert_error($q$delete from products$q$, 'permission denied');

  -- staff: read orders and stock, never write them directly
  perform pg_temp.as_user(staff_id);
  perform pg_temp.assert_eq((select count(*)::text from orders), '0', 'staff reads orders');
  perform pg_temp.assert_eq((select count(*)::text from inventory_items), '8', 'staff reads stock');
  perform pg_temp.assert_error($q$update orders set status = 'cancelled'$q$, 'permission denied');
  perform pg_temp.assert_error($q$delete from payments$q$, 'permission denied');
  perform pg_temp.assert_error($q$update profiles set role = 'admin'$q$, 'permission denied');
  perform pg_temp.assert_error('update inventory_items set on_hand = 999', 'permission denied');

  -- admin: edits catalog and settings, but stock counts only through functions
  perform pg_temp.as_user(admin_id);
  update settings set contact_mobile = '09171112222';
  update products set description = 'Edited' where name = 'Lechon Belly';
  perform pg_temp.assert_eq((select description from products where name = 'Lechon Belly'), 'Edited',
    'admin edits products');
  update inventory_items set reorder_level = 3 where id = item_id;
  perform pg_temp.assert_eq((select reorder_level::text from inventory_items where id = item_id), '3.00',
    'admin edits reorder level');
  perform pg_temp.assert_error('update inventory_items set on_hand = 999', 'permission denied');
  perform pg_temp.assert_error('update inventory_items set reserved = 1', 'permission denied');
  perform pg_temp.assert_error($q$update orders set status = 'cancelled'$q$, 'permission denied');

  -- staff cannot edit the catalog: RLS filters the rows, so nothing changes
  perform pg_temp.as_user(staff_id);
  update products set description = 'Staff edit' where name = 'Lechon Belly';
  perform pg_temp.assert_eq((select description from products where name = 'Lechon Belly'), 'Edited',
    'staff cannot edit products');

  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    exists (select 1 from storage.buckets where id = 'product-photos' and public),
    'public product-photos bucket exists');
  perform pg_temp.assert_eq(
    (select string_agg(tablename, ',' order by tablename) from pg_publication_tables
     where pubname = 'supabase_realtime'),
    'order_messages,orders', 'realtime publishes orders and messages');
end $$;

rollback;
