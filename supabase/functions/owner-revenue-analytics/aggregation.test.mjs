import test from "node:test";
import assert from "node:assert/strict";

import { aggregateRevenueAnalytics, resolveAnalyticsPeriod } from "./aggregation.js";

test("empty dataset returns zero-filled dynamic buckets and additive period fields", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [],
    cancelledTransactions: [],
    payments: [],
    transactionLines: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "this_week",
  });

  assert.equal(summary.period.type, "preset");
  assert.equal(summary.period.preset, "this_week");
  assert.equal(summary.period.start_date, "2026-03-30");
  assert.equal(summary.period.end_date, "2026-03-31");
  assert.equal(summary.period.day_count, 2);
  assert.equal(summary.comparison_period.day_count, 2);
  assert.equal(summary.period_total_minor, 0);
  assert.equal(summary.previous_period_total_minor, 0);
  assert.equal(summary.period_order_count, 0);
  assert.equal(summary.daily_trend.length, 14);
  assert.equal(summary.daily_trend.at(0).date, "2026-03-18");
  assert.equal(summary.daily_trend.at(-1).date, "2026-03-31");
  assert.equal(summary.weekly_summary.length, 1);
  assert.equal(summary.hourly_distribution.length, 24);
  assert.equal(summary.daypart_distribution.length, 5);
  assert.deepEqual(
    summary.hourly_distribution.map((bucket) => bucket.hour),
    Array.from({ length: 24 }, (_, hour) => hour),
  );
  assert.equal(
    summary.data_quality_notes.includes("Insufficient data for reliable comparison"),
    true,
  );
});

test("this_week preset resolves to Monday through today in London business time", () => {
  const resolved = resolveAnalyticsPeriod({
    generatedDate: new Date("2026-03-31T12:00:00.000Z"),
    periodType: "preset",
    preset: "this_week",
  });

  assert.equal(resolved.start.year, 2026);
  assert.equal(resolved.start.month, 3);
  assert.equal(resolved.start.day, 30);
  assert.equal(resolved.end.year, 2026);
  assert.equal(resolved.end.month, 3);
  assert.equal(resolved.end.day, 31);
  assert.equal(resolved.dayCount, 2);
});

test("last_14_days preset returns 14 daily buckets and matching previous-period window", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "last_14_days",
  });

  assert.equal(summary.period.start_date, "2026-03-18");
  assert.equal(summary.period.end_date, "2026-03-31");
  assert.equal(summary.period.day_count, 14);
  assert.equal(summary.comparison_period.start_date, "2026-03-04");
  assert.equal(summary.comparison_period.end_date, "2026-03-17");
  assert.equal(summary.daily_trend.length, 14);
});

test("custom period resolves to a same-length previous comparison period", () => {
  const resolved = resolveAnalyticsPeriod({
    generatedDate: new Date("2026-03-31T12:00:00.000Z"),
    periodType: "custom",
    startDate: "2026-03-01",
    endDate: "2026-03-10",
  });

  assert.equal(resolved.start.day, 1);
  assert.equal(resolved.end.day, 10);
  assert.equal(resolved.dayCount, 10);
  assert.equal(resolved.comparisonStart.day, 19);
  assert.equal(resolved.comparisonStart.month, 2);
  assert.equal(resolved.comparisonEnd.day, 28);
  assert.equal(resolved.comparisonEnd.month, 2);
});

test("DST transition keeps buckets on the correct London local day and hour", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-1",
        total_amount_minor: 1000,
        paid_at: "2026-03-29T00:30:00.000Z",
      },
      {
        uuid: "tx-2",
        total_amount_minor: 2000,
        paid_at: "2026-03-29T01:30:00.000Z",
      },
    ],
    payments: [],
    transactionLines: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "last_14_days",
  });

  const dstDay = summary.daily_trend.find((bucket) => bucket.date === "2026-03-29");
  assert.equal(dstDay.revenue_minor, 3000);
  assert.equal(summary.hourly_distribution[0].revenue_minor, 1000);
  assert.equal(summary.hourly_distribution[2].revenue_minor, 2000);
});

test("week start is Monday and Sunday revenue stays in the previous week", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-1",
        total_amount_minor: 1500,
        paid_at: "2026-03-29T09:00:00.000Z",
      },
      {
        uuid: "tx-2",
        total_amount_minor: 2500,
        paid_at: "2026-03-30T09:00:00.000Z",
      },
    ],
    payments: [],
    transactionLines: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "last_14_days",
  });

  const march23Week = summary.weekly_summary.find((bucket) => bucket.week_start === "2026-03-23");
  const march30Week = summary.weekly_summary.find((bucket) => bucket.week_start === "2026-03-30");
  assert.equal(march23Week.revenue_minor, 1500);
  assert.equal(march30Week.revenue_minor, 2500);
  assert.equal(summary.this_week_total_minor, 2500);
  assert.equal(summary.last_week_total_minor, 1500);
});

test("expanded contract fields remain additive and money stays in integer minor units", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-100",
        total_amount_minor: 2400,
        paid_at: "2026-03-31T08:15:00.000Z",
      },
      {
        uuid: "tx-101",
        total_amount_minor: 3600,
        paid_at: "2026-03-30T12:30:00.000Z",
      },
      {
        uuid: "tx-099",
        total_amount_minor: 1800,
        paid_at: "2026-03-24T18:45:00.000Z",
      },
      {
        uuid: "tx-080",
        total_amount_minor: 2000,
        paid_at: "2026-02-20T16:00:00.000Z",
      },
    ],
    cancelledTransactions: [],
    payments: [
      {
        transaction_uuid: "tx-100",
        method: "cash",
        amount_minor: 2400,
        paid_at: "2026-03-31T08:15:00.000Z",
      },
      {
        transaction_uuid: "tx-101",
        method: "card",
        amount_minor: 3600,
        paid_at: "2026-03-30T12:30:00.000Z",
      },
      {
        transaction_uuid: "tx-099",
        method: "cash",
        amount_minor: 1800,
        paid_at: "2026-03-24T18:45:00.000Z",
      },
      {
        transaction_uuid: "tx-080",
        method: "card",
        amount_minor: 2000,
        paid_at: "2026-02-20T16:00:00.000Z",
      },
    ],
    transactionLines: [
      {
        transaction_uuid: "tx-100",
        product_local_id: 11,
        product_name: "Flat White",
        quantity: 2,
        line_total_minor: 2400,
      },
      {
        transaction_uuid: "tx-101",
        product_local_id: 12,
        product_name: "Burger",
        quantity: 1,
        line_total_minor: 3600,
      },
      {
        transaction_uuid: "tx-080",
        product_local_id: 11,
        product_name: "Flat White",
        quantity: 1,
        line_total_minor: 2000,
      },
    ],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "last_14_days",
  });

  assert.equal(summary.hourly_distribution.length, 24);
  assert.equal(summary.daypart_distribution.length, 5);
  assert.equal(summary.today_order_count, 1);
  assert.equal(summary.yesterday_order_count, 1);
  assert.equal(summary.this_month_order_count, 3);
  assert.equal(summary.last_month_order_count, 1);
  assert.equal(summary.period_order_count, 3);
  assert.equal(summary.previous_period_order_count, 0);
  assert.equal(summary.this_week_average_order_value_minor, 3000);
  assert.equal(summary.last_week_average_order_value_minor, 1800);
  assert.equal(summary.this_month_cash_revenue_minor, 4200);
  assert.equal(summary.this_month_card_revenue_minor, 3600);
  assert.equal(summary.last_month_card_revenue_minor, 2000);
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "breakfast")
      .revenue_minor,
    2400,
  );
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "lunch")
      .revenue_minor,
    3600,
  );
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "evening")
      .revenue_minor,
    1800,
  );
  assert.deepEqual(summary.top_products_current_period.at(0), {
    product_key: "12",
    product_name: "Burger",
    quantity_sold: 1,
    revenue_minor: 3600,
  });

  const moneyFields = [
    summary.period_total_minor,
    summary.previous_period_total_minor,
    summary.today_total_minor,
    summary.this_week_total_minor,
    summary.this_month_total_minor,
    summary.period_average_order_value_minor,
    summary.this_month_cash_revenue_minor,
    summary.this_month_card_revenue_minor,
    summary.last_month_card_revenue_minor,
  ];
  assert.equal(moneyFields.every(Number.isInteger), true);
});

test("daypart distribution uses deterministic fixed buckets", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-breakfast",
        total_amount_minor: 1000,
        paid_at: "2026-03-31T05:30:00.000Z",
      },
      {
        uuid: "tx-lunch",
        total_amount_minor: 1100,
        paid_at: "2026-03-31T11:30:00.000Z",
      },
      {
        uuid: "tx-afternoon",
        total_amount_minor: 1200,
        paid_at: "2026-03-31T15:30:00.000Z",
      },
      {
        uuid: "tx-evening",
        total_amount_minor: 1300,
        paid_at: "2026-03-31T18:30:00.000Z",
      },
      {
        uuid: "tx-late",
        total_amount_minor: 1400,
        paid_at: "2026-03-31T22:30:00.000Z",
      },
    ],
    payments: [],
    transactionLines: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "today",
  });

  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "breakfast")
      .order_count,
    1,
  );
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "lunch")
      .order_count,
    1,
  );
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "afternoon")
      .order_count,
    1,
  );
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "evening")
      .order_count,
    1,
  );
  assert.equal(
    summary.daypart_distribution.find((bucket) => bucket.daypart === "late")
      .order_count,
    1,
  );
});

test("cancelled metrics use cancelled_at attribution and note missing timestamps", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [],
    cancelledTransactions: [
      {
        uuid: "cancel-1",
        cancelled_at: "2026-03-31T09:00:00.000Z",
        updated_at: "2026-03-31T09:00:00.000Z",
      },
      {
        uuid: "cancel-2",
        cancelled_at: "2026-03-24T09:00:00.000Z",
        updated_at: "2026-03-24T09:00:00.000Z",
      },
      {
        uuid: "cancel-3",
        cancelled_at: "2026-02-15T09:00:00.000Z",
        updated_at: "2026-02-15T09:00:00.000Z",
      },
      {
        uuid: "cancel-missing",
        cancelled_at: null,
        updated_at: "2026-03-30T09:00:00.000Z",
      },
    ],
    payments: [],
    transactionLines: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
    periodType: "preset",
    preset: "last_14_days",
  });

  assert.equal(summary.this_week_cancelled_order_count, 1);
  assert.equal(summary.last_week_cancelled_order_count, 1);
  assert.equal(summary.this_month_cancelled_order_count, 2);
  assert.equal(summary.last_month_cancelled_order_count, 1);
  assert.equal(summary.period_cancelled_order_count, 2);
  assert.equal(
    summary.data_quality_notes.includes(
      "cancelled attribution unavailable for some mirror rows because reliable cancelled_at was missing",
    ),
    true,
  );
});

test("payment mix is calculated for mixed payments within the selected period", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-cash",
        total_amount_minor: 2500,
        paid_at: "2026-04-01T10:00:00.000Z",
      },
      {
        uuid: "tx-card",
        total_amount_minor: 3500,
        paid_at: "2026-04-01T12:00:00.000Z",
      },
    ],
    payments: [
      {
        transaction_uuid: "tx-cash",
        method: "cash",
        amount_minor: 2500,
        paid_at: "2026-04-01T10:00:00.000Z",
      },
      {
        transaction_uuid: "tx-card",
        method: "card",
        amount_minor: 3500,
        paid_at: "2026-04-01T12:00:00.000Z",
      },
    ],
    transactionLines: [],
    generatedAt: "2026-04-01T12:30:00.000Z",
    periodType: "preset",
    preset: "today",
  });

  assert.equal(summary.period_total_minor, 6000);
  assert.equal(summary.period_cash_revenue_minor, 2500);
  assert.equal(summary.period_card_revenue_minor, 3500);
  assert.equal(
    summary.period_cash_revenue_minor + summary.period_card_revenue_minor,
    summary.period_total_minor,
  );
});

test("payment mix supports cash-only selected periods", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-cash-only",
        total_amount_minor: 4200,
        paid_at: "2026-04-01T15:00:00.000Z",
      },
    ],
    payments: [
      {
        transaction_uuid: "tx-cash-only",
        method: "cash",
        amount_minor: 4200,
        paid_at: "2026-04-01T15:00:00.000Z",
      },
    ],
    transactionLines: [],
    generatedAt: "2026-04-01T16:00:00.000Z",
    periodType: "preset",
    preset: "today",
  });

  assert.equal(summary.period_total_minor, 4200);
  assert.equal(summary.period_cash_revenue_minor, 4200);
  assert.equal(summary.period_card_revenue_minor, 0);
});

test("payment mix supports card-only selected periods", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-card-only",
        total_amount_minor: 5100,
        paid_at: "2026-04-01T18:00:00.000Z",
      },
    ],
    payments: [
      {
        transaction_uuid: "tx-card-only",
        method: "card",
        amount_minor: 5100,
        paid_at: "2026-04-01T18:00:00.000Z",
      },
    ],
    transactionLines: [],
    generatedAt: "2026-04-01T19:00:00.000Z",
    periodType: "preset",
    preset: "today",
  });

  assert.equal(summary.period_total_minor, 5100);
  assert.equal(summary.period_cash_revenue_minor, 0);
  assert.equal(summary.period_card_revenue_minor, 5100);
});

test("payment mix stays zero when revenue exists but payment rows are genuinely missing", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-missing-payment",
        total_amount_minor: 2800,
        paid_at: "2026-04-01T20:00:00.000Z",
      },
    ],
    payments: [],
    transactionLines: [],
    generatedAt: "2026-04-01T21:00:00.000Z",
    periodType: "preset",
    preset: "today",
  });

  assert.equal(summary.period_total_minor, 2800);
  assert.equal(summary.period_cash_revenue_minor, 0);
  assert.equal(summary.period_card_revenue_minor, 0);
});

test("payment mix uses the same selected-period filter as revenue totals", () => {
  const summary = aggregateRevenueAnalytics({
    paidTransactions: [
      {
        uuid: "tx-current",
        total_amount_minor: 3000,
        paid_at: "2026-04-01T11:00:00.000Z",
      },
      {
        uuid: "tx-previous",
        total_amount_minor: 2000,
        paid_at: "2026-03-31T11:00:00.000Z",
      },
    ],
    payments: [
      {
        transaction_uuid: "tx-current",
        method: "card",
        amount_minor: 3000,
        paid_at: "2026-04-01T11:00:00.000Z",
      },
      {
        transaction_uuid: "tx-previous",
        method: "cash",
        amount_minor: 2000,
        paid_at: "2026-03-31T11:00:00.000Z",
      },
    ],
    transactionLines: [],
    generatedAt: "2026-04-01T12:00:00.000Z",
    periodType: "preset",
    preset: "today",
  });

  assert.equal(summary.period_total_minor, 3000);
  assert.equal(summary.previous_period_total_minor, 2000);
  assert.equal(summary.period_cash_revenue_minor, 0);
  assert.equal(summary.period_card_revenue_minor, 3000);
  assert.equal(summary.previous_period_cash_revenue_minor, 2000);
  assert.equal(summary.previous_period_card_revenue_minor, 0);
});
