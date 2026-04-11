import {
  assert,
  assertEquals,
} from "jsr:@std/assert@1";

import {
  buildOrderModifierAuditContext,
  sanitizeOrderModifierRow,
  sanitizeOrderModifierRows,
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

    assertEquals(Object.keys(sanitized), <string>[
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
