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

# Shared exclusion globs: vendored/build trees AND non-shipped dirs, mirroring
# cpp_risk_scan.sh so anchors line up across the helper family. Path-segment globs
# alone miss suffix-named tests (leveldb db_test.cc, re2 parse_test.cc), the
# `testing/` gerund (re2), `extras/` (miniaudio split-copy + vendored decoders),
# and flat-root harnesses (lua ltests.*) — all added below (R3).
EXCLUDE_GLOBS=(
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
  --glob '!**/testing/**'
  --glob '!**/bench/**'
  --glob '!**/benches/**'
  --glob '!**/benchmark/**'
  --glob '!**/benchmarks/**'
  --glob '!**/examples/**'
  --glob '!**/example/**'
  --glob '!**/extras/**'
  --glob '!**/extra/**'
  --glob '!**/docs/**'
  --glob '!**/doc/**'
  --glob '!**/utest.h'
  --glob '!**/unity*'
  --glob '!**/catch.hpp'
  --glob '!**/catch2/**'
  --glob '!**/*_test.*'
  --glob '!**/*_tests.*'
  --glob '!**/*test*.c'
  --glob '!**/*test*.cc'
  --glob '!**/*test*.cpp'
  --glob '!**/*test*.cxx'
  --glob '!**/*_bench*.*'
  --glob '!**/ltests.*'
  # R3+ test/vendored/generated conventions that path-segment + suffix globs miss
  # (kept identical to cpp_risk_scan.sh so anchors line up): NASA cFE `ut-coverage/`/
  # `ut-stubs/`; CamelCase test roots (`STest/`, `FppTestProject/`, any `[A-Z]*Test/`
  # such as GTest/); the `*test_inc.h` driver-include (pcre2); generated `single_include/`
  # amalgamations (nlohmann); vendored target-libc headers under `*/win32/include/`
  # (tinycc mingw). Ordinary public `include/` is NOT excluded — only those variants.
  --glob '!**/ut-coverage/**'
  --glob '!**/ut-stubs/**'
  --glob '!**/STest/**'
  --glob '!**/*TestProject*/**'
  --glob '!**/[A-Z]*Test/**'
  --glob '!**/*test_inc.h'
  --glob '!**/single_include/**'
  --glob '!**/win32/include/**'
)

# Whole-file comment/string stripper (R2): emits "<cleaned>\t<path>:<line>:<orig>"
# for every line of the files passed as args, blanking // /* */ comment spans
# (block state tracked across lines from each file's start) and "..."/'...' literal
# contents. This carries multi-line block state correctly — the only robust way,
# since the `/*` opener often lands on a line the search pattern does not match.
# A downstream rg re-applies the search pattern to the cleaned field; `cut`
# recovers the original row. Replaces the old leading-marker-only F1b filter.
STRIP_COMMENTS_AWK='
FNR == 1 { inblock = 0 }
{
  print strip($0) "\t" FILENAME ":" FNR ":" $0
}
function strip(s,   out, i, c, nx, n) {
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1); nx = substr(s, i + 1, 1)
    if (inblock) {
      if (c == "*" && nx == "/") { inblock = 0; i += 2; continue }
      i++; continue
    }
    if (c == "/" && nx == "/") break
    if (c == "/" && nx == "*") { inblock = 1; i += 2; continue }
    if (c == "\"") {
      i++
      while (i <= n) { c = substr(s, i, 1); if (c == "\\") { i += 2; continue } if (c == "\"") { i++; break } i++ }
      out = out " "; continue
    }
    if (c == "\047") {
      i++
      while (i <= n) { c = substr(s, i, 1); if (c == "\\") { i += 2; continue } if (c == "\047") { i++; break } i++ }
      out = out " "; continue
    }
    if (c == "\t") c = " "   # keep the cleaned field tab-free so it is one
    out = out c; i++         # cut/awk field (source tab-indentation would split it)
  }
  return out
}'

# rg over SHIPPED C/C++ sources with whole-file comment/string stripping (R2/R3).
# Returns "path:line:original" rows whose CODE part matches PATTERN. Args: PATTERN REPO
rg_code() {
  local files
  files="$(rg -l --no-messages \
      --glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx}' \
      "${EXCLUDE_GLOBS[@]}" \
      "$1" "$2" 2>/dev/null | LC_ALL=C sort || true)"
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | awk 'NF' | tr '\n' '\0' \
    | xargs -0 awk "$STRIP_COMMENTS_AWK" 2>/dev/null \
    | rg -P "^[^\t]*(?:$1)" 2>/dev/null \
    | cut -f2- || true
}

# C++ signal: does the repo SHIP real C++ code? True only when an actual C++
# translation unit (.cc/.cpp/.cxx/.c++) OR C++-only header (.hpp/.hh/.hxx/.h++)
# exists in a SHIPPED (non-test/non-vendored/non-extras) dir — same exclusion set
# as the scan (R1). A lone CMAKE_CXX_STANDARD / enable_language(CXX) build variable
# or a test-only/extras .cpp must NOT count: it falsely flipped pure-C repos to C++
# and re-enabled C++-only advice. C++-only advice (std::span/string_view) is only
# emitted when this is "yes"; on pure-C repos the same surface is relabeled as a
# ptr+len ownership-contract gap (F1a / W2).
repo_has_cpp() {
  local repo="$1"
  if [ -n "$(rg --files --no-messages \
        --glob '*.{cc,cpp,cxx,c++,hpp,hh,hxx,h++}' \
        "${EXCLUDE_GLOBS[@]}" \
        "$repo" 2>/dev/null)" ]; then
    return 0
  fi
  return 1
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
  # --hidden so the dot-prefixed .github/workflows tree is searched (F3a/F6):
  # rg skips hidden dirs by default, which made CI detection blind to GH Actions.
  n="$(rg -o --hidden --no-messages -i "$pattern" "${globs[@]}" '' "$repo" 2>/dev/null \
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
      # token is path:line:rest (grep output) OR a bare path (rg -l --files).
      n = index($0, ":")
      if (n == 0) {
        # bare path: strip ./ and the repo prefix, then print.
        path = $0
        sub(/^\.\//, "", path)
        if (substr(path, 1, length(prefix)) == prefix) {
          path = substr(path, length(prefix) + 1)
        }
        print path
        next
      }
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
      # `|| true`: under `set -euo pipefail` a `grep` that matches nothing exits 1
      # and pipefail propagates it through `| head`, aborting the substitution and
      # the whole script (N-cmphang abort class). A no-match is benign here.
      api="$(printf '%s' "$line" | grep -oE '\b(strcpy|strcat|sprintf|gets)\b' | head -n1 || true)"
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
  local hits has_span is_cpp
  is_cpp=no
  if repo_has_cpp "$repo"; then
    is_cpp=yes
  fi
  # Does the repo already use span/string_view anywhere? If so, suppress the
  # span suggestion (it has the vocabulary; absence elsewhere is noise).
  has_span=no
  if rg -q --no-messages 'std::span|std::string_view|gsl::span|absl::Span' "$repo" 2>/dev/null; then
    has_span=yes
  fi
  # On C++ repos with no span vocabulary, recommend std::span/string_view. On a
  # pure-C repo ptr+len IS the idiom and span is impossible, so we relabel the
  # same surface as an ownership-contract documentation gap (F1a / W2).
  if [ "$is_cpp" = no ] || [ "$has_span" = no ]; then
    # pointer+length parameter pair in a signature: `T *name, size_t len`
    hits="$(rg_code '\*[A-Za-z_][A-Za-z0-9_]*\s*,\s*(size_t|std::size_t|unsigned|int|uint[0-9]+_t)\s+[A-Za-z_]*(len|size|count|n)[A-Za-z0-9_]*' "$repo" | strip_repo_prefix "$repo")"
    if [ -n "$hits" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        local anchor
        anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
        if [ "$is_cpp" = yes ]; then
          printf 'api-ergonomics\tpointer+length parameter pair with no std::span/string_view (misuse-prone surface)\t%s\n' "$anchor"
        else
          printf 'api-ergonomics\tpointer+length parameter pair (C: document the ptr+len ownership/bounds contract)\t%s\n' "$anchor"
        fi
      done <<EOF
$hits
EOF
    fi
  fi
  # owning raw new/malloc inside a header (ownership crosses the boundary). The
  # `new` arm only applies on C++ repos; on C we keep the malloc/calloc arm.
  local owner_pat
  if [ "$is_cpp" = yes ]; then
    owner_pat='(=|return)\s*(::)?(new\b|malloc\s*\(|calloc\s*\()'
  else
    owner_pat='(=|return)\s*(malloc\s*\(|calloc\s*\()'
  fi
  local hdr_files
  hdr_files="$(rg -l --no-messages \
      --glob '*.{h,hh,hpp,hxx,h++}' \
      "${EXCLUDE_GLOBS[@]}" \
      "$owner_pat" "$repo" 2>/dev/null | LC_ALL=C sort || true)"
  if [ -n "$hdr_files" ]; then
    hits="$(printf '%s\n' "$hdr_files" | awk 'NF' | tr '\n' '\0' \
        | xargs -0 awk "$STRIP_COMMENTS_AWK" 2>/dev/null \
        | rg -P "^[^\t]*(?:$owner_pat)" 2>/dev/null \
        | cut -f2- | strip_repo_prefix "$repo" || true)"
  else
    hits=""
  fi
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
  local ci_files compilers archs stds hits has_matrix
  # CI matrix files (anchor = the CI file path when present, else inventory key).
  # --hidden: .github/workflows is a dot-dir that rg skips by default, which made
  # the whole lane blind to GitHub Actions and over-report "no CI matrix" (F3a/F6).
  ci_files="$(rg -l --hidden --no-messages \
      --glob '**/.github/workflows/*.yml' --glob '**/.github/workflows/*.yaml' \
      --glob '**/.gitlab-ci.yml' --glob '**/azure-pipelines.yml' \
      --glob '**/.cirrus.yml' --glob '**/.travis.yml' --glob '**/appveyor.yml' \
      '' "$repo" 2>/dev/null | strip_repo_prefix "$repo" || true)"
  local ci_anchor
  if [ -n "$ci_files" ]; then
    ci_anchor="$(printf '%s\n' "$ci_files" | LC_ALL=C sort | head -n1)"
  else
    ci_anchor="inventory:ci.matrix"
  fi

  local ci_globs=(
    '**/.github/workflows/*.yml' '**/.github/workflows/*.yaml'
    '**/.gitlab-ci.yml' '**/azure-pipelines.yml'
    '**/.cirrus.yml' '**/.travis.yml' '**/appveyor.yml'
  )
  if [ -n "$ci_files" ]; then
    # Does any CI file declare an explicit build/test matrix (strategy.matrix,
    # a YAML matrix: key, or a multi-value compiler/arch list)?  If so we never
    # claim CI is missing; we report what the matrix covers instead (F3a).
    has_matrix=no
    if rg -q --hidden --no-messages -i 'strategy:|matrix:|include:|fail-fast:' \
        --glob '**/.github/workflows/*.yml' --glob '**/.github/workflows/*.yaml' \
        '' "$repo" 2>/dev/null; then
      has_matrix=yes
    fi
    # Count distinct compilers / arches mentioned across CI files.
    compilers="$(count_distinct '\b(gcc|g\+\+|clang|clang\+\+|cl\.exe|msvc|mingw)\b' "$repo" "${ci_globs[@]}")"
    archs="$(count_distinct '\b(x86_64|amd64|aarch64|arm64|armv7|armv8|thumb|mips|powerpc|ppc64|i686|riscv64|s390x|win32|win64)\b' "$repo" "${ci_globs[@]}")"
    if [ "$has_matrix" = yes ]; then
      printf 'portability\tCI matrix present (covers %s compiler(s), %s arch(es)); verify it spans intended targets\t%s\n' \
        "${compilers:-0}" "${archs:-0}" "$ci_anchor"
    else
      if [ "${compilers:-0}" -le 1 ]; then
        printf 'portability\tonly one compiler exercised in CI (add a second toolchain)\t%s\n' "$ci_anchor"
      fi
      if [ "${archs:-0}" -le 1 ]; then
        printf 'portability\tonly one architecture exercised in CI (add a second arch)\t%s\n' "$ci_anchor"
      fi
    fi
  else
    printf 'portability\tno CI matrix detected; toolchain/arch/std coverage is unproven\t%s\n' "$ci_anchor"
  fi

  # Standard versions exercised anywhere in build/CI config.
  stds="$(count_distinct '(c\+\+(98|03|11|14|17|20|23)|gnu\+\+[0-9]+|std=c[0-9]+|c(89|99|11|17|23))' "$repo" \
      '**/CMakeLists.txt' '**/*.cmake' '**/CMakePresets.json' '**/meson.build' '**/Makefile' '**/*.mk' \
      '**/.github/workflows/*.yml' '**/.github/workflows/*.yaml')"
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
  local has_fuzz fuzz_refs fuzz_files hits
  # Does any fuzz harness exist at all?  A fuzz*/ dir, any *fuzz* source file, or
  # any LLVMFuzzerTestOneInput definition counts (F3b). --hidden so a dot-prefixed
  # OSS-Fuzz layout is still seen.
  has_fuzz=no
  # Files that ARE fuzz harnesses, found by path (fuzz*/ dir or *fuzz* name) or by
  # an LLVMFuzzerTestOneInput entry point. --hidden so a dot-prefixed OSS-Fuzz
  # layout is still seen. We must never flag one of these as an "uncovered"
  # parser, and a parser referenced by one is COVERED (F3b).
  local fuzz_paths_abs
  fuzz_paths_abs="$(rg --files --hidden --no-messages \
      --glob '**/fuzz/**' --glob '**/fuzzing/**' --glob '**/*fuzz*' \
      --glob '!**/.git/**' \
      "$repo" 2>/dev/null || true)"
  local refs_abs
  refs_abs="$(rg -l --hidden --no-messages 'LLVMFuzzerTestOneInput' "$repo" 2>/dev/null || true)"
  fuzz_files="$(printf '%s\n' "$fuzz_paths_abs" | strip_repo_prefix "$repo" | awk 'NF')"
  fuzz_refs="$(printf '%s\n' "$refs_abs" | strip_repo_prefix "$repo" | awk 'NF')"
  if [ -n "$fuzz_files" ] || [ -n "$fuzz_refs" ]; then
    has_fuzz=yes
  fi
  # Repo-relative harness file list (so we never flag a harness as uncovered).
  local harness_index
  harness_index="$(printf '%s\n%s\n' "$fuzz_files" "$fuzz_refs" | awk 'NF' | LC_ALL=C sort -u)"
  # Harness corpus: the concatenated text of every harness file. A parser entry
  # is covered when its function name OR its source file's basename appears here
  # (i.e. the harness #includes the file or calls the function).
  local harness_corpus=""
  if [ "$has_fuzz" = yes ]; then
    local absf
    while IFS= read -r absf; do
      [ -n "$absf" ] || continue
      harness_corpus="$harness_corpus
$(cat "$absf" 2>/dev/null || true)"
    done <<EOF
$(printf '%s\n%s\n' "$fuzz_paths_abs" "$refs_abs" | awk 'NF' | LC_ALL=C sort -u)
EOF
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
    local anchor fname base content func
    anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
    fname="$(printf '%s' "$anchor" | cut -d: -f1)"
    base="$(basename "$fname")"
    # Never flag the fuzz harness file itself as an uncovered entry point (F3b).
    if printf '%s\n' "$harness_index" | grep -qxF "$fname" 2>/dev/null; then
      continue
    fi
    if [ "$has_fuzz" = yes ] && [ -n "$harness_corpus" ]; then
      # Covered if a harness #includes this file (basename appears in corpus)...
      if printf '%s\n' "$harness_corpus" | grep -qF "$base" 2>/dev/null; then
        continue
      fi
      # ...or a harness calls the entry-point function by name. Extract the
      # identifier immediately before the FIRST "(" on the line (the declared/
      # defined function), then look for it referenced in the harness corpus.
      content="$(printf '%s' "$line" | cut -d: -f3-)"
      # `|| true`: either `grep` can match nothing (the line's only `name(` is a
      # control keyword filtered by the `grep -v`), exiting 1; under pipefail that
      # status survives `| head | sed` and aborts the whole script (N-cmphang class).
      func="$(printf '%s' "$content" \
        | grep -oE '[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(' \
        | grep -vwE '(if|for|while|switch|return|sizeof|defined)[[:space:]]*\(' \
        | head -n1 | sed -E 's/[[:space:]]*\($//' || true)"
      if [ -n "$func" ] && printf '%s\n' "$harness_corpus" | grep -qE "(^|[^A-Za-z0-9_])${func}([^A-Za-z0-9_]|$)" 2>/dev/null; then
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
  # Build file with no hardening flags -> hardening build rows. R1 TRAP: it also
  # declares CMAKE_CXX_STANDARD + enable_language(CXX) for an auxiliary target,
  # which previously flipped this pure-C repo to "C++" and leaked std::span advice.
  # With zero shipped C++ TUs the repo MUST stay C (asserted below via the C
  # ownership-contract relabel + the no-span assertion).
  cat >"$tmp/CMakeLists.txt" <<'CM'
cmake_minimum_required(VERSION 3.16)
project(fake C)
set(CMAKE_CXX_STANDARD 17)
enable_language(CXX)
add_executable(fake src/main.c)
CM
  # Source with an injected strcpy and a parse_* entry point, no fuzz harness.
  # Also seeds comment-only prose that MUST NOT match (F1b/F1c): a doc comment
  # mentioning strcpy/sprintf/new/delete, and a ptr+len signature (F1a-C). The
  # R2 TRAP is a MULTI-LINE /* ... */ block whose CONTINUATION line mentions
  # `malloc()` with no leading marker (the leveldb c.h class of leak) — it must
  # NOT yield a hardening row; only the real strcpy call may.
  cat >"$tmp/src/main.c" <<'SRC'
#include <string.h>
#include <stdlib.h>
/* This routine used to call sprintf and strcpy; we now use snprintf. */
// delete the old buffer and allocate a new one (prose, not code)
/* REQUIRES: ptr was
   malloc()-ed by the caller and is freed here */
void copy_it(char *dst, const char *src) {
    strcpy(dst, src);
}
int read_bytes(char *buf, size_t len) {
    return (int)(buf[0] + len);
}
int parse_packet(const unsigned char *buf, size_t len) {
    return (int)(buf[0] + len);
}
SRC

  # A test-tree file with a real strcpy CALL that MUST be excluded (F7).
  mkdir -p "$tmp/tests"
  cat >"$tmp/tests/test_main.c" <<'SRC'
#include <string.h>
void t(char *d, const char *s) { strcpy(d, s); }
SRC

  # R3 TRAP: a SUFFIX-named test co-located with sources (Google style) carrying
  # a real strcpy CALL. No dir-glob catches it; the *_test.* filename filter must.
  cat >"$tmp/src/parser_test.c" <<'SRC'
#include <string.h>
void tp(char *d, const char *s) { strcpy(d, s); }
SRC

  # R3+ TRAP: real strcpy CALLS inside the NASA `ut-coverage/`/`ut-stubs/` test
  # convention and a vendored `win32/include/` target-libc header. The new R3+
  # exclusion globs must drop all three (the shipped `src/main.c` strcpy survives).
  mkdir -p "$tmp/modules/ut-coverage" "$tmp/modules/ut-stubs" "$tmp/win32/include"
  cat >"$tmp/modules/ut-coverage/cov.c" <<'SRC'
#include <string.h>
void cov(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/modules/ut-stubs/stub.c" <<'SRC'
#include <string.h>
void stub(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/win32/include/string.h" <<'SRC'
#include <string.h>
static void w32(char *d, const char *s) { strcpy(d, s); }
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
  # Assertion F1b/F1c: prose in comments (sprintf/strcpy/new/delete words) must
  # NOT yield a hardening row. The only unsafe-string row may be the real call.
  if printf '%s\n' "$out1" | grep -qE 'main\.c:4'; then
    printf 'cpp_backlog self-test: FAIL (matched a comment-only line, F1b)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion F7: a strcpy CALL inside tests/ must be excluded.
  if printf '%s\n' "$out1" | grep -qE 'tests/test_main\.c'; then
    printf 'cpp_backlog self-test: FAIL (tests/ tree not excluded, F7)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion R3: a SUFFIX-named *_test.c co-located in src/ must be excluded.
  if printf '%s\n' "$out1" | grep -qE 'src/parser_test\.c'; then
    printf 'cpp_backlog self-test: FAIL (suffix-named *_test.c not excluded, R3)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion R3+: NASA `ut-coverage/`/`ut-stubs/` and vendored `win32/include/`
  # hits must be excluded, while the real shipped `src/main.c` strcpy survives.
  if printf '%s\n' "$out1" | grep -qE 'ut-coverage/|ut-stubs/|win32/include/'; then
    printf 'cpp_backlog self-test: FAIL (R3+: ut-coverage/ut-stubs/win32-include path not excluded)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  if ! printf '%s\n' "$out1" | grep -qE 'src/main\.c:[0-9]+'; then
    printf 'cpp_backlog self-test: FAIL (R3+ over-correction: real shipped src/main.c hit dropped)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion R2: the multi-line block-comment CONTINUATION line that mentions
  # malloc() (no leading marker) must NOT produce a hardening malloc row. The
  # malloc-with-multiply row anchors only to real code; the doc line at main.c:6
  # must not appear anywhere.
  if printf '%s\n' "$out1" | grep -qE 'main\.c:6'; then
    printf 'cpp_backlog self-test: FAIL (block-comment continuation leaked a malloc row, R2)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  # Assertion F1a (C): on a pure-C repo, ptr+len advice is relabeled as an
  # ownership-contract gap, NOT a std::span/string_view suggestion.
  if ! printf '%s\n' "$out1" | grep -q 'api-ergonomics | pointer+length parameter pair (C: document the ptr+len ownership/bounds contract)'; then
    printf 'cpp_backlog self-test: FAIL (C ptr+len ownership-contract row absent, F1a)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out1"
    exit 1
  fi
  if printf '%s\n' "$out1" | grep -q 'no std::span/string_view'; then
    printf 'cpp_backlog self-test: FAIL (std::span advice emitted on a pure-C repo, F1a)\n'
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

  # -------------------------------------------------------------------------
  # F3a: a .github/workflows matrix must be DETECTED (no "no CI matrix" claim).
  # The dir is hidden, so this also locks the --hidden + **/ glob fix.
  # -------------------------------------------------------------------------
  mkdir -p "$tmp/.github/workflows"
  cat >"$tmp/.github/workflows/ci.yml" <<'YML'
name: ci
jobs:
  build:
    strategy:
      matrix:
        cc: [gcc, clang]
        arch: [x86_64, aarch64]
    runs-on: ubuntu-latest
YML
  local out_ci
  out_ci="$(run_backlog "$tmp" no)"
  if printf '%s\n' "$out_ci" | grep -q 'no CI matrix detected'; then
    printf 'cpp_backlog self-test: FAIL (blind to .github/workflows matrix, F3a)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_ci"
    exit 1
  fi
  if ! printf '%s\n' "$out_ci" | grep -q 'portability | CI matrix present'; then
    printf 'cpp_backlog self-test: FAIL (CI matrix not recognized, F3a)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_ci"
    exit 1
  fi
  if ! printf '%s\n' "$out_ci" | grep -qE 'CI matrix present.*\.github/workflows/ci\.yml'; then
    printf 'cpp_backlog self-test: FAIL (CI anchor not repo-relative, F3a)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_ci"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # F3b: a shipped fuzz harness that references a parser COVERS it (no row),
  # and the harness file itself is never flagged as an uncovered entry point.
  # -------------------------------------------------------------------------
  mkdir -p "$tmp/fuzz"
  cat >"$tmp/src/main.c" <<'SRC'
#include <string.h>
#include <stdlib.h>
int parse_packet(const unsigned char *buf, size_t len) {
    return (int)(buf[0] + len);
}
SRC
  cat >"$tmp/fuzz/fuzz_parse.c" <<'SRC'
#include <stddef.h>
#include <stdint.h>
int parse_packet(const unsigned char *buf, size_t len);
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    return parse_packet(data, size);
}
SRC
  local out_fuzz
  out_fuzz="$(run_backlog "$tmp" no)"
  if printf '%s\n' "$out_fuzz" | grep -qE 'test-fuzz-coverage \| parser/decoder.*\| src/main\.c'; then
    printf 'cpp_backlog self-test: FAIL (parser covered by fuzz harness still flagged, F3b)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_fuzz"
    exit 1
  fi
  if printf '%s\n' "$out_fuzz" | grep -qE 'test-fuzz-coverage \| parser/decoder.*\| fuzz/fuzz_parse\.c'; then
    printf 'cpp_backlog self-test: FAIL (fuzz harness file itself flagged as uncovered, F3b)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_fuzz"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # F1a (C++): on a repo WITH C++ sources, ptr+len advice recommends std::span/
  # string_view (not the C ownership-contract relabel).
  # -------------------------------------------------------------------------
  local cpptmp
  cpptmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp' '$cpptmp'" EXIT
  mkdir -p "$cpptmp/src"
  cat >"$cpptmp/CMakeLists.txt" <<'CM'
cmake_minimum_required(VERSION 3.16)
project(fakecpp CXX)
set(CMAKE_CXX_STANDARD 17)
add_executable(fakecpp src/main.cpp)
CM
  cat >"$cpptmp/src/main.cpp" <<'SRC'
#include <cstddef>
int sum_bytes(const char *buf, std::size_t len) {
    int t = 0;
    for (std::size_t i = 0; i < len; ++i) t += buf[i];
    return t;
}
SRC
  local out_cpp
  out_cpp="$(run_backlog "$cpptmp" no)"
  if ! printf '%s\n' "$out_cpp" | grep -q 'api-ergonomics | pointer+length parameter pair with no std::span/string_view'; then
    printf 'cpp_backlog self-test: FAIL (C++ repo did not get std::span advice, F1a)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_cpp"
    exit 1
  fi
  if printf '%s\n' "$out_cpp" | grep -q 'C: document the ptr+len'; then
    printf 'cpp_backlog self-test: FAIL (C ownership-contract relabel leaked onto a C++ repo, F1a)\n'
    printf '%s\n%s\n' '--- backlog ---' "$out_cpp"
    exit 1
  fi

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
