#!/usr/bin/env bash
# Synthesizes a domain's DCM `sources/` folder immediately before `snow dcm plan/deploy`.
#
# Why this exists: dcm/_template/sources/ is the ONE canonical, domain-agnostic template
# (reused by every domain), and dcm/account/sources/ is the account-level shared content
# (warehouses + their Tier 4 roles). Neither is ever committed per-domain. This script
# copies both into dcm/domains/<domain>/sources/ right before a DCM command runs, so that
# folder always reflects the current template + account content with zero duplication in
# git â€” dcm/domains/<domain>/sources/ is gitignored and regenerated fresh every run.
#
# Usage: dcm/sync-domain.sh <domain>   (e.g. dcm/sync-domain.sh customer)
set -euo pipefail

DOMAIN="${1:?Usage: sync-domain.sh <domain>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_DIR="${SCRIPT_DIR}/domains/${DOMAIN}"

if [ ! -f "${DOMAIN_DIR}/manifest.yml" ]; then
  echo "Error: ${DOMAIN_DIR}/manifest.yml does not exist â€” is '${DOMAIN}' a real domain?" >&2
  exit 1
fi

rm -rf "${DOMAIN_DIR}/sources"
mkdir -p "${DOMAIN_DIR}/sources/definitions" "${DOMAIN_DIR}/sources/macros"

cp -r "${SCRIPT_DIR}/_template/sources/definitions/." "${DOMAIN_DIR}/sources/definitions/"
cp -r "${SCRIPT_DIR}/_template/sources/macros/." "${DOMAIN_DIR}/sources/macros/"
cp -r "${SCRIPT_DIR}/account/sources/definitions/." "${DOMAIN_DIR}/sources/definitions/"

echo "Synthesized ${DOMAIN_DIR}/sources/ from _template/ + account/ (not committed â€” gitignored)."
