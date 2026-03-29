import { createClient } from "jsr:@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };
const remoteStatuses = new Set(["open", "paid", "cancelled"]);

type MirrorWriteRequest = {
  payload_version: number;
  transaction_uuid: string;
  transaction_idempotency_key: string;
  generated_at: string;
  transaction: Record<string, unknown>;
  transaction_lines: Array<Record<string, unknown>>;
  order_modifiers: Array<Record<string, unknown>>;
  payment: Record<string, unknown> | null;
};

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

  const transactionUuid = readString(payload, "transaction_uuid", issues);
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

  const rawPayment = payload["payment"];
  if (rawPayment !== null && rawPayment !== undefined && !isRecord(rawPayment)) {
    issues.push("payment must be an object or null");
  }
  const payment = isRecord(rawPayment) ? rawPayment : null;

  if (!transactionUuid || !idempotencyKey || !generatedAt || !isRecord(transaction)) {
    return { ok: false, issues };
  }

  const transactionRecordUuid = readString(transaction, "uuid", issues);
  const transactionStatus = readString(transaction, "status", issues);
  if (transactionRecordUuid && transactionRecordUuid !== transactionUuid) {
    issues.push("transaction.uuid must match transaction_uuid");
  }
  if (transactionStatus && !remoteStatuses.has(transactionStatus)) {
    issues.push("transaction.status must be one of open, paid, cancelled");
  }

  const lineUuids = new Set<string>();
  for (const line of transactionLines) {
    const lineUuid = readString(line, "uuid", issues);
    const lineTransactionUuid = readString(line, "transaction_uuid", issues);
    if (lineTransactionUuid && lineTransactionUuid !== transactionUuid) {
      issues.push("transaction_lines[*].transaction_uuid must match transaction_uuid");
    }
    if (lineUuid) {
      lineUuids.add(lineUuid);
    }
  }

  for (const modifier of orderModifiers) {
    const lineUuid = readString(modifier, "transaction_line_uuid", issues);
    if (lineUuid && !lineUuids.has(lineUuid)) {
      issues.push(
        "order_modifiers[*].transaction_line_uuid must reference a transaction_lines uuid in the same payload",
      );
    }
  }

  if (payment) {
    const paymentTransactionUuid = readString(payment, "transaction_uuid", issues);
    if (paymentTransactionUuid && paymentTransactionUuid !== transactionUuid) {
      issues.push("payment.transaction_uuid must match transaction_uuid");
    }
  }

  if (transactionStatus === "paid" && payment === null) {
    issues.push("paid transactions must include a payment mirror payload");
  }

  if (issues.isNotEmpty) {
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
      payment,
    },
  };
}

Deno.serve(async (request: Request) => {
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
  if (!supabaseUrl || !serviceRoleKey) {
    return serverConfigurationFailure(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be configured for mirror writes",
    );
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
    return serverFailure(
      "Failed to mirror transaction snapshot",
      transactionResult.error.message,
    );
  }

  if (payload.transaction_lines.length > 0) {
    const lineResult = await admin
      .from("transaction_lines")
      .upsert(payload.transaction_lines, { onConflict: "uuid" });
    if (lineResult.error) {
      return serverFailure(
        "Failed to mirror transaction line snapshots",
        lineResult.error.message,
      );
    }
  }

  if (payload.order_modifiers.length > 0) {
    const modifierResult = await admin
      .from("order_modifiers")
      .upsert(payload.order_modifiers, { onConflict: "uuid" });
    if (modifierResult.error) {
      return serverFailure(
        "Failed to mirror order modifier snapshots",
        modifierResult.error.message,
      );
    }
  }

  if (payload.payment) {
    const paymentResult = await admin
      .from("payments")
      .upsert(payload.payment, { onConflict: "uuid" });
    if (paymentResult.error) {
      return serverFailure(
        "Failed to mirror payment snapshot",
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
      payload.order_modifiers.length +
      (payload.payment ? 1 : 0),
  });
});
