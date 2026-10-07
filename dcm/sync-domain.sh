#!/usr/bin/env bash
# Synthesizes a domain's DCM `sources/` folder immediately before `snow dcm plan/deploy`.
#
# Why this exists: dcm/sources/ is the ONE canonical, domain-agnostic template (reused by
# every domain) - never committed per-domain. This script copies it into
# dcm/domains/<domain>/sources/ right before a DCM command runs, so that folder always
# reflects the current template content with zero duplication in git -
# dcm/domains/<domain>/sources/ is gitignored and regenerated fresh every run.
#
# Usage: dcm/sync-domain.sh <domain>   (e.g. dcm/sync-domain.sh customer)
set -euo pipefail

DOMAIN="${1:?Usage: sync-domain.sh <domain>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_DIR="${SCRIPT_DIR}/domains/${DOMAIN}"

if [ ! -f "${DOMAIN_DIR}/manifest.yml" ]; then
  echo "Error: ${DOMAIN_DIR}/manifest.yml does not exist - is '${DOMAIN}' a real domain?" >&2
  exit 1
fi

rm -rf "${DOMAIN_DIR}/sources"
mkdir -p "${DOMAIN_DIR}/sources/definitions" "${DOMAIN_DIR}/sources/macros"

cp -r "${SCRIPT_DIR}/sources/definitions/." "${DOMAIN_DIR}/sources/definitions/"
cp -r "${SCRIPT_DIR}/sources/macros/." "${DOMAIN_DIR}/sources/macros/"

echo "Synthesized ${DOMAIN_DIR}/sources/ from dcm/sources/ (not committed - gitignored)."# verification-only comment: confirming DCM Plan (gate) satisfies branch protection (throwaway, not merging)
