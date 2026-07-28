#!/usr/bin/env bash
# Reproduces the /File/Upload API-key failure against a working
# signature-auth control request on /Task/Detail.
#
# Usage:
#   export WIRO_API_KEY=...
#   export WIRO_API_SECRET=...
#   bash tool/file_upload_repro.sh
#
# Optional:
#   PHOTO=/path/to/photo.jpg bash tool/file_upload_repro.sh

set -euo pipefail

API_KEY="${WIRO_API_KEY:-}"
API_SECRET="${WIRO_API_SECRET:-}"
PHOTO="${PHOTO:-/tmp/wiro-file-upload-repro.jpg}"
BASE_URL="${WIRO_API_BASE_URL:-https://api.wiro.ai/v1}"

if [[ -z "$API_KEY" || -z "$API_SECRET" ]]; then
  echo "Set WIRO_API_KEY and WIRO_API_SECRET first." >&2
  exit 64
fi

sign() {
  NONCE="$(python3 -c 'import time; print(int(time.time() * 1000))')"
  SIGNATURE="$(
    printf '%s%s' "$API_SECRET" "$NONCE" \
      | openssl dgst -sha256 -hmac "$API_KEY" \
      | awk '{print $2}'
  )"
}

ensure_photo() {
  if [[ -f "$PHOTO" ]]; then
    echo "Using existing photo: $PHOTO"
    file "$PHOTO" || true
    return
  fi
  echo "Downloading a valid JPEG to $PHOTO ..."
  curl -sL -o "$PHOTO" \
    "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=512"
  file "$PHOTO" || true
}

echo "=== 1) CONTROL: Task/Detail with API key + signature ==="
echo "    Expect: task-not-founded (auth passed, task missing)"
sign
curl -s -X POST "$BASE_URL/Task/Detail" \
  -H "x-api-key: ${API_KEY}" \
  -H "x-nonce: ${NONCE}" \
  -H "x-signature: ${SIGNATURE}" \
  -H "Content-Type: application/json" \
  -d '{"tasktoken":"doesnotexist123"}'
echo
echo

ensure_photo
echo
echo "=== 2) FAIL: File/Upload, no content-type override ==="
echo "    Plain -F file=@photo.jpg; curl infers image/jpeg."
echo "    Expect today: invalid-parameters"
sign
curl -s -X POST "$BASE_URL/File/Upload" \
  -H "x-api-key: ${API_KEY}" \
  -H "x-nonce: ${NONCE}" \
  -H "x-signature: ${SIGNATURE}" \
  -F "file=@${PHOTO}"
echo
echo

echo "=== 3) FAIL: File/Upload with explicit content types ==="
echo "    Neither image/jpeg nor application/octet-stream changes it."
for content_type in image/jpeg application/octet-stream; do
  printf '    %s -> ' "$content_type"
  sign
  curl -s -X POST "$BASE_URL/File/Upload" \
    -H "x-api-key: ${API_KEY}" \
    -H "x-nonce: ${NONCE}" \
    -H "x-signature: ${SIGNATURE}" \
    -F "file=@${PHOTO};type=${content_type}"
  echo
done
echo

echo "=== 4) BEARER PATH: File/Upload with fake Bearer ==="
echo "    Expect: Authorization bearer token is invalid."
echo "    Shows File/Upload reaches auth for Bearer, not for API key."
curl -s -X POST "$BASE_URL/File/Upload" \
  -H "Authorization: Bearer faketoken123" \
  -F "file=@${PHOTO}"
echo
echo

echo "Done."
