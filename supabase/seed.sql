-- RJL Lechunan sample data. ALL prices, sizes and stock are PLACEHOLDERS.
-- Replace with the shop's real values before launch (docs/PLAN.md, section 11).

insert into settings (id, contact_mobile, pickup_address)
values (1, '09170000000', 'RJL Lechunan shop address (replace)')
on conflict (id) do nothing;

insert into inventory_items (name, kind, unit, on_hand, reorder_level) values
  ('Pig - Small (~15 kg)',  'pig',     'head',   6, 2),
  ('Pig - Medium (~20 kg)', 'pig',     'head',   6, 2),
  ('Pig - Large (~25 kg)',  'pig',     'head',   4, 1),
  ('Pig - Jumbo (30 kg+)',  'pig',     'head',   2, 1),
  ('Lechon sauce bottle',   'freebie', 'bottle', 80, 20),
  ('Puso tray',             'freebie', 'tray',   30, 10),
  ('Lechon paksiw pack',    'freebie', 'pack',   20, 5),
  ('Bilao packaging',       'supply',  'pc',     40, 10);

insert into categories (name, sort_order) values
  ('Whole Lechon', 1),
  ('Lechon by Kilo', 2);

insert into products (category_id, name, description, sell_type, price_per_kg, min_kg, kg_step, sort_order)
select c.id, 'Whole Lechon', 'Whole roasted pig, Cebu style.', 'by_size', null, 1, 0.5, 1
from categories c where c.name = 'Whole Lechon';

insert into products (category_id, name, description, sell_type, price_per_kg, min_kg, kg_step, sort_order)
select c.id, 'Chopped Lechon', 'Freshly chopped lechon, sold per kilo.', 'by_kg', 750, 1, 0.5, 1
from categories c where c.name = 'Lechon by Kilo';

insert into products (category_id, name, description, sell_type, price_per_kg, min_kg, kg_step, sort_order)
select c.id, 'Lechon Belly', 'Rolled boneless belly, sold per kilo.', 'by_kg', 900, 1, 0.5, 2
from categories c where c.name = 'Lechon by Kilo';

insert into product_sizes (product_id, name, approx_weight_kg, serves, price, inventory_item_id, sort_order)
select p.id, s.name, s.kg, s.serves, s.price, i.id, s.ord
from products p
cross join (values
  ('Small',  15, 'good for 20-30 people',  7500, 'Pig - Small (~15 kg)',  1),
  ('Medium', 20, 'good for 30-40 people',  9500, 'Pig - Medium (~20 kg)', 2),
  ('Large',  25, 'good for 40-50 people', 11500, 'Pig - Large (~25 kg)',  3),
  ('Jumbo',  30, 'good for 50-70 people', 14000, 'Pig - Jumbo (30 kg+)',  4)
) as s(name, kg, serves, price, item, ord)
join inventory_items i on i.name = s.item
where p.name = 'Whole Lechon';

insert into add_ons (product_id, name, price)
select p.id, a.name, a.price
from products p
cross join (values ('Chopping service', 200), ('Lemongrass stuffing', 300)) as a(name, price)
where p.name = 'Whole Lechon';

-- Freebie: Large or Jumbo whole lechon -> 2 sauce + 1 puso tray
with r as (
  insert into freebie_rules (name, trigger, size_id)
  select 'Large/Jumbo bundle (' || s.name || ')', 'size', s.id
  from product_sizes s where s.name in ('Large', 'Jumbo')
  returning id
)
insert into freebie_rule_items (rule_id, inventory_item_id, qty)
select r.id, i.id, q.qty
from r
cross join (values ('Lechon sauce bottle', 2), ('Puso tray', 1)) as q(item, qty)
join inventory_items i on i.name = q.item;

-- Freebie: 5 kg and up of kilo items -> 1 sauce bottle
with r as (
  insert into freebie_rules (name, trigger, threshold)
  values ('5 kg and up', 'kg_threshold', 5) returning id
)
insert into freebie_rule_items (rule_id, inventory_item_id, qty)
select r.id, i.id, 1 from r join inventory_items i on i.name = 'Lechon sauce bottle';

-- Freebie: order total PHP 15,000 and up -> 1 paksiw pack
with r as (
  insert into freebie_rules (name, trigger, threshold)
  values ('PHP 15,000 and up', 'order_amount', 15000) returning id
)
insert into freebie_rule_items (rule_id, inventory_item_id, qty)
select r.id, i.id, 1 from r join inventory_items i on i.name = 'Lechon paksiw pack';
