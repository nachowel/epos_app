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
* `sent` = an explicit submit/send-order action completed successfully, editable order-building is closed, the pre-payment snapshot is frozen, and payment/cancellation may proceed
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
* if a UI or report still uses the label `open orders`, that label means the combined active set `draft + sent`
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
* persisted `draft` creation happens only on the first successful product add
* minimum persisted draft condition is: transaction row + first line + computed totals in the same successful atomic flow
* do NOT create empty transactions from login, category taps, or screen entry
* do NOT create empty-cart transactions under any lifecycle shortcut
* do NOT create temporary transactions or persist cart state before transaction creation
* do NOT keep a parallel in-memory cart before transaction creation
* do NOT simulate cart behavior without a real transaction
* after payment, fully destroy cart state, clear selected category, close transaction context, and return to clean pre-order state

### Order lifecycle rules

* line-item mutation is allowed only in `draft`
* payment is allowed only from `sent`
* cancellation is allowed only from `sent`
* discarding a `draft` deletes it; discard is not a `cancelled` transition
* abandoned draft cleanup is manual discard/delete in the current model
* automatic abandoned-draft cleanup is future scope
* `draft` never syncs to the remote mirror
* `draft -> sent` happens only on the explicit send/submit-order action
* `sent -> paid` happens only on successful payment completion
* `sent -> cancelled` happens only on an explicit cancel action against an unpaid sent transaction
* entering `sent` atomically freezes the pre-payment snapshot and queues kitchen print exactly once
* `sent` is not editable because order-building must stop before payment/cancellation and before kitchen execution is treated as actionable
* `sent` does not require print success; it is the frozen commercial snapshot before payment
* kitchen print attempt happens only after successful `draft -> sent` and must never be triggered from pre-order or `draft` alone
* receipt print attempt happens only after successful `sent -> paid`
* active transaction lists consist of `draft` and `sent`
* if a UI/report surface still shows `open orders`, that label refers only to the combined active set `draft + sent`
* `paid` and `cancelled` are terminal persisted states

### Mutability matrix

| State       | lines | modifiers | discounts | table_number | notes / metadata |
| ----------- | ----- | --------- | --------- | ------------ | ---------------- |
| `draft`     | mutable | mutable | mutable | mutable | mutable |
| `sent`      | immutable | immutable | immutable | immutable | immutable |
| `paid`      | immutable | immutable | immutable | immutable | immutable |
| `cancelled` | immutable | immutable | immutable | immutable | immutable |

### Hard lifecycle guards

* each transition has exactly one allowed source state
* the same action must not resolve to multiple target states
* duplicate send requests must not create a second `draft -> sent` transition or duplicate kitchen-print side effects
* duplicate payment attempts must re-check persisted status and must not create a second payment row or duplicate `sent -> paid` transition
* duplicate cancel attempts must re-check persisted status and must not create a second `sent -> cancelled` transition
* terminal states must reject further lifecycle transitions

---

## 🏷 DISCOUNT RULES

* phase 1 supports transaction-level discount only
* line-item discount is out of scope
* tax, VAT, and service charge remain out of scope
* discount is part of the transaction snapshot, not a payment-side adjustment
* discount may be added, changed, or removed only while the transaction is in `draft`
* for discount mutability, `draft` is the only editable persisted transaction state in the canonical status model
* `sent`, `paid`, and `cancelled` transactions must not accept discount changes
* discount must be finalized before checkout/payment starts; payment uses the frozen post-discount total
* both `cashier` and `admin` may apply, change, or remove discount in phase 1
* no admin override or role-based limit exists in phase 1

### Discount storage contract

* `discount_type` = `amount | percent | null`
* `discount_value_minor` = raw integer input value
* `discount_amount_minor` = computed monetary discount actually deducted
* for `amount`, `discount_value_minor` stores currency minor units
* for `percent`, `discount_value_minor` stores whole-number percent integer `0..100` where `10 = 10%`
* do NOT use float/double, decimal percentages, or basis points
* `discount_reason` is nullable in phase 1
* `discount_applied_by` stores the acting `users.id` when a discount is present

### Discount pricing formula

```text
pre_discount_total_minor = subtotal_minor + modifier_total_minor
total_amount_minor = max(0, pre_discount_total_minor - discount_amount_minor)
```

Rules:

* fixed discount must not exceed `pre_discount_total_minor`
* for `discount_type = 'amount'`, `discount_amount_minor` equals the validated `discount_value_minor`
* percent discount must compute `discount_amount_minor` with integer-only round-half-up arithmetic against `pre_discount_total_minor`
* final total must never be negative
* removing discount resets `discount_type = null`, `discount_value_minor = 0`, `discount_amount_minor = 0`, `discount_reason = null`, and `discount_applied_by = null`
* receipt output must show discount as a separate line
* synced transaction snapshots must include the discount fields
* reporting in phase 1 must reconcile from net transaction total; separate discount analytics is future scope

---

## 💳 PAYMENT RULES

* EXACTLY ONE payment per transaction
* payment entry is allowed only when persisted `transactions.status = 'sent'`
* payment attempt must re-check persisted status immediately before inserting the payment row or finalizing payment
* if persisted status is not `sent`, payment must be rejected without payment-side effects
* `payments.amount_minor` MUST equal `transactions.total_amount_minor`
* atomic DB transaction required
* payment table must NOT store duplicate discount fields

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
* kitchen print eligibility begins only after successful `draft -> sent`
* receipt print eligibility begins only after successful `sent -> paid`
* kitchen print attempt occurs after successful `draft -> sent`; print success is not required to keep `sent`
* receipt print attempt occurs after successful `sent -> paid`; print success is not required to keep `paid`
* kitchen/receipt print flags are operational state only; they are not lifecycle state
* print retry must not create duplicate lifecycle transitions or duplicate payment records

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
* NEVER treat `open` as a syncable or stored status

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
17. ❌ Calculate discount only in payment UI without persisting it on the transaction
18. ❌ Add discount fields to `payments`
19. ❌ Change discount on `sent`, `paid`, or `cancelled` transactions
20. ❌ Use float/double for discount amount or percent math

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
