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
* breakfast/menu-engine contract docs

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

| Layer            | Truth Source                     |
| ---------------- | -------------------------------- |
| Schema           | `app_database.dart` + migrations |
| Business rules   | domain services                  |
| Breakfast engine | contract docs                    |
| Coding rules     | this file                        |
| Summary docs     | schema.md                        |

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

### ⚠️ IMPORTANT:

Live schema may use:

```text
draft / sent / paid / cancelled
```

Older docs may show:

```text
open / paid / cancelled
```

👉 FOLLOW LIVE SCHEMA (`app_database.dart`)

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
* NEVER `open/draft`

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
