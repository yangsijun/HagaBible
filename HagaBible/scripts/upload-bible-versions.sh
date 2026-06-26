#!/usr/bin/env bash
#
# Uploads the Bible_*.sqlite files to Supabase Storage for the ODR→Supabase
# FALLBACK path and the gated (geo / purchase) paths.
#
# Two buckets:
#   - bible-versions             (PUBLIC)  : KRV, WEB, WEBBE  (free, public domain)
#                                            ODR fallback downloads these directly.
#   - bible-versions-restricted  (PRIVATE) : KJV, NIV, NKRV
#                                            served ONLY via the bible-version-url
#                                            Edge Function (signed URL). KJV is
#                                            UK-geo-blocked; NIV/NKRV require a
#                                            verified StoreKit purchase. Paid
#                                            content must never sit at a public
#                                            URL, so these are private.
#
# Prereq: create both buckets in the Supabase dashboard (public/private as above).
# Auth:   SUPABASE_SERVICE_ROLE_KEY (Project Settings → API → service_role).
#         SECRET — never commit. Run, e.g.:
#           SUPABASE_SERVICE_ROLE_KEY=... ./scripts/upload-bible-versions.sh
#
# Object paths match BibleDatabaseService.fileName(for:) → "Bible_<CODE>.sqlite".
#
set -euo pipefail

PROJECT_URL="https://xvssaydpzuktneqvjcin.supabase.co"
PUBLIC_BUCKET="bible-versions"
PRIVATE_BUCKET="bible-versions-restricted"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)/HagaBible/Data/Local/GRDB/SQLite"

: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY before running}"

upload() { # $1=bucket $2=code
  local bucket="$1" code="$2" file="$SRC_DIR/Bible_${2}.sqlite"
  if [[ ! -f "$file" ]]; then echo "!! missing $file" >&2; exit 1; fi
  echo "→ $bucket / Bible_${code}.sqlite ($(du -h "$file" | cut -f1))"
  # x-upsert: true overwrites existing objects (re-runs / schema bumps).
  curl -sS -X POST \
    "$PROJECT_URL/storage/v1/object/$bucket/Bible_${code}.sqlite" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/x-sqlite3" \
    -H "x-upsert: true" \
    --data-binary "@$file" \
    -w "    HTTP %{http_code}\n" -o /dev/null
}

# Free, public-domain versions (ODR fallback downloads these directly).
for code in KRV WEB WEBBE; do upload "$PUBLIC_BUCKET" "$code"; done

# Gated versions (private; served via Edge Function only).
#   KJV  → UK-geo-blocked
#   NIV/NKRV → require a verified StoreKit purchase
for code in KJV NIV NKRV; do upload "$PRIVATE_BUCKET" "$code"; done

echo
echo "Done. Verify:"
echo "  public:  curl -I $PROJECT_URL/storage/v1/object/public/$PUBLIC_BUCKET/Bible_WEB.sqlite   # 200"
echo "  private: paid/geo versions must NOT be public — these should 400/404:"
echo "           curl -I $PROJECT_URL/storage/v1/object/public/$PRIVATE_BUCKET/Bible_KJV.sqlite"
echo "           curl -I $PROJECT_URL/storage/v1/object/public/$PRIVATE_BUCKET/Bible_NIV.sqlite"
echo "  gate:    deploy the Edge Function, then:"
echo "           # KJV from a non-UK IP → {url}; from UK → 403"
echo "           curl -X POST $PROJECT_URL/functions/v1/bible-version-url -H 'Content-Type: application/json' -d '{\"code\":\"KJV\"}'"
echo "           # NIV without a valid transaction → 402"
echo "           curl -X POST $PROJECT_URL/functions/v1/bible-version-url -H 'Content-Type: application/json' -d '{\"code\":\"NIV\"}'"
