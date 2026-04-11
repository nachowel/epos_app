import { createClient } from "jsr:@supabase/supabase-js@2";
import { validateInternalFunctionAuth } from "../_shared/internal_auth.js";

const jsonHeaders = { "Content-Type": "application/json" };
const remoteStatuses = new Set(["paid", "cancelled"]);
const canonicalUuidPattern =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

type MirrorWriteRequest = {
  payload_version: number;
  transaction_uuid: string;
  transaction_idempotency_key: string;
  generated_at: string;
  transaction: Record<string, unknown>;
  transaction_lines: Array<Record<string, unknown>>;
  order_modifiers: Array<Record<string, unknown>>;
  payments: Array<Record<string, unknown>>;
};

const orderModifierAllowedColumns = [
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
  "price_behavior",
  "ui_section",
] as const;
const orderModifierAllowedColumnSet = new Set<string>(orderModifierAllowedColumns);

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function validationFailure(message: string, issues: string[]): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "validation_failure",
      message,
      retryable: false,
      issues,
    },
    400,
  );
}

function serverFailure(
  message: string,
  details?: unknown,
  retryable = true,
): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "remote_server_error",
      message,
      retryable,
      details,
    },
    500,
  );
}

function tableFailure(
  message: string,
  table: string,
  recordUuids: string[],
  details?: unknown,
  retryable = true,
): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "remote_server_error",
      message,
      retryable,
      table,
      record_uuid: recordUuids.length === 1 ? recordUuids[0] : null,
      record_uuids: recordUuids,
      details,
    },
    500,
  );
}

function serverConfigurationFailure(message: string): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "server_configuration",
      message,
      retryable: false,
    },
    500,
  );
}

function unauthorizedFailure(
  message: string,
  failure = "unauthorized",
  status = 401,
): Response {
  return jsonResponse(
    {
      ok: false,
      failure,
      message,
      retryable: false,
    },
    status,
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readString(
  source: Record<string, unknown>,
  key: string,
  issues: string[],
): string | null {
  const value = source[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    issues.push(`${key} must be a non-empty string`);
    return null;
  }
  return value;
}

function readUuid(
  source: Record<string, unknown>,
  key: string,
  issues: string[],
): string | null {
  const value = readString(source, key, issues);
  if (value === null) {
    return null;
  }
  if (!canonicalUuidPattern.test(value)) {
    issues.push(`${key} must be a canonical UUID string`);
    return null;
  }
  return value;
}

function readRecordArray(
  source: Record<string, unknown>,
  key: string,
  issues: string[],
): Array<Record<string, unknown>> {
  const value = source[key];
  if (!Array.isArray(value)) {
    issues.push(`${key} must be an array`);
    return [];
  }
  if (value.some((item) => !isRecord(item))) {
    issues.push(`${key} must contain only objects`);
    return [];
  }
  return value as Array<Record<string, unknown>>;
}

function tableResult(
  table: string,
  recordUuids: string[],
): Record<string, unknown> {
  return {
    table,
    status: recordUuids.length === 0 ? "skipped" : "synced",
    record_count: recordUuids.length,
    record_uuids: recordUuids,
  };
}

function setIfDefined(
  target: Record<string, unknown>,
  key: string,
  value: unknown,
) {
  if (value !== undefined) {
    target[key] = value;
  }
}

export function sanitizeOrderModifierRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};
  setIfDefined(sanitized, "uuid", row["uuid"]);
  setIfDefined(
    sanitized,
    "transaction_line_uuid",
    row["transaction_line_uuid"],
  );
  setIfDefined(sanitized, "action", row["action"]);
  setIfDefined(sanitized, "item_name", row["item_name"]);
  setIfDefined(sanitized, "extra_price_minor", row["extra_price_minor"]);
  setIfDefined(sanitized, "quantity", row["quantity"]);
  setIfDefined(sanitized, "item_product_id", row["item_product_id"]);
  setIfDefined(sanitized, "charge_reason", row["charge_reason"]);
  setIfDefined(sanitized, "unit_price_minor", row["unit_price_minor"]);
  setIfDefined(sanitized, "price_effect_minor", row["price_effect_minor"]);
  setIfDefined(sanitized, "sort_key", row["sort_key"]);
  setIfDefined(sanitized, "price_behavior", row["price_behavior"]);
  setIfDefined(sanitized, "ui_section", row["ui_section"]);
  return sanitized;
}

export function sanitizeOrderModifierRows(
  rows: Array<Record<string, unknown>>,
): Array<Record<string, unknown>> {
  return rows.map((row) => sanitizeOrderModifierRow(row));
}

function findUnexpectedOrderModifierKeys(
  row: Record<string, unknown> | null,
): string[] {
  if (row === null) {
    return [];
  }
  return Object.keys(row).filter((key) => !orderModifierAllowedColumnSet.has(key));
}

function serializeSupabaseError(error: {
  message: string;
  details: string | null;
  hint: string | null;
  code: string;
}): Record<string, unknown> {
  return {
    message: error.message,
    details: error.details,
    hint: error.hint,
    code: error.code,
  };
}

export function buildOrderModifierAuditContext(
  rawRows: Array<Record<string, unknown>>,
  sanitizedRows: Array<Record<string, unknown>>,
): Record<string, unknown> {
  const rawFirstRow = rawRows.length > 0 ? rawRows[0] : null;
  const sanitizedFirstRow = sanitizedRows.length > 0 ? sanitizedRows[0] : null;
  return {
    row_count: sanitizedRows.length,
    raw_first_row_keys: rawFirstRow === null ? [] : Object.keys(rawFirstRow),
    raw_first_row_extra_keys: findUnexpectedOrderModifierKeys(rawFirstRow),
    raw_first_row_sample: rawFirstRow,
    sanitized_first_row_keys:
      sanitizedFirstRow === null ? [] : Object.keys(sanitizedFirstRow),
    sanitized_first_row_sample: sanitizedFirstRow,
  };
}

function validateRequest(payload: unknown):
  | { ok: true; value: MirrorWriteRequest }
  | { ok: false; issues: string[] } {
  const issues: string[] = [];
  if (!isRecord(payload)) {
    return { ok: false, issues: ["Request body must be a JSON object"] };
  }

  const payloadVersion = payload["payload_version"];
  if (payloadVersion !== 1) {
    issues.push("payload_version must equal 1");
  }

  const transactionUuid = readUuid(payload, "transaction_uuid", issues);
  const idempotencyKey = readString(
    payload,
    "transaction_idempotency_key",
    issues,
  );
  const generatedAt = readString(payload, "generated_at", issues);

  const transaction = payload["transaction"];
  if (!isRecord(transaction)) {
    issues.push("transaction must be an object");
  }

  const transactionLines = readRecordArray(payload, "transaction_lines", issues);
  const orderModifiers = readRecordArray(payload, "order_modifiers", issues);

  const payments = readRecordArray(payload, "payments", issues);

  if (!transactionUuid || !idempotencyKey || !generatedAt || !isRecord(transaction)) {
    return { ok: false, issues };
  }

  const transactionRecordUuid = readUuid(transaction, "uuid", issues);
  const transactionStatus = readString(transaction, "status", issues);
  if (transactionRecordUuid && transactionRecordUuid !== transactionUuid) {
    issues.push("transaction.uuid must match transaction_uuid");
  }
  if (transactionStatus && !remoteStatuses.has(transactionStatus)) {
    issues.push("transaction.status must be one of paid, cancelled");
  }

  const lineUuids = new Set<string>();
  for (const line of transactionLines) {
    const lineUuid = readUuid(line, "uuid", issues);
    const lineTransactionUuid = readUuid(line, "transaction_uuid", issues);
    if (lineTransactionUuid && lineTransactionUuid !== transactionUuid) {
      issues.push("transaction_lines[*].transaction_uuid must match transaction_uuid");
    }
    if (lineUuid) {
      lineUuids.add(lineUuid);
    }
  }

  for (const modifier of orderModifiers) {
    readUuid(modifier, "uuid", issues);
    const lineUuid = readUuid(modifier, "transaction_line_uuid", issues);
    if (lineUuid && !lineUuids.has(lineUuid)) {
      issues.push(
        "order_modifiers[*].transaction_line_uuid must reference a transaction_lines uuid in the same payload",
      );
    }
  }

  for (const payment of payments) {
    readUuid(payment, "uuid", issues);
    const paymentTransactionUuid = readUuid(payment, "transaction_uuid", issues);
    if (paymentTransactionUuid && paymentTransactionUuid !== transactionUuid) {
      issues.push("payments[*].transaction_uuid must match transaction_uuid");
    }
  }

  if (transactionStatus === "paid" && payments.length === 0) {
    issues.push("paid transactions must include at least one payment mirror payload");
  }

  if (issues.length > 0) {
    return { ok: false, issues };
  }

  return {
    ok: true,
    value: {
      payload_version: 1,
      transaction_uuid: transactionUuid,
      transaction_idempotency_key: idempotencyKey,
      generated_at: generatedAt,
      transaction,
      transaction_lines: transactionLines,
      order_modifiers: orderModifiers,
      payments,
    },
  };
}

export async function handleMirrorTransactionGraphRequest(
  request: Request,
): Promise<Response> {
  if (request.method !== "POST") {
    return jsonResponse(
      {
        ok: false,
        failure: "validation_failure",
        message: "mirror-transaction-graph accepts POST only",
        retryable: false,
      },
      405,
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (_) {
    return validationFailure("Request body must be valid JSON", [
      "Unable to parse JSON request body",
    ]);
  }

  const validation = validateRequest(body);
  if (!validation.ok) {
    return validationFailure(
      "Trusted mirror boundary rejected the payload",
      validation.issues,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const internalApiKey = Deno.env.get("EPOS_INTERNAL_API_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return serverConfigurationFailure(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be configured for mirror writes",
    );
  }
  if (!internalApiKey) {
    return serverConfigurationFailure(
      "EPOS_INTERNAL_API_KEY must be configured for mirror writes",
    );
  }
  console.log("[AUTH_DEBUG] expected_key_length:", internalApiKey?.length);
  console.log("[AUTH_DEBUG] expected_key_preview:", internalApiKey?.substring(0, 6));
  console.log(
    "[AUTH_DEBUG] received_key_preview:",
    request.headers.get("x-epos-internal-key")?.substring(0, 6),
  );
  console.log(
    "[AUTH_DEBUG] received_key_length:",
    request.headers.get("x-epos-internal-key")?.length,
  );
  const auth = validateInternalFunctionAuth(request.headers, internalApiKey);
  if (!auth.ok) {
    if (auth.status === 500) {
      return serverConfigurationFailure(auth.message);
    }
    return unauthorizedFailure(auth.message, auth.failure, auth.status);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const payload = validation.value;

  // Local Drift is the business authority. This function writes only the
  // already-finalized mirror snapshot to remote reporting tables.
  const transactionResult = await admin
    .from("transactions")
    .upsert(payload.transaction, { onConflict: "uuid" });
  if (transactionResult.error) {
    return tableFailure(
      "Failed to mirror transaction snapshot",
      "transactions",
      [payload.transaction_uuid],
      transactionResult.error.message,
    );
  }

  const transactionLineUuids = payload.transaction_lines
    .map((line) => typeof line["uuid"] === "string" ? line["uuid"] : null)
    .filter((uuid): uuid is string => uuid !== null);
  if (payload.transaction_lines.length > 0) {
    const lineResult = await admin
      .from("transaction_lines")
      .upsert(payload.transaction_lines, { onConflict: "uuid" });
    if (lineResult.error) {
      return tableFailure(
        "Failed to mirror transaction line snapshots",
        "transaction_lines",
        transactionLineUuids,
        lineResult.error.message,
      );
    }
  }

  const sanitizedOrderModifiers = sanitizeOrderModifierRows(
    payload.order_modifiers,
  );
  const orderModifierAuditContext = buildOrderModifierAuditContext(
    payload.order_modifiers,
    sanitizedOrderModifiers,
  );
  const orderModifierUuids = sanitizedOrderModifiers
    .map((modifier) => typeof modifier["uuid"] === "string" ? modifier["uuid"] : null)
    .filter((uuid): uuid is string => uuid !== null);
  if (payload.order_modifiers.length > 0) {
    console.log(
      "[ORDER_MODIFIERS_AUDIT]",
      JSON.stringify(orderModifierAuditContext),
    );
    const modifierResult = await admin
      .from("order_modifiers")
      .upsert(sanitizedOrderModifiers, { onConflict: "uuid" });
    if (modifierResult.error) {
      const failureDetails = {
        row_count: sanitizedOrderModifiers.length,
        sanitized_first_row_sample:
          orderModifierAuditContext["sanitized_first_row_sample"] ?? null,
        raw_first_row_extra_keys:
          orderModifierAuditContext["raw_first_row_extra_keys"] ?? [],
        supabase_error: serializeSupabaseError(modifierResult.error),
      };
      console.error(
        "[ORDER_MODIFIERS_UPSERT_FAILED]",
        JSON.stringify(failureDetails),
      );
      return tableFailure(
        "Failed to mirror order modifier snapshots",
        "order_modifiers",
        orderModifierUuids,
        failureDetails,
      );
    }
  }

  const paymentUuids = payload.payments
    .map((payment) => typeof payment["uuid"] === "string" ? payment["uuid"] : null)
    .filter((uuid): uuid is string => uuid !== null);
  if (payload.payments.length > 0) {
    const paymentResult = await admin
      .from("payments")
      .upsert(payload.payments, { onConflict: "uuid" });
    if (paymentResult.error) {
      return tableFailure(
        "Failed to mirror payment snapshots",
        "payments",
        paymentUuids,
        paymentResult.error.message,
      );
    }
  }

  return jsonResponse({
    ok: true,
    transaction_uuid: payload.transaction_uuid,
    transaction_status: payload.transaction["status"],
    mirrored_records:
      1 +
      payload.transaction_lines.length +
      sanitizedOrderModifiers.length +
      payload.payments.length,
    table_results: [
      tableResult("transactions", [payload.transaction_uuid]),
      tableResult("transaction_lines", transactionLineUuids),
      tableResult("order_modifiers", orderModifierUuids),
      tableResult("payments", paymentUuids),
    ],
  });
}

if (import.meta.main) {
  Deno.serve(handleMirrorTransactionGraphRequest);
}
