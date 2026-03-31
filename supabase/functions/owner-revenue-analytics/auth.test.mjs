import test from "node:test";
import assert from "node:assert/strict";

import { extractBearerToken } from "./auth.js";

test("extractBearerToken rejects a missing Authorization header", () => {
  const result = extractBearerToken(new Headers());

  assert.deepEqual(result, {
    ok: false,
    failure: "missing_token",
    message:
      "Authorization: Bearer <jwt> is required for owner revenue analytics.",
  });
});

test("extractBearerToken rejects malformed bearer values", () => {
  const result = extractBearerToken(
    new Headers({ authorization: "Bearer sb_publishable_not_a_jwt" }),
  );

  assert.deepEqual(result, {
    ok: false,
    failure: "invalid_token",
    message: "Authorization header must contain a valid Supabase Bearer JWT.",
  });
});

test("extractBearerToken accepts a JWT-shaped bearer token", () => {
  const result = extractBearerToken(
    new Headers({ authorization: "Bearer header.payload.signature" }),
  );

  assert.deepEqual(result, {
    ok: true,
    accessToken: "header.payload.signature",
  });
});
