export const INTERNAL_KEY_HEADER = "x-epos-internal-key";

function hasJwtShape(token) {
  if (typeof token !== "string") {
    return false;
  }
  const trimmed = token.trim();
  if (!trimmed) {
    return false;
  }
  const parts = trimmed.split(".");
  return parts.length === 3 && parts.every((part) => part.trim().length > 0);
}

export function validateInternalFunctionAuth(headers, expectedInternalKey) {
  if (typeof expectedInternalKey !== "string" || expectedInternalKey.trim().length === 0) {
    return {
      ok: false,
      status: 500,
      failure: "server_configuration",
      message: "EPOS_INTERNAL_API_KEY must be configured for secure edge functions.",
      retryable: false,
    };
  }

  const rawAuthorization = headers.get("authorization");
  if (rawAuthorization !== null) {
    const trimmedAuthorization = rawAuthorization.trim();
    if (
      trimmedAuthorization.length === 0 ||
      !trimmedAuthorization.toLowerCase().startsWith("bearer ")
    ) {
      return {
        ok: false,
        status: 401,
        failure: "auth_header_malformed",
        message:
          "Authorization header is malformed. Do not send publishable keys or internal keys as Bearer tokens.",
        retryable: false,
      };
    }

    const bearerToken = trimmedAuthorization.substring("Bearer ".length).trim();
    if (!hasJwtShape(bearerToken)) {
      return {
        ok: false,
        status: 401,
        failure: "auth_header_malformed",
        message:
          "Authorization header is malformed. Do not send publishable keys or internal keys as Bearer tokens.",
        retryable: false,
      };
    }
  }

  const internalKey = headers.get(INTERNAL_KEY_HEADER)?.trim() ?? "";
  if (internalKey.length === 0) {
    return {
      ok: false,
      status: 401,
      failure: "missing_internal_key",
      message:
        "Missing x-epos-internal-key header. Secure edge function calls must send the configured internal key.",
      retryable: false,
    };
  }
  if (internalKey !== expectedInternalKey) {
    return {
      ok: false,
      status: 403,
      failure: "unauthorized_internal_key",
      message: "The supplied x-epos-internal-key is not authorized.",
      retryable: false,
    };
  }

  return { ok: true };
}
