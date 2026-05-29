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

if ! command -v rg >/dev/null 2>&1; then
  printf 'error: rg is required for cpp_risk_scan.sh\n' >&2
  exit 3
fi

# Shared exclusions: vendored/build trees AND non-shipped dirs (tests, benches,
# examples, docs). These inflate the risk surface with code that never ships
# (F7). The split between shipped library code and test/bench harnesses is made
# explicit in the [scope] banner below.
search=(
  rg -n
  --glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx}'
  --glob '!**/.git/**'
  --glob '!**/build/**'
  --glob '!**/_deps/**'
  --glob '!**/third_party/**'
  --glob '!**/thirdparty/**'
  --glob '!**/vendor/**'
  --glob '!**/extern/**'
  --glob '!**/external/**'
  --glob '!**/tests/**'
  --glob '!**/test/**'
  --glob '!**/bench/**'
  --glob '!**/benches/**'
  --glob '!**/benchmark/**'
  --glob '!**/benchmarks/**'
  --glob '!**/examples/**'
  --glob '!**/example/**'
  --glob '!**/docs/**'
  --glob '!**/doc/**'
  --glob '!**/utest.h'
  --glob '!**/unity*'
  --glob '!**/catch.hpp'
  --glob '!**/catch2/**'
)

# C++ signal: does the repo actually contain C++ sources or a C++ build std?
# C++-only risk categories (raw new/delete) are suppressed on pure-C repos so we
# stop flagging the English words "new"/"delete" in C comments (F1a).
detect_cpp() {
  local t
  for t in "${targets[@]}"; do
    # Any C++ translation unit / header present?
    if [ -n "$(rg --files --no-messages \
          --glob '*.{cc,cpp,cxx,hpp,hh,hxx}' \
          --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
          "$t" 2>/dev/null)" ]; then
      printf 'yes'
      return 0
    fi
    # Or a C++ standard / CXX language declared in the build.
    if rg -q --no-messages \
        --glob 'CMakeLists.txt' --glob '*.cmake' --glob 'CMakePresets.json' \
        --glob 'meson.build' --glob 'Makefile' --glob '*.mk' \
        --glob '!**/.git/**' \
        '(-std=c\+\+|-std=gnu\+\+|CMAKE_CXX_STANDARD|CXX_STANDARD|cpp_std|languages?\s*\(.*CXX)' \
        "$t" 2>/dev/null; then
      printf 'yes'
      return 0
    fi
  done
  printf 'no'
}

HAS_CPP="$(detect_cpp)"

# Comment post-filter: rg emits "file:line:content"; drop rows whose content
# field, left-trimmed, begins with a doc/line-comment marker (* // /*). This
# kills "coordinate system", "operating system", "a new frame", "/* delete */",
# "gets va_list", and the like in prose without parsing the language (F1b).
drop_comment_lines() {
  awk -F: '
    {
      # content is everything after the second colon (file:line:content)
      p = index($0, ":")
      if (p == 0) { print; next }
      rest = substr($0, p + 1)
      q = index(rest, ":")
      if (q == 0) { print; next }
      content = substr(rest, q + 1)
      # left-trim whitespace
      sub(/^[ \t]+/, "", content)
      if (content ~ /^\*/)  next
      if (content ~ /^\/\//) next
      if (content ~ /^\/\*/) next
      print
    }'
}

status=0

# run_check PATTERN with comment filtering. Args: LABEL PATTERN
run_check() {
  local label="$1"
  local pattern="$2"
  local out
  printf '\n[%s]\n' "$label"
  out="$("${search[@]}" "$pattern" "${targets[@]}" 2>/dev/null | drop_comment_lines || true)"
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    status=1
  else
    printf 'no matches\n'
  fi
}

# Scope banner: be explicit that non-shipped dirs (tests/bench/examples/docs)
# and vendored frameworks are excluded so the surface reflects shipped code.
printf '[scope] shipped library code only; excludes tests/, test/, bench*/, examples/,\n'
printf '        docs/, third_party/, vendor/, extern/, and vendored test frameworks.\n'
printf '[scope] C++ signal: %s (raw new/delete category %s)\n' \
  "$HAS_CPP" "$([ "$HAS_CPP" = yes ] && printf enabled || printf 'suppressed (pure-C)')"

# Unsafe string/format APIs: require the function name as a word immediately
# followed by `(` so we match real CALLS, not prose or identifier substrings
# (F1c). snprintf/vsnprintf/vfprintf are the SAFE bounded alternatives and are
# deliberately NOT in this set; the genuinely unsafe variadic/copy APIs are.
run_check 'unsafe string or formatting APIs' \
  '\b(strcpy|strcat|stpcpy|sprintf|vsprintf|gets|scanf|sscanf|fscanf|vscanf|vsscanf|strncpy|strncat)\s*\('
run_check 'raw allocation function calls' '\b(malloc|calloc|realloc|free)\s*\('
if [ "$HAS_CPP" = yes ]; then
  run_check 'raw C++ new/delete expressions' \
    '(^|[^[:alnum:]_])(::)?new[[:space:]]+|(^|[^[:alnum:]_])delete(\[\])?[[:space:]]+'
else
  printf '\n[raw C++ new/delete expressions]\n'
  printf 'skipped: no C++ signal (pure-C repo; new/delete are not C constructs)\n'
fi
run_check 'casts requiring review' '\b(reinterpret_cast|const_cast|static_cast<.*\*>|\([A-Za-z_][A-Za-z0-9_:<>[:space:]]*\s*\*\))'
run_check 'unchecked memory movement' '\b(memcpy|memmove|memset|memcmp)\s*\('
run_check 'process or shell execution' '\b(system|popen|execl|execlp|execle|execv|execvp|execvpe|CreateProcess)\s*\('
run_check 'assert-only validation' '\bassert\s*\('
run_check 'threading primitives' '\b(pthread_[a-z_]+\s*\(|std::thread|std::async|std::mutex|std::atomic|CreateThread\s*\()'

# This is a side-effect-free triage REPORT, not a pass/fail gate: exit 0 on a
# successful run regardless of whether any category matched. A trailing rg
# no-match must NOT make a $?-checking caller see failure (F4).
: "$status"
exit 0
