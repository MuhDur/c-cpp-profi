#!/usr/bin/env bash
#
# cpp_backlog.sh - derive a deduplicated capability-gap backlog for a C/C++ repo.
#
# This is the "Enumerate Before Inventing" tool from references/INNOVATION-ENGINE.md.
# It is READ-ONLY: it never writes to the target repo. It runs cpp_inventory.sh and
# cpp_risk_scan.sh (located next to this script), plus its own deterministic greps,
# and emits one capability gap per line across four fixed lanes that hold for any
# C/C++ repo:
#
#   hardening           - missing sanitizer/_FORTIFY_SOURCE/stack-protector/CFI build
#                         evidence; raw strcpy/strcat/sprintf/gets/unchecked malloc(*
#   api-ergonomics      - pointer+length signatures with no span/view; owning raw
#                         new/malloc crossing a header boundary
#   portability         - only one compiler/arch/std exercised; load-bearing
#                         long/time_t/endian/packing assumptions
#   test-fuzz-coverage  - parse/decode entry points (incl. const uint8_t*/size_t)
#                         with no fuzz harness referencing them
#
# Every emitted row carries an evidence anchor (repo-relative file:line, or an
# inventory key). A row with no anchor is never emitted. Output is deterministic:
# repo-relative paths only, LC_ALL=C sort, no timestamps, no $RANDOM, no absolute
# paths, so two runs on an unchanged tree byte-match.
#
# Usage:
#   cpp_backlog.sh [REPO] [--json]     (default REPO=.)
#   cpp_backlog.sh --self-test
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
usage: cpp_backlog.sh [REPO] [--json]
       cpp_backlog.sh --self-test

Emits a deduplicated capability-gap backlog (lane | gap | anchor) for a C/C++
repo. READ-ONLY. Deterministic and reproducible: two runs byte-match.
Anchors are repo-relative file:line or an inventory key.
USAGE
}

# ---------------------------------------------------------------------------
# rg search base, mirroring cpp_risk_scan.sh's exclusions so anchors line up.
# ---------------------------------------------------------------------------
rg_available() {
  command -v rg >/dev/null 2>&1
}

rg_code() {
  # rg over C/C++ sources, vendored/build trees excluded. Args: PATTERN REPO
  rg -n --no-heading --no-messages \
    --glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx}' \
    --glob '!**/.git/**' \
    --glob '!**/build/**' \
    --glob '!**/_deps/**' \
    --glob '!**/third_party/**' \
    --glob '!**/vendor/**' \
    --glob '!**/external/**' \
    --glob '!**/test/gtest/**' \
    --glob '!**/test/gmock/**' \
    "$1" "$2" 2>/dev/null || true
}

# Count distinct (case-folded) matches of PATTERN under REPO across the CI/build
# globs passed as remaining args. Always prints a bare integer, never fails.
# Args: PATTERN REPO GLOB...
count_distinct() {
  local pattern="$1" repo="$2"
  shift 2
  local globs=()
  local g
  for g in "$@"; do
    globs+=(--glob "$g")
  done
  local n
  n="$(rg -o --no-messages -i "$pattern" "${globs[@]}" '' "$repo" 2>/dev/null \
        | tr 'A-Z' 'a-z' | LC_ALL=C sort -u | grep -c . || true)"
  [ -n "$n" ] || n=0
  printf '%s' "$n"
}

# Strip a leading "REPO/" (or "REPO" == ".") prefix so anchors are repo-relative.
# Args: REPO  (reads file:line tokens on stdin, rewrites the path component)
strip_repo_prefix() {
  local repo="$1"
  local prefix="$repo/"
  awk -v prefix="$prefix" '
    {
      # token is path:line:rest ; only the path part may carry the prefix
      n = index($0, ":")
      if (n == 0) { print; next }
      path = substr($0, 1, n - 1)
      rest = substr($0, n)
      # normalize ./ and the repo prefix
      sub(/^\.\//, "", path)
      if (substr(path, 1, length(prefix)) == prefix) {
        path = substr(path, length(prefix) + 1)
      }
      print path rest
    }'
}

# ---------------------------------------------------------------------------
# Lane producers. Each appends "lane\tgap\tanchor" lines to the backlog buffer.
# A line is only appended when a real anchor exists.
# ---------------------------------------------------------------------------

# hardening: build-file evidence gaps (anchor = inventory/build key) ----------
emit_hardening_build() {
  local repo="$1"
  local inv="$2"   # captured cpp_inventory.sh output
  local buildfiles
  # The set of build/config files that could carry hardening flags.
  buildfiles="$(rg -l --no-messages \
      --glob 'CMakeLists.txt' --glob '*.cmake' --glob 'CMakePresets.json' \
      --glob 'meson.build' --glob 'Makefile' --glob '*.mk' \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      '' "$repo" 2>/dev/null || true)"
  [ -n "$buildfiles" ] || return 0

  # Each missing hardening signal is anchored to the build-config inventory key,
  # so the row is grounded even though the evidence is an absence.
  if ! rg -q --no-messages '\-fsanitize|sanitizers|CMakePresets\.sanitizers' "$repo" 2>/dev/null; then
    printf 'hardening\tno sanitizer preset (-fsanitize) found in build files\tinventory:build.config\n'
  fi
  if ! rg -q --no-messages '_FORTIFY_SOURCE' "$repo" 2>/dev/null; then
    printf 'hardening\tno -D_FORTIFY_SOURCE in build files\tinventory:build.config\n'
  fi
  if ! rg -q --no-messages '\-fstack-protector|stack_protector' "$repo" 2>/dev/null; then
    printf 'hardening\tno stack-protector flag in build files\tinventory:build.config\n'
  fi
  if ! rg -q --no-messages '\-fcf-protection|\-fsanitize=cfi|cf-protection' "$repo" 2>/dev/null; then
    printf 'hardening\tno CFI / control-flow-protection evidence in build files\tinventory:build.config\n'
  fi
  return 0
}

# hardening: unsafe API call sites (anchor = file:line) ----------------------
emit_hardening_calls() {
  local repo="$1"
  local hits
  hits="$(rg_code '\b(strcpy|strcat|sprintf|gets)\s*\(' "$repo" | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local anchor api
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      api="$(printf '%s' "$line" | grep -oE '\b(strcpy|strcat|sprintf|gets)\b' | head -n1)"
      printf 'hardening\tunsafe string/format API %s (bounded-copy migration candidate)\t%s\n' "$api" "$anchor"
    done <<EOF
$hits
EOF
  fi
  # unchecked malloc with a multiply in the size argument (overflow risk)
  hits="$(rg_code '\b(malloc|calloc|realloc)\s*\([^)]*\*' "$repo" | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local anchor
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'hardening\tmalloc/calloc with a multiply in size arg (overflow guard candidate)\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi
  return 0
}

# api-ergonomics: pointer+length signatures, owning raw alloc in headers ------
emit_api_ergonomics() {
  local repo="$1"
  local hits has_span
  # Does the repo already use span/string_view anywhere? If so, suppress the
  # span suggestion (it has the vocabulary; absence elsewhere is noise).
  has_span=no
  if rg -q --no-messages 'std::span|std::string_view|gsl::span|absl::Span' "$repo" 2>/dev/null; then
    has_span=yes
  fi
  if [ "$has_span" = no ]; then
    # pointer+length parameter pair in a signature: `T *name, size_t len`
    hits="$(rg_code '\*[A-Za-z_][A-Za-z0-9_]*\s*,\s*(size_t|std::size_t|unsigned|int|uint[0-9]+_t)\s+[A-Za-z_]*(len|size|count|n)[A-Za-z0-9_]*' "$repo" | strip_repo_prefix "$repo")"
    if [ -n "$hits" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        local anchor
        anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
        printf 'api-ergonomics\tpointer+length parameter pair with no span/view (misuse-prone surface)\t%s\n' "$anchor"
      done <<EOF
$hits
EOF
    fi
  fi
  # owning raw new/malloc inside a header (ownership crosses the boundary)
  hits="$(rg -n --no-heading --no-messages \
      --glob '*.{h,hh,hpp,hxx}' \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      --glob '!**/third_party/**' --glob '!**/vendor/**' --glob '!**/external/**' \
      '(=|return)\s*(::)?(new\b|malloc\s*\(|calloc\s*\()' "$repo" 2>/dev/null | strip_repo_prefix "$repo" || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local anchor
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'api-ergonomics\towning raw new/malloc in a header (ownership crosses boundary; owner-annotated/RAII candidate)\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi
  return 0
}

# portability: single-toolchain CI, load-bearing width/endian assumptions -----
emit_portability() {
  local repo="$1"
  local ci_files compilers archs stds hits
  # CI matrix files (anchor = the CI file path when present, else inventory key).
  ci_files="$(rg -l --no-messages \
      --glob '.github/workflows/*.yml' --glob '.github/workflows/*.yaml' \
      --glob '.gitlab-ci.yml' --glob 'azure-pipelines.yml' \
      --glob '.cirrus.yml' --glob '.travis.yml' --glob 'appveyor.yml' \
      '' "$repo" 2>/dev/null | strip_repo_prefix "$repo" || true)"
  local ci_anchor
  if [ -n "$ci_files" ]; then
    ci_anchor="$(printf '%s\n' "$ci_files" | LC_ALL=C sort | head -n1)"
  else
    ci_anchor="inventory:ci.matrix"
  fi

  local ci_globs=(
    '.github/workflows/*.yml' '.github/workflows/*.yaml'
    '.gitlab-ci.yml' 'azure-pipelines.yml'
    '.cirrus.yml' '.travis.yml' 'appveyor.yml'
  )
  if [ -n "$ci_files" ]; then
    # Count distinct compilers / arches mentioned across CI files.
    compilers="$(count_distinct '\b(gcc|g\+\+|clang|clang\+\+|cl\.exe|msvc|mingw)\b' "$repo" "${ci_globs[@]}")"
    archs="$(count_distinct '\b(x86_64|amd64|aarch64|arm64|armv7|i686|ppc64|riscv64|s390x|win32|win64)\b' "$repo" "${ci_globs[@]}")"
    if [ "${compilers:-0}" -le 1 ]; then
      printf 'portability\tonly one compiler exercised in CI (add a second toolchain)\t%s\n' "$ci_anchor"
    fi
    if [ "${archs:-0}" -le 1 ]; then
      printf 'portability\tonly one architecture exercised in CI (add a second arch)\t%s\n' "$ci_anchor"
    fi
  else
    printf 'portability\tno CI matrix detected; toolchain/arch/std coverage is unproven\t%s\n' "$ci_anchor"
  fi

  # Standard versions exercised anywhere in build/CI config.
  stds="$(count_distinct '(c\+\+(98|03|11|14|17|20|23)|gnu\+\+[0-9]+|std=c[0-9]+|c(89|99|11|17|23))' "$repo" \
      'CMakeLists.txt' '*.cmake' 'CMakePresets.json' 'meson.build' 'Makefile' '*.mk' \
      '.github/workflows/*.yml' '.github/workflows/*.yaml')"
  if [ "${stds:-0}" -le 1 ]; then
    printf 'portability\tat most one language standard exercised in build/CI\t%s\n' "$ci_anchor"
  fi

  # Load-bearing width / time_t / endian / packing assumptions (anchor = file:line).
  hits="$(rg_code '\b(htons|htonl|ntohs|ntohl|__BYTE_ORDER__|BYTE_ORDER|__attribute__\s*\(\s*\(\s*packed|#pragma pack)\b' "$repo" | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local anchor
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'portability\tendian/packing assumption (load-bearing, needs a static_assert or portable accessor)\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi
  hits="$(rg_code '\b(time_t)\b' "$repo" | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local anchor
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'portability\ttime_t width assumption (verify against 32-bit / Y2038 targets)\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi
  return 0
}

# test-fuzz-coverage: parse/decode entry points with no fuzz harness ----------
emit_test_fuzz() {
  local repo="$1"
  local has_fuzz fuzz_refs hits
  # Does any fuzz harness exist at all?  (a fuzz/ dir or an LLVMFuzzerTestOneInput)
  has_fuzz=no
  if [ -d "$repo/fuzz" ] || [ -d "$repo/fuzzing" ] || [ -d "$repo/test/fuzz" ]; then
    has_fuzz=yes
  fi
  fuzz_refs=""
  fuzz_refs="$(rg -l --no-messages 'LLVMFuzzerTestOneInput' "$repo" 2>/dev/null || true)"
  if [ -n "$fuzz_refs" ]; then
    has_fuzz=yes
  fi

  # parser/decoder entry points: name matches *parse*/*decode*, or signature
  # takes a raw byte buffer + length (the canonical fuzz entry shape). We anchor
  # on `const uint8_t*`/`const unsigned char*` + size_t and deliberately exclude
  # `const char*`, which is overwhelmingly a C string, not an untrusted byte run.
  hits="$(rg_code '\b[A-Za-z_][A-Za-z0-9_]*(parse|decode|Parse|Decode)[A-Za-z0-9_]*\s*\(' "$repo" | strip_repo_prefix "$repo")"
  local sig_hits
  sig_hits="$(rg_code 'const\s+(uint8_t|unsigned char)\s*\*[A-Za-z0-9_ ]*,\s*(size_t|std::size_t)' "$repo" | strip_repo_prefix "$repo")"
  if [ -n "$sig_hits" ]; then
    if [ -n "$hits" ]; then
      hits="$hits
$sig_hits"
    else
      hits="$sig_hits"
    fi
  fi

  [ -n "$hits" ] || return 0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local anchor fname
    anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
    fname="$(printf '%s' "$anchor" | cut -d: -f1)"
    # If a harness references THIS file (by basename) skip; else it is uncovered.
    if [ "$has_fuzz" = yes ] && [ -n "$fuzz_refs" ]; then
      local base covered
      base="$(basename "$fname")"
      covered=no
      # is this source file's basename mentioned by any harness?
      if printf '%s\n' "$fuzz_refs" | grep -qF "$base" 2>/dev/null; then
        covered=yes
      fi
      if [ "$covered" = yes ]; then
        continue
      fi
    fi
    printf 'test-fuzz-coverage\tparser/decoder entry point with no fuzz harness referencing it\t%s\n' "$anchor"
  done <<EOF
$hits
EOF
  return 0
}

# ---------------------------------------------------------------------------
# Backlog assembly: gather rows, dedupe, sort deterministically.
# ---------------------------------------------------------------------------
build_backlog() {
  local repo="$1"
  local inv=""
  # cpp_inventory.sh is read-only; capture it (a couple of lanes anchor to it).
  if [ -x "$SELF_DIR/cpp_inventory.sh" ] || [ -f "$SELF_DIR/cpp_inventory.sh" ]; then
    inv="$(bash "$SELF_DIR/cpp_inventory.sh" "$repo" 2>/dev/null || true)"
  fi
  # cpp_risk_scan.sh is invoked for parity / side-effect-free triage; its file:line
  # anchors are reproduced here via rg_code so output stays deterministic.
  if [ -f "$SELF_DIR/cpp_risk_scan.sh" ]; then
    bash "$SELF_DIR/cpp_risk_scan.sh" "$repo" >/dev/null 2>&1 || true
  fi

  {
    emit_hardening_build "$repo" "$inv"
    emit_hardening_calls "$repo"
    emit_api_ergonomics "$repo"
    emit_portability "$repo"
    emit_test_fuzz "$repo"
  } | awk 'NF' | LC_ALL=C sort -u
}

emit_text() {
  # tab-separated lane/gap/anchor -> "lane | gap | anchor"
  awk -F'\t' 'NF>=3 { printf "%s | %s | %s\n", $1, $2, $3 }'
}

emit_json() {
  # tab-separated lane/gap/anchor -> JSON array of {lane,gap,anchor}
  awk -F'\t' '
    function esc(s,   r) {
      r = s
      gsub(/\\/, "\\\\", r)
      gsub(/"/, "\\\"", r)
      return r
    }
    BEGIN { printf "[" ; first = 1 }
    NF>=3 {
      if (!first) printf ","
      first = 0
      printf "\n  {\"lane\": \"%s\", \"gap\": \"%s\", \"anchor\": \"%s\"}", esc($1), esc($2), esc($3)
    }
    END { if (!first) printf "\n"; printf "]\n" }'
}

run_backlog() {
  local repo="$1"
  local json="$2"
  if [ ! -d "$repo" ]; then
    printf 'error: not a directory: %s\n' "$repo" >&2
    exit 2
  fi
  if ! rg_available; then
    printf 'error: rg (ripgrep) is required for cpp_backlog.sh\n' >&2
    exit 3
  fi
  local rows
  rows="$(build_backlog "$repo")"
  if [ "$json" = yes ]; then
    printf '%s\n' "$rows" | emit_json
  else
    printf '%s\n' "$rows" | emit_text
  fi
}

# ---------------------------------------------------------------------------
# Self-test: build a tiny fake repo, prove rows appear / disappear, prove
# two consecutive runs byte-match. Cleans up via trap.
# ---------------------------------------------------------------------------
self_test() {
  if ! rg_available; then
    printf 'cpp_backlog self-test: FAIL (rg not available)\n'
    exit 1
  fi
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  mkdir -p "$tmp/src"
  # Build file with no hardening flags -> hardening build rows.
  cat >"$tmp/CMakeLists.txt" <<'CM'
cmake_minimum_required(VERSION 3.16)
project(fake C)
add_executable(fake src/main.c)
CM
  # Source with an injected strcpy and a parse_* entry point, no fuzz harness.
  cat >"$tmp/src/main.c" <<'SRC'
#include <string.h>
#include <stdlib.h>
void copy_it(char *dst, const char *src) {
    strcpy(dst, src);
}
int parse_packet(const unsigned char *buf, size_t len) {
    return (int)(buf[0] + len);
}
SRC

  local out1 out2
  out1="$(run_backlog "$tmp" no)"

  # Assertion 1: a hardening strcpy row appears, anchored to main.c.
  if ! printf '%s\n' "$out1" | grep -q 'hardening | unsafe string/format API strcpy'; then
    printf 'cpp_backlog self-test: FAIL (expected strcpy hardening row absent)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  if ! printf '%s\n' "$out1" | grep -qE 'src/main\.c:[0-9]+'; then
    printf 'cpp_backlog self-test: FAIL (strcpy row carries no repo-relative anchor)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion 2: a test-fuzz-coverage row appears for parse_packet.
  if ! printf '%s\n' "$out1" | grep -q 'test-fuzz-coverage | parser/decoder entry point with no fuzz harness'; then
    printf 'cpp_backlog self-test: FAIL (expected parser/no-fuzz row absent)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion 3 (no absolute paths leak): output must not contain the temp dir.
  if printf '%s\n' "$out1" | grep -qF "$tmp"; then
    printf 'cpp_backlog self-test: FAIL (absolute path leaked into output)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion 4: reproducibility - two consecutive runs byte-match.
  out2="$(run_backlog "$tmp" no)"
  if [ "$out1" != "$out2" ]; then
    printf 'cpp_backlog self-test: FAIL (two runs did not byte-match)\n'
    diff <(printf '%s\n' "$out1") <(printf '%s\n' "$out2") || true
    exit 1
  fi

  # Now remove the injected gaps and assert the rows disappear.
  cat >"$tmp/src/main.c" <<'SRC'
#include <string.h>
#include <stdlib.h>
void copy_it(char *dst, const char *src, size_t cap) {
    snprintf(dst, cap, "%s", src);
}
int compute(int a, int b) {
    return a + b;
}
SRC

  local out3
  out3="$(run_backlog "$tmp" no)"
  if printf '%s\n' "$out3" | grep -q 'hardening | unsafe string/format API strcpy'; then
    printf 'cpp_backlog self-test: FAIL (strcpy row did not disappear after removal)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out3"
    exit 1
  fi
  if printf '%s\n' "$out3" | grep -q 'test-fuzz-coverage | parser/decoder entry point with no fuzz harness'; then
    printf 'cpp_backlog self-test: FAIL (parser/no-fuzz row did not disappear after removal)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out3"
    exit 1
  fi

  # JSON mode must be well-formed (an array) on the same tree.
  local js
  js="$(run_backlog "$tmp" yes)"
  case "$js" in
    \[*\]) : ;;
    *)
      printf 'cpp_backlog self-test: FAIL (JSON mode did not emit an array)\n'
      printf '%s\n%s\n' '--- json ---' "$js"
      exit 1
      ;;
  esac

  printf 'cpp_backlog self-test: PASS\n'
  exit 0
}

# ---------------------------------------------------------------------------
# Arg handling.
# ---------------------------------------------------------------------------
main() {
  local repo="."
  local json="no"
  local repo_set="no"

  for arg in "$@"; do
    case "$arg" in
      --self-test)
        self_test
        ;;
      --json)
        json="yes"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        printf 'error: unknown option: %s\n' "$arg" >&2
        usage >&2
        exit 2
        ;;
      *)
        if [ "$repo_set" = yes ]; then
          printf 'error: unexpected extra argument: %s\n' "$arg" >&2
          exit 2
        fi
        repo="$arg"
        repo_set="yes"
        ;;
    esac
  done

  # Normalize a trailing slash so prefix stripping is exact.
  repo="${repo%/}"
  [ -n "$repo" ] || repo="."

  run_backlog "$repo" "$json"
}

main "$@"
