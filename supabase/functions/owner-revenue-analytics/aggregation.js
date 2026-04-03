export const BUSINESS_TIMEZONE = "Europe/London";
export const HOURLY_BUCKETS = 24;
export const TOP_PRODUCTS_LIMIT = 5;

export const DAYPART_DEFINITIONS = [
  { daypart: "breakfast", startHour: 5, endHourInclusive: 10 },
  { daypart: "lunch", startHour: 11, endHourInclusive: 14 },
  { daypart: "afternoon", startHour: 15, endHourInclusive: 17 },
  { daypart: "evening", startHour: 18, endHourInclusive: 22 },
  { daypart: "late", startHour: 23, endHourInclusive: 4 },
];

const weekdayMap = {
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
  Sun: 7,
};

const localPartsFormatter = new Intl.DateTimeFormat("en-GB", {
  timeZone: BUSINESS_TIMEZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  weekday: "short",
  hour: "2-digit",
  hourCycle: "h23",
});

export function aggregateRevenueAnalytics({
  transactions,
  paidTransactions,
  cancelledTransactions = [],
  payments = [],
  transactionLines = [],
  generatedAt,
  periodType = "preset",
  preset = "this_week",
  startDate = null,
  endDate = null,
}) {
  const generatedDate = new Date(generatedAt);
  if (Number.isNaN(generatedDate.valueOf())) {
    throw new Error("generatedAt must be a valid ISO date");
  }

  const paidTransactionRows = paidTransactions ?? transactions ?? [];
  const today = getLocalCivilDate(generatedDate);
  const yesterday = addDays(today, -1);
  const thisWeekStart = startOfWeek(today);
  const lastWeekStart = addDays(thisWeekStart, -7);
  const thisMonthStart = startOfMonth(today);
  const lastMonthStart = addMonths(thisMonthStart, -1);
  const resolvedPeriod = resolveAnalyticsPeriod({
    generatedDate,
    periodType,
    preset,
    startDate,
    endDate,
  });

  const periodStartKey = civilDateKey(resolvedPeriod.start);
  const periodEndKey = civilDateKey(resolvedPeriod.end);
  const comparisonStartKey = civilDateKey(resolvedPeriod.comparisonStart);
  const comparisonEndKey = civilDateKey(resolvedPeriod.comparisonEnd);
  const trendWindowStart = addDays(today, -13);
  const trendWindowEnd = today;
  const dailyTrendDays = buildDailyTrendDays(trendWindowStart, trendWindowEnd);
  const dailyTrendMap = new Map(
    dailyTrendDays.map((civilDate) => [civilDateKey(civilDate), emptyBucket()]),
  );
  const weeklySummaryStarts = buildWeeklySummaryStartsForRange(
    resolvedPeriod.start,
    resolvedPeriod.end,
  );
  const weeklySummaryMap = new Map(
    weeklySummaryStarts.map((civilDate) => [
      civilDateKey(civilDate),
      emptyBucket(),
    ]),
  );
  const hourlyDistribution = Array.from({ length: HOURLY_BUCKETS }, (_, hour) => ({
    hour,
    revenue_minor: 0,
    order_count: 0,
  }));
  const daypartDistributionMap = new Map(
    DAYPART_DEFINITIONS.map(({ daypart }) => [
      daypart,
      {
        daypart,
        revenue_minor: 0,
        order_count: 0,
      },
    ]),
  );
  const dataQualityNotes = [
    "refunds not available in remote analytics",
    "true shift intelligence unavailable because shifts are not mirrored",
  ];

  let todayTotalMinor = 0;
  let yesterdayTotalMinor = 0;
  let thisWeekTotalMinor = 0;
  let lastWeekTotalMinor = 0;
  let thisMonthTotalMinor = 0;
  let lastMonthTotalMinor = 0;
  let todayOrderCount = 0;
  let yesterdayOrderCount = 0;
  let thisWeekOrderCount = 0;
  let lastWeekOrderCount = 0;
  let thisMonthOrderCount = 0;
  let lastMonthOrderCount = 0;
  let thisWeekCashRevenueMinor = 0;
  let thisWeekCardRevenueMinor = 0;
  let lastWeekCashRevenueMinor = 0;
  let lastWeekCardRevenueMinor = 0;
  let thisMonthCashRevenueMinor = 0;
  let thisMonthCardRevenueMinor = 0;
  let lastMonthCashRevenueMinor = 0;
  let lastMonthCardRevenueMinor = 0;
  let thisWeekCancelledOrderCount = 0;
  let lastWeekCancelledOrderCount = 0;
  let thisMonthCancelledOrderCount = 0;
  let lastMonthCancelledOrderCount = 0;

  let periodTotalMinor = 0;
  let previousPeriodTotalMinor = 0;
  let periodOrderCount = 0;
  let previousPeriodOrderCount = 0;
  let periodCashRevenueMinor = 0;
  let periodCardRevenueMinor = 0;
  let previousPeriodCashRevenueMinor = 0;
  let previousPeriodCardRevenueMinor = 0;
  let periodCancelledOrderCount = 0;
  let previousPeriodCancelledOrderCount = 0;

  const paidTransactionPeriods = new Map();
  const currentPeriodProducts = new Map();
  const previousPeriodProducts = new Map();

  for (const transaction of paidTransactionRows) {
    const paidAt = new Date(transaction.paid_at);
    if (Number.isNaN(paidAt.valueOf())) {
      throw new Error("transaction.paid_at must be a valid ISO date");
    }
    const revenueMinor = toMinorInt(transaction.total_amount_minor);
    if (revenueMinor < 0) {
      throw new Error("transaction.total_amount_minor must be non-negative");
    }

    const localParts = getLocalDateTimeParts(paidAt);
    const civilDate = {
      year: localParts.year,
      month: localParts.month,
      day: localParts.day,
    };
    const dayKey = civilDateKey(civilDate);
    const weekKey = civilDateKey(startOfWeek(civilDate));
    const monthKey = civilDateKey(startOfMonth(civilDate));
    const transactionUuid = readNonEmptyString(transaction.uuid, "transaction.uuid");

    const inCurrentPeriod = isBetweenKeys(dayKey, periodStartKey, periodEndKey);
    const inPreviousPeriod = isBetweenKeys(
      dayKey,
      comparisonStartKey,
      comparisonEndKey,
    );

    paidTransactionPeriods.set(transactionUuid, {
      dayKey,
      inCurrentPeriod,
      inPreviousPeriod,
    });

    if (dayKey === civilDateKey(today)) {
      todayTotalMinor += revenueMinor;
      todayOrderCount += 1;
    }
    if (dayKey === civilDateKey(yesterday)) {
      yesterdayTotalMinor += revenueMinor;
      yesterdayOrderCount += 1;
    }
    if (weekKey === civilDateKey(thisWeekStart)) {
      thisWeekTotalMinor += revenueMinor;
      thisWeekOrderCount += 1;
    }
    if (weekKey === civilDateKey(lastWeekStart)) {
      lastWeekTotalMinor += revenueMinor;
      lastWeekOrderCount += 1;
    }
    if (monthKey === civilDateKey(thisMonthStart)) {
      thisMonthTotalMinor += revenueMinor;
      thisMonthOrderCount += 1;
    }
    if (monthKey === civilDateKey(lastMonthStart)) {
      lastMonthTotalMinor += revenueMinor;
      lastMonthOrderCount += 1;
    }

    if (inCurrentPeriod) {
      periodTotalMinor += revenueMinor;
      periodOrderCount += 1;

      const hourBucket = hourlyDistribution[localParts.hour];
      hourBucket.revenue_minor += revenueMinor;
      hourBucket.order_count += 1;

      const daypartBucket = daypartDistributionMap.get(resolveDaypart(localParts.hour));
      daypartBucket.revenue_minor += revenueMinor;
      daypartBucket.order_count += 1;

      if (weeklySummaryMap.has(weekKey)) {
        const weeklyBucket = weeklySummaryMap.get(weekKey);
        weeklyBucket.revenue_minor += revenueMinor;
        weeklyBucket.order_count += 1;
      }
    } else if (inPreviousPeriod) {
      previousPeriodTotalMinor += revenueMinor;
      previousPeriodOrderCount += 1;
    }

    const dailyBucket = dailyTrendMap.get(dayKey);
    if (dailyBucket) {
      dailyBucket.revenue_minor += revenueMinor;
      dailyBucket.order_count += 1;
    }
  }

  for (const payment of payments) {
    const paymentPaidAt = new Date(payment.paid_at);
    if (Number.isNaN(paymentPaidAt.valueOf())) {
      throw new Error("payment.paid_at must be a valid ISO date");
    }
    const amountMinor = toMinorInt(payment.amount_minor);
    if (amountMinor < 0) {
      throw new Error("payment.amount_minor must be non-negative");
    }
    const method = readNonEmptyString(payment.method, "payment.method");
    if (method !== "cash" && method !== "card") {
      throw new Error("payment.method must be cash or card");
    }

    const localCivilDate = getLocalCivilDate(paymentPaidAt);
    const dayKey = civilDateKey(localCivilDate);
    const weekKey = civilDateKey(startOfWeek(localCivilDate));
    const monthKey = civilDateKey(startOfMonth(localCivilDate));
    const isCash = method === "cash";

    if (isBetweenKeys(dayKey, periodStartKey, periodEndKey)) {
      if (isCash) {
        periodCashRevenueMinor += amountMinor;
      } else {
        periodCardRevenueMinor += amountMinor;
      }
    } else if (isBetweenKeys(dayKey, comparisonStartKey, comparisonEndKey)) {
      if (isCash) {
        previousPeriodCashRevenueMinor += amountMinor;
      } else {
        previousPeriodCardRevenueMinor += amountMinor;
      }
    }

    if (weekKey === civilDateKey(thisWeekStart)) {
      if (isCash) {
        thisWeekCashRevenueMinor += amountMinor;
      } else {
        thisWeekCardRevenueMinor += amountMinor;
      }
    }
    if (weekKey === civilDateKey(lastWeekStart)) {
      if (isCash) {
        lastWeekCashRevenueMinor += amountMinor;
      } else {
        lastWeekCardRevenueMinor += amountMinor;
      }
    }
    if (monthKey === civilDateKey(thisMonthStart)) {
      if (isCash) {
        thisMonthCashRevenueMinor += amountMinor;
      } else {
        thisMonthCardRevenueMinor += amountMinor;
      }
    }
    if (monthKey === civilDateKey(lastMonthStart)) {
      if (isCash) {
        lastMonthCashRevenueMinor += amountMinor;
      } else {
        lastMonthCardRevenueMinor += amountMinor;
      }
    }
  }

  let usesNameBasedProductAggregation = false;
  for (const line of transactionLines) {
    const transactionUuid = readNonEmptyString(
      line.transaction_uuid,
      "transaction_line.transaction_uuid",
    );
    const transactionPeriod = paidTransactionPeriods.get(transactionUuid);
    if (!transactionPeriod) {
      continue;
    }

    const quantitySold = toPositiveInt(line.quantity, "transaction_line.quantity");
    const revenueMinor = toMinorInt(line.line_total_minor);
    if (revenueMinor < 0) {
      throw new Error("transaction_line.line_total_minor must be non-negative");
    }
    const productName = readNonEmptyString(
      line.product_name,
      "transaction_line.product_name",
    );

    let productKey;
    if (typeof line.product_local_id === "number" && !Number.isNaN(line.product_local_id)) {
      productKey = String(Math.trunc(line.product_local_id));
    } else {
      productKey = `name:${productName}`;
      usesNameBasedProductAggregation = true;
    }

    const bucket = transactionPeriod.inCurrentPeriod
      ? currentPeriodProducts
      : transactionPeriod.inPreviousPeriod
      ? previousPeriodProducts
      : null;
    if (bucket === null) {
      continue;
    }

    const existing = bucket.get(productKey) ?? {
      product_key: productKey,
      product_name: productName,
      quantity_sold: 0,
      revenue_minor: 0,
    };
    existing.quantity_sold += quantitySold;
    existing.revenue_minor += revenueMinor;
    bucket.set(productKey, existing);
  }

  if (usesNameBasedProductAggregation) {
    dataQualityNotes.push(
      "product mover aggregation is name-based because stable mirrored product identifiers were unavailable for part of the dataset",
    );
  }

  for (const transaction of cancelledTransactions) {
    const cancelledAtRaw = transaction.cancelled_at;
    if (typeof cancelledAtRaw !== "string" || cancelledAtRaw.trim().length === 0) {
      pushUnique(
        dataQualityNotes,
        "cancelled attribution unavailable for some mirror rows because reliable cancelled_at was missing",
      );
      continue;
    }
    const cancelledAt = new Date(cancelledAtRaw);
    if (Number.isNaN(cancelledAt.valueOf())) {
      pushUnique(
        dataQualityNotes,
        "cancelled attribution unavailable for some mirror rows because cancelled_at was invalid",
      );
      continue;
    }

    const localCivilDate = getLocalCivilDate(cancelledAt);
    const dayKey = civilDateKey(localCivilDate);
    const weekKey = civilDateKey(startOfWeek(localCivilDate));
    const monthKey = civilDateKey(startOfMonth(localCivilDate));

    if (isBetweenKeys(dayKey, periodStartKey, periodEndKey)) {
      periodCancelledOrderCount += 1;
    } else if (isBetweenKeys(dayKey, comparisonStartKey, comparisonEndKey)) {
      previousPeriodCancelledOrderCount += 1;
    }

    if (weekKey === civilDateKey(thisWeekStart)) {
      thisWeekCancelledOrderCount += 1;
    }
    if (weekKey === civilDateKey(lastWeekStart)) {
      lastWeekCancelledOrderCount += 1;
    }
    if (monthKey === civilDateKey(thisMonthStart)) {
      thisMonthCancelledOrderCount += 1;
    }
    if (monthKey === civilDateKey(lastMonthStart)) {
      lastMonthCancelledOrderCount += 1;
    }
  }

  if (resolvedPeriod.dayCount < 2 || (periodOrderCount == 0 && previousPeriodOrderCount == 0)) {
    pushUnique(dataQualityNotes, "Insufficient data for reliable comparison");
  }

  return {
    timezone: BUSINESS_TIMEZONE,
    generated_at: generatedDate.toISOString(),
    period: {
      type: resolvedPeriod.type,
      ...(resolvedPeriod.preset == null ? {} : { preset: resolvedPeriod.preset }),
      start_date: civilDateKey(resolvedPeriod.start),
      end_date: civilDateKey(resolvedPeriod.end),
      day_count: resolvedPeriod.dayCount,
    },
    comparison_period: {
      basis: "previous_equivalent_period",
      start_date: civilDateKey(resolvedPeriod.comparisonStart),
      end_date: civilDateKey(resolvedPeriod.comparisonEnd),
      day_count: resolvedPeriod.dayCount,
    },
    period_total_minor: periodTotalMinor,
    previous_period_total_minor: previousPeriodTotalMinor,
    period_order_count: periodOrderCount,
    previous_period_order_count: previousPeriodOrderCount,
    period_average_order_value_minor: averageOrderValueMinor(
      periodTotalMinor,
      periodOrderCount,
    ),
    previous_period_average_order_value_minor: averageOrderValueMinor(
      previousPeriodTotalMinor,
      previousPeriodOrderCount,
    ),
    period_cash_revenue_minor: periodCashRevenueMinor,
    period_card_revenue_minor: periodCardRevenueMinor,
    previous_period_cash_revenue_minor: previousPeriodCashRevenueMinor,
    previous_period_card_revenue_minor: previousPeriodCardRevenueMinor,
    period_cancelled_order_count: periodCancelledOrderCount,
    previous_period_cancelled_order_count: previousPeriodCancelledOrderCount,
    today_total_minor: todayTotalMinor,
    yesterday_total_minor: yesterdayTotalMinor,
    this_week_total_minor: thisWeekTotalMinor,
    last_week_total_minor: lastWeekTotalMinor,
    this_month_total_minor: thisMonthTotalMinor,
    last_month_total_minor: lastMonthTotalMinor,
    today_order_count: todayOrderCount,
    yesterday_order_count: yesterdayOrderCount,
    this_week_order_count: thisWeekOrderCount,
    last_week_order_count: lastWeekOrderCount,
    this_month_order_count: thisMonthOrderCount,
    last_month_order_count: lastMonthOrderCount,
    this_week_average_order_value_minor: averageOrderValueMinor(
      thisWeekTotalMinor,
      thisWeekOrderCount,
    ),
    last_week_average_order_value_minor: averageOrderValueMinor(
      lastWeekTotalMinor,
      lastWeekOrderCount,
    ),
    this_month_average_order_value_minor: averageOrderValueMinor(
      thisMonthTotalMinor,
      thisMonthOrderCount,
    ),
    last_month_average_order_value_minor: averageOrderValueMinor(
      lastMonthTotalMinor,
      lastMonthOrderCount,
    ),
    this_week_cash_revenue_minor: thisWeekCashRevenueMinor,
    this_week_card_revenue_minor: thisWeekCardRevenueMinor,
    last_week_cash_revenue_minor: lastWeekCashRevenueMinor,
    last_week_card_revenue_minor: lastWeekCardRevenueMinor,
    this_month_cash_revenue_minor: thisMonthCashRevenueMinor,
    this_month_card_revenue_minor: thisMonthCardRevenueMinor,
    last_month_cash_revenue_minor: lastMonthCashRevenueMinor,
    last_month_card_revenue_minor: lastMonthCardRevenueMinor,
    this_week_cancelled_order_count: thisWeekCancelledOrderCount,
    last_week_cancelled_order_count: lastWeekCancelledOrderCount,
    this_month_cancelled_order_count: thisMonthCancelledOrderCount,
    last_month_cancelled_order_count: lastMonthCancelledOrderCount,
    daily_trend: dailyTrendDays.map((civilDate) => ({
      date: civilDateKey(civilDate),
      ...dailyTrendMap.get(civilDateKey(civilDate)),
    })),
    weekly_summary: weeklySummaryStarts.map((civilDate) => ({
      week_start: civilDateKey(civilDate),
      ...weeklySummaryMap.get(civilDateKey(civilDate)),
    })),
    hourly_distribution: hourlyDistribution,
    daypart_distribution: DAYPART_DEFINITIONS.map(({ daypart }) =>
      daypartDistributionMap.get(daypart)
    ),
    top_products_current_period: buildTopProducts(currentPeriodProducts),
    top_products_previous_period: buildTopProducts(previousPeriodProducts),
    data_quality_notes: dataQualityNotes,
  };
}

export function resolveAnalyticsPeriod({
  generatedDate,
  periodType = "preset",
  preset = "this_week",
  startDate = null,
  endDate = null,
}) {
  const today = getLocalCivilDate(generatedDate);
  if (periodType === "custom") {
    const parsedStart = parseCivilDateInput(startDate);
    const parsedEnd = parseCivilDateInput(endDate);
    if (!parsedStart || !parsedEnd) {
      throw new Error("custom analytics period requires valid start_date and end_date");
    }
    const normalizedEnd = compareCivilDate(parsedEnd, today) > 0 ? today : parsedEnd;
    const normalizedStart = compareCivilDate(parsedStart, normalizedEnd) > 0
      ? normalizedEnd
      : parsedStart;
    const dayCount = diffCivilDays(normalizedStart, normalizedEnd) + 1;
    return {
      type: "custom",
      preset: null,
      start: normalizedStart,
      end: normalizedEnd,
      comparisonStart: addDays(normalizedStart, -dayCount),
      comparisonEnd: addDays(normalizedStart, -1),
      dayCount,
    };
  }

  const resolvedPreset = preset ?? "this_week";
  let start = today;
  let end = today;
  switch (resolvedPreset) {
    case "today":
      break;
    case "this_week":
      start = startOfWeek(today);
      break;
    case "this_month":
      start = startOfMonth(today);
      break;
    case "last_14_days":
      start = addDays(today, -13);
      break;
    default:
      throw new Error(`Unsupported analytics preset: ${resolvedPreset}`);
  }
  const dayCount = diffCivilDays(start, end) + 1;
  return {
    type: "preset",
    preset: resolvedPreset,
    start,
    end,
    comparisonStart: addDays(start, -dayCount),
    comparisonEnd: addDays(start, -1),
    dayCount,
  };
}

function buildDailyTrendDays(start, end) {
  const totalDays = diffCivilDays(start, end) + 1;
  return Array.from({ length: totalDays }, (_, index) => addDays(start, index));
}

function buildWeeklySummaryStartsForRange(start, end) {
  const startWeek = startOfWeek(start);
  const endWeek = startOfWeek(end);
  const weeks = [];
  for (
    let current = startWeek;
    compareCivilDate(current, endWeek) <= 0;
    current = addDays(current, 7)
  ) {
    weeks.push(current);
  }
  return weeks;
}

function parseCivilDateInput(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.valueOf())) {
    return null;
  }
  return {
    year: parsed.getUTCFullYear(),
    month: parsed.getUTCMonth() + 1,
    day: parsed.getUTCDate(),
  };
}

function diffCivilDays(start, end) {
  const startUtc = Date.UTC(start.year, start.month - 1, start.day);
  const endUtc = Date.UTC(end.year, end.month - 1, end.day);
  return Math.round((endUtc - startUtc) / (24 * 60 * 60 * 1000));
}

function compareCivilDate(left, right) {
  return civilDateKey(left).localeCompare(civilDateKey(right));
}

function isBetweenKeys(value, start, end) {
  return value >= start && value <= end;
}

function getLocalCivilDate(date) {
  const parts = getLocalDateTimeParts(date);
  return { year: parts.year, month: parts.month, day: parts.day };
}

function getLocalDateTimeParts(date) {
  const parts = localPartsFormatter.formatToParts(date);
  const resolved = {
    year: 0,
    month: 0,
    day: 0,
    hour: 0,
    weekday: 0,
  };

  for (const part of parts) {
    switch (part.type) {
      case "year":
        resolved.year = Number.parseInt(part.value, 10);
        break;
      case "month":
        resolved.month = Number.parseInt(part.value, 10);
        break;
      case "day":
        resolved.day = Number.parseInt(part.value, 10);
        break;
      case "hour":
        resolved.hour = Number.parseInt(part.value, 10);
        break;
      case "weekday":
        resolved.weekday = weekdayMap[part.value] ?? 0;
        break;
      default:
        break;
    }
  }

  if (
    resolved.year === 0 ||
    resolved.month === 0 ||
    resolved.day === 0 ||
    resolved.weekday === 0
  ) {
    throw new Error("Unable to resolve local business time parts");
  }

  return resolved;
}

function startOfWeek(civilDate) {
  const utcDate = new Date(
    Date.UTC(civilDate.year, civilDate.month - 1, civilDate.day),
  );
  const utcWeekday = utcDate.getUTCDay();
  const mondayOffset = (utcWeekday + 6) % 7;
  return addDays(civilDate, -mondayOffset);
}

function startOfMonth(civilDate) {
  return {
    year: civilDate.year,
    month: civilDate.month,
    day: 1,
  };
}

function addMonths(civilDate, months) {
  const shiftedDate = new Date(
    Date.UTC(civilDate.year, civilDate.month - 1 + months, 1),
  );
  return {
    year: shiftedDate.getUTCFullYear(),
    month: shiftedDate.getUTCMonth() + 1,
    day: shiftedDate.getUTCDate(),
  };
}

function addDays(civilDate, days) {
  const shiftedDate = new Date(
    Date.UTC(civilDate.year, civilDate.month - 1, civilDate.day + days),
  );
  return {
    year: shiftedDate.getUTCFullYear(),
    month: shiftedDate.getUTCMonth() + 1,
    day: shiftedDate.getUTCDate(),
  };
}

function civilDateKey(civilDate) {
  return `${civilDate.year.toString().padStart(4, "0")}-${civilDate.month
    .toString()
    .padStart(2, "0")}-${civilDate.day.toString().padStart(2, "0")}`;
}

function emptyBucket() {
  return {
    revenue_minor: 0,
    order_count: 0,
  };
}

function buildTopProducts(source) {
  return Array.from(source.values())
    .sort((left, right) =>
      right.revenue_minor - left.revenue_minor ||
      right.quantity_sold - left.quantity_sold ||
      left.product_name.localeCompare(right.product_name) ||
      left.product_key.localeCompare(right.product_key)
    )
    .slice(0, TOP_PRODUCTS_LIMIT);
}

function resolveDaypart(hour) {
  if (hour >= 5 && hour <= 10) {
    return "breakfast";
  }
  if (hour >= 11 && hour <= 14) {
    return "lunch";
  }
  if (hour >= 15 && hour <= 17) {
    return "afternoon";
  }
  if (hour >= 18 && hour <= 22) {
    return "evening";
  }
  return "late";
}

function averageOrderValueMinor(revenueMinor, orderCount) {
  if (orderCount <= 0) {
    return 0;
  }
  return Math.round(revenueMinor / orderCount);
}

function readNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${fieldName} must be a non-empty string`);
  }
  return value;
}

function toPositiveInt(value, fieldName) {
  const result = toMinorInt(value);
  if (result <= 0) {
    throw new Error(`${fieldName} must be positive`);
  }
  return result;
}

function pushUnique(target, value) {
  if (!target.includes(value)) {
    target.push(value);
  }
}

function toMinorInt(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    throw new Error("transaction.total_amount_minor must be numeric");
  }
  return Math.trunc(value);
}
