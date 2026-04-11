# POS Category Entry Flow Contract

---

## Purpose

This contract defines the approved behavior for:
- the Category Entry screen
- POS handoff from category selection
- transaction/order creation timing
- category ordering across screens
- admin category reorder behavior

Use this contract for implementation and documentation alignment after
`SYSTEM_OF_TRUTH.md` and the live schema.

---

## Core System Model

The Category Entry screen is the primary cashier/admin start and idle screen.

It appears:
- after successful login
- after payment completes
- while waiting for the next customer

It is a navigation layer only.

Selecting a category from Category Entry:
- opens the existing POS product screen with that category preselected
- does not create a cart
- does not create a draft transaction
- does not create an empty/open order

The transaction/order begins only when the first product is selected and added
to cart on the POS screen.

---

## Lifecycle States

### Pre-order state

Before the first product is added, the system is in a pre-order state.

Pre-order state characteristics:
- no transaction exists
- no cart exists, whether persisted or in-memory as a structured order
- no `transaction_id` is allocated
- UI may allow browsing categories and products

Forbidden in pre-order state:
- creating temporary transactions
- allocating transaction IDs before the first product is added
- persisting cart state without a transaction
- maintaining a parallel in-memory cart before transaction creation
- simulating cart behavior without a real transaction

### Pre-order exit condition

The system exits pre-order state only when a product is successfully added to
cart.

No other action may trigger pre-order exit.

Successful first-product add causes all of the following:
- the transaction is created
- the cart is created together with the transaction
- the cart is always tied to `transaction_id`
- a `transaction_id` is allocated
- the system leaves pre-order state
- the system enters active transaction flow

Persisted transaction status model:
- `draft`
- `sent`
- `paid`
- `cancelled`

---

## Screen Responsibility Split

### Category Entry screen

Responsibilities:
- present available categories
- act as the start/idle navigation screen
- hand off to the POS screen with a preselected category

Non-responsibilities:
- no category sidebar
- no cart interaction
- no order creation
- no transaction state mutation beyond navigation

### POS screen

Responsibilities:
- product browsing inside the selected category
- category switching through the POS category sidebar
- cart building
- transaction/order lifecycle after the first product is added

The Category Entry screen and POS screen are separate responsibilities and must
not be merged into a single behavioral contract.

---

## Approved Flow

1. User logs in.
2. Category Entry screen opens.
3. Cashier taps a category.
4. POS product screen opens with that category preselected.
5. Cashier may switch categories from the POS sidebar and add products.
6. The first successfully added product atomically creates the transaction/order context.
7. Payment completes.
8. Cart is fully destroyed.
9. Selected category is cleared.
10. Transaction context is closed.
11. System returns to a clean pre-order state on the Category Entry screen.

---

## Order Creation Trigger

The transaction/order creation trigger is:
- first successfully added product on the POS screen

The following events must not create a transaction/order:
- successful login
- entering the Category Entry screen
- tapping a category on the Category Entry screen
- opening the POS screen with a preselected category
- switching categories in the POS sidebar

Empty persisted transactions or active orders created only from navigation are forbidden.
Temporary transactions, preallocated transaction IDs, and persisted cart state
without a transaction are also forbidden.
Parallel in-memory carts before transaction creation and simulated cart
behavior without a real transaction are also forbidden.

---

## First Product Add Atomic Rule

The first successful product add must happen in one atomic operation.

That atomic operation must:
1. create the transaction
2. set `transaction.status = 'draft'`
3. insert the first `transaction_line`
4. compute totals
5. set `updated_at`

It is forbidden to:
- create a transaction without a line
- insert a line without a transaction

---

## Canonical Transaction Status Lifecycle

Canonical persisted `transactions.status` values are:
- `draft`
- `sent`
- `paid`
- `cancelled`

Operational meaning:
- `draft`: the first product has already been added, the transaction exists, the order is still editable, and it has not yet been sent
- `sent`: the order has been submitted from draft, line-item mutation is no longer allowed, and the order becomes eligible for payment or cancellation
- `paid`: payment completed successfully; this is terminal
- `cancelled`: a sent order was cancelled without payment; this is terminal

Allowed persisted transitions:
- pre-order -> no persisted transaction
- first successful product add -> create transaction with `status = 'draft'`
- `draft -> sent`
- `sent -> paid`
- `sent -> cancelled`

Forbidden transitions:
- pre-order -> any persisted status without a successful first product add
- `draft -> paid`
- `draft -> cancelled`
- `paid -> *`
- `cancelled -> *`

Draft discard rule:
- a `draft` may be discarded/deleted before send
- discard is not a persisted `cancelled` transition
- discard removes the draft transaction instead of converting it to another status

Legacy terminology rule:
- older `open` wording is deprecated compatibility language only
- `open` is not a canonical persisted transaction status
- docs and new implementation work must not use `open` as a stored `transactions.status` value

---

## Payment, Cancellation, Print, And Sync Rules

Payment eligibility:
- payment is allowed only from `sent`
- payment is forbidden from pre-order, `draft`, `paid`, and `cancelled`

Cancellation eligibility:
- cancellation is allowed only from `sent`
- cancellation is forbidden from pre-order, `draft`, `paid`, and `cancelled`

Kitchen print implications:
- kitchen print job is queued when the order transitions `draft -> sent`
- kitchen print eligibility belongs to `sent` and `paid`
- pre-order, `draft`, and `cancelled` are not kitchen-active states

Receipt print implications:
- receipt print job is queued when the order transitions `sent -> paid`
- receipt print eligibility belongs to `paid` only

Sync implications:
- only terminal transactions sync to the remote mirror
- sync-eligible statuses are `paid` and `cancelled`
- `draft` and `sent` remain local-only operational states

Active-order list rule:
- active/open-order lists consist of `draft` and `sent`
- `open orders` may be used as a UI/report label for that combined active set
- `open` must not be documented or implemented as a stored status value

After cancellation:
- the transaction remains persisted with `status = 'cancelled'`
- it is removed from active/open-order lists
- it is no longer editable or payable
- it remains available for reporting and terminal sync

---

## Payment Completion Reset Rule

After payment completes:
- the cart is fully destroyed
- the selected category is cleared
- the transaction context is closed
- the system returns to a clean pre-order state
- the Category Entry screen becomes the visible idle/start screen again

---

## Category Entry Layout Contract

The screen title must be:
- `Categories`

Category presentation rules:
- categories are ordered by `categories.sort_order`
- the first 4 categories by `sort_order` render as large cards
- remaining categories render as smaller cards in a grid below
- the first 4 categories must not be repeated in the lower grid

Layout rules:
- no sidebar
- no cart
- no POS order controls

---

## Category Ordering Contract

`categories.sort_order` is the single source of truth for category order.

This same order must be used by:
- Category Entry large-card section
- Category Entry lower grid
- POS category sidebar
- any other category picker unless a future contract explicitly defines an exception

Forbidden ordering behaviors:
- screen-level local sorting overrides
- popularity-based ordering
- dynamic reshuffling by system behavior
- separate featured-category configuration
- separate popularity-order source

All category displays must derive from `categories.sort_order`.

---

## Admin Reorder Contract

Admin must be able to reorder all categories.

Interaction contract:
- reorder is visual and card-based
- reorder uses long-press drag-and-drop on category cards
- reordering covers the full category list, not a text-only list

Persistence contract:
- dropping a card changes only the local pending order
- reorder must use explicit `Save` and `Cancel`
- `Save` persists the new order into `categories.sort_order`
- `Cancel` restores the prior persisted order
- auto-save on drop is forbidden

---

## Consistency Rule

Different screens must not apply different local sorting rules to the same
category dataset.

The system-wide rule is:
- one category order source
- one persisted order field
- one cross-screen presentation order

If two screens show categories in different orders without an explicit approved
contract exception, that behavior is wrong.

---

## Schema Impact

No schema change is required for this contract.

Reason:
- `categories.sort_order` already exists in the live schema
- the approved behavior does not require a separate featured field
- the approved behavior does not require a popularity field
- the approved behavior does not require an additional order-source table

If documentation or UI assumptions imply otherwise, correct the documentation
or UI behavior instead of inventing a new schema.
