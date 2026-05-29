#!/usr/bin/env bash
set -u

# Targets default to "." and are populated from "$@" by main(); --self-test runs
# against synthetic fixtures instead. detect_cpp()/run_check() read this global.
targets=(.)

if ! command -v rg >/dev/null 2>&1; then
  printf 'error: rg is required for cpp_risk_scan.sh\n' >&2
  exit 3
fi

# Shared exclusions: vendored/build trees AND non-shipped dirs (tests, benches,
# examples, docs, vendored split-copies / 3rd-party decoders under extras/). These
# inflate the risk surface with code that never ships (F7/R3). Path-segment globs
# alone miss suffix-named tests (leveldb db_test.cc, re2 parse_test.cc), the
# `testing/` gerund (re2), `extras/` (miniaudio's split copy + vendored decoders),
# and flat-root harnesses (lua ltests.*) — all added below (R3). The split between
# shipped library code and test/bench harnesses is made explicit in the [scope]
# banner. The same array drives detect_cpp() so the C++ signal is computed over
# exactly the shipped surface that is scanned (R1).
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
  # R10: vendored *runtime* deps + generated amalgam/aux trees that the
  # `_deps/`/`third_party/`/`vendor/` set missed (kept identical to the sibling
  # scripts so anchors line up): bare `deps/` (redis bundles hiredis/lua/jemalloc;
  # 2297/6599 of redis's risk hits lived there), `dependencies/` (simdjson bench
  # deps), the `singleheader/` generated amalgam (simdjson — alongside the existing
  # `single_include/`), `autosetup/` + the `jimsh0.c` bootstrap Jim-Tcl amalgam
  # (sqlite — 138 vendored risk hits), and OSS-Fuzz `fuzz/`/`fuzzing/` harness dirs
  # (libjpeg `fuzz/*.cc` decoders flipped the C++ signal and added codec noise). The
  # backlog test-fuzz lane still finds harnesses via its own explicit `**/fuzz/**`.
  --glob '!**/deps/**'
  --glob '!**/dependencies/**'
  --glob '!**/singleheader/**'
  --glob '!**/fuzz/**'
  --glob '!**/fuzzing/**'
  --glob '!**/autosetup/**'
  --glob '!**/jimsh0.c'
  # R11: vendored-framework excludes anchored to VENDORED LOCATIONS only — the bare
  # `!**/catch2/**`/`!**/catch.hpp`/`!**/unity*`/`!**/utest.h`/`!**/gtest|gmock`
  # globs excluded the framework's OWN shipped source when the repo IS that framework
  # (Catch2's `src/catch2/`, 289 files, were never risk-scanned → falsely-empty
  # new/delete + cast lanes while 8 reinterpret_cast + ~48 alloc/cast sites sat
  # unscanned). Anchored to a vendored parent they drop only embedded copies.
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/unity*'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/utest.h'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/catch.hpp'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/catch2/**'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/gtest/**'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/gmock/**'
  # Suffix-named test/bench files (Google/Abseil style co-locate tests next to
  # sources, e.g. leveldb db_test.cc, re2 parse_test.cc) and flat-root harnesses
  # (lua ltests.*) that no dir-glob catches (R3).
  --glob '!**/*_test.*'
  --glob '!**/*_tests.*'
  --glob '!**/*test*.c'
  --glob '!**/*test*.cc'
  --glob '!**/*test*.cpp'
  --glob '!**/*test*.cxx'
  --glob '!**/*_bench*.*'
  --glob '!**/ltests.*'
  # R3+ test/vendored/generated conventions that path-segment + suffix globs miss:
  #  - NASA cFE unit-test dirs `ut-coverage/`/`ut-stubs/` (77% of cFE's risk hits).
  #  - CamelCase test roots: F´ `STest/`, `FppTestProject/`, and any `*Test/` dir
  #    (GTest/, FooTest/) — `[A-Z]*Test` so ordinary lowercase dirs are untouched.
  #  - the `*test_inc.h` driver-include convention (pcre2 `pcre2test_inc.h`, the
  #    202 KB body of the test driver, #included only by `pcre2test.c`).
  #  - generated amalgamations `single_include/` (nlohmann — a generated mirror of
  #    `include/`; scanning it double-counts every shipped finding).
  #  - vendored target-libc headers under `*/win32/include/` (tinycc ships the
  #    Windows cross-compile target's mingw headers — NOT tinycc-authored source).
  # NB: ordinary public `include/` is NOT excluded (that is the real API surface);
  # only the `win32/include/` vendored variant and `single_include/` mirror are.
  --glob '!**/ut-coverage/**'
  --glob '!**/ut-stubs/**'
  --glob '!**/STest/**'
  --glob '!**/*TestProject*/**'
  --glob '!**/[A-Z]*Test/**'
  --glob '!**/*test_inc.h'
  --glob '!**/single_include/**'
  --glob '!**/win32/include/**'
)

# The file-extension glob applied to every scan/file-list pass. Kept next to the
# exclusion set so the shipped surface is defined in one place.
SRC_GLOB='*.{c,cc,cpp,cxx,h,hh,hpp,hxx}'

# R1-mixed: the C++-ONLY extension glob. The raw new/delete category is a C++
# construct, so it must scan ONLY C++ translation units / C++-only headers — never
# `.c`/`.h`, where `new`/`delete` are legal C identifiers (`struct k_thread *new =
# …;`, `delete = (value==NULL);`). On a MIXED C/C++ repo (zephyr: 8849 .c + 50 .cpp)
# the repo-level `HAS_CPP=yes` gate opened the lane repo-wide and it fired on the
# 99.4%-C portion → 35/40 new/delete hits were FPs on C vars. Scoping the lane to
# this glob keeps the 5 genuine `.cpp` hits and drops the C-file FPs. `.h` is
# excluded on purpose: a C header is not a C++ TU (a `.hpp`/`.hh`/`.hxx` is).
CPP_SRC_GLOB='*.{cc,cpp,cxx,c++,hpp,hh,hxx,h++}'

# C++ signal: does the repo SHIP real C++ code? A repo counts as C++ only when it
# carries an actual C++ translation unit (.cc/.cpp/.cxx/.c++) OR a C++-only header
# (.hpp/.hh/.hxx/.h++) in a SHIPPED (non-test/non-vendored/non-extras) dir — using
# the same exclusion set as the scan. A lone CMAKE_CXX_STANDARD / enable_language(CXX)
# build variable (set for an auxiliary C++ smoke-test or downstream linkage) or a
# test-only / extras/ .cpp must NOT count: those re-enabled the raw new/delete
# category on pure-C repos and produced hundreds of FPs flagging the English words
# "new"/"delete" in C comments and strings (R1: mbedtls 27, FreeRTOS ~200,
# miniaudio ~90). Suppressing the C++ categories on a genuinely pure-C repo is the
# whole point of the gate (F1a); the build-variable heuristic broke it.
detect_cpp() {
  local t
  for t in "${targets[@]}"; do
    # Shipped C++ translation unit or C++-only header present (extension is an
    # unambiguous C++ signal; .h is intentionally NOT in this set because a C
    # header is not a C++ signal). Test/vendored/extras trees are excluded.
    if [ -n "$(rg --files --no-messages \
          --glob '*.{cc,cpp,cxx,c++,hpp,hh,hxx,h++}' \
          "${EXCLUDE_GLOBS[@]}" \
          "$t" 2>/dev/null)" ]; then
      printf 'yes'
      return 0
    fi
  done
  printf 'no'
}

# Comment/string strip + re-match (F1b completion, R2). rg emits "file:line:content";
# the original F1b filter only dropped rows whose content STARTS with a comment
# marker, so a real match buried in a TRAILING `// ...` / inline `/* ... */`, a
# CONTINUATION line of a multi-line `/* ... */`, or inside a `"string literal"`
# leaked through (re2 `// new States`, FreeRTOS trailing `/* */` asm comments,
# leveldb `/* */` doc-comment continuation, lwip `system("%s")`).
#
# Strategy: a WHOLE-FILE stripper (not a per-match-line filter) is the only way to
# carry `/* ... */` block state across lines correctly — the `/*` opener often
# sits on a line the search pattern does NOT match, so a per-rg-row filter never
# sees it. This awk reads each candidate file end-to-end, blanks every comment and
# string/char-literal SPAN (tracking block state from the file start), and emits
# "<cleaned>\t<path>:<lineno>:<original>" for every line. A downstream rg applies
# the SAME pattern to the CLEANED field only (identical PCRE semantics to the
# search pass); the original row is recovered with `cut`. A token that lay entirely
# inside a comment or string therefore disappears, while a real call/expression on
# the code part of the line survives unchanged in the reported original text.
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

# run_check PATTERN with whole-file comment/string filtering. Args: LABEL PATTERN [GLOB].
# 1) rg -l finds candidate files (fast, on the shipped surface);
# 2) the whole-file stripper rewrites each to "<cleaned>\t<path>:<line>:<orig>";
# 3) rg re-applies PATTERN to the cleaned field; 4) cut recovers original rows.
# File list is LC_ALL=C sorted so two runs byte-match (determinism). The optional
# 3rd arg overrides the file-extension glob (default $SRC_GLOB) — used by the C++-
# only new/delete category to restrict its surface to C++ TUs/headers (R1-mixed).
run_check() {
  local label="$1"
  local pattern="$2"
  local glob="${3:-$SRC_GLOB}"
  local files out
  printf '\n[%s]\n' "$label"
  files="$(rg -l --glob "$glob" "${EXCLUDE_GLOBS[@]}" \
            "$pattern" "${targets[@]}" 2>/dev/null | LC_ALL=C sort || true)"
  if [ -z "$files" ]; then
    printf 'no matches\n'
    return 0
  fi
  out="$(printf '%s\n' "$files" \
        | awk 'NF' \
        | tr '\n' '\0' \
        | xargs -0 awk "$STRIP_COMMENTS_AWK" 2>/dev/null \
        | rg -P "^[^\t]*(?:$pattern)" 2>/dev/null \
        | cut -f2- || true)"
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    status=1
  else
    printf 'no matches\n'
  fi
}

# Run the full risk-scan report over the current `targets`. Computes the C++
# signal, prints the scope banner, then each category. Sets `status` (advisory).
run_scan() {
  HAS_CPP="$(detect_cpp)"
  status=0

  # Scope banner: be explicit that non-shipped dirs (tests/bench/examples/docs/
  # extras) and vendored frameworks are excluded so the surface reflects shipped
  # code, and that suffix-named tests / the testing/ gerund are excluded too (R3).
  printf '[scope] shipped library code only; excludes tests/, test/, testing/, bench*/,\n'
  printf '        examples/, extras/, docs/, third_party/, vendor/, extern/, vendored test\n'
  printf '        frameworks, and suffix-named tests (*_test.*, *test*.cc, ltests.*).\n'
  printf '[scope] C++ signal: %s (raw new/delete category %s)\n' \
    "$HAS_CPP" "$([ "$HAS_CPP" = yes ] && printf 'enabled, scanned over C++ TUs/headers only (.cc/.cpp/.cxx/.hpp/.hh/.hxx)' || printf 'suppressed (pure-C)')"

  # Unsafe string/format APIs: require the function name as a word immediately
  # followed by `(` so we match real CALLS, not prose or identifier substrings
  # (F1c). snprintf/vsnprintf/vfprintf are the SAFE bounded alternatives and are
  # deliberately NOT in this set; the genuinely unsafe variadic/copy APIs are.
  run_check 'unsafe string or formatting APIs' \
    '\b(strcpy|strcat|stpcpy|sprintf|vsprintf|gets|scanf|sscanf|fscanf|vscanf|vsscanf|strncpy|strncat)\s*\('
  run_check 'raw allocation function calls' '\b(malloc|calloc|realloc|free)\s*\('
  if [ "$HAS_CPP" = yes ]; then
    # R1-mixed: PER-FILE gating. The lane scans ONLY C++ TUs/headers ($CPP_SRC_GLOB),
    # never `.c`/`.h`, so on a mixed C/C++ repo the English-word `new`/`delete` C
    # identifiers do not flag — only real C++ new/delete expressions in `.cc`/`.cpp`/
    # `.cxx`/`.hpp`/… do. (Repo-wide `HAS_CPP=yes` still decides whether the lane runs
    # at all; the per-file glob decides WHICH files it reads.)
    run_check 'raw C++ new/delete expressions' \
      '(^|[^[:alnum:]_])(::)?new[[:space:]]+|(^|[^[:alnum:]_])delete(\[\])?[[:space:]]+' \
      "$CPP_SRC_GLOB"
  else
    printf '\n[raw C++ new/delete expressions]\n'
    printf 'skipped: no C++ signal (pure-C repo; new/delete are not C constructs)\n'
  fi
  # R7: the C-style-cast arm must require an actual cast OF A VALUE — a `(Type *)`
  # immediately followed by an OPERAND: an identifier, `(`, `&`, or a digit. The old
  # arm flagged any `(Type *)` regardless of what followed, so it misread single-
  # pointer function-prototype params `foo(Type *)` (nng's 314 NNG_DECL/extern decls
  # = 68% of its cast lane, plus tinycc/pcre2/cFE prototypes) and `sizeof(T *)`
  # (cFE/pcre2) as C-style casts. Requiring a trailing operand fixes BOTH classes at
  # once: a prototype `(Type *)` is followed by `)`/`,`/`;` and a `sizeof(T *)` by
  # `)`/`,`/`;`/an operator — none of which is an operand char — so neither matches,
  # while a genuine cast `(char*)malloc(...)` / `(uint8_t *) &x` / `(int *) 0` still
  # flags. The operand class deliberately EXCLUDES `*` so a binary multiply after a
  # pointer-sizeof (`sizeof(T *) * count`, nng aio.c) is not misread as a cast-then-
  # deref; a real cast-then-deref `*(int *)p` still flags via the trailing `p`. (No
  # lookbehind: the operand requirement alone subsumes the sizeof exclusion, keeping
  # the file-list and re-match passes on one PCRE- and default-engine-valid pattern.)
  run_check 'casts requiring review' '\b(reinterpret_cast|const_cast|static_cast<.*\*>)|\([A-Za-z_][A-Za-z0-9_:<>[:space:]]*\*\)\s*[A-Za-z_0-9(&]'
  run_check 'unchecked memory movement' '\b(memcpy|memmove|memset|memcmp)\s*\('
  run_check 'process or shell execution' '\b(system|popen|execl|execlp|execle|execv|execvp|execvpe|CreateProcess)\s*\('
  run_check 'assert-only validation' '\bassert\s*\('
  run_check 'threading primitives' '\b(pthread_[a-z_]+\s*\(|std::thread|std::async|std::mutex|std::atomic|CreateThread\s*\()'

  # This is a side-effect-free triage REPORT, not a pass/fail gate (F4): the
  # advisory `status` is intentionally not turned into a non-zero exit.
  : "$status"
}

# ---------------------------------------------------------------------------
# Self-test: build a tiny fake repo, prove the C++-signal gate, the comment/
# string strip (R2), and the path exclusions (R3). Locks each batch-2 regression.
# Cleans up via trap. Prints PASS / FAIL and exits.
# ---------------------------------------------------------------------------
self_test() {
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  # --- Fixture 1 (R1): a PURE-C repo whose CMake declares a CXX standard for an
  # auxiliary target, with ZERO shipped C++ TUs. The only .cpp is test-only. The
  # English words new/delete appear in C comments + string literals. The C++
  # new/delete category MUST be suppressed and emit ZERO new/delete hits. ------
  mkdir -p "$tmp/purec/src" "$tmp/purec/tests"
  cat >"$tmp/purec/CMakeLists.txt" <<'CM'
cmake_minimum_required(VERSION 3.16)
project(purec C)
set(CMAKE_CXX_STANDARD 17)
enable_language(CXX)
CM
  cat >"$tmp/purec/src/core.c" <<'SRC'
#include <string.h>
/* allocate a new session and delete the old one (prose, not code) */
void core_log(void) {
    const char *m = "new session ticket created; delete pending";
    int new_count = 0;          // track the new arrivals
    (void)m; (void)new_count;
}
SRC
  cat >"$tmp/purec/tests/test_core.cpp" <<'SRC'
struct T { T() { } };
void make() { T *p = new T(); delete p; }
SRC

  # --- Fixture 2 (R2): a C++ repo (real .cc) whose new/delete + unsafe-API hits
  # are all in TRAILING //, inline /* */, block-comment CONTINUATION, and string
  # literals — except ONE real `new` expression and ONE real `system(` call. ----
  mkdir -p "$tmp/cpp"
  cat >"$tmp/cpp/engine.cc" <<'SRC'
#include <cstdlib>
int budget; // remaining budget for new States
#include <cstdio> /* sprintf() is unsafe; we avoid it */
/* This is a multi-line comment that mentions
   a new Node and a call to delete here
   and even system("rm -rf /") in prose */
const char *banner = "run new build then delete temp; system(\"x\")";
void real_new() {
    int *p = new int[4];      /* this is a genuine allocation */
    free(p);
}
void real_exec(const char *c) { system(c); }
SRC

  # --- Fixture 3 (R3): suffix-named test + testing/ + extras/ + ltests.* that
  # carry real strcpy/new CALLS which MUST be excluded by filename/dir. ---------
  mkdir -p "$tmp/cpp/testing" "$tmp/cpp/extras"
  cat >"$tmp/cpp/foo_test.cc"  <<'SRC'
void t(char *d, const char *s) { __builtin_strcpy(d, s); int *q = new int; (void)q; }
SRC
  cat >"$tmp/cpp/testing/bar.cc" <<'SRC'
#include <cstring>
void u(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/cpp/extras/vend.cc" <<'SRC'
#include <cstring>
void v(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/cpp/ltests.c" <<'SRC'
#include <string.h>
void w(char *d, const char *s) { strcpy(d, s); }
SRC

  # --- Fixture 4 (R7 cast lane): a pure-C repo mixing GENUINE C-style casts (a
  # cast immediately followed by an operand) with the two false-positive shapes the
  # old arm flagged — single-pointer function PROTOTYPES `foo(Type *)` and
  # `sizeof(T *)`. The genuine casts MUST flag; the prototypes and sizeof MUST NOT.
  mkdir -p "$tmp/casts"
  cat >"$tmp/casts/casts.c" <<'SRC'
#include <stdlib.h>
#include <stdint.h>
/* prototypes: single-pointer param, NO operand after (Type *) — NOT casts */
extern void nni_aio_fini(nni_aio *);
void register_cb(callback_t *);
static void win_del(void *);
size_t type_size(void) {
    /* sizeof of a pointer type — NOT a cast */
    size_t a = sizeof(uint8_t *);
    size_t b = sizeof(struct foo *) * 4;   /* sizeof then multiply — NOT a cast */
    return a + b;
}
void real_casts(void *raw, sockaddr_t *sa) {
    char *p = (char *)malloc(16);           /* GENUINE cast of malloc() */
    uint8_t *q = (uint8_t *) &sa->addr;     /* GENUINE cast of an &-operand */
    int n = *(int *) raw;                   /* GENUINE cast-then-deref */
    void *z = (void *) 0;                   /* GENUINE cast of a number */
    free(p); (void)q; (void)n; (void)z;
}
SRC

  # --- Fixture 5 (R3+ exclusions): real risk hits living in dirs/files that the new
  # exclusion conventions must drop — NASA `ut-coverage/`/`ut-stubs/`, a CamelCase
  # `GTest/` dir, the `*test_inc.h` driver-include, a generated `single_include/`
  # amalgamation, and a vendored `win32/include/` target-libc header. A real shipped
  # `fsw/` hit in the SAME repo must SURVIVE (no over-correction). ----------------
  mkdir -p "$tmp/excl/fsw" "$tmp/excl/ut-coverage" "$tmp/excl/ut-stubs" \
           "$tmp/excl/GTest" "$tmp/excl/single_include" "$tmp/excl/win32/include"
  cat >"$tmp/excl/fsw/real.c" <<'SRC'
#include <string.h>
void fsw_copy(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/ut-coverage/cov.c" <<'SRC'
#include <string.h>
void cov(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/ut-stubs/stub.c" <<'SRC'
#include <string.h>
void stub(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/GTest/g.cc" <<'SRC'
#include <cstring>
void g(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/foo_test_inc.h" <<'SRC'
#include <string.h>
static void inc(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/single_include/amalgam.h" <<'SRC'
#include <string.h>
static void amalg(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/win32/include/stdlib.h" <<'SRC'
#include <string.h>
static void w32(char *d, const char *s) { strcpy(d, s); }
SRC
  # R10 additions to the excl fixture: a bare `deps/` vendored runtime dep, an
  # OSS-Fuzz `fuzz/` harness, an `autosetup/jimsh0.c` bootstrap amalgam, and an
  # embedded vendored framework copy under `tests/vendor/catch2/` — all must be
  # excluded; the real shipped `fsw/real.c` strcpy must SURVIVE.
  mkdir -p "$tmp/excl/deps/hiredis" "$tmp/excl/fuzz" "$tmp/excl/autosetup" \
           "$tmp/excl/tests/vendor/catch2"
  cat >"$tmp/excl/deps/hiredis/net.c" <<'SRC'
#include <string.h>
void vend(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/fuzz/decompress.cc" <<'SRC'
#include <cstring>
void fz(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/autosetup/jimsh0.c" <<'SRC'
#include <string.h>
void jim(char *d, const char *s) { strcpy(d, s); }
SRC
  cat >"$tmp/excl/tests/vendor/catch2/catch_amalgamated.cpp" <<'SRC'
#include <cstring>
void emb(char *d, const char *s) { strcpy(d, s); }
SRC

  # --- Fixture 6 (R1-mixed): a MIXED C/C++ repo. The repo-level C++ signal is yes
  # (it ships a real engine.cc), but the C files use `new`/`delete` as legal C
  # IDENTIFIERS. The new/delete category must scan ONLY the C++ TU (engine.cc) — the
  # C-file `struct k_thread *new = …;` / `delete = …;` must NOT flag (zephyr 35 FPs).
  mkdir -p "$tmp/mixed/src" "$tmp/mixed/arch"
  cat >"$tmp/mixed/src/engine.cc" <<'SRC'
struct Node { Node() {} };
void build() { Node *p = new Node(); delete p; }
SRC
  cat >"$tmp/mixed/arch/sched.c" <<'SRC'
struct k_thread { int id; };
int run(struct k_thread *old) {
    struct k_thread *new = old;      /* C var named `new` — NOT a C++ new-expr */
    int delete = (old == 0);         /* C var named `delete` — NOT C++ delete */
    if (new != old) return 1;
    return delete ? 0 : 2;
}
SRC
  cat >"$tmp/mixed/arch/util.h" <<'SRC'
struct buf { int len; };
static inline int bnew(struct buf *b) {
    int new = b->len;                /* C var named `new` in a .h header */
    return new + 1;
}
SRC

  # Run with RELATIVE targets (cd into the fixture root) so the report carries no
  # absolute path — risk-scan echoes the path it is handed verbatim by design.
  local purec_out cpp_out casts_out excl_out mixed_out exit_ok
  cd "$tmp" || { printf 'cpp_risk_scan self-test: FAIL (cd to tmp)\n'; exit 1; }
  targets=("purec"); purec_out="$(run_scan)"; exit_ok=$?
  targets=("cpp");   cpp_out="$(run_scan)"
  targets=("casts"); casts_out="$(run_scan)"
  targets=("excl");  excl_out="$(run_scan)"
  targets=("mixed"); mixed_out="$(run_scan)"

  # R1: pure-C repo with CXX_STANDARD + test-only .cpp must report C++ signal: no
  if ! printf '%s\n' "$purec_out" | grep -qF 'C++ signal: no'; then
    printf 'cpp_risk_scan self-test: FAIL (R1: pure-C repo with CXX_STANDARD got C++ signal: yes)\n'
    printf '%s\n%s\n' '--- purec ---' "$purec_out"; exit 1
  fi
  # R1: the new/delete category must be suppressed (skipped), zero FP lines.
  if ! printf '%s\n' "$purec_out" | grep -qF 'skipped: no C++ signal'; then
    printf 'cpp_risk_scan self-test: FAIL (R1: new/delete category not suppressed on pure-C)\n'
    printf '%s\n%s\n' '--- purec ---' "$purec_out"; exit 1
  fi
  # R2: comment/string prose new/delete on the pure-C repo must not leak anywhere.
  if printf '%s\n' "$purec_out" | grep -qE 'src/core\.c'; then
    printf 'cpp_risk_scan self-test: FAIL (R2: comment/string prose on pure-C repo leaked a hit)\n'
    printf '%s\n%s\n' '--- purec ---' "$purec_out"; exit 1
  fi

  # C++ repo: signal must be yes (it ships engine.cc).
  if ! printf '%s\n' "$cpp_out" | grep -qF 'C++ signal: yes'; then
    printf 'cpp_risk_scan self-test: FAIL (C++ repo not detected as C++)\n'
    printf '%s\n%s\n' '--- cpp ---' "$cpp_out"; exit 1
  fi
  # R2: the genuine `new int[4]` expression MUST still flag (no over-correction).
  if ! printf '%s\n' "$cpp_out" | grep -qE 'engine\.cc:[0-9]+:.*new int'; then
    printf 'cpp_risk_scan self-test: FAIL (R2 over-correction: real new expression dropped)\n'
    printf '%s\n%s\n' '--- cpp ---' "$cpp_out"; exit 1
  fi
  # R2: the genuine system(c) call MUST still flag.
  if ! printf '%s\n' "$cpp_out" | grep -qE 'engine\.cc:[0-9]+:.*system\(c\)'; then
    printf 'cpp_risk_scan self-test: FAIL (R2 over-correction: real system() call dropped)\n'
    printf '%s\n%s\n' '--- cpp ---' "$cpp_out"; exit 1
  fi
  # R2: every comment/string-only new/delete/system/sprintf line MUST be gone.
  if printf '%s\n' "$cpp_out" | grep -qE 'engine\.cc:2:|engine\.cc:3:|engine\.cc:[4-7]:'; then
    printf 'cpp_risk_scan self-test: FAIL (R2: trailing/inline/block/string comment leaked)\n'
    printf '%s\n%s\n' '--- cpp ---' "$cpp_out"; exit 1
  fi
  # R3: suffix-test/testing/extras/ltests files must be excluded entirely.
  if printf '%s\n' "$cpp_out" | grep -qE 'foo_test\.cc|testing/bar\.cc|extras/vend\.cc|ltests\.c'; then
    printf 'cpp_risk_scan self-test: FAIL (R3: a suffix-test/testing/extras/ltests file leaked)\n'
    printf '%s\n%s\n' '--- cpp ---' "$cpp_out"; exit 1
  fi

  # -------------------------------------------------------------------------
  # R7 (cast lane): genuine C-style casts flag; prototypes and sizeof do NOT.
  # -------------------------------------------------------------------------
  # R7.1: the four GENUINE casts (cast immediately followed by an operand) flag.
  local realcast
  for realcast in '\(char \*\)malloc' '\(uint8_t \*\) &sa' '\*\(int \*\) raw' '\(void \*\) 0'; do
    if ! printf '%s\n' "$casts_out" | grep -qE "casts\.c:[0-9]+:.*$realcast"; then
      printf 'cpp_risk_scan self-test: FAIL (R7 over-correction: a genuine cast was dropped: %s)\n' "$realcast"
      printf '%s\n%s\n' '--- casts ---' "$casts_out"; exit 1
    fi
  done
  # R7.2: the single-pointer PROTOTYPES `foo(Type *);` must NOT flag as casts.
  if printf '%s\n' "$casts_out" | grep -qE 'casts\.c:[0-9]+:.*(nni_aio_fini|register_cb|win_del)\s*\([A-Za-z_][A-Za-z0-9_ ]*\*\)\s*;'; then
    printf 'cpp_risk_scan self-test: FAIL (R7: a single-pointer function prototype flagged as a cast)\n'
    printf '%s\n%s\n' '--- casts ---' "$casts_out"; exit 1
  fi
  # R7.3: `sizeof(T *)` (incl. `sizeof(T *) * n`) must NOT flag as a cast.
  if printf '%s\n' "$casts_out" | grep -qE 'casts\.c:[0-9]+:.*sizeof\([A-Za-z_][A-Za-z0-9_ ]*\*\)'; then
    printf 'cpp_risk_scan self-test: FAIL (R7: sizeof(T *) flagged as a cast)\n'
    printf '%s\n%s\n' '--- casts ---' "$casts_out"; exit 1
  fi

  # -------------------------------------------------------------------------
  # R3+ exclusions: ut-coverage/ut-stubs/CamelCase-Test/test_inc.h/single_include/
  # win32-include all dropped; the real fsw/ hit in the same repo SURVIVES.
  # -------------------------------------------------------------------------
  if printf '%s\n' "$excl_out" | grep -qE 'ut-coverage/|ut-stubs/|GTest/|foo_test_inc\.h|single_include/|win32/include/'; then
    printf 'cpp_risk_scan self-test: FAIL (R3+: an excluded test/vendored/generated path leaked)\n'
    printf '%s\n%s\n' '--- excl ---' "$excl_out"; exit 1
  fi
  if ! printf '%s\n' "$excl_out" | grep -qE 'fsw/real\.c:[0-9]+:.*strcpy'; then
    printf 'cpp_risk_scan self-test: FAIL (R3+ over-correction: real shipped fsw/ hit was dropped)\n'
    printf '%s\n%s\n' '--- excl ---' "$excl_out"; exit 1
  fi
  # R10: bare deps/, OSS-Fuzz fuzz/, autosetup/jimsh0.c, and an embedded vendored
  # tests/vendor/catch2/ copy must all be excluded; fsw/real.c still survives (above).
  if printf '%s\n' "$excl_out" | grep -qE 'deps/|fuzz/|jimsh0\.c|tests/vendor/catch2/'; then
    printf 'cpp_risk_scan self-test: FAIL (R10: a deps/fuzz/jimsh0/embedded-catch2 path leaked)\n'
    printf '%s\n%s\n' '--- excl ---' "$excl_out"; exit 1
  fi

  # -------------------------------------------------------------------------
  # R1-mixed (per-FILE C++ gating): on a MIXED C/C++ repo the new/delete category
  # scans ONLY C++ TUs/headers — a C var named new/delete must NOT flag.
  # -------------------------------------------------------------------------
  # R1-mixed.0: the repo is detected as C++ (it ships engine.cc) and the lane runs.
  if ! printf '%s\n' "$mixed_out" | grep -qF 'C++ signal: yes'; then
    printf 'cpp_risk_scan self-test: FAIL (R1-mixed: mixed repo not detected as C++)\n'
    printf '%s\n%s\n' '--- mixed ---' "$mixed_out"; exit 1
  fi
  # R1-mixed.1: the GENUINE C++ new/delete in engine.cc MUST still flag (no over-correction).
  if ! printf '%s\n' "$mixed_out" | grep -qE 'src/engine\.cc:[0-9]+:.*new Node'; then
    printf 'cpp_risk_scan self-test: FAIL (R1-mixed over-correction: real .cc new-expression dropped)\n'
    printf '%s\n%s\n' '--- mixed ---' "$mixed_out"; exit 1
  fi
  # R1-mixed.2: the C-file `new`/`delete` IDENTIFIERS (arch/sched.c, arch/util.h) must
  # NOT flag as C++ new/delete expressions (zephyr's 35 .c/.h FPs).
  if printf '%s\n' "$mixed_out" | grep -qE '^arch/sched\.c:[0-9]+:|^arch/util\.h:[0-9]+:'; then
    printf 'cpp_risk_scan self-test: FAIL (R1-mixed: C-file new/delete identifier flagged as a C++ new/delete expr)\n'
    printf '%s\n%s\n' '--- mixed ---' "$mixed_out"; exit 1
  fi
  # R1-mixed.3: the new/delete category banner reflects the per-file C++-only scope.
  if ! printf '%s\n' "$mixed_out" | grep -qF 'scanned over C++ TUs/headers only'; then
    printf 'cpp_risk_scan self-test: FAIL (R1-mixed: scope banner does not state per-file C++ scope)\n'
    printf '%s\n%s\n' '--- mixed ---' "$mixed_out"; exit 1
  fi

  # No absolute path may leak.
  if printf '%s\n' "$purec_out" "$cpp_out" "$casts_out" "$excl_out" "$mixed_out" | grep -qF "$tmp"; then
    printf 'cpp_risk_scan self-test: FAIL (absolute path leaked into output)\n'; exit 1
  fi
  # F4 holds: exit 0 on a successful run.
  if [ "$exit_ok" -ne 0 ]; then
    printf 'cpp_risk_scan self-test: FAIL (run did not exit 0, F4)\n'; exit 1
  fi
  # Reproducibility: two runs on the C++ repo byte-match.
  local cpp_out2
  targets=("cpp"); cpp_out2="$(run_scan)"
  if [ "$cpp_out" != "$cpp_out2" ]; then
    printf 'cpp_risk_scan self-test: FAIL (two runs did not byte-match)\n'
    diff <(printf '%s\n' "$cpp_out") <(printf '%s\n' "$cpp_out2") || true; exit 1
  fi

  printf 'cpp_risk_scan self-test: PASS\n'
  exit 0
}

# ---------------------------------------------------------------------------
# Arg handling. --self-test runs the locked-regression fixtures; otherwise every
# positional arg is a target path. This is a side-effect-free triage REPORT, not
# a pass/fail gate: exit 0 on a successful run regardless of matches (F4).
# ---------------------------------------------------------------------------
main() {
  local args=()
  local arg
  for arg in "$@"; do
    case "$arg" in
      --self-test) self_test ;;
      -h|--help)
        printf 'usage: cpp_risk_scan.sh [PATH...]\n       cpp_risk_scan.sh --self-test\n'
        exit 0 ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "${#args[@]}" -gt 0 ]; then
    targets=("${args[@]}")
  fi
  for arg in "${targets[@]}"; do
    if [ ! -e "$arg" ]; then
      printf 'error: path does not exist: %s\n' "$arg" >&2
      exit 2
    fi
  done
  run_scan
  exit 0
}

main "$@"
