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
