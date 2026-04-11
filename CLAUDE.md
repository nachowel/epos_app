# CLAUDE.md — EPOS Project Intelligence File (Updated Authority Version)

---

## ⚠️ AUTHORITY NOTICE (READ FIRST)

This file is a **coding and workflow guidance document**, NOT the final authority for all system behavior.

### 🔴 Always follow this authority order:

1. `SYSTEM_OF_TRUTH.md`
2. `lib/data/database/app_database.dart`
3. embedded migration logic in `lib/data/database/app_database.dart`
4. Feature contract docs (`docs/*contract*.md`)
5. `CLAUDE.md` (this file)
6. `schema.md`

### Critical rule:

If this file conflicts with:

* live schema
* migration history
* feature contract docs

👉 **DO NOT follow this file. Follow higher authority and update this file later.**

---

## 📌 Project Summary

**System:** Custom EPOS for café/restaurant
**Platform:** Flutter (Android / iOS / Windows tablet)
**Architecture:** Clean Architecture (data / domain / presentation)
**Database:** Drift (SQLite)
**Sync:** Supabase (mirror only)

---

## 🏗 Architecture Rules (STRICT)

```text
data/         → DB + Supabase only
domain/       → business logic only
presentation/ → UI only
```

### NEVER BREAK THESE:

* ❌ No Drift in presentation
* ❌ No UI in data layer
* ❌ No BuildContext in domain
* ❌ No DB queries outside repositories
* ❌ No business logic in UI

---

## 🧠 Source of Truth Model

### Reality layers:

| Layer                | Truth Source                                |
| -------------------- | ------------------------------------------- |
| Schema               | `app_database.dart` + migrations            |
| Approved feature flow| contract docs                               |
| Runtime enforcement  | domain services                             |
| Breakfast engine     | contract docs                               |
| Coding rules         | this file                                   |
| Summary docs         | schema.md                                   |

---

## ⚠️ LEGACY vs CURRENT MODEL

This project has evolved.

### Legacy baseline (OLD)

* flat modifiers
* `included / extra`
* `remove / add`
* simple checkbox UI

### Current direction (ACTIVE)

* set engine
* choice groups
* swap engine
* semantic modifiers
* rebuild-based calculation

👉 **DO NOT build new features using legacy-only assumptions**

---

## 🍳 BREAKFAST / MENU ENGINE (AUTHORITATIVE MODEL)

### Core rule:

Modifier system is NOT flat anymore.

System supports:

1. **Choice**
2. **Swap**
3. **Extra**

---

### 🔹 Choice

* Comes from `modifier_groups`
* Example:

  * Tea / Coffee
  * Toast / Bread

Rules:

* `included_choice` → free
* default breakfast groups are one-of-one selections
* NEVER participates in swap

---

### 🔹 Swap

Triggered automatically:

```text
remove + add = swap
```

Rules:

* First 2 → `free_swap`
* 3rd+ → `paid_swap`
* Uses FULL product price

---

### 🔹 Extra

If no matching remove:

```text
add = extra_add
```

Rules:

* unlimited
* full price

---

### 🔴 Golden Rules

* Choice CAN become extra
* Choice can NEVER become swap
* Swap ONLY uses removed set-items
* UI must NOT decide swap vs extra
* Domain MUST decide

---

## 🧮 Pricing Formula

```text
line_total =
  base_price
+ extra_add_total
+ paid_swap_total
- removal_discount_total
```

---

## ⚙️ DOMAIN ENGINE RULE

### CRITICAL:

System MUST:

* rebuild from scratch
* NEVER patch incrementally

```text
input state → rebuild → output snapshot
```

---

## 🔄 TRANSACTION MODEL

### Canonical persisted statuses:

```text
draft / sent / paid / cancelled
```

Definitions:

* `draft` = first product has already been added, transaction exists, order is still editable
* `sent` = draft order has been submitted, order is no longer line-editable, payment/cancellation may proceed
* `paid` = payment completed; terminal
* `cancelled` = sent order cancelled without payment; terminal

Allowed persisted transitions:

```text
pre-order -(first successful product add)-> draft
draft -> sent
sent -> paid
sent -> cancelled
```

Legacy terminology rule:

* `open` is deprecated legacy wording only
* `open` may be used informally for active/open-order lists
* `open` is NOT a canonical stored `transactions.status`

### POS entry and transaction timing

* Category Entry screen is the primary post-login and post-payment idle/start screen
* Category Entry is navigation only
* before the first product is added, the system is in pre-order state
* pre-order state means no transaction, no cart exists as either persisted state or in-memory structured order, and no allocated `transaction_id`
* tapping a category opens the POS screen with that category preselected
* transaction/order creation happens only when the first product is successfully added to cart
* no action other than successful first-product add may exit pre-order state
* first product added creates the cart together with the transaction, and the cart is always tied to `transaction_id`
* first-product add must atomically create the transaction, set `status = 'draft'`, insert the first line, compute totals, and set `updated_at`
* do NOT create empty transactions from login, category taps, or screen entry
* do NOT create temporary transactions or persist cart state before transaction creation
* do NOT keep a parallel in-memory cart before transaction creation
* do NOT simulate cart behavior without a real transaction
* after payment, fully destroy cart state, clear selected category, close transaction context, and return to clean pre-order state

### Order lifecycle rules

* line-item mutation is allowed only in `draft`
* payment is allowed only from `sent`
* cancellation is allowed only from `sent`
* discarding a `draft` deletes it; discard is not a `cancelled` transition
* kitchen print is queued on `draft -> sent`
* receipt print is queued on `sent -> paid`
* active/open-order lists consist of `draft` and `sent`
* `paid` and `cancelled` are terminal persisted states

---

## 💳 PAYMENT RULES

* EXACTLY ONE payment per transaction
* amount MUST equal total
* atomic DB transaction required

---

## 🔁 IDEMPOTENCY

* generated at SUBMIT time
* NOT at cart creation
* UNIQUE constraint enforced

---

## 🧾 PRINT RULES

* print does NOT affect state
* failures do NOT rollback payment
* flags are informational only

---

## 🔒 SHIFT RULES

* only ONE active shift
* cashier preview ≠ shift close
* admin final close required

---

## 📊 REPORT VISIBILITY

Flow:

```text
report_service → report_visibility_service → UI / printer
```

Rules:

* cashier sees masked data
* admin sees real data
* UI must NOT calculate visibility

---

## ☁️ SUPABASE SYNC

### Architecture:

* local = source of truth
* supabase = mirror only

### Sync rules:

* ONLY `paid` / `cancelled`
* NEVER `draft` / `sent`
* NEVER treat `open` as a syncable stored status

### Write path:

```text
local → sync queue → edge function → supabase
```

---

## 🖨 Printer Rules

* always try/catch
* never silent fail
* printer service ONLY place for ESC/POS

---

## 🎯 UI RULES

### Modifier popup:

* Included → checkbox
* Extra → + button
* Must evolve into:

  * grouped UI (choice groups)
  * swap-aware display
  * clear labels

### Category flow and ordering

* Category Entry screen and POS screen are separate responsibilities
* Category Entry screen has no sidebar and no cart interaction
* POS screen owns product browsing, category sidebar switching, and cart building
* all category displays must use `categories.sort_order`
* do NOT add local screen-specific category sorting
* do NOT add popularity-driven or featured-category ordering
* admin category reorder must use long-press drag-and-drop with explicit Save / Cancel
* do NOT auto-save category reorder on drop

---

## 🚫 ABSOLUTE NO-GO LIST

1. ❌ Modify `app_database.g.dart`
2. ❌ Calculate pricing in UI
3. ❌ Ignore contract docs
4. ❌ Use flat modifier logic for sets
5. ❌ Partial DB writes for payment
6. ❌ Multiple payments per transaction
7. ❌ Let UI decide swap vs extra
8. ❌ Use stale schema assumptions
9. ❌ Create orders from category-only navigation
10. ❌ Use different category ordering rules on different screens
11. ❌ Allocate `transaction_id` before first product add
12. ❌ Persist cart state without a transaction
13. ❌ Maintain a parallel in-memory cart before transaction creation
14. ❌ Simulate cart behavior without a real transaction
15. ❌ Create a transaction without its first line in the same atomic flow
16. ❌ Insert the first line without the transaction in the same atomic flow

---

## 🧩 DEVELOPMENT FLOW

```text
1. schema (migration)
2. repository
3. domain logic
4. UI
```

---

## 🤖 AI USAGE RULE

When using Codex / Claude / Cursor:

ALWAYS start with:

```text
Follow SYSTEM_OF_TRUTH.md first.
Do not infer behavior from legacy flat modifier logic.
Use breakfast contract docs for set behavior.
Use POS category-entry contract docs for start-flow and category ordering.
```

---

## 🧠 FINAL MENTAL MODEL

Think like this:

* DB = truth of data
* Domain = truth of logic
* Contracts = truth of rules
* UI = just a viewer

If UI is deciding business logic → YOU DID IT WRONG.

---

## ✅ SUMMARY

This file:

* enforces discipline
* prevents bad architecture
* guides implementation

But:

👉 It is NOT the final authority for schema or domain truth.

Always follow:

* SYSTEM_OF_TRUTH.md
* live schema
* contract docs

---

**End of file**
