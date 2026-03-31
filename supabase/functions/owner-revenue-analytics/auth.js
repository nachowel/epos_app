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

export function extractBearerToken(headers) {
  const rawAuthorization = headers.get("authorization");
  if (rawAuthorization === null) {
    return {
      ok: false,
      failure: "missing_token",
      message:
        "Authorization: Bearer <jwt> is required for owner revenue analytics.",
    };
  }

  const trimmedAuthorization = rawAuthorization.trim();
  if (
    trimmedAuthorization.length === 0 ||
    !trimmedAuthorization.toLowerCase().startsWith("bearer ")
  ) {
    return {
      ok: false,
      failure: "invalid_token",
      message:
        "Authorization header must contain a valid Supabase Bearer JWT.",
    };
  }

  const accessToken = trimmedAuthorization.substring("Bearer ".length).trim();
  if (!hasJwtShape(accessToken)) {
    return {
      ok: false,
      failure: "invalid_token",
      message:
        "Authorization header must contain a valid Supabase Bearer JWT.",
    };
  }

  return {
    ok: true,
    accessToken,
  };
}
