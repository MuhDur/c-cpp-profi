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

  # main( definitions. Match an int-returning main with an arg list, the canonical
  # C/C++ program entry; skip obvious call sites by requiring the ( open paren.
  hits="$(rg_code '\bint\s+main\s*\(' "$repo" | strip_repo_prefix "$repo")"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      anchor="$(printf '%s' "$line" | cut -d: -f1-2)"
      printf 'entrypoint\tmain() program entry\t%s\n' "$anchor"
    done <<EOF
$hits
EOF
  fi

  # libFuzzer harness entry.
  hits="$(rg_code 'LLVMFuzzerTestOneInput' "$repo" | strip_repo_prefix "$repo")"
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
  hits="$(rg_code '__attribute__\s*\(\s*\(\s*visibility\s*\(\s*"default"|\b[A-Z][A-Z0-9_]*_(EXPORT|API)\b|\bEXPORT\b|\b__declspec\s*\(\s*dllexport' "$repo" | strip_repo_prefix "$repo")"
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
  # files), count per component, emit "module\t<dir> (<n> files)\t<anchor>".
  printf '%s\n' "$files" | awk '
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

# ---------------------------------------------------------------------------
# Map assembly: gather rows, dedupe build/entry rows, sort deterministically.
# Module rows are already unique per top-level dir.
# ---------------------------------------------------------------------------
build_map() {
  local repo="$1"
  local section="$2"
  case "$section" in
    build)      emit_build "$repo"       | awk 'NF' | LC_ALL=C sort -u ;;
    entrypoint) emit_entrypoints "$repo" | awk 'NF' | LC_ALL=C sort -u ;;
    module)     emit_modules "$repo"     | awk 'NF' | LC_ALL=C sort -u ;;
  esac
}

emit_text() {
  # tab-separated section/key/anchor -> grouped, human-readable map.
  local repo="$1"
  printf '## L1 build graph & ground\n'
  build_map "$repo" build | awk -F'\t' 'NF>=3 { printf "%s | %s\n", $2, $3 }'
  printf '\n## L2 entry points\n'
  local ep
  ep="$(build_map "$repo" entrypoint)"
  if [ -n "$ep" ]; then
    printf '%s\n' "$ep" | awk -F'\t' 'NF>=3 { printf "%s | %s\n", $2, $3 }'
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
  # tab-separated section rows -> {build, entrypoints, modules} of {key,anchor}.
  local repo="$1"
  {
    build_map "$repo" build      | awk -F'\t' 'NF>=3 { print "build\t" $2 "\t" $3 }'
    build_map "$repo" entrypoint | awk -F'\t' 'NF>=3 { print "entrypoint\t" $2 "\t" $3 }'
    build_map "$repo" module     | awk -F'\t' 'NF>=3 { print "module\t" $2 "\t" $3 }'
  } | awk -F'\t' '
    function esc(s,   r) {
      r = s
      gsub(/\\/, "\\\\", r)
      gsub(/"/, "\\\"", r)
      return r
    }
    function open_arr(name) { printf "  \"%s\": [", name; first = 1 }
    function row() {
      if (!first) printf ","
      first = 0
      printf "\n    {\"key\": \"%s\", \"anchor\": \"%s\"}", esc($2), esc($3)
    }
    function close_arr() { if (!first) printf "\n  "; printf "]" }
    BEGIN { printf "{\n"; open_arr("build"); section = "build" }
    {
      if ($1 != section) {
        close_arr(); printf ",\n"
        if ($1 == "entrypoint") open_arr("entrypoints")
        else                    open_arr("modules")
        section = $1
      }
      row()
    }
    END {
      close_arr()
      # Emit any still-unopened sections as empty arrays so the shape is stable.
      if (section == "build")      { printf ",\n"; open_arr("entrypoints"); close_arr(); printf ",\n"; open_arr("modules"); close_arr() }
      else if (section == "entrypoint") { printf ",\n"; open_arr("modules"); close_arr() }
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
int util_run(int n);
#endif
SRC

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
  for key in '"build"' '"entrypoints"' '"modules"' 'app/main.c' 'fuzz/t.c'; do
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
