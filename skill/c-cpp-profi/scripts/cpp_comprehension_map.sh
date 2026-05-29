#!/usr/bin/env bash
#
# cpp_comprehension_map.sh - emit a falsifiable L1+L2 comprehension map of a C/C++ repo.
#
# This is the fast-path probe for references/REPO-COMPREHENSION.md L1 (build graph
# & ground) and L2 (entry points + module map). It is READ-ONLY: it never writes
# to the target repo. In one command it answers "what builds this, where does it
# start, and how is it shaped" with anchored, falsifiable rows an agent can paste
# into the comprehension gate.
#
# It emits three sections, each line carrying a repo-relative anchor:
#
#   L1 build graph & ground - detected build system(s) (CMakeLists.txt / meson.build /
#                             Makefile / configure / Bazel), presence of
#                             compile_commands.json, a language breakdown (counts of
#                             .c/.cc/.cpp/.cxx/.h/.hpp), and toolchain/std hints found
#                             in build files (CMAKE_CXX_STANDARD, -std=, c_std/cpp_std).
#   L2 entry points         - main( definitions, LLVMFuzzerTestOneInput, and exported
#                             library API hints (public headers under include/ or
#                             top-level *.h; visibility("default")/EXPORT/API macros),
#                             each with a repo-relative file:line anchor.
#   L2 module map           - top-level source directories with per-dir file counts (a
#                             coarse module map).
#
# Output is deterministic: repo-relative paths only, LC_ALL=C sort, no timestamps,
# no $RANDOM, no absolute paths, so two runs on an unchanged tree byte-match.
#
# Usage:
#   cpp_comprehension_map.sh [REPO] [--json]   (default REPO=.)
#   cpp_comprehension_map.sh --self-test
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SELF_DIR is BASH_SOURCE-relative so the script works from any cwd. It is not
# otherwise used, matching the sibling helpers' location discipline.
: "${SELF_DIR:?}"

usage() {
  cat <<'USAGE'
usage: cpp_comprehension_map.sh [REPO] [--json]
       cpp_comprehension_map.sh --self-test

Emits a falsifiable L1+L2 comprehension map (build graph + entry points + module
map) for a C/C++ repo. READ-ONLY. Deterministic and reproducible: two runs on an
unchanged tree byte-match. Every entry-point/module line carries a repo-relative
file:line or path anchor.
USAGE
}

# ---------------------------------------------------------------------------
# rg guard + search base, mirroring cpp_risk_scan.sh's exclusions so anchors
# line up across the helper family.
# ---------------------------------------------------------------------------
rg_available() {
  command -v rg >/dev/null 2>&1
}

# R3+ test/vendored/generated exclusion conventions that path-segment + suffix
# globs miss, mirroring the sibling scripts so the comprehension map reflects the
# shipped surface (and so a generated mirror does not double-list the API):
#  - NASA cFE unit-test dirs `ut-coverage/`/`ut-stubs/`.
#  - CamelCase test roots: F´ `STest/`, `FppTestProject/`, and any `[A-Z]*Test/`
#    dir (GTest/, FooTest/) — `[A-Z]*` so ordinary lowercase dirs are untouched.
#  - the `*test_inc.h` driver-include convention (pcre2 `pcre2test_inc.h`).
#  - generated amalgamations `single_include/` (nlohmann — a generated mirror of
#    `include/`; without this its exported-API list is every public decl twice).
#  - vendored target-libc headers under `*/win32/include/` (tinycc mingw headers).
# Ordinary public `include/` is NOT excluded — that is the real API surface; only
# the `single_include/` mirror and the `win32/include/` vendored variant are.
R3PLUS_GLOBS=(
  --glob '!**/ut-coverage/**'
  --glob '!**/ut-stubs/**'
  --glob '!**/STest/**'
  --glob '!**/*TestProject*/**'
  --glob '!**/[A-Z]*Test/**'
  --glob '!**/*test_inc.h'
  --glob '!**/single_include/**'
  --glob '!**/win32/include/**'
)

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
    "${R3PLUS_GLOBS[@]}" \
    "$1" "$2" 2>/dev/null || true
}

# Strip a leading "REPO/" (or "REPO" == ".") prefix so anchors are repo-relative.
# Args: REPO  (reads file:line tokens on stdin, rewrites the path component)
strip_repo_prefix() {
  local repo="$1"
  local prefix="$repo/"
  awk -v prefix="$prefix" '
    {
      n = index($0, ":")
      if (n == 0) { print; next }
      path = substr($0, 1, n - 1)
      rest = substr($0, n)
      sub(/^\.\//, "", path)
      if (substr(path, 1, length(prefix)) == prefix) {
        path = substr(path, length(prefix) + 1)
      }
      print path rest
    }'
}

# Strip a leading "REPO/" prefix from bare path tokens (no file:line). Used for
# `rg --files` output, whose lines carry no colon. Args: REPO (paths on stdin)
strip_repo_path() {
  local repo="$1"
  local prefix="$repo/"
  awk -v prefix="$prefix" '
    {
      path = $0
      sub(/^\.\//, "", path)
      if (substr(path, 1, length(prefix)) == prefix) {
        path = substr(path, length(prefix) + 1)
      }
      print path
    }'
}

# Count C/C++ files of a given extension under REPO, excluding vendored/build
# trees, always printing a bare integer. Args: REPO EXT...
count_ext() {
  local repo="$1"
  shift
  local globs=()
  local e
  for e in "$@"; do
    globs+=(--glob "*.$e")
  done
  local n
  n="$(rg --files --no-messages \
        "${globs[@]}" \
        --glob '!**/.git/**' \
        --glob '!**/build/**' \
        --glob '!**/_deps/**' \
        --glob '!**/third_party/**' \
        --glob '!**/vendor/**' \
        --glob '!**/external/**' \
        "${R3PLUS_GLOBS[@]}" \
        "$repo" 2>/dev/null | grep -c . || true)"
  [ -n "$n" ] || n=0
  printf '%s' "$n"
}

# Comment post-filter (F5): rg emits "file:line:content"; drop rows whose content
# field, left-trimmed, begins with a doc/line-comment marker (* // /*). This is
# the SAME filter as cpp_risk_scan.sh / cpp_domain_detect.sh's drop_comment_lines
# so anchors line up across the helper family. It kills doc-comment `int main()`
# in headers (uthash/utlist.h ` * int main() {`, klib) being counted as entries.
drop_comment_lines() {
  awk -F: '
    {
      p = index($0, ":")
      if (p == 0) { print; next }
      rest = substr($0, p + 1)
      q = index(rest, ":")
      if (q == 0) { print; next }
      content = substr(rest, q + 1)
      sub(/^[ \t]+/, "", content)
      if (content ~ /^\*/)  next
      if (content ~ /^\/\//) next
      if (content ~ /^\/\*/) next
      print
    }'
}

# Dedup + cap a list of "key\tanchor" rows (F5): LC_ALL=C sort -u for determinism,
# then keep the first CAP rows and, when more existed, append a single footer row
# "... (+N more; capped)\tcapped" so output stays bounded and reproducible. cglm's
# 1511 unranked symbol-hints motivated this. Reads rows on stdin. Arg: CAP
dedup_cap() {
  local cap="$1"
  LC_ALL=C sort -u | awk -F'\t' -v cap="$cap" '
    { rows[NR] = $0; total = NR }
    END {
      shown = (total < cap ? total : cap)
      for (i = 1; i <= shown; i++) print rows[i]
      if (total > cap)
        printf "... (+%d more; capped)\tcapped\n", total - cap
    }'
}

# ---------------------------------------------------------------------------
# Section producers. Each appends "section\tkey\tanchor" lines to the buffer.
# A line is only appended when a real anchor (path or file:line) exists.
# ---------------------------------------------------------------------------

# L1 build graph & ground. ----------------------------------------------------
emit_build() {
  local repo="$1"
  local files f rel

  # Detected build systems. The anchor is the repo-relative path of the first
  # (LC_ALL=C-sorted) matching file, so the row is grounded in a real artifact.
  emit_build_system "$repo" 'CMakeLists.txt' 'cmake' \
    --glob 'CMakeLists.txt' --glob '*.cmake' --glob 'CMakePresets.json'
  emit_build_system "$repo" 'meson.build'    'meson' \
    --glob 'meson.build'
  emit_build_system "$repo" 'Makefile'       'make' \
    --glob 'Makefile' --glob 'GNUmakefile' --glob '*.mk'
  emit_build_system "$repo" 'configure'      'autotools' \
    --glob 'configure' --glob 'configure.ac' --glob 'Makefile.am'
  emit_build_system "$repo" 'BUILD/WORKSPACE' 'bazel' \
    --glob 'WORKSPACE' --glob 'WORKSPACE.bazel' --glob 'BUILD' --glob 'BUILD.bazel'

  # compile_commands.json presence (the per-TU flag database L1 depends on).
  files="$(rg --files --no-messages --glob 'compile_commands.json' \
      --glob '!**/.git/**' "$repo" 2>/dev/null | strip_repo_path "$repo" \
      | LC_ALL=C sort || true)"
  if [ -n "$files" ]; then
    rel="$(printf '%s\n' "$files" | head -n1)"
    printf 'build\tcompile_commands.json present (per-TU flag database)\t%s\n' "$rel"
  else
    printf 'build\tcompile_commands.json absent (index tools blind; generate it for L2)\tno-compile-commands\n'
  fi

  # Language breakdown (counts of each source/header extension).
  printf 'build\tlanguage breakdown: .c=%s\tcount\n'   "$(count_ext "$repo" c)"
  printf 'build\tlanguage breakdown: .cc=%s\tcount\n'  "$(count_ext "$repo" cc)"
  printf 'build\tlanguage breakdown: .cpp=%s\tcount\n' "$(count_ext "$repo" cpp)"
  printf 'build\tlanguage breakdown: .cxx=%s\tcount\n' "$(count_ext "$repo" cxx)"
  printf 'build\tlanguage breakdown: .h=%s\tcount\n'   "$(count_ext "$repo" h)"
  printf 'build\tlanguage breakdown: .hpp=%s\tcount\n' "$(count_ext "$repo" hpp)"

  # Toolchain / std hints inside build files (anchored to the line that asserts them).
  emit_std_hints "$repo"
  return 0
}

# Detect one build system. Args: REPO LABEL KIND --glob G [--glob G ...]
emit_build_system() {
  local repo="$1" label="$2" kind="$3"
  shift 3
  local files rel
  files="$(rg --files --no-messages "$@" \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      "$repo" 2>/dev/null | strip_repo_path "$repo" | LC_ALL=C sort || true)"
  if [ -n "$files" ]; then
    rel="$(printf '%s\n' "$files" | head -n1)"
    printf 'build\tbuild system detected: %s\t%s\n' "$kind" "$rel"
  fi
  return 0
}

# Toolchain/std hints found in build files (file:line anchored).
emit_std_hints() {
  local repo="$1"
  local build_globs=(
    --glob 'CMakeLists.txt' --glob '*.cmake' --glob 'CMakePresets.json'
    --glob 'meson.build' --glob 'Makefile' --glob 'GNUmakefile' --glob '*.mk'
    --glob 'configure' --glob 'configure.ac' --glob 'Makefile.am'
    --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**'
  )
  local hits
  hits="$(rg -n --no-heading --no-messages "${build_globs[@]}" \
      'CMAKE_CXX_STANDARD|CMAKE_C_STANDARD|cxx_std_|c_std_|[[:space:]]c_std[[:space:]>=:]|[[:space:]]cpp_std[[:space:]>=:]|-std=' \
      "$repo" 2>/dev/null | strip_repo_prefix "$repo" || true)"
  [ -n "$hits" ] || return 0
  local line anchor hint
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
    # N-cmphang FIX: under `set -euo pipefail`, a `grep -oE` that finds nothing
    # (e.g. a `-std=$(call ...)` Makefile where the broad rg prefilter matched but
    # the narrow `-std=[a-z0-9+]+` extractor does not) exits 1; pipefail propagates
    # that through the `| head` so the `$(...)` fails and `set -e` aborts the WHOLE
    # script BEFORE the `|| hint='std hint'` fallback below ever runs — dropping all
    # of L2 and exiting 1 (nlohmann docs/Makefile). Same brittleness class as F2's
    # `-ffast-math`. Guard the substitution with `|| true` so a no-match is benign.
    hint="$(printf '%s' "$line" \
      | grep -oE 'CMAKE_CXX_STANDARD|CMAKE_C_STANDARD|cxx_std_[0-9]+|c_std_[0-9]+|c_std|cpp_std|-std=[a-z0-9+]+' \
      | head -n1 || true)"
    [ -n "$hint" ] || hint='std hint'
    printf 'build\ttoolchain/std hint: %s\t%s\n' "$hint" "$anchor"
  done <<EOF
$hits
EOF
  return 0
}

# L2 entry points. -----------------------------------------------------------
emit_entrypoints() {
  local repo="$1"
  local hits line anchor
  # Base to re-open files at: anchors are repo-relative, so prefix with "$repo/"
  # to read the file again (for the `*_MAIN` guard walk). When repo==".", a bare
  # relative path already resolves, so use "." explicitly and keep it read-only.
  local REPO_ABS="$repo"

  # main( definitions. Match an int-returning main with an arg list, the canonical
  # C/C++ program entry; skip obvious call sites by requiring the ( open paren.
  # Comment lines are dropped (F5) so a doc-comment ` * int main() {` in a header
  # (uthash/utlist.h, klib) is not counted as an entry. A real main() that sits
  # inside a `#if(def) <NAME>_MAIN` / `<NAME>_TEST_MAIN` block is LABELED as a
  # conditional test driver (sds.c's `#ifdef SDS_TEST_MAIN`, klib's `*_MAIN`),
  # not a program entry: it only compiles when that self-test macro is defined.
  hits="$(rg_code '\bint\s+main\s*\(' "$repo" | drop_comment_lines | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    # Group the matched file:line anchors by file, then for each file walk it once
    # with awk to decide, per main() line, whether it is inside a `*_MAIN` guard.
    local files file mainlines
    files="$(printf '%s\n' "$hits" | awk -F: 'NF>=2 { print $1 }' | LC_ALL=C sort -u)"
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      # Lines (within this file) where a main() definition was matched.
      mainlines="$(printf '%s\n' "$hits" \
        | awk -F: -v f="$file" '$1 == f { print $2 }' | LC_ALL=C sort -un)"
      [ -n "$mainlines" ] || continue
      # Walk the file tracking #if/#ifdef/#ifndef nesting; when a conditional is
      # opened by a `*_MAIN`/`*_TEST_MAIN` token, remember that guard for the depth.
      # For each requested main() line, report "<line>\t<guard-or-empty>".
      awk -v want="$mainlines" '
        BEGIN {
          n = split(want, w, "\n")
          for (i = 1; i <= n; i++) if (w[i] != "") wanted[w[i] + 0] = 1
          depth = 0
          incomment = 0
        }
        {
          # Comment-block state AS OF the start of this line. A doc-comment usage
          # example with `int main()` inside a /* ... */ block (klib khash.h,
          # uthash) must NOT count as an entry: drop wanted lines that begin inside
          # an open block comment. The per-line drop_comment_lines filter upstream
          # only catches lines whose FIRST char is a comment marker, so it misses
          # these interior lines — this block-aware pass closes that gap.
          at_line_start_incomment = incomment
          # Advance the /* */ state across this line, char by char (ignore // here;
          # a // before a real main() definition is implausible).
          s = $0
          ln_len = length(s)
          k = 1
          while (k <= ln_len) {
            two = substr(s, k, 2)
            if (incomment) {
              if (two == "*/") { incomment = 0; k += 2 } else { k++ }
            } else {
              if (two == "/*") { incomment = 1; k += 2 }
              else if (two == "//") { break }
              else { k++ }
            }
          }

          # Preprocessor nesting (only meaningful outside comments). Portable
          # detection (gawk treats \b as backspace, not a word boundary), so we
          # anchor on the directive + a non-identifier char.
          stripped = $0
          sub(/^[ \t]+/, "", stripped)
          if (!at_line_start_incomment && stripped ~ /^#[ \t]*(if|ifdef|ifndef)([^A-Za-z0-9_]|$)/) {
            depth++
            g = ""
            if (match(stripped, /[A-Za-z_][A-Za-z0-9_]*(_MAIN|_TEST_MAIN|TEST_MAIN)([^A-Za-z0-9_]|$)/)) {
              g = substr(stripped, RSTART, RLENGTH)
              gsub(/[^A-Za-z0-9_]+$/, "", g)   # trim the trailing boundary char
            }
            guard[depth] = g
          } else if (!at_line_start_incomment && stripped ~ /^#[ \t]*endif([^A-Za-z0-9_]|$)/) {
            if (depth > 0) { guard[depth] = ""; depth-- }
          }
          if (wanted[FNR]) {
            if (at_line_start_incomment) next   # main() inside a /* */ doc comment
            active = ""
            for (d = 1; d <= depth; d++) if (guard[d] != "") active = guard[d]
            printf "%d\t%s\n", FNR, active
          }
        }
      ' "$REPO_ABS/$file" 2>/dev/null \
      | while IFS=$'\t' read -r ln guard; do
          [ -n "$ln" ] || continue
          if [ -n "$guard" ]; then
            printf 'entrypoint\tmain() (conditional test driver — #if %s)\t%s:%s\n' "$guard" "$file" "$ln"
          else
            printf 'entrypoint\tmain() program entry\t%s:%s\n' "$file" "$ln"
          fi
        done
    done <<EOF
$files
EOF
  fi

  # libFuzzer harness entry.
  hits="$(rg_code 'LLVMFuzzerTestOneInput' "$repo" | drop_comment_lines | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'entrypoint\tLLVMFuzzerTestOneInput fuzz harness entry\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi

  # Exported API via visibility/EXPORT/API macros (the public-symbol surface).
  # Comment lines dropped (F5); the whole symbol-hint list is deduped + capped in
  # build_map so an API-macro-per-line header lib (cglm: 1511 hits) stays bounded.
  hits="$(rg_code '__attribute__\s*\(\s*\(\s*visibility\s*\(\s*"default"|\b[A-Z][A-Z0-9_]*_(EXPORT|API)\b|\bEXPORT\b|\b__declspec\s*\(\s*dllexport' "$repo" | drop_comment_lines | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'entrypoint\texported-symbol hint (visibility/EXPORT/API macro)\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi

  # Public headers: top-level *.h and anything under include/ (the API one would
  # include). Anchor is the header path; this is a path-level entry hint.
  local headers
  headers="$(rg --files --no-messages \
      --glob 'include/**/*.{h,hh,hpp,hxx}' \
      --glob '*.{h,hh,hpp,hxx}' \
      --max-depth 1 \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      --glob '!**/third_party/**' --glob '!**/vendor/**' --glob '!**/external/**' \
      "${R3PLUS_GLOBS[@]}" \
      "$repo" 2>/dev/null | strip_repo_path "$repo" || true)"
  # rg --max-depth above bounds the top-level *.h scan; include/** is unbounded.
  local includes
  includes="$(rg --files --no-messages \
      --glob 'include/**/*.{h,hh,hpp,hxx}' \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      --glob '!**/third_party/**' --glob '!**/vendor/**' --glob '!**/external/**' \
      "${R3PLUS_GLOBS[@]}" \
      "$repo" 2>/dev/null | strip_repo_path "$repo" || true)"
  if [ -n "$includes" ]; then
    headers="$headers
$includes"
  fi
  if [ -n "$headers" ]; then
    local hdr
    while IFS= read -r hdr; do
      [ -n "$hdr" ] || continue
      printf 'entrypoint\tpublic header (library API surface)\t%s\n' "$hdr"
    done <<EOF
$headers
EOF
  fi
  return 0
}

# L2 exported API: non-static function declarations in PUBLIC headers. ---------
# This is the first thing a reviewer of a library-shaped repo needs (F5): inih's
# ini_parse / ini_parse_file / ini_parse_string, logc's log_* functions. L2 entry
# points only ever showed main() + visibility macro hints, so a library reported
# "none/weak". We scan PUBLIC, shipped headers — top-level *.h, include/**/*.h,
# and other source-tree *.h (e.g. logc's src/log.h) with tests/examples/bench/
# vendored trees excluded — and surface lines that look like a function
# DECLARATION: `<return-type ...> <identifier>(`. We walk each file (not just the
# matching line) so `/* ... */` and `//` comment interiors are stripped first,
# then keep declarations that are not `static` (internal linkage), not `typedef`
# (e.g. function-pointer typedefs `typedef int (*ini_handler)(...)`), not a
# preprocessor / macro-only line, and not a control statement. Output is the
# function name + a file:line anchor. Heuristic + conservative; deduped + capped
# upstream so an API-macro-per-line header lib (cglm) stays bounded.
#
# NOTE on portability: this awk avoids the GNU-only `\b` regex escape (gawk treats
# `\b` as backspace, not a word boundary), using explicit start-anchored keyword
# matches with a trailing non-identifier character class instead.
emit_exported_api() {
  local repo="$1"
  # Public, shipped header set: all *.h-family headers minus vendored/build trees
  # and minus non-shipped dirs (tests/examples/bench/docs), mirroring the sibling
  # scripts' exclusions so the API surface reflects shipped code. This is wider
  # than the entry-point public-header set on purpose: a single-dir vendored lib
  # keeps its API header under src/ (logc: src/log.h), which top-level+include/
  # alone would miss.
  local all
  all="$(rg --files --no-messages \
      --glob '*.{h,hh,hpp,hxx}' \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      --glob '!**/third_party/**' --glob '!**/thirdparty/**' \
      --glob '!**/vendor/**' --glob '!**/extern/**' --glob '!**/external/**' \
      --glob '!**/tests/**' --glob '!**/test/**' \
      --glob '!**/bench/**' --glob '!**/benches/**' \
      --glob '!**/benchmark/**' --glob '!**/benchmarks/**' \
      --glob '!**/examples/**' --glob '!**/example/**' \
      --glob '!**/docs/**' --glob '!**/doc/**' \
      "${R3PLUS_GLOBS[@]}" \
      "$repo" 2>/dev/null | LC_ALL=C sort -u || true)"
  [ -n "$all" ] || return 0

  # Walk each header file, strip comments, JOIN multi-line declarations into one
  # logical statement (terminated by `;`, `{`, or `}` at the top level), then emit
  # "<rank>:<file>:<line>:<name>" for each function declaration. <rank> is 0 for a
  # likely-public decl (header under include/**, or a leading/trailing export
  # macro), 1 otherwise — so the cap upstream shows public API first (R4.4). xargs
  # passes the files; FILENAME gives the path (stripped to repo-relative after).
  #
  # The extractor handles the macro/paren-wrapped declaration idioms serious C
  # libraries use (R4): a paren-wrapped name `<ret> ( <name> ) ( ... )` (Lua's
  # `LUA_API int (lua_absindex)(...)`), a leading export-macro prefix
  # `<EXPORT_MACRO> <ret> <name>(...)` (libuv `UV_EXTERN`, `LUA_API`, `*_API`,
  # `*_EXPORT`, `*_PUBLIC`), a macro-wrapped return type `MACRO(<ret>) <name>(...)`
  # (cJSON `CJSON_PUBLIC(cJSON *) cJSON_Parse(...)`), and a trailing macro suffix
  # `<ret> <name>( ... ) PRIVILEGED_FUNCTION;` (FreeRTOS, possibly multi-line). It
  # also EXCLUDES non-functions: `MBEDTLS_PRIVATE(field)` struct-field markers,
  # reserved/asm `__\w+__` tokens (`__volatile__`), and ALL-UPPERCASE/underscore
  # macro-shaped "names" (`OP`, `NAME`, `XSIMD_RVV_TYPE`, `CBRT2`) — real public C
  # API names are lowercase/mixedCase.
  printf '%s\n' "$all" \
    | xargs -d '\n' -r awk -v repo="$repo" '
        # Per-file reset. is_include: header is part of the PUBLIC surface — a
        # top-level `include/` header or a top-level header (no dir) — ranked first.
        # Per-arch / vendor BSP headers (under portable/, ports/, arch/, or a
        # NESTED include/ like portable/.../include/) are NOT the public API and
        # stay rank-1 so they do not crowd the cap (FreeRTOS card weakness #5).
        # is_cpp: a C++ header by extension (.hpp/.hh/.hxx) OR (later) a .h seen to
        # carry class/namespace/template — so a C++ `static` MEMBER function is NOT
        # dropped like a C file-scope `static` (R4.3, leveldb DB::Open). cpp_seen
        # latches once class/namespace is observed while walking the file.
        FNR == 1 {
          inblock = 0; stmt = ""; startline = 0; cpp_seen = 0
          rel = FILENAME
          sub(/^\.\//, "", rel)
          pfx = repo "/"
          if (substr(rel, 1, length(pfx)) == pfx) rel = substr(rel, length(pfx) + 1)
          # Public-include: relative path begins with `include/`, or is a top-level
          # header (no slash). Vendored/per-arch trees are excluded.
          is_include = 0
          if (rel ~ /^include\// || rel !~ /\//) is_include = 1
          if (rel ~ /(^|\/)(portable|ports|port|arch|vendor|extras)\//) is_include = 0
          is_cpp = (FILENAME ~ /\.(hpp|hh|hxx)$/) ? 1 : 0
        }
        {
          line = $0
          out = ""
          i = 1
          n = length(line)
          # Strip /* */ (incl. multi-line) and // comments char-by-char so a
          # declaration sharing a line with a trailing comment still parses, and
          # comment-interior prose never reaches the declaration test.
          while (i <= n) {
            two = substr(line, i, 2)
            if (inblock) {
              if (two == "*/") { inblock = 0; i += 2 } else { i++ }
              continue
            }
            if (two == "/*") { inblock = 1; i += 2; continue }
            if (two == "//") { break }       # rest of line is a comment
            out = out substr(line, i, 1)
            i++
          }
          # Collapse whitespace runs so the joined logical statement is uniform.
          gsub(/[ \t]+/, " ", out)
          tout = out; sub(/^ /, "", tout); sub(/ $/, "", tout)
          # Latch C++-ness for a .h header the moment a class/namespace/template
          # appears (so a later `static` member decl is treated as C++ API).
          if (!is_cpp && tout ~ /(^|[^A-Za-z0-9_])(class|namespace|template)([^A-Za-z0-9_]|$)/) {
            cpp_seen = 1
          }
          if (tout == "") next
          # Preprocessor lines are atomic: they neither start nor extend a C decl.
          # Reset any in-progress accumulation so a `#define` body cannot fuse onto
          # a following decl.
          if (tout ~ /^#/) { stmt = ""; startline = 0; next }
          # Accumulate into a logical statement; remember its FIRST line as the
          # anchor (the return-type / function-name line).
          if (stmt == "") startline = FNR
          stmt = (stmt == "" ? tout : stmt " " tout)
          # A logical statement terminates at the first `;`/`{`/`}` (a decl ends
          # with `;`; a definition opens `{`; a stray `}` closes a scope). Until
          # then keep accumulating continuation lines (multi-line decls, FreeRTOS).
          if (stmt !~ /[;{}]/) next
          # Cut at the first terminator; the cut text is the candidate declaration.
          tpos = 0; slen = length(stmt)
          for (j = 1; j <= slen; j++) {
            ch1 = substr(stmt, j, 1)
            if (ch1 == ";" || ch1 == "{" || ch1 == "}") { tpos = j; break }
          }
          c = substr(stmt, 1, tpos - 1)
          declline = startline
          stmt = ""; startline = 0          # statement consumed; reset accumulator
          sub(/^ +/, "", c); sub(/ +$/, "", c)
          if (c == "") next
          eff_cpp = (is_cpp || cpp_seen)
          # Skip obvious non-declarations.
          if (c ~ /^[}{]/) next
          # typedef (incl. fn-pointer typedefs `typedef int (*cb)(...)`): not API.
          if (c ~ /^typedef([^A-Za-z0-9_]|$)/) next
          if (c ~ /^extern "C"/) next         # `extern "C" {` linkage block opener
          # Aggregate/type definitions, not function declarations.
          if (c ~ /^(struct|union|enum|class|namespace|using)([^A-Za-z0-9_]|$)/) next
          # Control keywords / statements that can precede a "(".
          if (c ~ /^(if|for|while|switch|do|else|case|return|sizeof|catch)([^A-Za-z0-9_]|$)/) next
          if (c ~ /^\(/) next                 # leading "(" => expr / fn-ptr cast
          # `static`: C file-scope internal linkage is NOT API and is dropped — but
          # in a C++ header a `static` MEMBER function (leveldb DB::Open
          # `static Status Open(...)`, the headline entry) IS public API (R4.3). In
          # a C++ header strip the keyword so name-extraction lands on the member;
          # in a C header drop the decl.
          if (c ~ /^static([^A-Za-z0-9_]|$)/) {
            if (!eff_cpp) next
            sub(/^static[ \t]+/, "", c)
          }
          # Other C++ member specifiers that can precede a member-fn decl.
          if (eff_cpp) {
            sub(/^(virtual|explicit|constexpr|inline|friend)([ \t]+(virtual|explicit|constexpr|inline|friend))*[ \t]+/, "", c)
          }
          # Leading export-macro prefix: `UV_EXTERN int uv_run(...)`,
          # `LUA_API int (lua_absindex)(...)`, `LEVELDB_EXPORT Status DestroyDB(...)`
          # (R4.1). Strip a known/shaped export macro so the return type + name
          # follow. The macro is ALL-CAPS, an exact known name or a known export
          # suffix, and must be followed by a TYPE token (letter), NOT by `(` (that
          # is the macro-WRAPPED case below) — so a `MACRO(args)` call is not eaten.
          had_export = 0
          if (match(c, /^[A-Z][A-Za-z0-9_]*[ \t]+[A-Za-z_]/)) {
            mtok = substr(c, RSTART, RLENGTH)
            sub(/[ \t]+[A-Za-z_]$/, "", mtok)
            if (mtok == "UV_EXTERN" || mtok == "LUA_API" || mtok == "LUALIB_API" || \
                mtok == "MA_API" || mtok ~ /_API$/ || mtok ~ /_EXPORT$/ || \
                mtok ~ /_PUBLIC$/ || mtok ~ /_EXTERN$/) {
              sub(/^[A-Z][A-Za-z0-9_]*[ \t]+/, "", c); had_export = 1
            }
          }
          # Macro-wrapped return type: `CJSON_PUBLIC(cJSON *) cJSON_Parse(...)`. The
          # function name is the identifier AFTER the macro call`s close paren.
          macro_wrapped = 0
          # NB: `close` is a gawk built-in — use `closepos` for the index variable.
          if (match(c, /^[A-Z][A-Z0-9_]*[ \t]*\(/)) {
            d = 0; m = length(c); closepos = 0
            for (j = 1; j <= m; j++) {
              ch = substr(c, j, 1)
              if (ch == "(") d++
              else if (ch == ")") { d--; if (d == 0) { closepos = j; break } }
            }
            # Re-base only if a NAMED identifier+"(" follows the macro close paren;
            # otherwise (e.g. `MACRO(x);`) leave `c` as-is (it will be rejected).
            if (closepos > 0) {
              tail = substr(c, closepos + 1)
              if (tail ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) { c = tail; macro_wrapped = 1; had_export = 1 }
            }
            sub(/^[ \t]+/, "", c)
          }
          # Paren-wrapped name: `<ret> ( <name> ) ( <args> )` — Lua dodges macro
          # expansion this way (`int (lua_absindex)(...)`) (R4.1). Detect a
          # `(<identifier>)` group whose CLOSE paren is immediately followed by
          # another `(` (the arg list) and rewrite it to `<ret> <name> (` so the
          # generic extractor below lands on <name> rather than the return type.
          if (match(c, /\([ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\)[ \t]*\(/)) {
            grp = substr(c, RSTART, RLENGTH)
            gpos = RSTART
            if (match(grp, /[A-Za-z_][A-Za-z0-9_]*/)) {
              inner = substr(grp, RSTART, RLENGTH)
              c = substr(c, 1, gpos - 1) " " inner " ("
            }
          }
          paren = index(c, "(")
          if (paren == 0) next
          head = substr(c, 1, paren - 1)      # text before the first "("
          # Function name = trailing identifier of head (optionally space before "(").
          if (!match(head, /[A-Za-z_][A-Za-z0-9_]*[ \t]*$/)) next
          tok = substr(head, RSTART, RLENGTH)
          gsub(/[ \t]+/, "", tok)
          if (tok == "" || tok == "main") next
          # Reserved/asm tokens (`__volatile__`, `__attribute__`, `__asm__`),
          # double-underscore RESERVED-namespace internals (`__ieee754_rem_pio2`,
          # `__kernel_rem_pio2` — fdlibm internals, not public), and ALL-UPPERCASE/
          # underscore MACRO-shaped "names" (`MBEDTLS_PRIVATE` field markers,
          # `OP`/`NAME`/`XSIMD_RVV_TYPE`/`CBRT2` macro params/bodies) are NOT public
          # C API — real names are lowercase or mixedCase (R4.2).
          if (tok ~ /^__/) next               # leading `__`: reserved / asm token
          if (tok ~ /^[A-Z0-9_]+$/) next      # ALL-CAPS / ALL-UPPER+underscore
          # Require a return-type-ish prefix before the name (so a bare "NAME(" —
          # a macro invocation or call — is rejected). The prefix must carry a
          # word/pointer token.
          pre = substr(head, 1, RSTART - 1)
          sub(/[ \t]+$/, "", pre)
          # A bare "NAME(" with no preceding return type is a macro call/invocation,
          # NOT a declaration — UNLESS we rebased past a macro wrapper (cJSON) or
          # stripped an export macro (the macro stood in for / preceded the type).
          if (!macro_wrapped && !had_export) {
            if (pre == "") next
            if (pre !~ /[A-Za-z_*]/) next
          }
          # Whole head (return type + name) must be type-ish: identifiers, spaces,
          # pointer/ref/template/scope punctuation only. A statement / macro body
          # / assignment carries `;`, `=`, `+`, `,`, digits-as-operators etc. and
          # is rejected here — this kills `__test_num++; printf`, `x = MACRO(...)`,
          # and `struct __attribute__ ((__packed__)) name`-class lines.
          if (head !~ /^[A-Za-z_][A-Za-z0-9_ \t*:<>&~]*$/) next
          # Rank 0 = likely-public (include/** header OR an export macro present);
          # rank 1 = the rest (internal/per-arch). The cap upstream shows 0 first
          # so a repo whose internal `uv__*`/`epoll_*`/`db_impl` symbols outnumber
          # the public API still surfaces the public API (R4.4).
          rank = (is_include || had_export) ? 0 : 1
          printf "%d\t%s\t%d\t%s\n", rank, FILENAME, declline, tok
        }
      ' 2>/dev/null \
    | strip_repo_api_prefix "$repo" \
    | LC_ALL=C sort -t"$(printf '\t')" -k1,1n -k4,4 -k2,2 -k3,3n -u \
    | awk -F"$(printf '\t')" 'NF>=4 { printf "exported_api\t%s\t%s()\t%s:%d\n", $1, $4, $2, $3 }'
  return 0
}

# Strip the repo prefix from the FILENAME field (column 2) of the rank-tagged
# "rank<TAB>file<TAB>line<TAB>name" rows emitted by the exported-API awk. The
# generic strip_repo_prefix keys on the FIRST ":"; here the path is column 2 of a
# tab record, so do a tab-field-aware strip. Args: REPO (rows on stdin).
strip_repo_api_prefix() {
  local repo="$1"
  local prefix="$repo/"
  awk -F'\t' -v OFS='\t' -v prefix="$prefix" '
    NF>=4 {
      path = $2
      sub(/^\.\//, "", path)
      if (substr(path, 1, length(prefix)) == prefix) path = substr(path, length(prefix) + 1)
      $2 = path
      print
    }'
}

# L2 module map: top-level source directories with per-dir file counts. -------
emit_modules() {
  local repo="$1"
  # All C/C++ source/header files, repo-relative, vendored/build trees excluded.
  local files
  files="$(rg --files --no-messages \
      --glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx}' \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      --glob '!**/third_party/**' --glob '!**/vendor/**' --glob '!**/external/**' \
      "${R3PLUS_GLOBS[@]}" \
      "$repo" 2>/dev/null | strip_repo_path "$repo" || true)"
  [ -n "$files" ] || return 0
  # Reduce each file to its top-level component (dir, or "(root)" for top-level
  # files), count per component, emit "module\t<dir> (<n> files)\t<anchor>". The
  # input is LC_ALL=C-sorted first so the per-component "first seen" anchor is
  # deterministic: for the (root) component the anchor is a specific file, and
  # rg --files' listing order is not stable across runs (e.g. inih root flips
  # between ini.c and ini.h). Sorting fixes that so two runs byte-match.
  printf '%s\n' "$files" | LC_ALL=C sort | awk '
    {
      n = index($0, "/")
      if (n == 0) { top = "(root)"; anchor = $0 }
      else        { top = substr($0, 1, n - 1); anchor = top "/" }
      count[top]++
      if (!(top in firstanchor)) firstanchor[top] = anchor
    }
    END {
      for (t in count)
        printf "module\t%s module (%d source files)\t%s\n", t, count[t], firstanchor[t]
    }'
  return 0
}

# Per-section dedup + cap (F5). The bounded, high-volume rows are the
# "exported-symbol hint" lines (cglm: 1511) and the exported-API declarations.
# We cap those KINDS to CAP_LIST rows each (with a "... (+N more; capped)" footer)
# while leaving the inherently-few main()/fuzz/public-header rows uncapped so a
# real entry point is never truncated out of the list. Everything is LC_ALL=C
# sorted for determinism.
#
# Input/output rows are "section\tkey\tanchor". The capped KIND is selected by an
# awk regex on the key. Args: SECTION CAPPED_KEY_REGEX  (rows on stdin)
cap_section() {
  local section="$1"
  local capped_pattern="$2"
  local all
  all="$(cat)"
  [ -n "$all" ] || return 0
  # Uncapped rows (key does NOT match the capped kind): dedup + sort, kept whole.
  printf '%s\n' "$all" \
    | awk -F'\t' -v pat="$capped_pattern" 'NF>=3 && $2 !~ pat' \
    | LC_ALL=C sort -u || true
  # Capped rows (the high-volume KIND): drop section, dedup + sort + cap, re-prefix.
  printf '%s\n' "$all" \
    | awk -F'\t' -v pat="$capped_pattern" 'NF>=3 && $2 ~ pat { print $2 "\t" $3 }' \
    | dedup_cap "$CAP_LIST" \
    | awk -F'\t' -v s="$section" 'NF>=2 { print s "\t" $1 "\t" $2 }' || true
  return 0
}
CAP_LIST=40

# Rank-preserving, per-file round-robin cap for the exported-API list (R4.4).
# Input rows are 4-field "exported_api<TAB>rank<TAB>key<TAB>anchor", ALREADY sorted
# rank-first, then by name, then by file (so likely-public include/**/export-macro
# decls lead). We must NOT collapse back to a flat alphabetical cap — that is what
# buried the public API behind internal `uv__*`/`epoll_*`/`db_impl`/per-arch
# symbols, AND lets a single mega-header (FreeRTOS `mpu_prototypes.h`'s ~280
# MPU_-wrappers, libuv `os390-syscalls.h`) monopolize all 40 slots and crowd out
# the canonical `task.h`/`queue.h`/`uv.h` surface. So within each rank we round-
# robin ACROSS source files: take the 1st (alphabetical) decl of every file, then
# the 2nd of every file, ... until the cap fills. Lower rank is fully emitted
# before any higher rank. Ties broken by (rank, file, name) so two runs byte-match.
# The rank column is dropped on the way out (downstream sees normal 3-field rows);
# a "... (+N more; capped)" footer is appended when rows were truncated.
cap_exported_api() {
  local cap="$1"
  awk -F'\t' -v cap="$cap" '
    # Bucket rows by (rank, file), preserving the incoming per-file name order.
    # Track, per rank, the ordered list of its files (first-seen order, which is
    # deterministic since the input was stably sorted rank/name/file).
    NF>=4 {
      total++
      rank = $2 + 0
      split($4, ap, ":"); file = ap[1]
      gk = rank SUBSEP file
      if (!(gk in seen)) {
        seen[gk] = 1
        if (!(rank in maxrank_seen)) { maxrank_seen[rank] = 1; ranks[++nranks] = rank }
        files[rank, ++nfiles[rank]] = file
      }
      grp[gk, ++cnt[gk]] = $1 "\t" $3 "\t" $4
    }
    END {
      # Emit lower ranks first (rank 0 = likely-public, fully before rank 1). Sort
      # the seen ranks ascending (typically just {0,1}).
      for (a = 1; a <= nranks; a++)
        for (b = a + 1; b <= nranks; b++)
          if (ranks[b] < ranks[a]) { t = ranks[a]; ranks[a] = ranks[b]; ranks[b] = t }
      shown = 0
      for (r = 1; r <= nranks && shown < cap; r++) {
        rank = ranks[r]
        # max per-file depth within this rank
        maxd = 0
        for (i = 1; i <= nfiles[rank]; i++) { gk = rank SUBSEP files[rank, i]; if (cnt[gk] > maxd) maxd = cnt[gk] }
        # round-robin: depth-th decl of every file in this rank, then depth+1, ...
        for (depth = 1; depth <= maxd && shown < cap; depth++) {
          for (i = 1; i <= nfiles[rank] && shown < cap; i++) {
            gk = rank SUBSEP files[rank, i]
            if (depth <= cnt[gk]) { print grp[gk, depth]; shown++ }
          }
        }
      }
      if (total > shown)
        printf "exported_api\t... (+%d more; capped)\tcapped\n", total - shown
    }'
  return 0
}

# ---------------------------------------------------------------------------
# Map assembly: gather rows, dedupe build/entry rows, sort deterministically.
# Module rows are already unique per top-level dir. Entry-point symbol hints and
# the exported-API list are deduped + capped (F5) so output stays bounded.
# ---------------------------------------------------------------------------
build_map() {
  local repo="$1"
  local section="$2"
  case "$section" in
    build)
      emit_build "$repo" | awk 'NF' | LC_ALL=C sort -u ;;
    entrypoint)
      # Cap only the symbol-hint KIND; main()/fuzz/public-header rows are kept.
      emit_entrypoints "$repo" | awk 'NF' \
        | cap_section entrypoint '^exported-symbol hint' ;;
    exported_api)
      # Rank-preserving cap: rows arrive rank-first (public API leads); cap without
      # re-sorting so the public surface is never buried behind internals (R4.4).
      emit_exported_api "$repo" | awk 'NF' \
        | cap_exported_api "$CAP_LIST" ;;
    module)
      emit_modules "$repo" | awk 'NF' | LC_ALL=C sort -u ;;
  esac
}

# Render one section's rows as "key | anchor", except the cap footer row
# (anchor == "capped") which prints just its key. Reads rows on stdin.
render_rows() {
  awk -F'\t' 'NF>=3 {
    if ($3 == "capped") { print $2 }
    else                { printf "%s | %s\n", $2, $3 }
  }'
}

emit_text() {
  # tab-separated section/key/anchor -> grouped, human-readable map.
  local repo="$1"
  printf '## L1 build graph & ground\n'
  build_map "$repo" build | awk -F'\t' 'NF>=3 { printf "%s | %s\n", $2, $3 }'
  printf '\n## L2 exported API (non-static decls in public headers)\n'
  local ea
  ea="$(build_map "$repo" exported_api)"
  if [ -n "$ea" ]; then
    printf '%s\n' "$ea" | render_rows
  else
    printf 'none detected\n'
  fi
  printf '\n## L2 entry points\n'
  local ep
  ep="$(build_map "$repo" entrypoint)"
  if [ -n "$ep" ]; then
    printf '%s\n' "$ep" | render_rows
  else
    printf 'none detected\n'
  fi
  printf '\n## L2 module map\n'
  local mm
  mm="$(build_map "$repo" module)"
  if [ -n "$mm" ]; then
    printf '%s\n' "$mm" | awk -F'\t' 'NF>=3 { printf "%s | %s\n", $2, $3 }'
  else
    printf 'none detected\n'
  fi
}

emit_json() {
  # tab-separated section rows -> a stable object with arrays
  # {build, exported_api, entrypoints, modules} of {key, anchor}. Sections are
  # collected into per-section buckets and emitted in fixed order so the shape is
  # always present (empty arrays when a section had no rows).
  local repo="$1"
  {
    build_map "$repo" build        | awk -F'\t' 'NF>=3 { print "build\t" $2 "\t" $3 }'
    build_map "$repo" exported_api | awk -F'\t' 'NF>=3 { print "exported_api\t" $2 "\t" $3 }'
    build_map "$repo" entrypoint   | awk -F'\t' 'NF>=3 { print "entrypoint\t" $2 "\t" $3 }'
    build_map "$repo" module       | awk -F'\t' 'NF>=3 { print "module\t" $2 "\t" $3 }'
  } | awk -F'\t' '
    function esc(s,   r) {
      r = s
      gsub(/\\/, "\\\\", r)
      gsub(/"/, "\\\"", r)
      return r
    }
    { sec = $1; n[sec]++; key[sec, n[sec]] = $2; anchor[sec, n[sec]] = $3 }
    function emit_arr(jsonname, sec,   i) {
      printf "  \"%s\": [", jsonname
      for (i = 1; i <= n[sec]; i++) {
        if (i > 1) printf ","
        printf "\n    {\"key\": \"%s\", \"anchor\": \"%s\"}", esc(key[sec, i]), esc(anchor[sec, i])
      }
      if (n[sec] > 0) printf "\n  "
      printf "]"
    }
    END {
      printf "{\n"
      emit_arr("build", "build");               printf ",\n"
      emit_arr("exported_api", "exported_api"); printf ",\n"
      emit_arr("entrypoints", "entrypoint");    printf ",\n"
      emit_arr("modules", "module")
      printf "\n}\n"
    }'
}

run_map() {
  local repo="$1"
  local json="$2"
  if [ ! -d "$repo" ]; then
    printf 'error: not a directory: %s\n' "$repo" >&2
    exit 2
  fi
  if ! rg_available; then
    printf 'error: rg (ripgrep) is required for cpp_comprehension_map.sh\n' >&2
    exit 3
  fi
  if [ "$json" = yes ]; then
    emit_json "$repo"
  else
    emit_text "$repo"
  fi
}

# ---------------------------------------------------------------------------
# Self-test: build a tiny fake repo, prove the build system / main / fuzz entry
# / module dirs are detected, prove two consecutive runs byte-match and no
# absolute path leaks. Cleans up via trap.
# ---------------------------------------------------------------------------
self_test() {
  if ! rg_available; then
    printf 'cpp_comprehension_map self-test: FAIL (rg not available)\n'
    exit 1
  fi
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  mkdir -p "$tmp/app" "$tmp/fuzz" "$tmp/lib" "$tmp/include"
  cat >"$tmp/CMakeLists.txt" <<'CM'
cmake_minimum_required(VERSION 3.16)
project(fake C)
set(CMAKE_C_STANDARD 11)
add_executable(fake app/main.c lib/util.c)
CM
  # N-cmphang FIX fixture: a Makefile whose std flag is computed via a `$(call ...)`,
  # so the broad std-hint rg prefilter matches `-std=` but the narrow `grep -oE
  # '-std=[a-z0-9+]+'` extractor finds nothing (the next char is `$`) and `grep`
  # exits 1. Before the `|| true` guard, `set -euo pipefail` aborted the WHOLE script
  # right there, dropping all of L2 and exiting 1 (nlohmann/json docs/Makefile). With
  # the guard the run must reach exit 0 and still emit the L2 sections below.
  mkdir -p "$tmp/docs"
  cat >"$tmp/docs/Makefile" <<'MK'
CXXSTD = -std=$(call detect_std,c++17)
all:
	$(CXX) $(CXXSTD) -o demo demo.cpp
MK
  cat >"$tmp/app/main.c" <<'SRC'
#include "util.h"
int main(int argc, char **argv) {
    return util_run(argc);
}
SRC
  cat >"$tmp/fuzz/t.c" <<'SRC'
#include <stddef.h>
#include <stdint.h>
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    return (int)(size ? data[0] : 0);
}
SRC
  cat >"$tmp/lib/util.c" <<'SRC'
#include "util.h"
int util_run(int n) { return n + 1; }
SRC
  cat >"$tmp/include/util.h" <<'SRC'
#ifndef UTIL_H
#define UTIL_H
/* Public API. Usage example (a doc comment, NOT an entry point):
   int main(void) {
       return util_run(0);
   }
*/
typedef int (*util_cb)(int n);       /* fn-pointer typedef: not exported API */
int util_run(int n);                 /* exported API */
const char *util_name(void);         /* exported API */
static int util_helper(int n);       /* internal linkage: not exported API */
LIBUTIL_API(int) util_open(const char *path);  /* macro-WRAPPED exported API (cJSON-style) */
/* R4.1 macro/paren-wrapped declaration idioms: */
LUA_API int   (util_absindex) (int idx);        /* paren-wrapped name (Lua idiom) */
UV_EXTERN int util_run_mode(int mode);           /* leading export MACRO prefix (libuv) */
UTIL_API const char *util_strerror(int e);       /* *_API export prefix */
int util_create( int a,
                 int b ) UTIL_PRIVILEGED;         /* multi-line + trailing macro suffix (FreeRTOS) */
/* R4.2 macro noise / reserved tokens that must NOT be surfaced as API: */
int marker UTIL_PRIVATE(field);                  /* struct-field name-mangler, not a function */
#define UTIL_OP(x) __asm__ __volatile__("nop")   /* macro body w/ asm token (preprocessor: ignored) */
#endif
SRC
  # A vendored-style single-TU lib whose main() lives behind a *_MAIN self-test
  # guard (sds.c / klib pattern): it must be LABELED a conditional test driver,
  # NOT a program entry. Also a real main() in app/ above stays a program entry.
  cat >"$tmp/lib/selftest.c" <<'SRC'
#include "util.h"
int util_run(int n) { return n + 1; }
#ifdef SELFTEST_MAIN
int main(void) {
    return util_run(0);
}
#endif
SRC
  # A C++ public header (R4.3): a `static` MEMBER function in a class is public
  # API (leveldb `DB::Open`) and must NOT be dropped like a C file-scope `static`.
  # A bare C-style file-scope `static` (in a .h with no class) still IS dropped —
  # but here the file carries a class, so the latch treats statics as members.
  cat >"$tmp/include/db.hpp" <<'SRC'
#ifndef DB_HPP
#define DB_HPP
namespace fake {
class Database {
 public:
  static Status DbOpen(const char *name);   /* C++ static MEMBER fn: public API */
  Status Put(const char *k, const char *v); /* ordinary member */
};
}  // namespace fake
#endif
SRC
  # A header carrying many distinct visibility/EXPORT-macro hint lines so the
  # entry-point symbol-hint list exceeds the cap and the "... (+N more; capped)"
  # footer fires. These are exported VARIABLES (no `name(` decl), so they inflate
  # only the symbol-hint list, not the exported-API list (keeping that list under
  # cap so the util_* API assertions below are not truncated out).
  {
    printf '#ifndef MANY_H\n#define MANY_H\n'
    local k
    for k in $(seq 1 60); do
      printf '__attribute__((visibility("default"))) extern int many_var_%02d;\n' "$k"
    done
    printf '#endif\n'
  } >"$tmp/include/many.h"
  # R3+ FIX fixture: a generated `single_include/` amalgamation that MIRRORS the
  # public `include/` API (the nlohmann/json case). It declares the SAME functions
  # as include/util.h; without the `single_include/` exclusion the exported-API list
  # double-lists every decl and the module map gains a spurious `single_include`
  # module. The R3+ glob must drop it while keeping the real `include/` surface.
  mkdir -p "$tmp/single_include/fake"
  cat >"$tmp/single_include/fake/amalgam.h" <<'SRC'
#ifndef AMALGAM_H
#define AMALGAM_H
/* GENERATED amalgamation — do not edit. Mirror of include/. */
int util_run(int n);                 /* duplicate of the include/ decl */
const char *util_name(void);         /* duplicate of the include/ decl */
#endif
SRC

  local out1 out2 run_rc
  # Capture the exit code: N-cmphang regressed by aborting (exit 1) mid-run, so the
  # self-test must assert a clean exit, not just inspect the (partial) output. `|| rc`
  # keeps `set -e` from killing the test if run_map ever exits non-zero again.
  out1="$(run_map "$tmp" no)" && run_rc=0 || run_rc=$?

  # N-cmphang: the run MUST exit 0 even though docs/Makefile carries `-std=$(call ...)`.
  if [ "$run_rc" -ne 0 ]; then
    printf 'cpp_comprehension_map self-test: FAIL (N-cmphang: run aborted with exit %s on a -std=$(call) Makefile)\n' "$run_rc"
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # N-cmphang: ALL FOUR L2 sections must be present (the abort dropped everything
  # after L1). Assert the exported-API + entry-points + module-map headers exist.
  local sec
  for sec in '## L1 build graph & ground' '## L2 exported API' '## L2 entry points' '## L2 module map'; do
    if ! printf '%s\n' "$out1" | grep -qF "$sec"; then
      printf 'cpp_comprehension_map self-test: FAIL (N-cmphang: section "%s" missing — L2 dropped)\n' "$sec"
      printf '%s\n%s\n' '--- map ---' "$out1"
      exit 1
    fi
  done

  # Assertion 1: the CMake build system is detected, anchored to CMakeLists.txt.
  if ! printf '%s\n' "$out1" | grep -q 'build system detected: cmake | CMakeLists.txt'; then
    printf 'cpp_comprehension_map self-test: FAIL (cmake build system not detected)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # Assertion 2: the std hint from the build file is detected.
  if ! printf '%s\n' "$out1" | grep -qE 'toolchain/std hint: CMAKE_C_STANDARD \| CMakeLists\.txt:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (CMAKE_C_STANDARD std hint not detected)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # Assertion 3: the main() entry point is detected, anchored to app/main.c.
  if ! printf '%s\n' "$out1" | grep -qE 'main\(\) program entry \| app/main\.c:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (main entry point not detected)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # Assertion 4: the fuzz entry point is detected, anchored to fuzz/t.c.
  if ! printf '%s\n' "$out1" | grep -qE 'LLVMFuzzerTestOneInput fuzz harness entry \| fuzz/t\.c:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (fuzz entry point not detected)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # Assertion 5: the module dirs (app, fuzz, lib, include) are all detected.
  local mod
  for mod in app fuzz lib include; do
    if ! printf '%s\n' "$out1" | grep -qE "^${mod} module \([0-9]+ source files\) \| ${mod}/"; then
      printf 'cpp_comprehension_map self-test: FAIL (module dir %s not detected)\n' "$mod"
      printf '%s\n%s\n' '--- map ---' "$out1"
      exit 1
    fi
  done
  # Assertion 6 (no absolute paths leak): output must not contain the temp dir.
  if printf '%s\n' "$out1" | grep -qF "$tmp"; then
    printf 'cpp_comprehension_map self-test: FAIL (absolute path leaked into output)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # Assertion 7: reproducibility - two consecutive runs byte-match.
  out2="$(run_map "$tmp" no)"
  if [ "$out1" != "$out2" ]; then
    printf 'cpp_comprehension_map self-test: FAIL (two runs did not byte-match)\n'
    diff <(printf '%s\n' "$out1") <(printf '%s\n' "$out2") || true
    exit 1
  fi

  # Assertion 8: JSON mode emits the {build, entrypoints, modules} object and
  # carries the same anchors, with no absolute path leak.
  local js
  js="$(run_map "$tmp" yes)"
  case "$js" in
    \{*\}) : ;;
    *)
      printf 'cpp_comprehension_map self-test: FAIL (JSON mode did not emit an object)\n'
      printf '%s\n%s\n' '--- json ---' "$js"
      exit 1
      ;;
  esac
  local key
  for key in '"build"' '"exported_api"' '"entrypoints"' '"modules"' 'app/main.c' 'fuzz/t.c'; do
    if ! printf '%s\n' "$js" | grep -qF "$key"; then
      printf 'cpp_comprehension_map self-test: FAIL (JSON missing %s)\n' "$key"
      printf '%s\n%s\n' '--- json ---' "$js"
      exit 1
    fi
  done
  if printf '%s\n' "$js" | grep -qF "$tmp"; then
    printf 'cpp_comprehension_map self-test: FAIL (absolute path leaked into JSON)\n'
    printf '%s\n%s\n' '--- json ---' "$js"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # F5 assertions: exported-API surfacing, conditional-test-driver labeling,
  # comment/static/typedef exclusion, macro-wrapped decls, and dedup+cap.
  # -------------------------------------------------------------------------
  # F5.1: a non-static function decl in a public header is surfaced as exported
  # API, anchored to the header file:line.
  if ! printf '%s\n' "$out1" | grep -qE '^util_run\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: exported API util_run not surfaced)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  if ! printf '%s\n' "$out1" | grep -qE '^util_name\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: exported API util_name not surfaced)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # F5.1b: a macro-wrapped declaration (LIBUTIL_API int util_open(...)) is surfaced
  # by its real function name, not the wrapping macro (the cJSON CJSON_PUBLIC case).
  if ! printf '%s\n' "$out1" | grep -qE '^util_open\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: macro-wrapped util_open not surfaced)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # F5.1c: static (internal linkage) and typedef (fn-pointer) decls are NOT API.
  if printf '%s\n' "$out1" | grep -qE '^util_helper\(\) \|'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: static util_helper leaked into exported API)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  if printf '%s\n' "$out1" | grep -qE '^util_cb\(\) \|'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: fn-pointer typedef util_cb leaked into exported API)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # R4 assertions: macro/paren-wrapped declaration idioms, macro-noise/reserved
  # token exclusion, C++ static member functions, and public-first ranking.
  # -------------------------------------------------------------------------
  # R4.1a: a paren-wrapped name `LUA_API int (util_absindex)(...)` (the Lua idiom)
  # surfaces as `util_absindex`, NOT `int()` (the return type).
  if ! printf '%s\n' "$out1" | grep -qE '^util_absindex\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.1: paren-wrapped name util_absindex not surfaced — Lua idiom)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  if printf '%s\n' "$out1" | grep -qE '^int\(\) \| include/util\.h:'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.1: return type `int()` leaked instead of the function name)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.1b: a leading export-MACRO prefix `UV_EXTERN int util_run_mode(...)` (libuv)
  # surfaces by the real name, not the macro/return type.
  if ! printf '%s\n' "$out1" | grep -qE '^util_run_mode\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.1: export-macro-prefixed util_run_mode not surfaced — libuv UV_EXTERN idiom)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.1b2: a `*_API` export prefix `UTIL_API const char *util_strerror(...)`.
  if ! printf '%s\n' "$out1" | grep -qE '^util_strerror\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.1: *_API-prefixed util_strerror not surfaced)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.1c: a multi-line declaration with a trailing macro suffix
  # `int util_create( ...\n... ) UTIL_PRIVILEGED;` (FreeRTOS PRIVILEGED_FUNCTION)
  # surfaces by name; the trailing macro does not derail extraction.
  if ! printf '%s\n' "$out1" | grep -qE '^util_create\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.1: multi-line + trailing-macro util_create not surfaced — FreeRTOS idiom)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.2a: a `UTIL_PRIVATE(field)` struct-field name-mangler (mbedtls MBEDTLS_PRIVATE)
  # is NOT a function and must NOT be surfaced as exported API.
  if printf '%s\n' "$out1" | grep -qE '^UTIL_PRIVATE\(\) \|'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.2: UTIL_PRIVATE field marker leaked as exported API — MBEDTLS_PRIVATE case)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.2b: reserved/asm tokens (`__volatile__`) and ALL-CAPS macro-shaped names
  # (`OP`/`NAME`/`UTIL_OP`) are not API and must not appear.
  if printf '%s\n' "$out1" | grep -qE '^(__volatile__|UTIL_OP|OP|NAME)\(\) \|'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.2: reserved/asm or ALL-CAPS macro token leaked as exported API)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.3: a C++ `static` MEMBER function in a public C++ header (leveldb DB::Open)
  # is public API and must be surfaced; the C `static` filter must not drop it.
  if ! printf '%s\n' "$out1" | grep -qE '^DbOpen\(\) \| include/db\.hpp:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.3: C++ static member DbOpen dropped — leveldb DB::Open case)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R4.3b: an ordinary C++ member function still surfaces (no over-correction).
  if ! printf '%s\n' "$out1" | grep -qE '^Put\(\) \| include/db\.hpp:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R4.3: ordinary C++ member Put not surfaced)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi

  # F5.2: a doc-comment `int main()` inside a /* */ block in include/util.h must
  # NOT be reported as a program entry.
  if printf '%s\n' "$out1" | grep -qE 'main\(\).*\| include/util\.h:'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: doc-comment main() in header counted as entry)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # F5.2b: main() behind a *_MAIN self-test guard is LABELED a conditional test
  # driver naming the guard, NOT a plain program entry.
  if ! printf '%s\n' "$out1" | grep -qE 'main\(\) \(conditional test driver — #if SELFTEST_MAIN\) \| lib/selftest\.c:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: guarded main not labeled conditional test driver)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # F5.2c: the REAL main() in app/main.c is STILL a program entry (no regression).
  if ! printf '%s\n' "$out1" | grep -qE '^main\(\) program entry \| app/main\.c:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: real program entry mislabeled/lost)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # F5.2d: the guarded main must NOT also appear as a plain program entry.
  if printf '%s\n' "$out1" | grep -qE '^main\(\) program entry \| lib/selftest\.c:'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: guarded main also reported as program entry)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # F5.3: the symbol-hint list exceeds the cap and is bounded by a footer.
  local hintcount
  # `grep -c` exits 1 when the count is 0; under `set -e` that would abort the
  # self-test on a zero-hint tree (same pipefail-abort class as N-cmphang). Guard it.
  hintcount="$(printf '%s\n' "$out1" | grep -c 'exported-symbol hint' || true)"
  if [ "$hintcount" -gt "$CAP_LIST" ]; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: symbol-hint list not capped: %s > %s)\n' "$hintcount" "$CAP_LIST"
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  if ! printf '%s\n' "$out1" | grep -qE '^\.\.\. \(\+[0-9]+ more; capped\)$'; then
    printf 'cpp_comprehension_map self-test: FAIL (F5: cap footer missing for over-cap list)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi

  # R3+: the generated single_include/ amalgamation must be EXCLUDED — no anchor may
  # point into it (no double-listed API, no spurious module), while the real
  # include/ API surface is preserved (util_run/util_name from include/util.h).
  if printf '%s\n' "$out1" | grep -qE 'single_include/'; then
    printf 'cpp_comprehension_map self-test: FAIL (R3+: single_include/ amalgamation leaked into the map)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  if printf '%s\n' "$out1" | grep -qE '^single_include module '; then
    printf 'cpp_comprehension_map self-test: FAIL (R3+: single_include listed as a module)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi
  # R3+ no over-correction: the REAL include/ public API is still surfaced.
  if ! printf '%s\n' "$out1" | grep -qE '^util_run\(\) \| include/util\.h:[0-9]+'; then
    printf 'cpp_comprehension_map self-test: FAIL (R3+ over-correction: real include/ API util_run dropped)\n'
    printf '%s\n%s\n' '--- map ---' "$out1"
    exit 1
  fi

  printf 'cpp_comprehension_map self-test: PASS\n'
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

  repo="${repo%/}"
  [ -n "$repo" ] || repo="."

  run_map "$repo" "$json"
}

main "$@"
