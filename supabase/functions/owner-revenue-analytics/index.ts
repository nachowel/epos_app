import { createClient } from "jsr:@supabase/supabase-js@2";

import {
  aggregateRevenueAnalytics,
} from "./aggregation.js";
import { extractBearerToken } from "./auth.js";

const jsonHeaders = { "Content-Type": "application/json" };
const lookbackDays = 120;
const pageSize = 1000;

type TransactionRow = {
  total_amount_minor: number;
  paid_at: string;
};

type AnalyticsAccessRow = {
  is_active: boolean;
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function serverConfigurationFailure(message: string): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "server_configuration",
      message,
    },
    500,
  );
}

function unauthorizedFailure(
  message: string,
  failure = "unauthorized",
): Response {
  return jsonResponse(
    {
      ok: false,
      failure,
      message,
    },
    401,
  );
}

function forbiddenFailure(message: string, failure = "unauthorized"): Response {
  return jsonResponse(
    {
      ok: false,
      failure,
      message,
    },
    403,
  );
}

function serverFailure(message: string): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "server_error",
      message,
    },
    500,
  );
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse(
      {
        ok: false,
        failure: "validation_failure",
        message: "owner-revenue-analytics accepts POST only",
      },
      405,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return serverConfigurationFailure(
      "SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY must be configured for revenue analytics",
    );
  }

  const token = extractBearerToken(request.headers);
  if (!token.ok) {
    return unauthorizedFailure(token.message, token.failure);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  let authUserId = "";
  try {
    const authResult = await authClient.auth.getUser(token.accessToken);
    const authUser = authResult.data.user;
    if (authResult.error || !authUser) {
      return unauthorizedFailure(
        "Authorization token is invalid or expired.",
        "invalid_token",
      );
    }
    authUserId = authUser.id;
  } catch (error) {
    return serverFailure(
      "Failed to validate the Supabase access token.",
    );
  }

  const mappedUserResult = await admin
    .from("analytics_access_map")
    .select("is_active")
    .eq("supabase_auth_id", authUserId)
    .maybeSingle();
  if (mappedUserResult.error) {
    return serverFailure(
      "Failed to verify admin access for owner revenue analytics.",
    );
  }

  const mappedUser = mappedUserResult.data as AnalyticsAccessRow | null;
  if (!mappedUser) {
    return forbiddenFailure(
      "Authenticated Supabase user is not authorized for owner revenue analytics.",
      "analytics_access_missing",
    );
  }
  if (!mappedUser.is_active) {
    return forbiddenFailure(
      "Authenticated user's owner analytics access is inactive.",
      "analytics_access_inactive",
    );
  }

  const now = new Date();
  const windowStart = new Date(
    now.getTime() - lookbackDays * 24 * 60 * 60 * 1000,
  );

  const transactions: TransactionRow[] = [];
  let offset = 0;
  while (true) {
    const result = await admin
      .from("transactions")
      .select("total_amount_minor,paid_at")
      .eq("status", "paid")
      .not("paid_at", "is", null)
      .gte("paid_at", windowStart.toISOString())
      .lte("paid_at", now.toISOString())
      .order("paid_at", { ascending: true })
      .range(offset, offset + pageSize - 1);

    if (result.error) {
      return serverFailure(
        "Failed to read paid revenue transactions from the mirror",
      );
    }

    const page = (result.data ?? []) as TransactionRow[];
    transactions.push(...page);

    if (page.length < pageSize) {
      break;
    }
    offset += pageSize;
  }

  try {
    return jsonResponse({
      ok: true,
      ...aggregateRevenueAnalytics({
        transactions,
        generatedAt: now.toISOString(),
      }),
    });
  } catch (error) {
    return serverFailure(
      "Failed to aggregate revenue analytics.",
    );
  }
});
