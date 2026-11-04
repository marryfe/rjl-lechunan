# RJL Lechunan — Detailed Build Plan (for Claude Code)

Version 1 · 4 Nov 2026 · Owner: Jhoren

This is the full specification. `CLAUDE.md` holds the short rules; this file holds the detail. Build in the phase order of §13. Each phase has a ready-to-paste prompt.

---

## Contents

0. How to use this plan with Claude Code
1. Product summary
2. Decisions and defaults (open questions)
3. Architecture
4. Repository layout
5. Data model
6. Database functions (API) — `0002_functions.sql`
7. Business rules in detail
8. Screens and routes
9. UI guidelines
10. Notifications
11. Environments, secrets and deployment
12. Testing and acceptance
13. Build phases with prompts
14. Owner's manual steps (accounts and settings)
15. Out of scope for the MVP

---

## 0. How to use this plan with Claude Code

1. Create an empty folder, e.g. `rjl-lechunan`, and copy in this starter kit: `CLAUDE.md`, `docs/PLAN.md`, `docs/PROGRESS.md`, `supabase/migrations/0001_init.sql`, `supabase/seed.sql`.
2. Install: Node.js LTS, Git, Docker Desktop (for the local Supabase database), and Claude Code.
3. Open a terminal in the folder and run `claude`.
4. Paste the **Phase 0 prompt** from §13. When Claude Code finishes, test what it built, then paste the next phase's prompt. One phase per session works best; start each new session with: *"Read CLAUDE.md, docs/PLAN.md and docs/PROGRESS.md, then continue with Phase N."*
5. Do the owner steps in §14 when a phase asks for them (creating free accounts, inviting staff).

---

## 1. Product summary

| | |
| --- | --- |
| Business | RJL Lechunan — lechon sold by kilo and by whole-pig size, with freebies |
| Customer apps | Android app, iPhone app, website — same screens, one codebase |
| Staff/admin | Web dashboard at `/staff` and `/admin`; staff order screens also work in the mobile app |
| Payment | Cash on delivery or pickup. Downpayment arranged by chat; staff record it (cash, GCash, bank, other) |
| Key rule | Orders are for a date and time slot. Each date has a max number of whole pigs and a max kg for kilo items |
| Stock | Held on capacity when placed; inventory **reserved** when staff confirm; **deducted** when completed; **released** when cancelled |
| Tools | Expo, Supabase Free, Cloudflare Pages, EAS Build Free, GitHub — all free |
| Launch target | Website + Android APK in ~12 weeks; Google Play next; iPhone App Store optional |

---

## 2. Decisions and defaults (open questions)

Claude Code uses these defaults until the owner changes them. All are **settings or data**, not code, so changing them later needs no rebuild.

| Question | Default used | Where to change |
| --- | --- | --- |
| Real sizes, kilo ranges and prices | Placeholders in `seed.sql` (Small ₱7,500 … Jumbo ₱14,000; chopped ₱750/kg, belly ₱900/kg) | Admin → Products |
| Freebie rules and stacking | 3 sample rules; freebies stack | Admin → Freebies; Settings → "Freebies stack" |
| Is a downpayment required? | Staff decide per order (they move it to *Awaiting downpayment* or straight to *Confirmed*) | Process, no setting |
| Downpayment deadline | 24 hours after staff ask for it; overdue orders are flagged, staff cancel manually | Settings |
| How downpayments are paid | Recorded as cash, GCash, bank transfer or other, with reference number | Staff → Order detail |
| Lead time / booking window | Order at least 2 days ahead; up to 60 days ahead | Settings |
| Daily capacity | 10 whole pigs and 50 kg of kilo items per day, editable per date | Admin → Capacity |
| Time slots | 09–11, 11–13, 13–15, 15–17 | Settings |
| Delivery | Enabled, one flat fee (₱0 placeholder) | Settings |
| Cancellation / refund | Staff cancel with a reason; refunds are recorded as a `refund` payment | Process |
| Staff count / admin | Owner is admin; staff invited by email | §14 |
| Language | English UI | Code (strings in `src/lib/strings.ts` for later Tagalog) |

---

## 3. Architecture

```
 Customers                         Staff / Admin
 ┌──────────────┐ ┌────────────┐   ┌───────────────────────────┐
 │ Android app  │ │ iPhone app │   │ Web dashboard (/staff,     │
 │  (EAS APK)   │ │ (later)    │   │ /admin) + staff screens on │
 └──────┬───────┘ └─────┬──────┘   │ the mobile app             │
        │  ┌────────────┴───┐      └─────────────┬─────────────┘
        │  │ Website         │                    │
        │  │ Cloudflare Pages│                    │ email + password login
        │  └───────┬─────────┘                    │
        └──────────┼──────────────────────────────┘
                   │ supabase-js (anon key + user JWT)
          ┌────────▼─────────────────────────────────┐
          │ Supabase (Free)                          │
          │  Postgres: tables + RLS + RPC functions  │
          │  Auth: staff/admin accounts only         │
          │  Storage: product-photos bucket (public) │
          │  Realtime: orders, order_messages        │
          └────────▲─────────────────────────────────┘
                   │ daily keep-awake ping, weekly pg_dump
          ┌────────┴────────┐
          │ GitHub Actions  │
          └─────────────────┘
```

- **Single Expo app** with Expo Router. The same build serves customers (`/`), staff (`/staff/*`) and admin (`/admin/*`). Admin routes render only on web.
- All business logic lives in **Postgres functions** (§6), so the app, website and dashboard always agree on prices, freebies and stock.
- Guest customers call public functions with the anon key. Staff/admin sign in; functions check `is_staff()` / `is_admin()`.

---

## 4. Repository layout

```
rjl-lechunan/
├── CLAUDE.md
├── docs/
│   ├── PLAN.md
│   └── PROGRESS.md
├── app/                              # Expo Router routes
│   ├── _layout.tsx                   # providers: QueryClient, Supabase session, fonts, toasts
│   ├── index.tsx                     # Home
│   ├── menu.tsx
│   ├── product/[id].tsx
│   ├── cart.tsx
│   ├── checkout.tsx
│   ├── order/[orderNo].tsx           # order placed + tracking (asks for mobile if not remembered)
│   ├── track.tsx                     # find my order: order no + mobile
│   ├── staff/
│   │   ├── _layout.tsx               # guard: signed in + is_staff
│   │   ├── login.tsx
│   │   ├── index.tsx                 # order queue
│   │   ├── orders/[id].tsx           # order detail
│   │   └── prep.tsx                  # daily prep sheet
│   └── admin/
│       ├── _layout.tsx               # guard: web + is_admin; sidebar nav
│       ├── index.tsx                 # dashboard
│       ├── products/index.tsx
│       ├── products/[id].tsx         # product + sizes + add-ons editor
│       ├── freebies.tsx
│       ├── inventory/index.tsx
│       ├── inventory/[id].tsx        # item detail + movement log
│       ├── capacity.tsx
│       ├── reports.tsx
│       ├── users.tsx
│       └── settings.tsx
├── src/
│   ├── api/                          # typed wrappers around supabase.rpc / from()
│   │   ├── keys.ts
│   │   ├── catalog.ts  orders.ts  staff.ts  admin.ts
│   ├── components/                   # Button, Card, Price, QtyStepper, KgStepper, DatePicker, StatusBadge, EmptyState ...
│   ├── features/
│   │   ├── cart/store.ts             # zustand + AsyncStorage persist
│   │   ├── checkout/schema.ts        # zod
│   │   └── orders/status.ts          # labels, colours, allowed next steps (mirror of §7.4)
│   ├── lib/
│   │   ├── supabase.ts               # client with AsyncStorage session on native, localStorage on web
│   │   ├── money.ts  dates.ts  phone.ts  errors.ts  strings.ts
│   └── types/database.ts             # generated: npm run db:types
├── supabase/
│   ├── config.toml                   # created by `npx supabase init`
│   ├── migrations/
│   │   ├── 0001_init.sql             # PROVIDED: tables, enums, RLS, helpers (tested on Postgres 16)
│   │   └── 0002_functions.sql        # Phase 1: the functions in §6
│   ├── seed.sql                      # PROVIDED: placeholder catalog, stock, freebies
│   └── tests/                        # SQL test scripts (§12)
├── public/_redirects                 # "/*  /index.html  200"  (SPA routing on Cloudflare Pages)
├── .github/workflows/
│   ├── ci.yml                        # typecheck, lint, jest on push
│   ├── keep-awake.yml                # daily ping so the free Supabase project never pauses
│   └── backup.yml                    # weekly pg_dump as a workflow artifact
├── app.json  eas.json  tailwind.config.js  babel.config.js  tsconfig.json
└── .env.example                      # EXPO_PUBLIC_SUPABASE_URL, EXPO_PUBLIC_SUPABASE_ANON_KEY
```

---

## 5. Data model

The schema is in `supabase/migrations/0001_init.sql` (provided, already tested). Summary:

| Table | Purpose | Key columns |
| --- | --- | --- |
| `profiles` | Staff/admin accounts (1:1 with `auth.users`) | `role` admin/staff, `is_active`, `push_token` |
| `settings` | Single row of shop settings | lead days, booking window, downpayment hours, default daily caps, delivery fee, freebies_stack, time_slots |
| `categories` | Menu groups | `name`, `sort_order` |
| `products` | Sellable items | `sell_type` by_kg/by_size, `price_per_kg`, `min_kg`, `kg_step`, `photo_path` |
| `product_sizes` | Whole-pig sizes | `price`, `approx_weight_kg`, `serves`, `inventory_item_id` (pig stock) |
| `add_ons` | Extras per product | `price`, optional `inventory_item_id` |
| `freebie_rules` / `freebie_rule_items` | What triggers a freebie and what it gives | `trigger` size/kg_threshold/order_amount/promo_dates, `threshold`, dates, `priority` |
| `inventory_items` | Pigs by size, freebies, supplies | `on_hand`, `reserved`, `reorder_level`; available = on_hand − reserved |
| `stock_movements` | Every stock change | `on_hand_change`, `reserved_change`, `reason`, `order_id`, `user_id` |
| `daily_capacity` | Per-date override of default caps | `max_pigs`, `max_kg`, `is_closed` |
| `orders` | One customer order | `order_no` RJL-1001…, customer fields, `scheduled_date`, `time_slot`, `status`, `pig_count`, `total_kg`, totals, `amount_paid`, `balance_due` (generated), `stock_reserved`, `downpayment_due_at` |
| `order_items` | Lines, prices copied at order time | `size_id` xor `kg`, `qty`, `unit_price`, `add_ons` jsonb, `line_total` |
| `order_freebies` | Freebies applied to the order | `inventory_item_id`, `item_name`, `qty` |
| `order_messages` | Downpayment chat | `sender` customer/staff, `body` |
| `payments` | Downpayments, COD balance, refunds | `type`, `amount`, `method`, `reference_no`, `received_by` |
| `order_status_history` | Audit trail | `from_status`, `to_status`, `user_id`, `note` |

Also in 0001: `is_staff()`, `is_admin()`, the `handle_new_user` trigger (new auth users get an **inactive** staff profile), RLS policies (public catalog read; admin writes catalog/settings/capacity/inventory; staff read orders; no direct customer access to orders).

Storage: create a **public** bucket `product-photos`; only admins may upload (storage policy `is_admin()` for insert/update/delete).

---

## 6. Database functions (API) — write in `0002_functions.sql`

General rules for every function:

- `language plpgsql`, `security definer`, `set search_path = public`.
- Public functions: `grant execute ... to anon, authenticated`. Staff/admin functions: `revoke execute ... from public, anon`, `grant ... to authenticated`, and check `is_staff()` / `is_admin()` at the top (`raise exception 'FORBIDDEN'`).
- Errors: `raise exception '<CODE>: <short detail>'`. Codes used below are the contract with `src/lib/errors.ts`.
- "Today" = `(now() at time zone 'Asia/Manila')::date`.

### 6.1 Public (customers, no login)

| Function | Returns | Rules |
| --- | --- | --- |
| `get_availability(p_from date, p_to date)` | `table(day date, pigs_left int, kg_left numeric, is_open boolean, reason text)` | Max 62 days per call. Caps = `daily_capacity` row or `settings` defaults. Booked = sum of `pig_count` / `total_kg` of orders on that date with status ≠ cancelled. `is_open = false` with reason `CLOSED`, `TOO_SOON` (before today + lead days), `TOO_FAR` (after booking window) or `FULL` (pigs_left ≤ 0 **and** kg_left ≤ 0). |
| `quote_cart(p_items jsonb, p_fulfillment fulfillment_type, p_date date)` | `jsonb` (see shape below) | Validates and prices the cart; computes freebies (§7.2). Never writes. Used by Cart and Checkout on every change (debounced 300 ms). |
| `place_order(p_order jsonb)` | `jsonb {order_no, total, scheduled_date, time_slot}` | See §6.3. |
| `get_public_order(p_order_no text, p_mobile text)` | `jsonb` or `null` | Returns status, scheduled date/slot, fulfillment, items, freebies, subtotal, delivery fee, total, amount_paid, balance_due, downpayment_due_at, status history (status + time only) and messages (sender, body, created_at — never staff ids/names). `null` when order no + normalised mobile don't match. |
| `post_customer_message(p_order_no text, p_mobile text, p_body text)` | `void` | Same match check. Not allowed if status is completed/cancelled (`ORDER_CLOSED`). Body 1–1000 chars. Max 30 customer messages per order per day (`RATE_LIMIT`). |

`p_items` shape (from the cart):

```json
[
  { "product_id": "uuid", "size_id": "uuid", "qty": 1, "add_on_ids": ["uuid"] },
  { "product_id": "uuid", "kg": 2.5 }
]
```

`quote_cart` result shape:

```json
{
  "lines": [
    { "product_id": "…", "product_name": "Whole Lechon", "size_id": "…", "size_name": "Large",
      "kg": null, "qty": 1, "unit_price": 11500, "add_ons": [{ "id": "…", "name": "Chopping service", "price": 200 }],
      "line_total": 11700 }
  ],
  "freebies": [ { "rule_id": "…", "rule_name": "Large/Jumbo bundle", "inventory_item_id": "…", "item_name": "Lechon sauce bottle", "qty": 2 } ],
  "skipped_freebies": [ { "rule_name": "…", "reason": "OUT_OF_STOCK" } ],
  "pig_count": 1, "total_kg": 0,
  "subtotal": 11700, "delivery_fee": 0, "total": 11700
}
```

Validation errors: `PRODUCT_UNAVAILABLE`, `SIZE_MISMATCH` (size not of that product / product is by_kg), `INVALID_KG` (missing, < min_kg, not a multiple of kg_step, > 50), `INVALID_QTY` (1–10), `ADDON_MISMATCH`, `EMPTY_CART`, `DELIVERY_DISABLED`.

### 6.2 Staff (signed in, `is_staff()`)

| Function | Rules |
| --- | --- |
| `set_order_status(p_order_id uuid, p_to order_status, p_note text default null)` | Enforces the transition table in §7.4 and its side effects (reserve / deduct / release stock, downpayment deadline). Locks the order row (`for update`). Writes `order_status_history`. Errors: `BAD_TRANSITION`, `NOT_ENOUGH_STOCK: <item names>`, `BALANCE_DUE`, `REASON_REQUIRED`. |
| `record_payment(p_order_id uuid, p_type payment_type, p_amount numeric, p_method payment_method, p_reference text, p_note text)` | Inserts `payments`; `amount_paid` += amount (refund: −=). Payments may not make `amount_paid` exceed `total` (`OVERPAY`) or go below 0. Not allowed on cancelled orders except `refund`. |
| `post_staff_message(p_order_id uuid, p_body text)` | Inserts a staff message (`staff_id = auth.uid()`). |
| `get_prep_sheet(p_date date)` | `jsonb`: whole pigs by size (count), kg by product, add-ons by name, freebies by item, list of orders (order no, customer, slot, fulfillment, status, balance due). Excludes cancelled. |

Staff read orders, items, messages and payments directly through RLS `select` (for lists and realtime), but never write those tables directly.

### 6.3 `place_order` in detail

Input:

```json
{
  "customer_name": "Juan Dela Cruz", "customer_mobile": "09171234567", "customer_email": null,
  "fulfillment": "delivery", "address": "…", "landmark": "…",
  "scheduled_date": "2026-12-20", "time_slot": "09:00-11:00",
  "note": "Can I pay ₱1,000 downpayment via GCash?",
  "items": [ …same as quote_cart… ]
}
```

Steps, in one transaction:

1. Validate fields: name 2–80 chars; mobile normalised (`+639…` → `09…`) and matches `^09\d{9}$` (`INVALID_MOBILE`); delivery needs address (`ADDRESS_REQUIRED`); time slot in `settings.time_slots` (`INVALID_SLOT`).
2. Anti-abuse: max 3 orders per mobile number per hour (`RATE_LIMIT`).
3. `pg_advisory_xact_lock(hashtext('cap:' || scheduled_date))` so two customers can't take the last slot together.
4. Run `quote_cart`. Check `get_availability` for that date: open, `pigs_left ≥ pig_count`, `kg_left ≥ total_kg` (`CAPACITY_FULL`, `DATE_UNAVAILABLE`).
5. Insert `orders` (status `new`), `order_items`, `order_freebies`, history row (null → new), and the note as the first `order_messages` row (sender customer) if present.
6. Return `order_no`. The app saves `{order_no, mobile}` in local storage so "My recent orders" works without an account.

### 6.4 Admin (signed in, `is_admin()`)

Catalog, freebies, capacity and settings are edited with plain table writes (RLS allows admin). Stock changes and reports use functions:

| Function | Rules |
| --- | --- |
| `adjust_stock(p_item_id uuid, p_change numeric, p_reason movement_reason, p_note text)` | Reasons allowed: purchase (+), spoilage (−), adjustment (±). Cannot make on_hand < reserved (`STOCK_BELOW_RESERVED`). Logs `stock_movements`. |
| `set_stock_count(p_item_id uuid, p_counted numeric, p_note text)` | Physical count: logs the difference as reason `count`. Same reserved check. |
| `get_dashboard(p_date date)` | `jsonb`: today's orders by status, today's sales (completed total), downpayments received today, overdue downpayments (awaiting + `downpayment_due_at < now()`), low-stock items (available ≤ reorder_level), next 7 days capacity used. |
| `report_sales(p_from date, p_to date)` | `jsonb`: per day — orders, completed sales, downpayments, COD collected, refunds, cancellations; per product/size — qty, kg, revenue. Max 366 days. |
| `set_staff(p_user_id uuid, p_full_name text, p_role user_role, p_is_active boolean)` | Updates a profile. An admin cannot deactivate or demote themself (`SELF_LOCKOUT`). |

---

## 7. Business rules in detail

### 7.1 Pricing

- **By size**: `line_total = (size.price + Σ add_on.price) × qty`.
- **By kg**: `line_total = round(price_per_kg × kg, 2)`; add-ons not offered on kilo items in the MVP.
- `subtotal = Σ line_total`; `delivery_fee = settings.delivery_fee` if delivery else 0; `total = subtotal + delivery_fee`.
- `pig_count = Σ qty` of by-size lines; `total_kg = Σ kg` of by-kg lines.
- Prices are **copied into `order_items`** at placement; later price edits never change existing orders.

### 7.2 Freebies

For the cart and the scheduled date, evaluate every active rule whose optional `start_date`/`end_date` window contains the scheduled date:

| Trigger | Fires when | Quantity |
| --- | --- | --- |
| `size` | the cart has lines with that `size_id` | rule item qty × Σ qty of those lines |
| `kg_threshold` | `total_kg ≥ threshold` | rule item qty × 1 |
| `order_amount` | `subtotal ≥ threshold` (before delivery fee) | rule item qty × 1 |
| `promo_dates` | scheduled date within start–end | rule item qty × 1 |

- If `settings.freebies_stack = false`, give only one rule: the fired rule with the highest `priority` that has stock (ties: newest `created_at`, then lowest `id`). If it is out of stock, move to the next fired rule.
- A rule is **skipped** (listed in `skipped_freebies` with `OUT_OF_STOCK`) if any of its items has available stock (on_hand − reserved) below the needed qty. The cart shows "Freebie currently unavailable".
- Same item from several rules → merged into one line in `order_freebies`.
- Freebies appear in the cart and on the order as **₱0** lines.

### 7.3 Capacity vs inventory

- **Capacity** (per day): limits how many whole pigs and how many kg can be roasted that day. Counted from the moment an order is placed (status ≠ cancelled). This is what greys out dates in the customer calendar.
- **Inventory** (stock on hand): pigs by size, freebie items, add-on supplies. **Reserved at confirm, deducted at complete, released at cancel.** Kilo items do not consume pig inventory in the MVP; the admin controls kilo volume through `max_kg` per day.
- Low stock: available ≤ reorder_level → dashboard alert.

### 7.4 Order status flow

```
new ──► awaiting_downpayment ──► confirmed ──► roasting ──► ready ──► completed
 │              │                    │                       │  ▲
 │              │                    │                       ▼  │
 │              │                    │              out_for_delivery (delivery only)
 └──────────────┴────────────────────┴──► cancelled ◄────────┘ (ready: admin only)
```

| From | Allowed to | Side effects / checks |
| --- | --- | --- |
| new | awaiting_downpayment | `downpayment_due_at = now() + settings.downpayment_deadline_hours` |
| new, awaiting_downpayment | confirmed | **Reserve stock** for: each size line's pig item × qty, add-on items × qty, freebie items. All-or-nothing; else `NOT_ENOUGH_STOCK: Pig - Large (need 2, have 1)`. Set `stock_reserved = true`. |
| confirmed | roasting | — |
| roasting | ready | — |
| ready | out_for_delivery | only if fulfillment = delivery |
| out_for_delivery | ready | failed delivery, note required |
| ready, out_for_delivery | completed | requires `balance_due ≤ 0` (`BALANCE_DUE`) — staff record the COD payment first. **Deduct stock**: on_hand −= qty, reserved −= qty. |
| new, awaiting_downpayment, confirmed | cancelled | note (reason) required. If `stock_reserved`, **release**: reserved −= qty. Capacity frees automatically. |
| ready | cancelled | admin only; same as above |

Every change: `order_status_history` row; every stock change: `stock_movements` row with `order_id`.

The UI shows only allowed next steps as buttons (mirror of this table in `src/features/orders/status.ts`).

### 7.5 Downpayment by message

1. Customer writes a note at checkout → first chat message.
2. Staff open the order (new-order alert via Realtime), reply in the chat, or call/text the mobile number (tap-to-call, tap-to-SMS links; the phone's own SMS app — free).
3. Staff choose **Ask for downpayment** (→ awaiting_downpayment, deadline shown to the customer) or **Confirm without downpayment**.
4. When paid, staff use **Record downpayment** (amount, method, reference) then **Confirm**. One combined button: "Record & confirm".
5. Overdue downpayments show a red badge in the queue and on the dashboard; staff decide to extend (post a message, re-enter awaiting state to reset the deadline) or cancel.
6. On handover, staff **Record COD balance** then **Complete**.

### 7.6 Order numbers and tracking

- `RJL-1001`, `RJL-1002` … (sequence). Shown big on the confirmation screen with a "Copy" button and a "Save screenshot" hint.
- Tracking needs order no + mobile number. The app remembers the last 10 orders on the device.

---

## 8. Screens and routes

Customer screens work on Android, iPhone and web. Layout: single column on phones; max width 1100 px centred on desktop with a 2–3 column product grid.

### 8.1 Customer

| Route | Screen | Content and behaviour |
| --- | --- | --- |
| `/` | Home | Logo/name "RJL Lechunan", hero photo, "Order now" → `/menu`, how it works (3 steps: choose → pick a date → pay cash; downpayment by chat), freebie highlights, contact (tap to call, Messenger link from settings), "Track my order". |
| `/menu` | Menu | Categories as tabs/sections; product cards with photo, name, "from ₱X" or "₱X / kg", badge "By size" / "By kilo", freebie chip if any rule targets it. |
| `/product/[id]` | Product | By size: size cards (name, ~kg, serves, price), qty stepper 1–10, add-on checkboxes. By kg: kg stepper (min, step from product), live price. Freebies that would apply. "Add to cart". |
| `/cart` | Cart | Lines with edit/remove; freebies as ₱0 lines; skipped freebies note; subtotal. Uses `quote_cart` (fulfillment pickup, date null until checkout). "Checkout". |
| `/checkout` | Checkout | Step 1 Pickup or delivery (+ address, landmark). Step 2 Date calendar from `get_availability` (closed/full/too-soon days disabled with reason tooltip) and time slot. Step 3 Name, mobile, optional email, **message to the shop** (prefilled hint: "Ask about downpayment, e.g. GCash"). Summary with total and "Pay in cash on pickup/delivery". "Place order" → `place_order`. Validation with zod; server errors mapped to friendly text. |
| `/order/[orderNo]` | Order placed / tracking | After placing: big order number, "We will message you here about the downpayment". Status timeline, items, freebies, totals, amount paid, balance due, downpayment deadline, chat thread with send box. Polls every 30 s (no customer Realtime in MVP). If mobile not remembered, ask for it first. |
| `/track` | Find my order | Order no + mobile → `/order/[orderNo]`; list of orders remembered on this device. |

### 8.2 Staff (web + mobile, sign-in required)

| Route | Screen | Content and behaviour |
| --- | --- | --- |
| `/staff/login` | Login | Email + password (Supabase Auth). Inactive profile → "Ask the owner to activate your account". |
| `/staff` | Order queue | Date filter (Today / Tomorrow / This week / pick date), status tabs with counts, search by order no / name / mobile. Card: order no, name, slot, pickup/delivery, items summary, total, balance due, badges (New, Unread message, Overdue downpayment). Realtime: new orders and messages appear instantly with a sound + toast on web. |
| `/staff/orders/[id]` | Order detail | Customer (tap to call/text), schedule, items, freebies, totals; chat thread + reply box; payments list + "Record payment" sheet; next-step buttons from §7.4 with confirm dialogs; cancel with reason; status history. |
| `/staff/prep` | Prep sheet | `get_prep_sheet` for a date: pigs by size, kg by product, add-ons, freebies to pack, orders by slot. Print button on web (print-friendly CSS). |

### 8.3 Admin (web only)

| Route | Screen | Content |
| --- | --- | --- |
| `/admin` | Dashboard | `get_dashboard`: today's orders by status, sales, downpayments, overdue list, low stock, next 7 days capacity bars. |
| `/admin/products` | Products | List with active toggle, sort order; "New product". |
| `/admin/products/[id]` | Product editor | Name, category, description, photo upload (Storage), sell type; by kg: price/kg, min kg, step; by size: sizes table (name, ~kg, serves, price, linked pig stock item, active); add-ons table. |
| `/admin/freebies` | Freebie rules | List + editor: name, trigger, size / threshold / dates, priority, items (inventory item + qty), active. Preview: "Applies to: Large whole lechon". |
| `/admin/inventory` | Inventory | Items with on hand, reserved, available, reorder level, low badge; actions: Stock in, Spoilage, Adjust, Count; new item. |
| `/admin/inventory/[id]` | Item detail | Movement log (date, change, reason, order link, user, note). |
| `/admin/capacity` | Capacity calendar | Month view; per day: booked / max pigs and kg; click to override max or close the day (e.g. holidays). |
| `/admin/reports` | Reports | Date range; table + simple bar chart (sales per day) using `report_sales`; export CSV (generated in the browser). |
| `/admin/users` | Users | Profiles list; activate/deactivate, role, name (`set_staff`). Help text on inviting staff from the Supabase dashboard (§14). |
| `/admin/settings` | Settings | All fields of `settings`. |

---

## 9. UI guidelines

- Brand: warm, appetising. Placeholder palette until the owner gives a logo: primary `#B4441C` (roasted skin), accent `#F2B134` (golden), dark text `#2B1A12`, background `#FFF8F1`. Defined once in `tailwind.config.js`.
- Typography: system fonts; prices bold; peso sign ₱.
- Every list has an empty state, every async action shows loading and errors, every destructive action asks for confirmation.
- Accessibility: labels on inputs, contrast AA, tap targets ≥ 44 px, works at 360 px width.
- Images: product photos compressed on upload (max 1200 px, WebP/JPEG) to stay inside the 1 GB free storage.

---

## 10. Notifications (all free)

| When | MVP | Later |
| --- | --- | --- |
| New order / new customer message | Staff dashboard Realtime toast + sound | Expo push to staff phones |
| Status changes, staff replies | Customer sees them on the tracking page | Expo push to the customer's device (store token with the order), optional email |
| Customer contact | Tap-to-call / tap-to-SMS from the staff's own phone; Messenger link | — |

No paid SMS gateway.

---

## 11. Environments, secrets and deployment

**Environments**: `local` (Supabase CLI in Docker) and `production` (Supabase cloud free project). Optional second free project as staging.

`.env` (never committed; `.env.example` is):

```
EXPO_PUBLIC_SUPABASE_URL=https://<project>.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=<anon or publishable key>
```

**Database deploy**: `npx supabase link --project-ref <ref>` then `npx supabase db push`. Seed production with real data via the admin screens (not `seed.sql`).

**Website**: Cloudflare Pages connected to the GitHub repo. Build command `npx expo export -p web`, output `dist`, env vars as above. `public/_redirects` contains `/*  /index.html  200`. URL `rjllechunan.pages.dev`.

**Android**: `eas.json` profiles:
- `preview` → `"android": { "buildType": "apk" }` for direct download (share link / QR on the website and Facebook page).
- `production` → AAB for Google Play when the owner pays the one-time fee.
- App id `com.rjllechunan.app`, name "RJL Lechunan", version via `app.json`.
- Free EAS plan: 30 builds/month — build only when a release is ready; use EAS Update for small JS fixes.

**iPhone** (optional, later): needs the Apple Developer Program (about US$99/yr). Until then iPhone users use the website (add to home screen).

**GitHub Actions** (free for private repos within monthly minutes):
- `ci.yml`: on push → `npm ci`, typecheck, lint, test.
- `keep-awake.yml`: daily cron `0 1 * * *` → `curl "$SUPABASE_URL/rest/v1/settings?select=id" -H "apikey: $SUPABASE_ANON_KEY"` (a real DB query, so the free project is never paused for inactivity).
- `backup.yml`: weekly → `npx supabase db dump --db-url "$SUPABASE_DB_URL" -f backup.sql` (+ `--data-only` dump) uploaded as a workflow artifact (retention 90 days). Secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_DB_URL`.

---

## 12. Testing and acceptance

**SQL tests** (`supabase/tests/*.sql`, run by `npm run db:test` against the local DB after `db reset`). Each test is a `do $$ … $$` block that raises on failure. Minimum cases:

1. `quote_cart`: Large × 1 + Chopping service → line 11,700; freebies 2 sauce + 1 puso.
2. `quote_cart`: chopped lechon 5 kg → 3,750 + "5 kg and up" sauce; 4.5 kg → no freebie; 1.25 kg → `INVALID_KG`.
3. `quote_cart`: Jumbo × 1 + Large × 1 (subtotal 25,500) adds the paksiw pack plus both size bundles (4 sauce, 2 puso); with `freebies_stack = false` and priorities set explicitly in the test, only the highest-priority rule remains.
4. Freebie item with 0 available → rule in `skipped_freebies`.
5. `get_availability`: date before today+lead → TOO_SOON; closed day → CLOSED; caps reduce after an order; cancelled order frees capacity.
6. `place_order`: valid order returns RJL-xxxx; 4th order from same mobile within an hour → RATE_LIMIT; capacity exceeded → CAPACITY_FULL; bad mobile → INVALID_MOBILE.
7. `get_public_order`: wrong mobile → null; right mobile → no staff ids in messages.
8. `set_order_status`: confirm reserves stock; not enough pigs → NOT_ENOUGH_STOCK and nothing changes; complete with balance → BALANCE_DUE; complete after COD payment deducts stock; cancel after confirm releases stock; bad transition → BAD_TRANSITION.
9. `record_payment`: overpay → OVERPAY; refund reduces amount_paid.
10. Anon cannot `select` from `orders`, cannot call `set_order_status`; inactive staff gets FORBIDDEN.

To simulate users in SQL tests: `set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';`.

**App tests** (jest): money/phone/date helpers; cart store; checkout zod schema; status helper (allowed next steps match §7.4); a render test for Product (kg stepper respects min/step).

**Manual acceptance before launch** (do on a real Android phone and a laptop):

- [ ] Customer orders a Large lechon for pickup with a downpayment note; sees freebies; gets an order number.
- [ ] Staff see it instantly, reply in chat, ask for downpayment; customer sees the reply and deadline on the tracking page.
- [ ] Staff record ₱1,000 GCash with reference, confirm; inventory shows 1 pig reserved.
- [ ] Prep sheet for that date lists 1 Large + freebies.
- [ ] Staff move to roasting → ready, record COD balance, complete; inventory on-hand drops by 1; report shows the sale, downpayment and COD.
- [ ] A full day is greyed out for customers; closing a date in Capacity works.
- [ ] Cancelling a confirmed order releases stock.
- [ ] Admin changes a price; new carts use it; the old order keeps the old price.
- [ ] Website works on Chrome desktop and mobile Safari; APK installs on Android 10+.

---

## 13. Build phases with prompts

Estimated 12 weeks for one developer working with Claude Code (rough guide).

### Phase 0 — Project setup (week 1)

Tasks
- [ ] `create-expo-app` (TypeScript, Expo Router) in this folder without overwriting CLAUDE.md, docs/, supabase/.
- [ ] Install NativeWind, supabase-js, react-query, zustand + AsyncStorage, react-hook-form, zod, date-fns(-tz); ESLint + Prettier; jest-expo.
- [ ] `src/lib/supabase.ts`, providers in `app/_layout.tsx`, `.env.example`, npm scripts from CLAUDE.md.
- [ ] `npx supabase init`; keep provided migration and seed; `npx supabase start && npx supabase db reset` works.
- [ ] Placeholder Home screen reading `settings.store_name` from Supabase (proves the connection).
- [ ] `app.json` web output `single`, `public/_redirects`, `eas.json` with `preview` (APK) and `production` profiles; `ci.yml`.
- [ ] Create `docs/PROGRESS.md` entries.

Done when: `npm run web` and the Android emulator/Expo Go both show "RJL Lechunan" loaded from the local DB; typecheck, lint and tests pass.

Prompt:
> Read CLAUDE.md and docs/PLAN.md fully. Do Phase 0 (§13) exactly. Keep the provided supabase/migrations/0001_init.sql and supabase/seed.sql unchanged. Use the latest stable Expo SDK. When finished, show me how to run the app on web and on my Android phone, and update docs/PROGRESS.md.

### Phase 1 — Database functions (weeks 2–3)

Tasks
- [ ] Write `supabase/migrations/0002_functions.sql` with every function in §6, grants, and the storage bucket + policies.
- [ ] Write the SQL tests in §12 and `npm run db:test`.
- [ ] Enable Realtime on `orders` and `order_messages`.
- [ ] Generate `src/types/database.ts`; typed wrappers in `src/api/*` and `src/lib/errors.ts`.

Done when: all SQL tests pass after `npx supabase db reset`.

Prompt:
> Read CLAUDE.md and docs/PLAN.md. Do Phase 1: write 0002_functions.sql implementing §6 and the rules in §7 exactly (error codes, transitions, stock side effects), then the SQL tests in §12. Run them until they all pass. Then generate types and the typed API wrappers. Update docs/PROGRESS.md and list any rule you found ambiguous.

### Phase 2 — Menu, product and cart (weeks 4–5)

Tasks
- [ ] Home, Menu, Product, Cart screens (§8.1) with the UI guidelines (§9).
- [ ] Cart store (persisted); `useQuote` calling `quote_cart`; freebies shown as ₱0; skipped freebies note.
- [ ] Responsive layout for desktop web.

Done when: a customer can add a Large lechon with an add-on and 2.5 kg chopped lechon, and the cart total and freebies match the SQL test values.

Prompt:
> Read CLAUDE.md, docs/PLAN.md and docs/PROGRESS.md. Do Phase 2 (§13, screens §8.1 Home/Menu/Product/Cart). All prices and freebies must come from quote_cart. Make it look good on a 360 px Android phone and on desktop web. Add jest tests for the cart store. Update PROGRESS.md.

### Phase 3 — Checkout and tracking (week 6)

Tasks
- [ ] Checkout steps with availability calendar and time slots; zod validation; `place_order`; friendly errors.
- [ ] Order placed / tracking page with chat, polling, remembered orders; Track page.

Done when: a customer can place an order for an open date, sees it with its order number on the tracking page, and can send a message; full or closed dates cannot be picked.

Prompt:
> Continue with Phase 3: Checkout, Order placed/Tracking and Track screens (§8.1, §6.3, §7.5, §7.6). Disabled dates must show why. Remember the last 10 orders on the device. Update PROGRESS.md.

### Phase 4 — Staff screens (weeks 7–8)

Tasks
- [ ] Staff login + guard; inactive account message.
- [ ] Order queue with filters, search, counts, badges, Realtime toasts + sound.
- [ ] Order detail: chat, record payment sheet, next-step buttons per §7.4, "Record & confirm", cancel with reason, history.
- [ ] Admin only, on order detail: add, remove or swap the freebies on that one order, through a new Postgres function that keeps stock correct if the order is already confirmed.
- [ ] Prep sheet with print view.

Done when: the full order lifecycle in §12 manual checks works end to end between two browsers (customer and staff).

Prompt:
> Continue with Phase 4: the staff screens in §8.2. Buttons must show only the allowed next steps from §7.4, and every action goes through the Postgres functions. New orders and messages must appear in real time. Make the staff screens usable on an Android phone too. Update PROGRESS.md.

### Phase 5 — Admin screens (weeks 9–10)

Tasks
- [ ] Admin layout (web only) with sidebar.
- [ ] Dashboard, Products + editor with photo upload, Freebie rules, Inventory + item log + stock actions, Capacity calendar, Reports + CSV, Users, Settings.

Done when: the owner can run the shop from the admin screens without touching the database; remaining manual checks in §12 pass.

Prompt:
> Continue with Phase 5: the admin screens in §8.3 (web only). Compress photos before upload. Reports need a simple bar chart and CSV export. Update PROGRESS.md.

### Phase 6 — Launch (weeks 11–12)

Tasks
- [ ] Polish: empty/loading/error states, accessibility pass, app icon and splash (placeholder until the owner's logo), favicon, page titles.
- [ ] `keep-awake.yml` and `backup.yml`.
- [ ] Production Supabase project: link, `db push`, create the admin account (§14), disable public sign-ups.
- [ ] Cloudflare Pages deploy; EAS `preview` APK; download page/QR on the website Home.
- [ ] Run every manual acceptance check on a real phone; fix issues.
- [ ] Write `docs/OWNER_GUIDE.md`: how to add products, manage stock, handle a downpayment, close a day, invite staff (plain language).

Done when: the website is live at rjllechunan.pages.dev, the APK installs on an Android phone, and all §12 checks pass on production.

Prompt:
> Continue with Phase 6 (launch). Walk me through each owner step in §14 when you reach it and wait for me to confirm. Then deploy the website to Cloudflare Pages, build the Android APK with EAS, set up the GitHub Actions jobs, and write docs/OWNER_GUIDE.md in simple English. Update PROGRESS.md.

### Phase 7 — After launch (when ready)

- Google Play listing (one-time fee): production AAB, store listing text and screenshots, privacy policy page on the website.
- Expo push notifications for staff and customers (Edge Function or database webhook on status change).
- Optional customer accounts (saved addresses, order history).
- Deliveries screen and rider assignment.
- iPhone App Store (optional, yearly fee).
- Tagalog translation of `strings.ts`.

---

## 14. Owner's manual steps

| When | Step |
| --- | --- |
| Phase 0 | Create free accounts: GitHub, Expo (expo.dev), Supabase, Cloudflare. Install Expo Go on your Android phone. |
| Phase 6 | Create the production Supabase project (region: Singapore). Give Claude Code the project ref and keys via `.env` — never paste the service role key into the app. |
| Phase 6 | Supabase → Authentication → disable "Allow new users to sign up". Invite yourself (Users → Invite), set a password, then run in the SQL editor: `update profiles set role = 'admin', is_active = true, full_name = 'Jhoren' where id = (select id from auth.users where email = '<your email>');` |
| Phase 6 | Invite each staff member the same way; activate them in Admin → Users. |
| Phase 6 | Cloudflare Pages → connect the GitHub repo; add the two `EXPO_PUBLIC_*` variables. |
| Phase 6 | GitHub repo → Settings → Secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_DB_URL`. |
| Before launch | Enter real products, sizes, prices, freebies, stock, capacity and settings in the admin screens. Answer the questions in §2. |
| Phase 7 | Google Play Console account (one-time fee) when ready to list the app. |

---

## 15. Out of scope for the MVP

Online payments (GCash/card processing), SMS, customer accounts, loyalty points, rider app with GPS, multiple branches, offline mode, recipe-level supply deduction (e.g. charcoal per pig), and native iPhone app store release.
