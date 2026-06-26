// bible-version-url — geo-gated signed-URL issuer for restricted Bible versions.
//
// The app calls this for versions that must be territory-restricted (KJV, which
// is under Crown copyright in the UK). The function determines the caller's
// country server-side and:
//   - returns 403 if the version is restricted in that country (or the country
//     cannot be determined — FAIL CLOSED, for copyright safety), or
//   - returns { url } with a short-lived signed URL to the PRIVATE bucket
//     otherwise, which the app then downloads directly.
//
// Deploy:  supabase functions deploy bible-version-url --no-verify-jwt
//   (--no-verify-jwt because the app may call this before/without a user
//    session; the gate is geographic, not per-user. Remove it if you require
//    an authenticated user.)
//
// Secrets used (auto-present in the Supabase runtime): SUPABASE_URL,
// SUPABASE_SERVICE_ROLE_KEY. Set IPINFO_TOKEN for ipinfo.io IP→country lookups.

import { createClient } from "jsr:@supabase/supabase-js@2";

// versionCode → ISO 3166-1 alpha-2 countries where download is forbidden.
const RESTRICTED: Record<string, string[]> = {
  KJV: ["GB"], // United Kingdom (Crown copyright)
};

const PRIVATE_BUCKET = "bible-versions-restricted";
const SIGNED_URL_TTL_SECONDS = 120;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Best-effort caller country (ISO alpha-2, uppercased) or null if unknown. */
async function detectCountry(req: Request): Promise<string | null> {
  // Supabase Edge Runtime does NOT inject x-country / cf-ipcountry /
  // x-vercel-ip-country — those are Cloudflare/Vercel-specific and fully
  // client-spoofable here. Do NOT read them.
  //
  // x-forwarded-for: the Supabase gateway appends the real client IP as the
  // RIGHTMOST entry (confirmed: github.com/orgs/supabase/discussions/34647).
  // A client can prepend spoofed values, so we must take the last entry.
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  const parts = fwd.split(",").map((s) => s.trim()).filter(Boolean);
  const ip = parts.at(-1) ?? null;
  if (!ip) return null;
  try {
    const token = Deno.env.get("IPINFO_TOKEN");
    const url = token
      ? `https://ipinfo.io/${ip}/country?token=${token}`
      : `https://ipinfo.io/${ip}/country`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const country = (await res.text()).trim();
    return country.length === 2 ? country.toUpperCase() : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  let code: unknown;
  try {
    code = (await req.json())?.code;
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  if (typeof code !== "string" || !/^[A-Z0-9]+$/.test(code)) {
    return json({ error: "invalid code" }, 400);
  }

  const restrictedCountries = RESTRICTED[code];
  if (restrictedCountries) {
    const country = await detectCountry(req);
    // FAIL CLOSED: if the country can't be verified, deny a restricted version.
    if (country === null || restrictedCountries.includes(country)) {
      return json({ error: "not available in your region" }, 403);
    }
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const path = `Bible_${code}.sqlite`;
  const { data, error } = await supabase.storage
    .from(PRIVATE_BUCKET)
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);

  if (error || !data?.signedUrl) {
    return json({ error: "not found" }, 404);
  }
  return json({ url: data.signedUrl }, 200);
});
