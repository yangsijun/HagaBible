// bible-version-url — gated signed-URL issuer for restricted Bible versions.
//
// The app calls this for any version that must NOT live at a plain public URL.
// Two kinds of gate, chosen per version code:
//
//   1. GEO-RESTRICTED (KJV): under Crown copyright in the UK. The function
//      determines the caller's country server-side and returns 403 if the
//      version is restricted there (or the country can't be determined — FAIL
//      CLOSED, for copyright safety).
//
//   2. PAID (NIV, NKRV): licensed, paid content. The app attaches its
//      Apple-signed StoreKit transaction (JWS). The function verifies the
//      signature + certificate chain (to an Apple root CA) + bundle id +
//      product id offline, and returns 402 if it can't confirm the purchase.
//
// On success it returns { url } with a short-lived signed URL to the PRIVATE
// bucket, which the app then downloads directly. Free, public-domain versions
// never reach this function — the app downloads those straight from the public
// bucket.
//
// Deploy:  supabase functions deploy bible-version-url --no-verify-jwt
//   (--no-verify-jwt because the app may call this before/without a Supabase
//    user session; these gates are geographic / StoreKit-based, not per-user.)
//
// Secrets (auto-present): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// Set IPINFO_TOKEN for ipinfo.io IP→country lookups.
// Set APP_APPLE_ID (numeric App Store app id) — REQUIRED to verify PRODUCTION
//   StoreKit transactions; Sandbox/TestFlight verification works without it.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { Buffer } from "node:buffer";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@1";

// versionCode → ISO 3166-1 alpha-2 countries where download is forbidden.
const GEO_RESTRICTED: Record<string, string[]> = {
  KJV: ["GB"], // United Kingdom (Crown copyright)
};

// versionCode → App Store product identifier for PAID versions. Must mirror the
// app's BibleVersionPurchaseCatalog.
const PAID_PRODUCT_IDS: Record<string, string> = {
  NIV: "dev.sijun.HagaBible.bible.niv",
  NKRV: "dev.sijun.HagaBible.bible.nkrv",
};

const BUNDLE_ID = "dev.sijun.HagaBible";
const PRIVATE_BUCKET = "bible-versions-restricted";
const SIGNED_URL_TTL_SECONDS = 120;

// Apple root CAs (DER, base64). StoreKit transaction JWS chains to Apple Root
// CA - G3; G2 included for resilience. Public certs (apple.com/certificateauthority).
const APPLE_ROOT_CA_G3_B64 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==";
const APPLE_ROOT_CA_G2_B64 =
  "MIIFkjCCA3qgAwIBAgIIAeDltYNno+AwDQYJKoZIhvcNAQEMBQAwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEcyMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxMDA5WhcNMzkwNDMwMTgxMDA5WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzIxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgREkhI2imKScUcx+xuM23+TfvgHN6sXuI2pyT5f1BrTM65MFQn5bPW7SXmMLYFN14UIhHF6Kob0vuy0gmVOKTvKkmMXT5xZgM4+xb1hYjkWpIMBDLyyED7Ul+f9sDx47pFoFDVEovy3d6RhiPw9bZyLgHaC/YuOQhfGaFjQQscp5TBhsRTL3b2CtcM0YM/GlMZ81fVJ3/8E7j4ko380yhDPLVoACVdJ2LT3VXdRCCQgzWTxb+4Gftr49wIQuavbfqeQMpOhYV4SbHXw8EwOTKrfl+q04tvny0aIWhwZ7Oj8ZhBbZF8+NfbqOdfIRqMM78xdLe40fTgIvS/cjTf94FNcX1RoeKz8NMoFnNvzcytN31O661A4T+B/fc9Cj6i8b0xlilZ3MIZgIxbdMYs0xBTJh0UT8TUgWY8h2czJxQI6bR3hDRSj4n4aJgXv8O7qhOTH11UL6jHfPsNFL4VPSQ08prcdUFmIrQB1guvkJ4M6mL4m1k8COKWNORj3rw31OsMiANDC1CvoDTdUE0V+1ok2Az6DGOeHwOx4e7hqkP0ZmUoNwIx7wHHHtHMn23KVDpA287PT0aLSmWaasZobNfMmRtHsHLDd4/E92GcdB/O/WuhwpyUgquUoue9G7q5cDmVF8Up8zlYNPXEpMZ7YLlmQ1A/bmH8DvmGqmAMQ0uVAgMBAAGjQjBAMB0GA1UdDgQWBBTEmRNsGAPCe8CjoA1/coB6HHcmjTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQwFAAOCAgEAUabz4vS4PZO/Lc4Pu1vhVRROTtHlznldgX/+tvCHM/jvlOV+3Gp5pxy+8JS3ptEwnMgNCnWefZKVfhidfsJxaXwU6s+DDuQUQp50DhDNqxq6EWGBeNjxtUVAeKuowM77fWM3aPbn+6/Gw0vsHzYmE1SGlHKy6gLti23kDKaQwFd1z4xCfVzmMX3zybKSaUYOiPjjLUKyOKimGY3xn83uamW8GrAlvacp/fQ+onVJv57byfenHmOZ4VxG/5IFjPoeIPmGlFYl5bRXOJ3riGQUIUkhOb9iZqmxospvPyFgxYnURTbImHy99v6ZSYA7LNKmp4gDBDEZt7Y6YUX6yfIjyGNzv1aJMbDZfGKnexWoiIqrOEDCzBL/FePwN983csvMmOa/orz6JopxVtfnJBtIRD6e/J/JzBrsQzwBvDR4yGn1xuZW7AYJNpDrFEobXsmII9oDMJELuDY++ee1KG++P+w8j2Ud5cAeh6Squpj9kuNsJnfdBrRkBof0Tta6SqoWqPQFZ2aWuuJVecMsXUmPgEkrihLHdoBR37q9ZV0+N0djMenl9MU/S60EinpxLK8JQzcPqOMyT/RFtm2XNuyE9QoB6he7hY1Ck3DDUOUUi78/w0EP3SIEIwiKum1xRKtzCTrJ+VKACd+66eYWyi4uTLLT3OUEVLLUNIAytbwPF+E=";

const APPLE_ROOT_CAS = [
  Buffer.from(APPLE_ROOT_CA_G3_B64, "base64"),
  Buffer.from(APPLE_ROOT_CA_G2_B64, "base64"),
];

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

/** Reads the (unverified) `environment` claim so we can pick the right verifier. */
function peekEnvironment(jws: string): Environment {
  try {
    const payload = jws.split(".")[1];
    const decoded = JSON.parse(
      atob(payload.replace(/-/g, "+").replace(/_/g, "/")),
    );
    return decoded.environment === "Production"
      ? Environment.PRODUCTION
      : Environment.SANDBOX;
  } catch {
    // Default to PRODUCTION; verification still enforces the real environment.
    return Environment.PRODUCTION;
  }
}

/**
 * Verifies an Apple-signed StoreKit transaction (JWS) proves ownership of
 * `expectedProductId`. Returns true only when the signature, certificate chain,
 * bundle id, and product id all check out and the purchase isn't revoked.
 */
async function verifyPurchase(
  jws: string,
  expectedProductId: string,
): Promise<boolean> {
  const environment = peekEnvironment(jws);
  // PRODUCTION requires the app's numeric Apple id; SANDBOX does not.
  const appAppleId = environment === Environment.PRODUCTION
    ? Number(Deno.env.get("APP_APPLE_ID"))
    : undefined;
  if (environment === Environment.PRODUCTION && !appAppleId) {
    console.error("APP_APPLE_ID is required to verify PRODUCTION transactions");
    return false; // fail closed
  }

  try {
    const verifier = new SignedDataVerifier(
      APPLE_ROOT_CAS,
      /* enableOnlineChecks */ false,
      environment,
      BUNDLE_ID,
      appAppleId,
    );
    // Validates signature + cert chain to an Apple root + bundle id + environment.
    const tx = await verifier.verifyAndDecodeTransaction(jws);
    if (tx.productId !== expectedProductId) return false;
    if (tx.revocationDate) return false; // refunded/revoked
    return true;
  } catch (e) {
    console.warn(`StoreKit verification failed: ${(e as Error).message ?? e}`);
    return false; // fail closed
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  let payload: { code?: unknown; transaction?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const code = payload?.code;
  if (typeof code !== "string" || !/^[A-Z0-9]+$/.test(code)) {
    return json({ error: "invalid code" }, 400);
  }

  if (code in GEO_RESTRICTED) {
    const country = await detectCountry(req);
    // FAIL CLOSED: if the country can't be verified, deny a restricted version.
    if (country === null || GEO_RESTRICTED[code].includes(country)) {
      return json({ error: "not available in your region" }, 403);
    }
  } else if (code in PAID_PRODUCT_IDS) {
    const transaction = payload?.transaction;
    if (typeof transaction !== "string" || transaction.length === 0) {
      return json({ error: "purchase required" }, 402);
    }
    const ok = await verifyPurchase(transaction, PAID_PRODUCT_IDS[code]);
    if (!ok) return json({ error: "purchase could not be verified" }, 402);
  } else {
    // This function only serves gated versions; free ones use the public bucket.
    return json({ error: "version is not gated" }, 400);
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
