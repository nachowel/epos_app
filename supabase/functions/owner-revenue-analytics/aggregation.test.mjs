import test from "node:test";
import assert from "node:assert/strict";

import { aggregateRevenueAnalytics } from "./aggregation.js";

test("empty dataset returns zero-filled daily, weekly and hourly buckets", () => {
  const summary = aggregateRevenueAnalytics({
    transactions: [],
    generatedAt: "2026-03-31T12:00:00.000Z",
  });

  assert.equal(summary.today_total_minor, 0);
  assert.equal(summary.this_week_total_minor, 0);
  assert.equal(summary.this_month_total_minor, 0);
  assert.equal(summary.this_week_order_count, 0);
  assert.equal(summary.daily_trend.length, 14);
  assert.equal(summary.weekly_summary.length, 6);
  assert.equal(summary.hourly_distribution.length, 24);
  assert.deepEqual(
    summary.hourly_distribution.map((bucket) => bucket.hour),
    Array.from({ length: 24 }, (_, hour) => hour),
  );
  assert.equal(summary.weekly_summary.at(-1).week_start, "2026-03-30");
});

test("DST transition keeps buckets on the correct London local day and hour", () => {
  const summary = aggregateRevenueAnalytics({
    transactions: [
      {
        total_amount_minor: 1000,
        paid_at: "2026-03-29T00:30:00.000Z",
      },
      {
        total_amount_minor: 2000,
        paid_at: "2026-03-29T01:30:00.000Z",
      },
    ],
    generatedAt: "2026-03-31T12:00:00.000Z",
  });

  const dstDay = summary.daily_trend.find((bucket) => bucket.date === "2026-03-29");
  assert.equal(dstDay.revenue_minor, 3000);
  assert.equal(summary.hourly_distribution[0].revenue_minor, 1000);
  assert.equal(summary.hourly_distribution[2].revenue_minor, 2000);
});

test("week start is Monday and Sunday revenue stays in the previous week", () => {
  const summary = aggregateRevenueAnalytics({
    transactions: [
      {
        total_amount_minor: 1500,
        paid_at: "2026-03-29T09:00:00.000Z",
      },
      {
        total_amount_minor: 2500,
        paid_at: "2026-03-30T09:00:00.000Z",
      },
    ],
    generatedAt: "2026-03-31T12:00:00.000Z",
  });

  const lastWeek = summary.weekly_summary.at(-2);
  const thisWeek = summary.weekly_summary.at(-1);
  assert.equal(lastWeek.week_start, "2026-03-23");
  assert.equal(lastWeek.revenue_minor, 1500);
  assert.equal(thisWeek.week_start, "2026-03-30");
  assert.equal(thisWeek.revenue_minor, 2500);
  assert.equal(summary.this_week_total_minor, 2500);
  assert.equal(summary.last_week_total_minor, 1500);
});
