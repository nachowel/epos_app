import { createClient } from "jsr:@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };
const allowedTables = new Set([
  "transactions",
  "transaction_lines",
  "order_modifiers",
  "payments",
]);

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse(
      {
        ok: false,
        failure: "validation_failure",
        message: "mirror-health accepts POST only",
        retryable: false,
      },
      405,
    );
  }

  let body: unknown = {};
  try {
    body = await request.json();
  } catch (_) {
    body = {};
  }

  const requiredTables = isRecord(body) && Array.isArray(body["required_tables"])
    ? body["required_tables"].filter((value): value is string =>
        typeof value === "string" && allowedTables.has(value)
      )
    : Array.from(allowedTables);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      {
        ok: false,
        failure: "server_configuration",
        message:
          "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be configured for mirror health checks",
        retryable: false,
      },
      500,
    );
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const tableStates: Record<string, string> = {};
  for (const tableName of requiredTables) {
    const result = await admin.from(tableName).select("uuid").limit(1);
    if (!result.error) {
      tableStates[tableName] = "present";
      continue;
    }

    const message = result.error.message.toLowerCase();
    if (
      message.includes("does not exist") ||
      message.includes("not found in the schema cache") ||
      message.includes("pgrst205")
    ) {
      tableStates[tableName] = "missing";
      continue;
    }

    tableStates[tableName] = "inaccessible";
  }

  return jsonResponse({
    ok: true,
    table_states: tableStates,
    successful_query_count:
      Object.values(tableStates).filter((value) => value === "present").length,
  });
});
