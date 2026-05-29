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
    hint="$(printf '%s' "$line" \
      | grep -oE 'CMAKE_CXX_STANDARD|CMAKE_C_STANDARD|cxx_std_[0-9]+|c_std_[0-9]+|c_std|cpp_std|-std=[a-z0-9+]+' \
      | head -n1)"
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
      "$repo" 2>/dev/null | strip_repo_path "$repo" || true)"
  # rg --max-depth above bounds the top-level *.h scan; include/** is unbounded.
  local includes
  includes="$(rg --files --no-messages \
      --glob 'include/**/*.{h,hh,hpp,hxx}' \
      --glob '!**/.git/**' --glob '!**/build/**' --glob '!**/_deps/**' \
      --glob '!**/third_party/**' --glob '!**/vendor/**' --glob '!**/external/**' \
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
      "$repo" 2>/dev/null | LC_ALL=C sort -u || true)"
  [ -n "$all" ] || return 0

  # Walk each header file, strip comments, emit "<file>:<line>:<name>" for each
  # non-static function declaration. xargs passes the files; FILENAME gives the
  # path (stripped to repo-relative afterward).
  printf '%s\n' "$all" \
    | xargs -d '\n' -r awk '
        FNR == 1 { inblock = 0 }    # reset block-comment state per file
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
          c = out
          sub(/^[ \t]+/, "", c)              # left-trim
          if (c == "") next
          # Skip preprocessor, braces, and obvious non-declarations.
          if (c ~ /^#/) next
          if (c ~ /^[}{]/) next
          # static (internal linkage) / typedef (incl. fn-pointer typedefs):
          # start-anchored keyword followed by a non-identifier char (portable
          # word-boundary; avoids gawk-only \b).
          if (c ~ /^static([^A-Za-z0-9_]|$)/)  next
          if (c ~ /^typedef([^A-Za-z0-9_]|$)/) next
          if (c ~ /^extern[ \t]+"C"/) next    # `extern "C" {` linkage block opener
          # Aggregate/type definitions, not function declarations.
          if (c ~ /^(struct|union|enum|class|namespace|using)([^A-Za-z0-9_]|$)/) next
          # Control keywords / statements that can precede a "(".
          if (c ~ /^(if|for|while|switch|do|else|case|return|sizeof|catch)([^A-Za-z0-9_]|$)/) next
          if (c ~ /^\(/) next                 # leading "(" => expr / fn-ptr cast
          # Macro-wrapped declaration idiom: a return type wrapped in an
          # ALL-CAPS export macro, e.g. cJSON `CJSON_PUBLIC(cJSON *) cJSON_Parse(`.
          # The real function name is the identifier AFTER the macro call`s close
          # paren. Detect a leading `UPPER_MACRO( ... )` and re-base `c` past it so
          # the generic name-extraction below lands on the function, not the macro.
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
              if (tail ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) { c = tail; macro_wrapped = 1 }
            }
            sub(/^[ \t]+/, "", c)
          }
          paren = index(c, "(")
          if (paren == 0) next
          head = substr(c, 1, paren - 1)      # text before the first "("
          # Function name = trailing identifier of head (optionally space before "(").
          if (!match(head, /[A-Za-z_][A-Za-z0-9_]*[ \t]*$/)) next
          tok = substr(head, RSTART, RLENGTH)
          gsub(/[ \t]+/, "", tok)
          if (tok == "" || tok == "main" || tok == "__attribute__") next
          # Require a return-type-ish prefix before the name (so a bare "NAME(" —
          # a macro invocation or call — is rejected). The prefix must carry a
          # word/pointer token.
          pre = substr(head, 1, RSTART - 1)
          sub(/[ \t]+$/, "", pre)
          # A bare "NAME(" with no preceding return type is a macro call/invocation,
          # NOT a declaration — UNLESS we rebased past a macro wrapper (cJSON), where
          # the macro WAS the return type and an empty prefix is expected.
          if (!macro_wrapped) {
            if (pre == "") next
            if (pre !~ /[A-Za-z_*]/) next
          }
          # Whole head (return type + name) must be type-ish: identifiers, spaces,
          # pointer/ref/template/scope punctuation only. A statement / macro body
          # / assignment carries `;`, `=`, `+`, `,`, digits-as-operators etc. and
          # is rejected here — this kills `__test_num++; printf`, `x = MACRO(...)`,
          # and `struct __attribute__ ((__packed__)) name`-class lines.
          if (head !~ /^[A-Za-z_][A-Za-z0-9_ \t*:<>&~]*$/) next
          printf "%s:%d:%s\n", FILENAME, FNR, tok
        }
      ' 2>/dev/null \
    | strip_repo_prefix "$repo" \
    | awk -F: 'NF>=3 { printf "exported_api\t%s()\t%s:%s\n", $3, $1, $2 }'
  return 0
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
      # The whole exported-API list is one KIND; cap all of it (key matches '.').
      emit_exported_api "$repo" | awk 'NF' \
        | cap_section exported_api '.' ;;
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

  local out1 out2
  out1="$(run_map "$tmp" no)"

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
  hintcount="$(printf '%s\n' "$out1" | grep -c 'exported-symbol hint')"
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
