export const BUSINESS_TIMEZONE = "Europe/London";
export const DAILY_TREND_DAYS = 14;
export const WEEKLY_SUMMARY_WEEKS = 6;
export const HOURLY_BUCKETS = 24;

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

export function aggregateRevenueAnalytics({ transactions, generatedAt }) {
  const generatedDate = new Date(generatedAt);
  if (Number.isNaN(generatedDate.valueOf())) {
    throw new Error("generatedAt must be a valid ISO date");
  }

  const today = getLocalCivilDate(generatedDate);
  const yesterday = addDays(today, -1);
  const thisWeekStart = startOfWeek(today);
  const lastWeekStart = addDays(thisWeekStart, -7);
  const thisMonthStart = startOfMonth(today);
  const lastMonthStart = addMonths(thisMonthStart, -1);

  const dailyTrendDays = buildDailyTrendDays(today);
  const dailyTrendMap = new Map(
    dailyTrendDays.map((civilDate) => [civilDateKey(civilDate), emptyBucket()]),
  );
  const weeklySummaryStarts = buildWeeklySummaryStarts(thisWeekStart);
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

  let todayTotalMinor = 0;
  let yesterdayTotalMinor = 0;
  let thisWeekTotalMinor = 0;
  let lastWeekTotalMinor = 0;
  let thisMonthTotalMinor = 0;
  let lastMonthTotalMinor = 0;
  let thisWeekOrderCount = 0;
  let lastWeekOrderCount = 0;

  for (const transaction of transactions) {
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

    if (dayKey === civilDateKey(today)) {
      todayTotalMinor += revenueMinor;
    }
    if (dayKey === civilDateKey(yesterday)) {
      yesterdayTotalMinor += revenueMinor;
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
    }
    if (monthKey === civilDateKey(lastMonthStart)) {
      lastMonthTotalMinor += revenueMinor;
    }

    if (dailyTrendMap.has(dayKey)) {
      const dailyBucket = dailyTrendMap.get(dayKey);
      dailyBucket.revenue_minor += revenueMinor;
      dailyBucket.order_count += 1;

      const hourBucket = hourlyDistribution[localParts.hour];
      hourBucket.revenue_minor += revenueMinor;
      hourBucket.order_count += 1;
    }

    if (weeklySummaryMap.has(weekKey)) {
      const weeklyBucket = weeklySummaryMap.get(weekKey);
      weeklyBucket.revenue_minor += revenueMinor;
      weeklyBucket.order_count += 1;
    }
  }

  return {
    timezone: BUSINESS_TIMEZONE,
    generated_at: generatedDate.toISOString(),
    today_total_minor: todayTotalMinor,
    yesterday_total_minor: yesterdayTotalMinor,
    this_week_total_minor: thisWeekTotalMinor,
    last_week_total_minor: lastWeekTotalMinor,
    this_month_total_minor: thisMonthTotalMinor,
    last_month_total_minor: lastMonthTotalMinor,
    this_week_order_count: thisWeekOrderCount,
    last_week_order_count: lastWeekOrderCount,
    daily_trend: dailyTrendDays.map((civilDate) => ({
      date: civilDateKey(civilDate),
      ...dailyTrendMap.get(civilDateKey(civilDate)),
    })),
    weekly_summary: weeklySummaryStarts.map((civilDate) => ({
      week_start: civilDateKey(civilDate),
      ...weeklySummaryMap.get(civilDateKey(civilDate)),
    })),
    hourly_distribution: hourlyDistribution,
  };
}

function buildDailyTrendDays(today) {
  return Array.from({ length: DAILY_TREND_DAYS }, (_, index) =>
    addDays(today, index - (DAILY_TREND_DAYS - 1)),
  );
}

function buildWeeklySummaryStarts(thisWeekStart) {
  return Array.from({ length: WEEKLY_SUMMARY_WEEKS }, (_, index) =>
    addDays(thisWeekStart, -7 * (WEEKLY_SUMMARY_WEEKS - 1 - index)),
  );
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

function toMinorInt(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    throw new Error("transaction.total_amount_minor must be numeric");
  }
  return Math.trunc(value);
}
