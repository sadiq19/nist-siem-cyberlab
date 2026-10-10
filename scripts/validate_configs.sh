#!/usr/bin/env bash
# Validate repo layout, Wazuh local_rules.xml syntax, and banned filler in Markdown.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

errors=0

fail() {
  echo "FAIL: $*" >&2
  errors=1
}

ok() {
  echo "OK: $*"
}

required_files=(
  .cursorrules
  README.md
  docs/01-architecture/README.md
  docs/02-compliance-nist/README.md
  docs/03-configuration-guide/README.md
  docs/04-testing-verification/README.md
  docs/05-post-mortem-lessons/README.md
  configs/wazuh/ossec.conf
  configs/wazuh/local_rules.xml
  configs/endpoints/rsyslog.conf
  configs/endpoints/auditd.rules
  configs/network/rsyslog-network.conf
  scripts/init_project.sh
  scripts/validate_configs.sh
)

echo "== 1. Required files =="
for rel in "${required_files[@]}"; do
  if [[ -f "$ROOT/$rel" ]]; then
    ok "$rel"
  else
    fail "missing file: $rel"
  fi
done

echo "== 2. XML syntax local_rules.xml =="
xml_file="$ROOT/configs/wazuh/local_rules.xml"
if [[ -f "$xml_file" ]]; then
  xml_checked=0
  if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$xml_file" 2>/tmp/local_rules_xmllint.err; then
      ok "xmllint: valid XML"
      xml_checked=1
    else
      fail "xmllint rejected configs/wazuh/local_rules.xml"
      cat /tmp/local_rules_xmllint.err >&2 || true
      xml_checked=1
    fi
  fi
  if [[ "$xml_checked" -eq 0 ]] && command -v python3 >/dev/null 2>&1; then
    if python3 - "$xml_file" <<'PY'
import sys
import xml.etree.ElementTree as ET
path = sys.argv[1]
try:
    ET.parse(path)
except ET.ParseError as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PY
    then
      ok "python3 xml.etree: valid XML"
      xml_checked=1
    else
      fail "python3 xml.etree rejected configs/wazuh/local_rules.xml"
      xml_checked=1
    fi
  fi
  if [[ "$xml_checked" -eq 0 ]]; then
    fail "no XML parser available (install libxml2/xmllint or python3)"
  fi
else
  fail "cannot validate XML: file missing"
fi

echo "== 3. Banned phrases in Markdown =="
# Phrases from .cursorrules. Egrep, case-insensitive. Apostrophe in "today's" matched as .
forbidden_regex='i dagens digitale tidsalder|revolusjonerende|sømløs integrasjon|robust løsning|det er viktig å merke seg at|oppsummert|avslutningsvis|in this section we will|this comprehensive guide|it is important to note|summary:|seamless integration|robust solution|in today.s digital age'

mapfile -t md_files < <(find "$ROOT" -type f -name '*.md' ! -path '*/.git/*' | sort)

if [[ "${#md_files[@]}" -eq 0 ]]; then
  fail "no Markdown files found"
else
  hits="$(grep -nEi "$forbidden_regex" "${md_files[@]}" || true)"
  if [[ -n "$hits" ]]; then
    fail "banned filler found:"
    echo "$hits" >&2
  else
    ok "no banned phrases in ${#md_files[@]} markdown files"
  fi
fi

if [[ "$errors" -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation OK."
exit 0
