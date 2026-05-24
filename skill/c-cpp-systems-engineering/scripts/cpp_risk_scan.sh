#!/usr/bin/env bash
set -u

root="${1:-.}"

if [ ! -d "$root" ]; then
  printf 'error: not a directory: %s\n' "$root" >&2
  exit 2
fi

if command -v rg >/dev/null 2>&1; then
  search='rg -n --glob=*.{c,cc,cpp,cxx,h,hh,hpp,hxx}'
else
  printf 'error: rg is required for cpp_risk_scan.sh\n' >&2
  exit 3
fi

status=0

run_check() {
  label="$1"
  pattern="$2"
  printf '\n[%s]\n' "$label"
  # shellcheck disable=SC2086
  if $search "$pattern" "$root"; then
    status=1
  else
    printf 'no matches\n'
  fi
}

run_check 'unsafe string or formatting APIs' '\b(strcpy|strcat|sprintf|vsprintf|gets|scanf|sscanf)\b'
run_check 'raw allocation APIs' '\b(malloc|calloc|realloc|free|new|delete)\b'
run_check 'casts requiring review' '\b(reinterpret_cast|const_cast|static_cast<.*\*>|\([A-Za-z_][A-Za-z0-9_:<>[:space:]]*\s*\*\))'
run_check 'unchecked memory movement' '\b(memcpy|memmove|memset|memcmp)\b'
run_check 'process or shell execution' '\b(system|popen|execl|execv|CreateProcess)\b'
run_check 'assert-only validation' '\bassert\s*\('
run_check 'threading primitives' '\b(pthread_|std::thread|std::async|std::mutex|std::atomic|CreateThread)\b'

exit "$status"
