-- RJL Lechunan: initial schema (tables, enums, helpers, RLS).
-- Business functions (quote_cart, place_order, set_order_status, ...) are added in
-- 0002_functions.sql during Phase 1 (see docs/PLAN.md, section 6).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- enums
create type user_role        as enum ('admin', 'staff');
create type sell_type        as enum ('by_kg', 'by_size');
create type order_status     as enum ('new', 'awaiting_downpayment', 'confirmed', 'roasting',
                                      'ready', 'out_for_delivery', 'completed', 'cancelled');
create type fulfillment_type as enum ('pickup', 'delivery');
create type freebie_trigger  as enum ('size', 'kg_threshold', 'order_amount', 'promo_dates');
create type inventory_kind   as enum ('pig', 'supply', 'freebie');
create type movement_reason  as enum ('purchase', 'reserve', 'release', 'deduct',
                                      'spoilage', 'adjustment', 'count');
create type payment_type     as enum ('downpayment', 'cod_balance', 'refund');
create type payment_method   as enum ('cash', 'gcash', 'bank_transfer', 'other');
create type message_sender   as enum ('customer', 'staff');

-- ---------------------------------------------------------------- staff
create table profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null,
  role        user_role not null default 'staff',
  is_active   boolean not null default true,
  push_token  text,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------- settings (single row)
create table settings (
  id                         int primary key default 1 check (id = 1),
  store_name                 text not null default 'RJL Lechunan',
  contact_mobile             text,
  messenger_url              text,
  pickup_address             text,
  order_lead_days            int not null default 2 check (order_lead_days >= 0),
  booking_window_days        int not null default 60 check (booking_window_days > 0),
  downpayment_deadline_hours int not null default 24 check (downpayment_deadline_hours > 0),
  default_max_pigs_per_day   int not null default 10 check (default_max_pigs_per_day >= 0),
  default_max_kg_per_day     numeric(8,2) not null default 50 check (default_max_kg_per_day >= 0),
  delivery_enabled           boolean not null default true,
  delivery_fee               numeric(10,2) not null default 0 check (delivery_fee >= 0),
  freebies_stack             boolean not null default true,
  time_slots                 text[] not null default array['09:00-11:00','11:00-13:00','13:00-15:00','15:00-17:00'],
  updated_at                 timestamptz not null default now()
);

-- ---------------------------------------------------------------- inventory
create table inventory_items (
  id             uuid primary key default gen_random_uuid(),
  name           text not null unique,
  kind           inventory_kind not null,
  unit           text not null,                       -- 'head', 'bottle', 'pc', 'kg'
  on_hand        numeric(10,2) not null default 0 check (on_hand >= 0),
  reserved       numeric(10,2) not null default 0 check (reserved >= 0),
  reorder_level  numeric(10,2) not null default 0 check (reorder_level >= 0),
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  check (reserved <= on_hand)
);

-- ---------------------------------------------------------------- catalog
create table categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  sort_order  int not null default 0
);

create table products (
  id            uuid primary key default gen_random_uuid(),
  category_id   uuid references categories (id) on delete set null,
  name          text not null,
  description   text,
  photo_path    text,                                  -- Supabase Storage path in bucket 'product-photos'
  sell_type     sell_type not null,
  price_per_kg  numeric(10,2) check (price_per_kg > 0),
  min_kg        numeric(6,2) not null default 1   check (min_kg > 0),
  kg_step       numeric(6,2) not null default 0.5 check (kg_step > 0),
  is_active     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  check (sell_type <> 'by_kg' or price_per_kg is not null)
);

create table product_sizes (
  id                 uuid primary key default gen_random_uuid(),
  product_id         uuid not null references products (id) on delete cascade,
  name               text not null,                    -- 'Small', 'Medium', 'Large', 'Jumbo'
  approx_weight_kg   numeric(6,2),
  serves             text,                             -- 'good for 40-50 people'
  price              numeric(10,2) not null check (price > 0),
  inventory_item_id  uuid references inventory_items (id), -- the pig stock this size uses
  is_active          boolean not null default true,
  sort_order         int not null default 0,
  unique (product_id, name)
);

create table add_ons (
  id                 uuid primary key default gen_random_uuid(),
  product_id         uuid not null references products (id) on delete cascade,
  name               text not null,
  price              numeric(10,2) not null default 0 check (price >= 0),
  inventory_item_id  uuid references inventory_items (id),
  is_active          boolean not null default true,
  unique (product_id, name)
);

create table freebie_rules (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  trigger     freebie_trigger not null,
  size_id     uuid references product_sizes (id) on delete cascade, -- trigger = 'size'
  threshold   numeric(10,2),                                        -- kg or PHP amount
  start_date  date,                                                 -- trigger = 'promo_dates', or optional window for any rule
  end_date    date,
  priority    int not null default 0,   -- when settings.freebies_stack = false, highest priority wins
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  check (trigger <> 'size' or size_id is not null),
  check (trigger not in ('kg_threshold', 'order_amount') or threshold is not null),
  check (trigger <> 'promo_dates' or (start_date is not null and end_date is not null)),
  check (start_date is null or end_date is null or start_date <= end_date)
);

create table freebie_rule_items (
  id                 uuid primary key default gen_random_uuid(),
  rule_id            uuid not null references freebie_rules (id) on delete cascade,
  inventory_item_id  uuid not null references inventory_items (id),
  qty                numeric(8,2) not null check (qty > 0)
);

-- ---------------------------------------------------------------- capacity
-- A row overrides the defaults in settings for that date. No row = defaults apply.
create table daily_capacity (
  date       date primary key,
  max_pigs   int not null check (max_pigs >= 0),
  max_kg     numeric(8,2) not null check (max_kg >= 0),
  is_closed  boolean not null default false,
  note       text
);

-- ---------------------------------------------------------------- orders
create sequence order_no_seq start 1001;

create table orders (
  id                  uuid primary key default gen_random_uuid(),
  order_no            text not null unique default ('RJL-' || nextval('order_no_seq')),
  customer_name       text not null,
  customer_mobile     text not null check (customer_mobile ~ '^(09|\+639)\d{9}$'),
  customer_email      text,
  fulfillment         fulfillment_type not null,
  address             text,
  landmark            text,
  scheduled_date      date not null,
  time_slot           text not null,
  status              order_status not null default 'new',
  pig_count           int not null default 0 check (pig_count >= 0),       -- whole lechon heads in this order
  total_kg            numeric(8,2) not null default 0 check (total_kg >= 0), -- kilo items in this order
  subtotal            numeric(10,2) not null check (subtotal >= 0),
  delivery_fee        numeric(10,2) not null default 0 check (delivery_fee >= 0),
  total               numeric(10,2) not null check (total >= 0),
  amount_paid         numeric(10,2) not null default 0,
  balance_due         numeric(10,2) generated always as (total - amount_paid) stored,
  stock_reserved      boolean not null default false,
  downpayment_due_at  timestamptz,
  cancel_reason       text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (fulfillment <> 'delivery' or address is not null)
);
create index orders_scheduled_date_idx on orders (scheduled_date) where status <> 'cancelled';
create index orders_status_idx on orders (status);
create index orders_lookup_idx on orders (order_no, customer_mobile);

create table order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references orders (id) on delete cascade,
  product_id    uuid not null references products (id),
  size_id       uuid references product_sizes (id),
  product_name  text not null,             -- copied at order time
  size_name     text,
  kg            numeric(6,2) check (kg > 0),
  qty           int not null default 1 check (qty > 0),
  unit_price    numeric(10,2) not null,    -- price per kg or price per size, copied at order time
  add_ons       jsonb not null default '[]'::jsonb, -- [{id, name, price}]
  line_total    numeric(10,2) not null,
  check ((size_id is null) <> (kg is null))       -- exactly one of size or kg
);

create table order_freebies (
  id                 uuid primary key default gen_random_uuid(),
  order_id           uuid not null references orders (id) on delete cascade,
  rule_id            uuid references freebie_rules (id) on delete set null,
  inventory_item_id  uuid not null references inventory_items (id),
  item_name          text not null,
  qty                numeric(8,2) not null check (qty > 0)
);

create table order_messages (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders (id) on delete cascade,
  sender      message_sender not null,
  staff_id    uuid references profiles (id),
  body        text not null check (length(body) between 1 and 1000),
  created_at  timestamptz not null default now()
);
create index order_messages_order_idx on order_messages (order_id, created_at);

create table payments (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references orders (id) on delete cascade,
  type          payment_type not null,
  amount        numeric(10,2) not null check (amount > 0),
  method        payment_method not null,
  reference_no  text,
  note          text,
  received_by   uuid not null references profiles (id),
  paid_at       timestamptz not null default now()
);

create table order_status_history (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders (id) on delete cascade,
  from_status  order_status,
  to_status    order_status not null,
  user_id      uuid references profiles (id),
  note         text,
  created_at   timestamptz not null default now()
);

create table stock_movements (
  id               uuid primary key default gen_random_uuid(),
  item_id          uuid not null references inventory_items (id),
  on_hand_change   numeric(10,2) not null default 0,
  reserved_change  numeric(10,2) not null default 0,
  reason           movement_reason not null,
  order_id         uuid references orders (id) on delete set null,
  user_id          uuid references profiles (id),
  note             text,
  created_at       timestamptz not null default now()
);
create index stock_movements_item_idx on stock_movements (item_id, created_at desc);

-- ---------------------------------------------------------------- helpers
create or replace function is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and is_active);
$$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and is_active and role = 'admin');
$$;

create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Every new auth user (staff invited from the Supabase dashboard) gets an INACTIVE staff profile.
-- The admin activates it and sets the role in the Users screen. Public sign-up stays disabled.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, role, is_active)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'New staff'), 'staff', false)
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

create trigger orders_touch before update on orders
  for each row execute function touch_updated_at();
create trigger settings_touch before update on settings
  for each row execute function touch_updated_at();

-- ---------------------------------------------------------------- row level security
-- Customers never read or write tables directly except the public catalog.
-- Guest ordering, tracking and messaging go through SECURITY DEFINER functions (0002).
alter table profiles             enable row level security;
alter table settings             enable row level security;
alter table inventory_items      enable row level security;
alter table categories           enable row level security;
alter table products             enable row level security;
alter table product_sizes        enable row level security;
alter table add_ons              enable row level security;
alter table freebie_rules        enable row level security;
alter table freebie_rule_items   enable row level security;
alter table daily_capacity       enable row level security;
alter table orders               enable row level security;
alter table order_items          enable row level security;
alter table order_freebies       enable row level security;
alter table order_messages       enable row level security;
alter table payments             enable row level security;
alter table order_status_history enable row level security;
alter table stock_movements      enable row level security;

-- public catalog (anyone, including signed-out customers)
create policy catalog_read_categories on categories    for select using (true);
create policy catalog_read_products   on products      for select using (is_active or is_staff());
create policy catalog_read_sizes      on product_sizes for select using (is_active or is_staff());
create policy catalog_read_addons     on add_ons       for select using (is_active or is_staff());
create policy catalog_read_freebies   on freebie_rules for select using (is_active or is_staff());
create policy catalog_read_fr_items   on freebie_rule_items for select using (true);
create policy settings_read           on settings      for select using (true);

-- admin manages catalog, settings, capacity, inventory
create policy admin_all_categories on categories         for all using (is_admin()) with check (is_admin());
create policy admin_all_products   on products           for all using (is_admin()) with check (is_admin());
create policy admin_all_sizes      on product_sizes      for all using (is_admin()) with check (is_admin());
create policy admin_all_addons     on add_ons            for all using (is_admin()) with check (is_admin());
create policy admin_all_rules      on freebie_rules      for all using (is_admin()) with check (is_admin());
create policy admin_all_rule_items on freebie_rule_items for all using (is_admin()) with check (is_admin());
create policy admin_update_settings on settings          for update using (is_admin()) with check (is_admin());
create policy admin_all_capacity   on daily_capacity     for all using (is_admin()) with check (is_admin());
create policy staff_read_capacity  on daily_capacity     for select using (is_staff());
create policy admin_all_inventory  on inventory_items    for all using (is_admin()) with check (is_admin());
create policy staff_read_inventory on inventory_items    for select using (is_staff());
create policy staff_read_movements on stock_movements    for select using (is_staff());

-- staff read orders and related rows; writes go through functions (0002) so stock stays consistent
create policy staff_read_orders    on orders               for select using (is_staff());
create policy staff_read_items     on order_items          for select using (is_staff());
create policy staff_read_freebies  on order_freebies       for select using (is_staff());
create policy staff_read_messages  on order_messages       for select using (is_staff());
create policy staff_read_payments  on payments             for select using (is_staff());
create policy staff_read_history   on order_status_history for select using (is_staff());

-- profiles: everyone on staff sees the team; only admin changes it
create policy staff_read_profiles  on profiles for select using (is_staff());
create policy admin_all_profiles   on profiles for all using (is_admin()) with check (is_admin());

-- realtime: staff dashboard listens for new orders and messages
-- (run in Supabase: alter publication supabase_realtime add table orders, order_messages;)
