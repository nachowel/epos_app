import postgres from "npm:postgres@3.4.4";

const jsonHeaders = { "Content-Type": "application/json" };

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse(
      {
        ok: false,
        message: "ops-apply-phase1-sql accepts POST only",
      },
      405,
    );
  }

  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!dbUrl) {
    return jsonResponse(
      {
        ok: false,
        message: "SUPABASE_DB_URL is not configured",
      },
      500,
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse(
      {
        ok: false,
        message: "Request body must be valid JSON",
      },
      400,
    );
  }

  const sqlText = typeof body === "object" && body !== null && "sql" in body
    ? (body as { sql?: unknown }).sql
    : null;
  if (typeof sqlText !== "string" || sqlText.trim().length === 0) {
    return jsonResponse(
      {
        ok: false,
        message: "Body.sql must be a non-empty string",
      },
      400,
    );
  }

  const client = postgres(dbUrl, {
    prepare: false,
    max: 1,
  });

  try {
    await client.unsafe(sqlText);
    return jsonResponse({ ok: true });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        message: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  } finally {
    await client.end({ timeout: 5 });
  }
});
