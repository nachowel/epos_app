import test from "node:test";
import assert from "node:assert/strict";

import { validateInternalFunctionAuth } from "./internal_auth.js";

test("accepts x-epos-internal-key without Authorization", () => {
  const result = validateInternalFunctionAuth(
    new Headers({ "x-epos-internal-key": "secret-key" }),
    "secret-key",
  );

  assert.deepEqual(result, { ok: true });
});

test("rejects Bearer internal key as malformed Authorization", () => {
  const result = validateInternalFunctionAuth(
    new Headers({
      authorization: "Bearer local-dev-key",
      "x-epos-internal-key": "secret-key",
    }),
    "secret-key",
  );

  assert.equal(result.ok, false);
  assert.equal(result.failure, "auth_header_malformed");
  assert.equal(result.status, 401);
});

test("rejects Bearer publishable key as malformed Authorization", () => {
  const result = validateInternalFunctionAuth(
    new Headers({
      authorization: "Bearer sb_publishable_bad",
      "x-epos-internal-key": "secret-key",
    }),
    "secret-key",
  );

  assert.equal(result.ok, false);
  assert.equal(result.failure, "auth_header_malformed");
  assert.equal(result.status, 401);
});

test("rejects missing internal key header", () => {
  const result = validateInternalFunctionAuth(new Headers(), "secret-key");

  assert.equal(result.ok, false);
  assert.equal(result.failure, "missing_internal_key");
  assert.equal(result.status, 401);
});

test("rejects unauthorized internal key", () => {
  const result = validateInternalFunctionAuth(
    new Headers({ "x-epos-internal-key": "wrong-key" }),
    "secret-key",
  );

  assert.equal(result.ok, false);
  assert.equal(result.failure, "unauthorized_internal_key");
  assert.equal(result.status, 403);
});
