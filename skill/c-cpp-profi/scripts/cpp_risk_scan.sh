#!/usr/bin/env bash
set -u

if [ "$#" -eq 0 ]; then
  targets=(.)
else
  targets=("$@")
fi

for target in "${targets[@]}"; do
  if [ ! -e "$target" ]; then
    printf 'error: path does not exist: %s\n' "$target" >&2
    exit 2
  fi
done

if command -v rg >/dev/null 2>&1; then
  search=(
    rg -n
    --glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx}'
    --glob '!**/.git/**'
    --glob '!**/build/**'
    --glob '!**/_deps/**'
    --glob '!**/third_party/**'
    --glob '!**/vendor/**'
    --glob '!**/external/**'
    --glob '!**/test/gtest/**'
    --glob '!**/test/gmock/**'
  )
else
  printf 'error: rg is required for cpp_risk_scan.sh\n' >&2
  exit 3
fi

status=0

run_check() {
  label="$1"
  pattern="$2"
  printf '\n[%s]\n' "$label"
  if "${search[@]}" "$pattern" "${targets[@]}"; then
    status=1
  else
    printf 'no matches\n'
  fi
}

run_check 'unsafe string or formatting APIs' '\b(strcpy|strcat|sprintf|vsprintf|gets|scanf|sscanf)\b'
run_check 'raw allocation function calls' '\b(malloc|calloc|realloc|free)\s*\('
run_check 'raw C++ new/delete expressions' '(^|[^[:alnum:]_])(::)?new[[:space:]]+|(^|[^[:alnum:]_])delete(\[\])?[[:space:]]+'
run_check 'casts requiring review' '\b(reinterpret_cast|const_cast|static_cast<.*\*>|\([A-Za-z_][A-Za-z0-9_:<>[:space:]]*\s*\*\))'
run_check 'unchecked memory movement' '\b(memcpy|memmove|memset|memcmp)\b'
run_check 'process or shell execution' '\b(system|popen|execl|execv|CreateProcess)\b'
run_check 'assert-only validation' '\bassert\s*\('
run_check 'threading primitives' '\b(pthread_|std::thread|std::async|std::mutex|std::atomic|CreateThread)\b'

exit "$status"
