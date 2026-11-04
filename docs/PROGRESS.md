# Progress — RJL Lechunan

Claude Code: tick tasks as you finish them, and add notes for the owner under "Decisions needed".

| Phase | Status | Notes |
| --- | --- | --- |
| 0 — Project setup | Done | Web and Android phone both show the shop name from the local database |
| 1 — Database functions | Done | All functions in PLAN §6, SQL tests pass after `db reset`, typed API ready |
| 2 — Menu, product, cart | Not started | |
| 3 — Checkout and tracking | Not started | |
| 4 — Staff screens | Not started | |
| 5 — Admin screens | Not started | |
| 6 — Launch | Not started | |
| 7 — After launch | Not started | |

## Phase 0 checklist

- [x] Expo app created (SDK 58, TypeScript, Expo Router); CLAUDE.md, docs/ and supabase/ kept
- [x] NativeWind, supabase-js, react-query, zustand + AsyncStorage, react-hook-form, zod, date-fns(-tz), ESLint + Prettier, jest-expo installed
- [x] `src/lib/supabase.ts`, providers in `app/_layout.tsx`, `.env.example`, npm scripts
- [x] `npx supabase init` done; 0001_init.sql and seed.sql unchanged (checksums match)
- [x] `npx supabase start && npx supabase db reset` works (Postgres 17)
- [x] Placeholder Home reads `settings.store_name` from the real local database
- [x] `app.json` web output `single`, `public/_redirects`, `eas.json`, `ci.yml`
- [x] PROGRESS.md entries
- [x] Done when (web): `npm run web` shows "RJL Lechunan" from the local DB
- [x] Done when (Android): Expo Go on the owner's phone shows "RJL Lechunan" from the local DB

Passing now: typecheck, lint, jest (6 tests), web and Android bundles, Home at 360 px in Chrome against the real database. Customer (anon) access can read the catalog, cannot see a real order, and cannot change `settings`.

Deferred from the PLAN §4 `_layout.tsx` note: toasts (Phase 4, first used there); fonts need no provider because §9 uses system fonts.

## Phase 1 checklist

- [x] `supabase/migrations/0002_functions.sql`: every function in §6, grants, storage bucket and policies
- [x] SQL tests for §12 cases 1–10, plus admin functions, in `supabase/tests/`; `npm run db:test` passes after `db reset`
- [x] Realtime enabled on `orders` and `order_messages`
- [x] `src/types/database.ts` generated; typed wrappers in `src/api/*`; `src/lib/errors.ts`

Also checked over real HTTP with real sign-in: customers are refused on order and stock tables; 6 customers racing for the last pig gives exactly 1 winner; 2 staff confirming the last pig cannot over-reserve; new orders reach staff through Realtime; only admins can upload photos.

### Rule decisions made in Phase 1

The spec was unclear or silent on these. They live in `0002_functions.sql`, so changing one needs a new migration, not a rebuild of the app. Owner: tell Claude Code if any should change.

| Situation | What the app does now |
| --- | --- |
| Extending a downpayment deadline (§7.5 says re-enter the state, §7.4 has no such step) | awaiting → awaiting is allowed and resets the deadline |
| Cancelling while roasting or out for delivery | Not allowed, exactly as §7.4 says |
| Staff (not admin) cancelling a Ready order | `FORBIDDEN` |
| Two freebie rules need the same item and stock covers only one | Highest priority first; the later rule is skipped whole as `OUT_OF_STOCK` |
| Stacking off, and the top rule is out of stock | No freebie; it does not fall back to the next rule |
| Cart has no date yet, and a freebie rule has date limits | The rule waits until a date is picked at checkout |
| Same freebie item from several rules | One merged line; `rule_id` is null, `rule_name` lists the rules |
| Which day a sale counts on in reports | The day it was completed. Payments count on the day received; orders on the day placed |
| Rate limit of 3 orders per hour | Cancelled orders still count |
| Refund after an order is completed | Allowed |
| Same add-on sent twice in a cart line | Charged once |
| Availability numbers when a day is overbooked | `pigs_left` and `kg_left` stop at 0 |

Error codes added beyond the spec, all mapped in `src/lib/errors.ts`: `INVALID_NAME`, `INVALID_FULFILLMENT`, `INVALID_MESSAGE`, `INVALID_RANGE`, `INVALID_AMOUNT`, `INVALID_REASON`, `ORDER_NOT_FOUND`, `ITEM_NOT_FOUND`, `USER_NOT_FOUND`, `ORDER_CLOSED`, `REFUND_TOO_LARGE`.

## Needs action

- **Decide before launch: order lookup attempts.** `get_public_order` has no attempt limit in the spec. A lookup needs both the order number and the mobile number, but order numbers are sequential, so someone could try many guesses. Consider a limit in Phase 6.
- **Expo Go version (for any new test phone).** The app uses SDK 58, but the Expo Go in the app stores is listed for SDK 57. Install Expo Go 58.0.5 from the APK link in the Expo release: https://github.com/expo/expo-go-releases/releases/download/Expo-Go-58.0.5/Expo-Go-58.0.5.apk
- **Phone testing setup on this PC.** The "remi" Wi-Fi is set to Private, and the firewall rule "RJL Lechunan dev" allows ports 8081 and 54321 on Private networks.

## Decisions needed from the owner

- Real sizes, kilo ranges and prices (seed has placeholders).
- Real freebie rules; should freebies stack?
- Downpayment: required for which orders? minimum amount? deadline?
- Daily roasting capacity and order lead time.
- Delivery areas and fee.
- Cancellation and refund rule.
- Logo and brand colours.

## Log

<!-- yyyy-mm-dd — what was done -->

2026-11-04 — Phase 0 code finished on Expo SDK 58. Local database not run because Docker is missing.
2026-11-04 — Docker installed. Migration and seed load on Postgres 17; website reads the shop name from the real local database.
2026-11-04 — Fixed a NativeWind colour scheme crash on web (`darkMode: 'class'`). Owner confirmed web and Android phone. Phase 0 done.
2026-11-05 — Phase 1 done: `0002_functions.sql`, 5 SQL test files, typed API and error messages. Local now needs explicit grants, like a new cloud project (`auto_expose_new_tables = false`).
