import {
  assert,
  assertEquals,
} from "jsr:@std/assert@1";

import {
  buildOrderModifierAuditContext,
  findUnexpectedPayloadKeys,
  sanitizeOrderModifierRow,
  sanitizeOrderModifierRows,
  validateRequest,
} from "./index.ts";

function hasOwn(source: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(source, key);
}

Deno.test(
  "sanitizeOrderModifierRow keeps only allowed order_modifiers columns",
  () => {
    const sanitized = sanitizeOrderModifierRow({
      uuid: "33333333-3333-3333-3333-333333333333",
      transaction_line_uuid: "22222222-2222-2222-2222-222222222222",
      action: "add",
      item_name: "Extra Cheese",
      extra_price_minor: 150,
      quantity: 1,
      item_product_id: null,
      charge_reason: "extra_add",
      unit_price_minor: 150,
      price_effect_minor: 150,
      sort_key: 2,
      price_behavior: undefined,
      ui_section: null,
      unexpected_flag: true,
      nested_garbage: { bad: true },
    });

    assertEquals(Object.keys(sanitized), <string[]>[
      "uuid",
      "transaction_line_uuid",
      "action",
      "item_name",
      "extra_price_minor",
      "quantity",
      "item_product_id",
      "charge_reason",
      "unit_price_minor",
      "price_effect_minor",
      "sort_key",
      "ui_section",
    ]);
    assertEquals(sanitized["ui_section"], null);
    assert(!hasOwn(sanitized, "price_behavior"));
    assert(!hasOwn(sanitized, "unexpected_flag"));
    assert(!hasOwn(sanitized, "nested_garbage"));
  },
);

Deno.test(
  "buildOrderModifierAuditContext reports raw extras and sanitized sample",
  () => {
    const rawRows = [
      {
        uuid: "33333333-3333-3333-3333-333333333333",
        transaction_line_uuid: "22222222-2222-2222-2222-222222222222",
        action: "add",
        item_name: "Extra Cheese",
        extra_price_minor: 150,
        quantity: 1,
        item_product_id: null,
        charge_reason: "extra_add",
        unit_price_minor: 150,
        price_effect_minor: 150,
        sort_key: 2,
        ui_section: "toppings",
        stray_array: ["bad"],
      },
    ];
    const sanitizedRows = sanitizeOrderModifierRows(rawRows);

    const auditContext = buildOrderModifierAuditContext(rawRows, sanitizedRows);

    assertEquals(auditContext["row_count"], 1);
    assertEquals(auditContext["raw_first_row_extra_keys"], ["stray_array"]);
    assertEquals(
      auditContext["sanitized_first_row_sample"],
      sanitizedRows[0],
    );
    assertEquals(
      auditContext["sanitized_first_row_keys"],
      Object.keys(sanitizedRows[0]),
    );
  },
);

Deno.test(
  "findUnexpectedPayloadKeys reports drifted transaction payload columns",
  () => {
    const unexpectedColumns = findUnexpectedPayloadKeys("transactions", {
      uuid: "11111111-1111-1111-1111-111111111111",
      status: "paid",
      subtotal_minor: 1000,
      total_amount_minor: 1000,
      rogue_flag: true,
    });

    assertEquals(unexpectedColumns, ["rogue_flag"]);
  },
);

Deno.test(
  "validateRequest rejects unexpected payload columns before any upsert runs",
  () => {
    const validation = validateRequest({
      payload_version: 1,
      transaction_uuid: "11111111-1111-1111-1111-111111111111",
      transaction_idempotency_key: "idem-1",
      generated_at: "2026-04-18T10:00:00.000Z",
      transaction: {
        uuid: "11111111-1111-1111-1111-111111111111",
        status: "paid",
        shift_local_id: 1,
        user_local_id: 2,
        table_number: null,
        subtotal_minor: 1000,
        modifier_total_minor: 0,
        discount_type: null,
        discount_value_minor: 0,
        discount_amount_minor: 0,
        discount_reason: null,
        discount_applied_by_local_id: null,
        total_amount_minor: 1000,
        created_at: "2026-04-18T09:55:00.000Z",
        paid_at: "2026-04-18T10:00:00.000Z",
        updated_at: "2026-04-18T10:00:00.000Z",
        cancelled_at: null,
        cancelled_by_local_id: null,
        kitchen_printed: true,
        receipt_printed: true,
      },
      transaction_lines: [{
        uuid: "22222222-2222-2222-2222-222222222222",
        transaction_uuid: "11111111-1111-1111-1111-111111111111",
        product_local_id: 11,
        product_name: "Latte",
        unit_price_minor: 1000,
        quantity: 1,
        pricing_mode: "standard",
        removal_discount_total_minor: 0,
        line_total_minor: 1000,
      }],
      order_modifiers: [{
        uuid: "33333333-3333-3333-3333-333333333333",
        transaction_line_uuid: "22222222-2222-2222-2222-222222222222",
        action: "add",
        item_name: "Extra Shot",
        extra_price_minor: 50,
        quantity: 1,
        item_product_id: null,
        charge_reason: null,
        unit_price_minor: 50,
        price_effect_minor: 50,
        sort_key: 0,
        rogue_flag: true,
      }],
      payments: [{
        uuid: "44444444-4444-4444-4444-444444444444",
        transaction_uuid: "11111111-1111-1111-1111-111111111111",
        method: "card",
        amount_minor: 1000,
        paid_at: "2026-04-18T10:00:00.000Z",
      }],
    });

    assertEquals(validation.ok, false);
    if (validation.ok) {
      throw new Error("Expected validation failure.");
    }
    assert(
      validation.issues.some((issue) =>
        issue.includes(
          "order_modifiers[0] contains unexpected columns: rogue_flag",
        )
      ),
    );
  },
);
