import { createClient } from "jsr:@supabase/supabase-js@2";

import {
  aggregateRevenueAnalytics,
  resolveAnalyticsPeriod,
} from "./aggregation.js";
import { extractBearerToken } from "./auth.js";

const jsonHeaders = { "Content-Type": "application/json" };
const lookbackDays = 120;
const pageSize = 1000;

type AnalyticsRequestBody = {
  period_type?: "preset" | "custom";
  preset?: "today" | "this_week" | "this_month" | "last_14_days";
  start_date?: string;
  end_date?: string;
};

type TransactionRow = {
  uuid: string;
  total_amount_minor: number;
  paid_at: string;
};

type CancelledTransactionRow = {
  uuid: string;
  cancelled_at: string | null;
  updated_at: string;
};

type PaymentRow = {
  transaction_uuid: string;
  method: "cash" | "card";
  amount_minor: number;
  paid_at: string;
};

type TransactionLineRow = {
  transaction_uuid: string;
  product_local_id: number | null;
  product_name: string;
  quantity: number;
  line_total_minor: number;
};

type AnalyticsAccessRow = {
  is_active: boolean;
};

const transactionChunkSize = 200;

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function validationFailure(message: string): Response {
  return jsonResponse(
    {
      ok: false,
      failure: "validation_failure",
      message,
    },
    400,
  );
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

function chunkValues<T>(values: T[], chunkSize: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += chunkSize) {
    chunks.push(values.slice(index, index + chunkSize));
  }
  return chunks;
}

function readRequestBody(requestText: string): AnalyticsRequestBody {
  if (requestText.trim().length === 0) {
    return {};
  }
  const parsed = JSON.parse(requestText);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("owner-revenue-analytics request body must be a JSON object");
  }
  return parsed as AnalyticsRequestBody;
}

function civilDateToUtcIso(civilDate: { year: number; month: number; day: number }) {
  return new Date(Date.UTC(civilDate.year, civilDate.month - 1, civilDate.day)).toISOString();
}

function earlierCivilDate(
  left: { year: number; month: number; day: number },
  right: { year: number; month: number; day: number },
) {
  const leftKey = `${left.year}-${left.month}-${left.day}`;
  const rightKey = `${right.year}-${right.month}-${right.day}`;
  return leftKey <= rightKey ? left : right;
}

async function fetchPaidTransactions(
  admin: ReturnType<typeof createClient>,
  windowStartIso: string,
  windowEndIso: string,
): Promise<TransactionRow[]> {
  const transactions: TransactionRow[] = [];
  let offset = 0;

  while (true) {
    const result = await admin
      .from("transactions")
      .select("uuid,total_amount_minor,paid_at")
      .eq("status", "paid")
      .not("paid_at", "is", null)
      .gte("paid_at", windowStartIso)
      .lte("paid_at", windowEndIso)
      .order("paid_at", { ascending: true })
      .range(offset, offset + pageSize - 1);

    if (result.error) {
      throw new Error("Failed to read paid revenue transactions from the mirror");
    }

    const page = (result.data ?? []) as TransactionRow[];
    transactions.push(...page);
    if (page.length < pageSize) {
      return transactions;
    }
    offset += pageSize;
  }
}

async function fetchCancelledTransactions(
  admin: ReturnType<typeof createClient>,
  windowStartIso: string,
  windowEndIso: string,
): Promise<CancelledTransactionRow[]> {
  const transactions: CancelledTransactionRow[] = [];
  let offset = 0;

  while (true) {
    const result = await admin
      .from("transactions")
      .select("uuid,cancelled_at,updated_at")
      .eq("status", "cancelled")
      .gte("updated_at", windowStartIso)
      .lte("updated_at", windowEndIso)
      .order("updated_at", { ascending: true })
      .range(offset, offset + pageSize - 1);

    if (result.error) {
      throw new Error(
        "Failed to read cancelled revenue transactions from the mirror",
      );
    }

    const page = (result.data ?? []) as CancelledTransactionRow[];
    transactions.push(...page);
    if (page.length < pageSize) {
      return transactions;
    }
    offset += pageSize;
  }
}

async function fetchPaymentsForTransactions(
  admin: ReturnType<typeof createClient>,
  transactionUuids: string[],
): Promise<PaymentRow[]> {
  const payments: PaymentRow[] = [];

  for (const chunk of chunkValues(transactionUuids, transactionChunkSize)) {
    let offset = 0;
    while (true) {
      const result = await admin
        .from("payments")
        .select("transaction_uuid,method,amount_minor,paid_at")
        .in("transaction_uuid", chunk)
        .order("transaction_uuid", { ascending: true })
        .range(offset, offset + pageSize - 1);

      if (result.error) {
        throw new Error("Failed to read revenue payment mix from the mirror");
      }

      const page = (result.data ?? []) as PaymentRow[];
      payments.push(...page);
      if (page.length < pageSize) {
        break;
      }
      offset += pageSize;
    }
  }

  return payments;
}

async function fetchTransactionLinesForTransactions(
  admin: ReturnType<typeof createClient>,
  transactionUuids: string[],
): Promise<TransactionLineRow[]> {
  const lines: TransactionLineRow[] = [];

  for (const chunk of chunkValues(transactionUuids, transactionChunkSize)) {
    let offset = 0;
    while (true) {
      const result = await admin
        .from("transaction_lines")
        .select(
          "transaction_uuid,product_local_id,product_name,quantity,line_total_minor",
        )
        .in("transaction_uuid", chunk)
        .order("transaction_uuid", { ascending: true })
        .range(offset, offset + pageSize - 1);

      if (result.error) {
        throw new Error("Failed to read product mover snapshots from the mirror");
      }

      const page = (result.data ?? []) as TransactionLineRow[];
      lines.push(...page);
      if (page.length < pageSize) {
        break;
      }
      offset += pageSize;
    }
  }

  return lines;
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

  let body: AnalyticsRequestBody;
  try {
    body = readRequestBody(await request.text());
  } catch (_) {
    return validationFailure(
      "owner-revenue-analytics request body must be a valid JSON object",
    );
  }

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
  } catch (_) {
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
  let resolvedPeriod;
  try {
    resolvedPeriod = resolveAnalyticsPeriod({
      generatedDate: now,
      periodType: body.period_type,
      preset: body.preset,
      startDate: body.start_date,
      endDate: body.end_date,
    });
  } catch (error) {
    return validationFailure(
      error instanceof Error ? error.message : "Invalid analytics period request",
    );
  }

  const defaultWindowStart = new Date(
    now.getTime() - lookbackDays * 24 * 60 * 60 * 1000,
  );
  const defaultWindowStartCivil = {
    year: defaultWindowStart.getUTCFullYear(),
    month: defaultWindowStart.getUTCMonth() + 1,
    day: defaultWindowStart.getUTCDate(),
  };
  const earliestStart = earlierCivilDate(
    defaultWindowStartCivil,
    resolvedPeriod.comparisonStart,
  );
  const fetchWindowStartIso = civilDateToUtcIso(earliestStart);
  const fetchWindowEndIso = now.toISOString();

  try {
    const paidTransactions = await fetchPaidTransactions(
      admin,
      fetchWindowStartIso,
      fetchWindowEndIso,
    );
    const cancelledTransactions = await fetchCancelledTransactions(
      admin,
      fetchWindowStartIso,
      fetchWindowEndIso,
    );
    const paidTransactionUuids = paidTransactions.map((row) => row.uuid);
    const payments = paidTransactionUuids.length == 0
      ? []
      : await fetchPaymentsForTransactions(admin, paidTransactionUuids);
    const transactionLines = paidTransactionUuids.length == 0
      ? []
      : await fetchTransactionLinesForTransactions(admin, paidTransactionUuids);

    return jsonResponse({
      ok: true,
      ...aggregateRevenueAnalytics({
        paidTransactions,
        cancelledTransactions,
        payments,
        transactionLines,
        generatedAt: now.toISOString(),
        periodType: resolvedPeriod.type,
        preset: resolvedPeriod.preset ?? undefined,
        startDate: body.start_date ?? undefined,
        endDate: body.end_date ?? undefined,
      }),
    });
  } catch (_) {
    return serverFailure(
      "Failed to aggregate revenue analytics.",
    );
  }
});
