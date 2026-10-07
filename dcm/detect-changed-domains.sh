#!/usr/bin/env bash
# Determines which domains' DCM plan/deploy jobs actually need to run, based on changed
# files -- this is the mechanism that keeps CI load flat as domains scale into the
# hundreds: a PR touching only dcm/domains/customer/ should never trigger every other
# domain's plan/deploy, and vice versa.
#
# A domain only ever runs if it's listed in active_domains.json (see that file's
# comment) -- a domain whose manifest.yml exists but isn't "active" (e.g.
# dcm/domains/procurement/, a deliberately-not-yet-deployed template) never gets a job no
# matter what changed, even if its own files changed. This is a safety property, not an
# oversight: it's the only thing stopping a template domain from accidentally going live.
#
# Outputs a JSON array of {"name": ..., "target": ...} objects to stdout (possibly empty:
# "[]") -- consumed directly as a GitHub Actions `matrix.include` value.
#
# Usage:
#   detect-changed-domains.sh ALL                  # force every active domain (workflow_dispatch)
#   detect-changed-domains.sh <base-sha> <head-sha> # only domains with changed files in that range
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIVE_DOMAINS_FILE="${SCRIPT_DIR}/active_domains.json"

if [ "${1:-}" = "ALL" ]; then
  jq -c . "${ACTIVE_DOMAINS_FILE}"
  exit 0
fi

BASE_SHA="${1:?Usage: detect-changed-domains.sh ALL | detect-changed-domains.sh <base-sha> <head-sha>}"
HEAD_SHA="${2:?Usage: detect-changed-domains.sh ALL | detect-changed-domains.sh <base-sha> <head-sha>}"

# All-zero SHA shows up as `github.event.before` on a branch's first-ever push -- there is
# no real "before" commit to diff against, so fall back to the safe default (replan/redeploy
# every active domain) rather than erroring on a nonexistent ref.
if [ "${BASE_SHA}" = "0000000000000000000000000000000000000000" ]; then
  jq -c . "${ACTIVE_DOMAINS_FILE}"
  exit 0
fi

CHANGED_FILES="$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}")"

# The shared template affects every domain's rendered SQL -- a template change means every
# active domain must be replanned/redeployed, not just whichever domain's own folder
# happened to also change in the same commit.
if echo "${CHANGED_FILES}" | grep -q '^dcm/sources/'; then
  jq -c . "${ACTIVE_DOMAINS_FILE}"
  exit 0
fi

jq -c --argjson changed "$(echo "${CHANGED_FILES}" | jq -R . | jq -s .)" '
  [.[] | select(. as $d | $changed | any(startswith("dcm/domains/" + $d.name + "/")))]
' "${ACTIVE_DOMAINS_FILE}"
