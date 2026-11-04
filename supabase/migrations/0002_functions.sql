-- RJL Lechunan: business functions, permissions, storage and realtime.
-- Rules live in docs/PLAN.md sections 6 and 7. Error messages start with a code; src/lib/errors.ts
-- maps each code to friendly text, so keep the two in step.

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
