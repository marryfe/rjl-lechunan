-- Shared test helpers. scripts/db-test.mjs runs this before every test file, in the same session.
-- Files starting with "_" are not test files.

create or replace function pg_temp.assert_true(condition boolean, label text) returns void
language plpgsql as $$
begin
  if condition is not true then
    raise exception 'FAIL: %', label;
  end if;
end $$;

create or replace function pg_temp.assert_eq(actual text, expected text, label text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL: % (expected %, got %)', label, expected, actual;
  end if;
end $$;

-- Runs a statement that must fail with a message starting with the given text.
create or replace function pg_temp.assert_error(statement text, expected text) returns void
language plpgsql as $$
declare
  got text;
begin
  begin
    execute statement;
  exception when others then
    got := sqlerrm;
  end;
  if got is null then
    raise exception 'FAIL: expected error % but it succeeded: %', expected, statement;
  end if;
  if got not like expected || '%' then
    raise exception 'FAIL: expected error %, got %: %', expected, got, statement;
  end if;
end $$;

create or replace function pg_temp.as_owner() returns void
language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create or replace function pg_temp.as_anon() returns void
language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;

create or replace function pg_temp.as_user(user_id uuid) returns void
language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
end $$;

-- Cart line for a whole lechon size, optionally with add-ons by name.
create or replace function pg_temp.size_line(size_name text, qty int, add_ons text[] default '{}')
returns jsonb language sql as $$
  select jsonb_build_object(
    'product_id', s.product_id, 'size_id', s.id, 'qty', qty,
    'add_on_ids', coalesce(
      (select jsonb_agg(a.id) from add_ons a
       where a.product_id = s.product_id and a.name = any(add_ons)), '[]'::jsonb))
  from product_sizes s where s.name = size_name;
$$;

-- Cart line for a kilo item.
create or replace function pg_temp.kg_line(product_name text, kg numeric) returns jsonb
language sql as $$
  select jsonb_build_object('product_id', p.id, 'kg', kg) from products p where p.name = product_name;
$$;

-- Quantity of one freebie item in a quote, or 0.
create or replace function pg_temp.freebie_qty(quote jsonb, item text) returns numeric
language sql as $$
  select coalesce(sum((f ->> 'qty')::numeric), 0)
  from jsonb_array_elements(quote -> 'freebies') f where f ->> 'item_name' = item;
$$;

-- A valid place_order payload for pickup.
create or replace function pg_temp.order_json(mobile text, day date, items jsonb) returns jsonb
language sql as $$
  select jsonb_build_object(
    'customer_name', 'Juan Dela Cruz', 'customer_mobile', mobile, 'fulfillment', 'pickup',
    'scheduled_date', day, 'time_slot', '09:00-11:00', 'items', items);
$$;

create or replace function pg_temp.manila_day(days_ahead int) returns date
language sql as $$
  select (now() at time zone 'Asia/Manila')::date + days_ahead;
$$;

-- Places a pickup order and returns its id. Call as owner.
create or replace function pg_temp.new_order(mobile text, day date, items jsonb, extra jsonb default '{}')
returns uuid language plpgsql as $$
declare
  placed jsonb := place_order(pg_temp.order_json(mobile, day, items) || extra);
begin
  return (select id from orders where order_no = placed ->> 'order_no');
end $$;

-- "on_hand/reserved" of an inventory item, such as "4/1".
create or replace function pg_temp.stock(item text) returns text
language sql as $$
  select trim_scale(on_hand) || '/' || trim_scale(reserved) from inventory_items where name = item;
$$;

-- Creates an auth user and sets its profile. Call as owner.
create or replace function pg_temp.make_user(user_role user_role, active boolean) returns uuid
language plpgsql as $$
declare
  new_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (new_id, new_id || '@test.local');
  update profiles set role = user_role, is_active = active where id = new_id;
  return new_id;
end $$;
