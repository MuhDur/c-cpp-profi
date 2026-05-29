#!/usr/bin/env bash
#
# cpp_domain_detect.sh - mechanize the Pack-Selection Procedure from
# references/DOMAIN-AGNOSTIC-MASTERY.md.
#
# It runs the per-pack signal greps over a repo and prints every matched domain
# pack with the repo-relative file:line (or anchor) that matched. A repo may
# match several packs -> all are printed (the strictest constraint wins; union
# their gates). When no pack matches it prints:
#
#   unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md
#
# It is READ-ONLY: it never writes to the target repo. Output is deterministic:
# repo-relative paths only, LC_ALL=C sort, no timestamps, no $RANDOM, no absolute
# paths, so two runs on an unchanged tree byte-match.
#
# Usage:
#   cpp_domain_detect.sh [REPO] [--json]   (default REPO=.)
#   cpp_domain_detect.sh --self-test
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SELF_DIR is BASH_SOURCE-relative so the script works from any cwd. It is not
# otherwise used, matching the sibling helpers' location discipline.
: "${SELF_DIR:?}"

usage() {
  cat <<'USAGE'
usage: cpp_domain_detect.sh [REPO] [--json]
       cpp_domain_detect.sh --self-test

Mechanizes the Pack-Selection Procedure in references/DOMAIN-AGNOSTIC-MASTERY.md:
runs the per-pack signal greps over a repo and prints every matched domain pack
with the repo-relative file:line that selected it (a repo may match several ->
all printed). Prints "unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md"
when none match. READ-ONLY. Deterministic and reproducible: two runs byte-match.
USAGE
}

# ---------------------------------------------------------------------------
# rg guard + search base, mirroring the sibling helpers' exclusions so anchors
# line up across the helper family. The detector greps source/header AND build
# and CI/config files, so its glob set is wider than the code-only helpers.
# ---------------------------------------------------------------------------
rg_available() {
  command -v rg >/dev/null 2>&1
}

# rg over the repo, vendored/build trees AND non-shipped dirs (tests, docs,
# examples, benches, runners) excluded so detection runs on the project's own
# shipped code, not its test fixtures / docs / vendored frameworks (F2b).
# Case-insensitive (signals are matched loosely). Args: PATTERN REPO [MODE]
#
# MODE selects the glob set:
#   all  (default) - source/header AND build/config files. Toolchain signals
#                    (`-ffast-math`, `nvcc`, `CMAKE_*`) live in build files.
#   code           - source/header files only. Used for the parser and generic
#                    packs, whose signals (format names like `toml`/`csv`,
#                    `*_parse`, `*_init/*_free`) are *code* identity; in build
#                    files those same tokens are filenames/targets (e.g. a
#                    Makefile listing `tests/*.toml`) and would misclassify (F2b).
#
# F2c BUG FIX: the pattern is passed via `-e "$1"` (not positionally). Several
# pack regexes begin with a dash (the HPC pattern starts with `-ffast-math`);
# passed positionally, rg parses the leading `-f` as its own `--file` flag,
# errors out, and `--no-messages`/`|| true` silently swallow it -> the pack is
# never detected. `-e` (and `--` before the path) makes a leading-dash pattern
# a literal search term, restoring HPC/SIMD detection (cglm's 297 `_mm_`).
# Shared exclusion globs, mirroring cpp_risk_scan.sh / cpp_backlog.sh so anchors
# line up across the helper family. Adds testing/, extras/, suffix-named tests and
# flat-root harnesses (R3) on top of the existing dir excludes — so a repo's own
# test/bench/vendored-split code never contributes domain signal.
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
  --glob '!**/docs/**'
  --glob '!**/doc/**'
  --glob '!**/examples/**'
  --glob '!**/example/**'
  --glob '!**/bench/**'
  --glob '!**/benches/**'
  --glob '!**/benchmark/**'
  --glob '!**/benchmarks/**'
  --glob '!**/extras/**'
  --glob '!**/extra/**'
  --glob '!**/runners/**'
  # R10: vendored *runtime* dependencies and generated amalgam/aux trees that the
  # `_deps/`/`third_party/`/`vendor/` set missed: the bare `deps/` convention
  # (redis/git/php bundle libs there — hiredis/lua/jemalloc), `dependencies/`
  # (simdjson's benchmark deps), the `singleheader/` generated amalgam (simdjson,
  # alongside the existing `single_include/`), `autosetup/` build glue + its
  # `jimsh0.c` bootstrap Jim-Tcl amalgam (sqlite), and OSS-Fuzz `fuzz/`/`fuzzing/`
  # harness dirs whose `*.cc`/`*.cpp` decoders otherwise flip the C++ signal and add
  # codec noise (libjpeg). The backlog test-fuzz lane still finds harnesses via its
  # OWN explicit `**/fuzz/**` glob, so coverage detection is unaffected.
  --glob '!**/deps/**'
  --glob '!**/dependencies/**'
  --glob '!**/singleheader/**'
  --glob '!**/fuzz/**'
  --glob '!**/fuzzing/**'
  --glob '!**/autosetup/**'
  --glob '!**/jimsh0.c'
  # R13/R10: data tables are NOT code. Even though `txt` is no longer in the build
  # glob, drop data-table files outright so a renamed/relocated table (or the literal
  # `CMakeLists.txt` glob) can never count `UnicodeData.txt`/`CaseFolding.txt` "LETTER
  # SHA" rows, `*.tables`, or binary `*.dat` as a code signal.
  --glob '!**/*.tables'
  --glob '!**/*.dat'
  --glob '!**/Unicode*.txt'
  --glob '!**/UnicodeData.txt'
  --glob '!**/CaseFolding.txt'
  # R11: vendored-framework excludes anchored to VENDORED LOCATIONS only. The bare
  # `!**/catch2/**`/`!**/catch.hpp`/`!**/gtest/**`/`!**/gmock/**`/`!**/unity*`/
  # `!**/utest.h` globs were meant to skip an EMBEDDED copy of a test framework that
  # OTHER repos vendor — but they also excluded the framework's OWN shipped source
  # when the repo IS that framework (Catch2's `src/catch2/`, 289 files, blinded 3/4
  # gates → a wrong Compilers primary off CMake `Interpreter` glue). Anchoring each
  # to a vendored parent (`third_party`/`vendor`/`extern`/`external`/`_deps`/`deps`/
  # `test`/`tests`/`testing`) drops only embedded copies while leaving the
  # framework's own `src/`/`include/` scannable.
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/unity*'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/utest.h'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/catch.hpp'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/catch2/**'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/gtest/**'
  --glob '!**/{third_party,thirdparty,vendor,extern,external,_deps,deps,test,tests,testing}/**/gmock/**'
  --glob '!**/*_test.*'
  --glob '!**/*_tests.*'
  --glob '!**/*test*.c'
  --glob '!**/*test*.cc'
  --glob '!**/*test*.cpp'
  --glob '!**/*test*.cxx'
  --glob '!**/*_bench*.*'
  --glob '!**/ltests.*'
  # R3+ test/vendored/generated conventions that path-segment + suffix globs miss
  # (kept identical to cpp_risk_scan.sh / cpp_backlog.sh so anchors line up): NASA
  # cFE `ut-coverage/`/`ut-stubs/`; CamelCase test roots (`STest/`, `FppTestProject/`,
  # any `[A-Z]*Test/` such as GTest/); the `*test_inc.h` driver-include (pcre2);
  # generated `single_include/` amalgamations (nlohmann); vendored target-libc
  # headers under `*/win32/include/` (tinycc mingw). These also keep a wrong domain
  # signal from a repo's test/vendored trees (fprime's Compilers anchor lived in
  # `FppTestProject/`). Ordinary public `include/` is NOT excluded — only the
  # `single_include/` mirror and `win32/include/` vendored variant.
  --glob '!**/ut-coverage/**'
  --glob '!**/ut-stubs/**'
  --glob '!**/STest/**'
  --glob '!**/*TestProject*/**'
  --glob '!**/[A-Z]*Test/**'
  --glob '!**/*test_inc.h'
  --glob '!**/single_include/**'
  --glob '!**/win32/include/**'
)

# Whole-file comment/string stripper (R2 + R13): emits "<cleaned>\t<path>:<line>:<orig>"
# for every line of the files passed as args, blanking C/C++ // /* */ comment
# spans (block state tracked across lines from each file's start) and "..."/'...'
# literal contents. The same helper used by the sibling scripts; a downstream rg
# re-applies the signal pattern to the CLEANED field so a token that lived only
# in a TRAILING //, an inline/▸multi-line /* */, or a string literal disappears
# (the F1b leading-marker-only filter missed all three). Build/CI files (YAML/
# CMake) carry their tokens in code, not C comments, so the strip is a near no-op
# there and never removes a real toolchain signal.
#
# R13: in a NON-C file (Makefile/YAML/sh/CMake/etc.) a `#` begins a comment to
# end-of-line and is blanked too — so a Makefile `@# SHA1: 774be8…` checksum
# comment and a YAML `# note` no longer feed the signal greps (this, plus the
# data-file skip, is what stops duktape's false Crypto primary). In a C/C++ file
# `#` is a PREPROCESSOR directive (`#pragma omp`, `#define X_IMPLEMENTATION`,
# `#include`) that carries real domain signal, so it is NEVER treated as a comment
# there. The per-file `hashcomment` flag is set at FNR==1 from the extension.
STRIP_COMMENTS_AWK='
FNR == 1 {
  inblock = 0
  hashcomment = (FILENAME ~ /\.(c|cc|cpp|cxx|h|hh|hpp|hxx|cu|cuh|cl)$/) ? 0 : 1
}
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
    if (hashcomment && c == "#") break
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

# Glob set for a mode: source/header always; build/config files added for 'all'.
# R13/R10: `txt` is intentionally NOT in the build-file wildcard. The only `.txt`
# that carries a toolchain signal is `CMakeLists.txt`, matched by its own literal
# glob below; a bare `*.txt` wildcard instead pulled in DATA TABLES as "code"
# matches (sqlite `ext/fts3/unicode/UnicodeData.txt`/`CaseFolding.txt`, duktape
# `src-input/UnicodeData.txt`) — the "CYRILLIC LETTER SHA" rows that handed duktape
# a false Crypto primary and sqlite spurious Filesystems/Crypto secondaries. Data
# tables (`*.txt`/`*.tables`/`Unicode*.txt`/`*.dat`) are belt-and-suspenders dropped
# in EXCLUDE_GLOBS too, so they never count even via the literal `CMakeLists.txt`.
signal_globs() {
  local mode="${1:-all}"
  printf '%s\0' '*.{c,cc,cpp,cxx,h,hh,hpp,hxx,cu,cuh,cl}'
  if [ "$mode" = all ]; then
    printf '%s\0' '*.{cmake,build,mk,json,yml,yaml,ld,ini}' \
                  'CMakeLists.txt' 'Makefile' 'GNUmakefile' \
                  'meson.build' 'Kconfig' 'Kbuild'
  fi
}

# Comment/string-stripped, mostly-case-insensitive signal matches for PATTERN under
# REPO. Returns "path:line:original" rows whose CODE part matches (R2/R3). Args: PATTERN REPO [MODE]
#
# R8: matching is case-insensitive by default (signals are matched loosely), but a
# pack may force a DISTINCTIVE token case-sensitive with an inline `(?-i:...)` group
# so its uppercase-API vocabulary matches the real domain but NOT ordinary
# identifiers that merely share the spelling. The SPACE pack's `OS_`/`CFE_`/`OS_API`
# and the Compilers pack's `opcode`/`OPCODE` use this: without it the case-folded
# `OS_[A-Z]` matched zlib's gzip-header `OS_CODE` (+ `os_flush`) → SPACE-primary on a
# compression lib, and `\bopcode\b` matched fprime's CamelCase `FwOpcodeType` →
# Compilers over Space. Because `(?-i:...)` (and the `OS_(?!CODE\b)` negative
# lookahead the SPACE pack uses to drop the gzip token) are PCRE constructs that
# rg's DEFAULT regex engine rejects, BOTH the file-list pass and the re-match pass
# run under PCRE (`-P`); the patterns are plain alternations/`\b`/char-classes that
# the re-match pass already required to be PCRE-valid, so this is semantics-stable.
rg_signal() {
  local mode="${3:-all}"
  local gl=()
  local g
  while IFS= read -r -d '' g; do gl+=(--glob "$g"); done < <(signal_globs "$mode")
  local files
  files="$(rg -liP -l --no-messages \
      "${gl[@]}" \
      "${EXCLUDE_GLOBS[@]}" \
      -e "$1" -- "$2" 2>/dev/null | LC_ALL=C sort || true)"
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | awk 'NF' | tr '\n' '\0' \
    | xargs -0 awk "$STRIP_COMMENTS_AWK" 2>/dev/null \
    | rg -iP "^[^\t]*(?:$1)" 2>/dev/null \
    | cut -f2- || true
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

# Repo-relative, comment/string-stripped, de-duplicated file:line anchors for
# PATTERN under REPO, LC_ALL=C sorted (rg_signal already strips comments/strings
# and re-matches, so a token that lived only in a comment/literal is gone). Args:
# PATTERN REPO [MODE]
pack_anchors() {
  rg_signal "$1" "$2" "${3:-all}" \
    | strip_repo_prefix "$2" \
    | awk -F: 'NF>=2 { print $1 ":" $2 }' \
    | LC_ALL=C sort -u
}

# ---------------------------------------------------------------------------
# Pack table. Each pack is "id|label|signal-regex". The regex is the union of
# the pack's Pack-Selection signals from DOMAIN-AGNOSTIC-MASTERY.md. Order is
# fixed so output is deterministic.
# ---------------------------------------------------------------------------
# Real-domain packs are listed first; `generic` is the honest fallback for a
# real C/C++ library that matches no domain and is ranked/handled specially in
# detect() so it never masks a genuine domain match.
pack_ids() {
  printf '%s\n' \
    space embedded kernel gpu hpc crypto networking compression \
    compilers databases audio filesystems parser generic
}

pack_label() {
  case "$1" in
    space)       printf 'Space / satellites' ;;
    embedded)    printf 'Embedded / real-time' ;;
    kernel)      printf 'Kernel / drivers' ;;
    gpu)         printf 'GPU (CUDA / SYCL / HIP)' ;;
    hpc)         printf 'HPC / SIMD / numerics' ;;
    crypto)      printf 'Crypto' ;;
    networking)  printf 'Networking / protocols' ;;
    compression) printf 'Compression / codec' ;;
    compilers)   printf 'Compilers / interpreters / VMs' ;;
    databases)   printf 'Databases / storage engines' ;;
    audio)       printf 'Audio / DSP / real-time media' ;;
    filesystems) printf 'Filesystems / block storage' ;;
    parser)      printf 'Parser / text-format / serialization' ;;
    generic)     printf 'Generic library / data-structures / strings' ;;
    *)           printf 'unknown' ;;
  esac
}

# Signal regex per pack. Patterns are deliberately conservative: they mirror the
# documented signals and avoid tokens that fire on unrelated code. Matching is
# case-insensitive by default; a DISTINCTIVE token is wrapped in an inline
# `(?-i:...)` group so it is matched CASE-SENSITIVELY (R8/R9-vocab):
#   - SPACE: `cFE_`/`CFE_`/`OS_API`/`OS_*` (with `OS_(?!CODE\b)` dropping zlib's
#     gzip-header `OS_CODE`) plus F´/F-Prime `CCSDS`/`Framer`/`Deframer`/`Tlm`/
#     `APID`/`FwOpcode`/`CmdResponse` (case-sensitive so they match fprime's flight
#     vocabulary but not prose), and Compilers' `opcode`/`OPCODE` — so cFS/F´/compiler
#     vocabulary matches but ordinary identifiers (zlib `OS_CODE`/`os_flush`, fprime's
#     CamelCase `FwOpcodeType`) do not.
#   - COMPRESSION: `LZ4_`/`LZ77`/`ZSTD_` are case-sensitive (the codec API spelling),
#     while `deflate`/`inflate`/`compress`/`crc32`/`adler32`/`gzip` stay loose.
#   - NETWORKING: the distinctive nouns (`socket`/`listener`/`dialer`/`endpoint`/
#     `sockaddr`) stay loose, but the generic syscall verbs `connect`/`bind`/`accept`/
#     `send`/`recv`/`sendto`/`recvfrom`/`poll`/`epoll` are case-sensitive LOWERCASE
#     (the POSIX socket convention) so they match real socket I/O but NOT CamelCase
#     methods that merely share the spelling (tinyxml2's visitor `Accept()`).
#   - CRYPTO: the bare `hash` token is NOT used (it fires on hashtable containers —
#     klib/uthash/lua); `hash` only counts inside a crypto context
#     (`crypto`/`sha`/`blake`/`hmac` prefix or a `256`/`512`/`sha` suffix).
pack_regex() {
  case "$1" in
    space)       printf '%s' '\bMISRA\b|rules? of ten|Power of Ten|(?-i:\bcFE_|\bCFE_|\bOS_API|\bOS_(?!CODE\b)[A-Z]|\bCCSDS\b|\bFramer\b|\bDeframer\b|\bTlm\b|\bAPID\b|\bFwOpcode|\bCmdResponse)|\btelemetry\b|\bspacecraft\b|\bwatchdog\b|\bRTEMS\b|EXPORT_SYMBOL_NASA' ;;
    embedded)    printf '%s' '\bFreeRTOS\b|\bZephyr\b|xTaskCreate|-ffreestanding|\bvolatile\b.*(0x[0-9A-Fa-f]+|register)|ISR_HANDLER|\bHAL_' ;;
    kernel)      printf '%s' '(^|[^A-Za-z0-9_])__user([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])copy_(to|from)_user([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])MODULE_LICENSE([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])EXPORT_SYMBOL([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])spin_lock([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])GFP_(KERNEL|ATOMIC)([^A-Za-z0-9_]|$)' ;;
    gpu)         printf '%s' '(^|[^A-Za-z0-9_])__global__([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])__device__([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])__syncthreads([^A-Za-z0-9_]|$)|\bcudaMalloc\b|\bcudaMemcpy\b|\bhipMalloc\b|sycl::|-fsycl' ;;
    hpc)         printf '%s' '-ffast-math|_mm_[a-z]|vld1|svptrue|Eigen/|highway|#pragma omp|<cfenv>' ;;
    crypto)      printf '%s' 'constant.time|secret-dependent|\bEVP_|crypto_[a-z]|explicit_bzero|memset_s|\bFIPS\b|test.vector|\bhmac\b|\baead\b|\bblake|\bsha[0-9]?\b|\bsha3\b|\bmd5\b|\bchacha\b|\bpoly1305\b|\bkeystream\b|\bnonce\b|\bdigest\b|\bcipher\b|\baes\b|\bgcm\b|\bccm\b|\brsa\b|\becdsa\b|\becdh\b|\becdhe\b|\bx509\b|\bpkcs\b|\bpsk\b|\bcamellia\b|\bblowfish\b|\baria\b|\bsalsa20\b|\bcurve25519\b|\bed25519\b|\bsiphash\b|\bencrypt\b|\bdecrypt\b|\bciphertext\b|\bplaintext\b|\bkeypair\b|(crypto|secure|keyed|message|one.?way)[a-z0-9_]*hash|hash[a-z0-9_]*(256|512|384|224|md5|sha)|(sha|blake|md5|hmac|keccak)[a-z0-9_]*hash' ;;
    networking)  printf '%s' '\bntohl\b|\bhtons\b|\bntohs\b|\bhtonl\b|parse_packet|RFC[0-9]|__attribute__.*packed|#pragma pack|\bsocket\b|\blistener\b|\bdialer\b|\bsockaddr|\bsetsockopt\b|\bgetsockopt\b|\bendpoint\b|\btransport\b|(?-i:\bconnect\b|\bbind\b|\baccept\b|\bsend\b|\brecv\b|\bsendto\b|\brecvfrom\b|\bpoll\b|\bepoll\b)' ;;
    compression) printf '%s' '\bdeflate\b|\binflate\b|\binflateBack\b|(?-i:\bLZ4_|\bLZ77\b|\bZSTD_)|\blz4\b|\bzstd\b|\bhuffman\b|\bcompress\b|\buncompress\b|\bdecompress\b|\bgzip\b|\bgzopen\b|\bcrc32\b|\badler32\b|literal.length|sliding.window' ;;
    compilers)   printf '%s' 'LLVMContext|llvm::|IRBuilder|emitOpcode|(?-i:\bopcode\b|\bOPCODE\b)|\bbytecode\b|interpreter|codegen|opt -verify' ;;
    databases)   printf '%s' '\bfsync\b|fdatasync|write-ahead|write.?ahead|\bWAL\b|\bMVCC\b|crash.consistency|page_checksum|page.?cache|\bpwrite\b|dm-flakey|\bALICE\b|\bsqlite3?\b|\bbtree\b|b-tree|\bpager\b|\bvdbe\b|opcode.*VDBE|\browid\b|(?-i:\bPRAGMA\b|\bPragma)|\bvacuum\b|\bredis\b|\bredisDb\b|\brobj\b|\bRDB\b|\bAOF\b|\brdbSave\b|\brdbAdd|\bkeyspace\b|dict.*entry|\btransaction\b|\bcommit\b|\brollback\b|\bcompaction\b|\bmemtable\b|\bsstable\b|\bmanifest\b|\bsnapshot\b|write.?batch' ;;
    audio)       printf '%s' 'audio_?callback|audio_?buffer|process_block|\bdenormal|\bxrun\b|\bjack_|kAudioUnit|\bVST3\b|\bASIO\b|\bCoreAudio\b|flush.to.zero|samples?_per_(buffer|frame)' ;;
    filesystems) printf '%s' '\bsuperblock\b|\binode\b|on-disk|\bmount\b|\bfsck\b|dm-flakey|\bFUA\b|crash.injection|barrier' ;;
    parser)      printf '%s' '\b(json|xml|yaml|toml|ini|csv|protobuf|msgpack|riff|fourcc)\b|\bhttp_?(parse|request|response)|[a-z0-9]+_parse\b|\bparse_[a-z]|\btokeniz|\blexer\b|\bgrammar\b|\b(json|xml|yaml|toml|http|url|base64|hex|utf8?|token|field|header|message)[a-z0-9]*_decode\b|\bdeserialize\b|\bphr_|\byy(parse|lex|_)|\bdr(wav|flac|mp3)_' ;;
    generic)     printf '%s' '\bKHASH|\bkh_init\b|\bkvec_t\b|kv_(init|push)\b|\bUT_hash|HASH_(ADD|FIND|DEL)\b|stb_ds|\bsds[a-z]+\(|typedef +struct[^;]*\{|[A-Za-z][A-Za-z0-9]*_(init|free|destroy|new)\b|#define +[A-Z0-9_]*IMPLEMENTATION' ;;
    *)           printf '%s' 'a^' ;;   # never matches
  esac
}

# Sort priority tier (F2b ranking). gpu/kernel carry unambiguous, never-incidental
# signatures (`__global__`, `MODULE_LICENSE`, `copy_from_user`) so they always
# outrank the generic fallback regardless of count — this protects real CUDA /
# kernel detection. Every other pack (including generic) shares the base tier and
# is then ranked by code-match count. Higher tier sorts first.
pack_priority() {
  case "$1" in
    gpu|kernel) printf '1' ;;
    *)          printf '0' ;;
  esac
}

# Search mode per pack. The parser and generic packs match *code* identity
# (format names, idiomatic API/macro shapes) that appears as filenames/targets
# in build files, so they scan source/headers only; every other pack also wants
# its toolchain signals from build files and uses the wide ('all') set.
pack_mode() {
  case "$1" in
    parser|generic) printf 'code' ;;
    *)              printf 'all' ;;
  esac
}

# ---------------------------------------------------------------------------
# Detection (R5 ranked): count each pack's distinct, comment/string-stripped code
# matches, then RANK. Emits tab-separated "id\tlabel\tanchor\tcount\trole" rows.
# Roles: primary (the binding classification) / secondary (other confident packs).
# Packs with a single incidental code match (count==1) are dropped (F2b).
#
# Ranking is primarily by COUNT, with two corrections proven necessary on the
# batch-2 repos (R5):
#  (b) TIER-1 COUNT FLOOR. gpu/kernel carry unambiguous, never-incidental tokens
#      (`__global__`, `MODULE_LICENSE`, `copy_from_user`) and sit in priority tier
#      1 so a genuine CUDA/Linux-driver repo outranks the broad generic pack. But
#      a tier-1 pack must EARN that promotion: it only jumps ahead of a
#      higher-count tier-0 pack when its own count clears a floor (>=3) AND is
#      within 10x of the leader. This stops 8 incidental GPU substring hits from
#      beating 1446 Audio matches (miniaudio) and 13 Pico-spinlock `spin_lock`
#      hits from beating 1968 RTOS matches (FreeRTOS) — both are real regressions.
#  (c) GENERIC IS NEVER PRIMARY WHEN A SPECIFIC PACK CLEARS THE FLOOR. `generic`
#      is the honest "it's just a C library" fallback. Its broad vocabulary
#      (ctx/init/free/struct/string idioms) wins raw count on any sizeable library
#      and buried the true domain (lwip Networking, mbedtls Crypto, leveldb
#      Databases). So when the count leader is `generic` but some SPECIFIC pack
#      has >= GENERIC_FLOOR (3) matches, the best-supported specific pack becomes
#      primary and generic drops to last. With no specific pack clearing the floor
#      (klib/uthash/sds containers), generic stays primary — the honest result.
# When nothing confident matches, detect() emits nothing -> unknown-domain.
# ---------------------------------------------------------------------------
detect() {
  local repo="$1"
  local id label rx anchor count prio anchors
  local raw=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    rx="$(pack_regex "$id")"
    # Materialize the anchor list once (avoids re-running rg, and avoids a
    # `head`-on-a-huge-`sort` SIGPIPE on big repos like dr_libs). The first line
    # is the anchor; the line count is the code-match count.
    anchors="$(pack_anchors "$rx" "$repo" "$(pack_mode "$id")")"
    [ -n "$anchors" ] || continue
    count="$(printf '%s\n' "$anchors" | awk 'END { print NR }')"
    # Drop single incidental hits (count<=1): F2b. They are the __packed__ ->
    # Networking, "ideal%" -> Crypto, "coordinate system" class of false packs.
    [ "$count" -ge 2 ] || continue
    anchor="$(printf '%s\n' "$anchors" | awk 'NR==1 { print; exit }')"
    [ -n "$anchor" ] || continue
    label="$(pack_label "$id")"
    prio="$(pack_priority "$id")"
    raw="${raw}${prio}\t${count}\t${id}\t${label}\t${anchor}"$'\n'
  done < <(pack_ids)

  [ -n "$raw" ] || return 0

  # Base order: COUNT desc, then original pack order asc (the priority column is
  # carried for the tier-1 floor logic but is NOT the primary sort key any more).
  printf '%b' "$raw" \
    | awk -F'\t' 'NF>=5 { print NR "\t" $0 }' \
    | LC_ALL=C sort -t$'\t' -k3,3nr -k1,1n \
    | awk -F'\t' '
        BEGIN { TIER1_FLOOR = 3; TIER1_RATIO = 10; GENERIC_FLOOR = 3 }
        { order[NR]=$1; prio[NR]=$2; count[NR]=$3
          id[NR]=$4; label[NR]=$5; anchor[NR]=$6; n=NR }
        END {
          # Count leader (row 1 after the count-desc sort).
          leader = 1
          # (b) Tier-1 promotion: the highest-count tier-1 pack is promoted to
          # primary ONLY if it clears the floor and is within TIER1_RATIO of the
          # leader. Otherwise tier-1 gets no special standing (ranked by count).
          tier1 = 0
          for (i = 1; i <= n; i++) {
            if (prio[i] == "1") {
              if (count[i] >= TIER1_FLOOR && count[i] * TIER1_RATIO >= count[leader]) {
                tier1 = i
              }
              break   # rows are count-sorted; first tier-1 is the strongest
            }
          }
          primary = (tier1 > 0 ? tier1 : leader)
          # (c) Generic demotion: if the chosen primary is generic but a specific
          # pack clears GENERIC_FLOOR, the best-supported specific pack wins.
          if (id[primary] == "generic") {
            best_specific = 0
            for (i = 1; i <= n; i++) {
              if (id[i] != "generic" && count[i] >= GENERIC_FLOOR) { best_specific = i; break }
            }
            if (best_specific > 0) primary = best_specific
          }
          # Emit: primary first, then the rest in count order; generic always
          # last (it is the least-specific label whenever a real pack exists).
          emitted = 0
          emit(++emitted, primary)
          for (i = 1; i <= n; i++) if (i != primary && id[i] != "generic") emit(++emitted, i)
          for (i = 1; i <= n; i++) if (i != primary && id[i] == "generic") emit(++emitted, i)
        }
        function emit(rank, i,   role) {
          role = (rank == 1 ? "primary" : "secondary")
          printf "%s\t%s\t%s\t%s\t%s\n", id[i], label[i], anchor[i], count[i], role
        }'
}

emit_text() {
  # tab-separated id/label/anchor/count/role -> "pack[role]: <label> | <anchor>
  # (<count> code matches)", or the unknown-domain line when there were no
  # confident matches.
  local rows="$1"
  if [ -z "$rows" ]; then
    printf 'unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md\n'
    return 0
  fi
  printf '%s\n' "$rows" \
    | awk -F'\t' 'NF>=5 {
        printf "pack[%s]: %s | %s (%s code matches)\n", $5, $2, $3, $4 }'
}

emit_json() {
  # tab-separated id/label/anchor/count/role -> {"matched": bool, "packs": [...]}.
  local rows="$1"
  printf '%s\n' "$rows" | awk -F'\t' '
    function esc(s,   r) {
      r = s
      gsub(/\\/, "\\\\", r)
      gsub(/"/, "\\\"", r)
      return r
    }
    BEGIN { n = 0 }
    NF>=5 {
      n++
      id[n] = $1; label[n] = $2; anchor[n] = $3; count[n] = $4; role[n] = $5
    }
    END {
      printf "{\n"
      printf "  \"matched\": %s,\n", (n > 0 ? "true" : "false")
      printf "  \"packs\": ["
      for (i = 1; i <= n; i++) {
        if (i > 1) printf ","
        printf "\n    {\"id\": \"%s\", \"pack\": \"%s\", \"anchor\": \"%s\", \"matches\": %s, \"role\": \"%s\"}", \
          esc(id[i]), esc(label[i]), esc(anchor[i]), (count[i]+0), esc(role[i])
      }
      if (n > 0) printf "\n  "
      printf "]"
      if (n == 0) {
        printf ",\n  \"hint\": \"build a pack from references/UNKNOWN-DOMAIN.md\""
      }
      printf "\n}\n"
    }'
}

run_detect() {
  local repo="$1"
  local json="$2"
  if [ ! -d "$repo" ]; then
    printf 'error: not a directory: %s\n' "$repo" >&2
    exit 2
  fi
  if ! rg_available; then
    printf 'error: rg (ripgrep) is required for cpp_domain_detect.sh\n' >&2
    exit 3
  fi
  local rows
  rows="$(detect "$repo")"
  if [ "$json" = yes ]; then
    emit_json "$rows"
  else
    emit_text "$rows"
  fi
}

# ---------------------------------------------------------------------------
# Self-test: build tiny fake repos, prove the documented signal->pack mappings
# fire, prove a plain repo reports unknown-domain, prove reproducibility and
# no absolute-path leak. Cleans up via trap.
# ---------------------------------------------------------------------------
self_test() {
  if ! rg_available; then
    printf 'cpp_domain_detect self-test: FAIL (rg not available)\n'
    exit 1
  fi
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  # Fixture A: a CUDA file -> GPU pack.
  mkdir -p "$tmp/gpu/src"
  cat >"$tmp/gpu/src/kernel.cu" <<'SRC'
__global__ void add(const float *a, const float *b, float *c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}
void launch(void) { cudaMalloc((void**)0, 0); }
SRC

  # Fixture B: a __user + MODULE_LICENSE file -> kernel pack.
  mkdir -p "$tmp/kernel/drivers"
  cat >"$tmp/kernel/drivers/foo.c" <<'SRC'
#include <linux/module.h>
long do_ioctl(void __user *arg) {
    char buf[16];
    if (copy_from_user(buf, arg, sizeof(buf)))
        return -1;
    return 0;
}
MODULE_LICENSE("GPL");
SRC

  # Fixture C: a plain repo -> unknown-domain.
  mkdir -p "$tmp/plain/src"
  cat >"$tmp/plain/src/main.c" <<'SRC'
#include <stdio.h>
int main(void) {
    printf("hello\n");
    return 0;
}
SRC

  # Fixture D (F2c regression): a SIMD/HPC repo whose ONLY build flag is
  # `-ffast-math` plus `_mm_*` intrinsics. The HPC pack regex begins with a dash;
  # before the `-e` fix rg parsed `-f` as `--file` and the pack silently vanished
  # (cglm-class miss). This fixture must select HPC.
  mkdir -p "$tmp/hpc"
  cat >"$tmp/hpc/CMakeLists.txt" <<'SRC'
add_compile_options(-ffast-math -march=native)
SRC
  cat >"$tmp/hpc/simd.c" <<'SRC'
#include <immintrin.h>
void axpy(float *y, const float *x, float a, int n) {
    __m128 va = _mm_set1_ps(a);
    for (int i = 0; i < n; i += 4) {
        __m128 vx = _mm_loadu_ps(x + i);
        __m128 vy = _mm_loadu_ps(y + i);
        _mm_storeu_ps(y + i, _mm_add_ps(vy, _mm_mul_ps(va, vx)));
    }
}
SRC

  # Fixture P (F2a parser): a JSON parser. Named format + *_parse API -> Parser.
  mkdir -p "$tmp/parser"
  cat >"$tmp/parser/jsonparse.c" <<'SRC'
#include "jsonparse.h"
int json_parse(const char *buf, size_t len, struct json_token *out) {
    if (len == 0) return -1;          /* validate length before read */
    return parse_value(buf, len, out);
}
int parse_value(const char *buf, size_t len, struct json_token *out) {
    return tokenize_json(buf, len, out);
}
SRC

  # Fixture G (F2a generic + F2b ranking): a header-only container library that
  # ALSO carries exactly one incidental `__attribute__((__packed__))` (the
  # klib/sds misfire). It must select Generic, and the single packed-struct hit
  # must NOT promote a confident "Networking" pack.
  mkdir -p "$tmp/generic"
  cat >"$tmp/generic/vec.h" <<'SRC'
#ifndef VEC_H
#define VEC_H
typedef struct vec_s { int *data; size_t len, cap; } vec_t;
struct __attribute__((__packed__)) vec_hdr { unsigned char tag; };
static inline vec_t *vec_init(void) { return calloc(1, sizeof(vec_t)); }
static inline void vec_free(vec_t *v) { free(v->data); free(v); }
static inline void vec_destroy(vec_t *v) { vec_free(v); }
#endif
SRC

  # Fixture K (F2b comment-stripping): domain tokens appear ONLY in comments.
  # They must be stripped, leaving no confident pack -> unknown-domain.
  mkdir -p "$tmp/comments"
  cat >"$tmp/comments/util.c" <<'SRC'
/* This converts a left-handed coordinate system to right-handed. */
/* It does not use crypto_box or any EVP_ routine; see the ring buffer note. */
// htons() is mentioned here only in prose, not called.
int util_clamp(int x, int lo, int hi) {
    return x < lo ? lo : (x > hi ? hi : x);
}
SRC

  # Fixture Z (R8 case-fold SPACE FP): a zlib-like compression lib whose ONLY
  # "SPACE" tokens are the gzip RFC-1952 header byte `OS_CODE` (uppercase) and a
  # lowercase `os_flush()` C++ method. Case-INSENSITIVE matching let `\bOS_[A-Z]`
  # match both → SPACE won PRIMARY on a compression lib. With the case-sensitive
  # `OS_(?!CODE\b)` token, NEITHER matches, so the repo must NOT be SPACE-primary.
  mkdir -p "$tmp/zlibish"
  cat >"$tmp/zlibish/zutil.h" <<'SRC'
#ifndef ZUTIL_H
#define ZUTIL_H
#  define OS_CODE  0x03   /* gzip OS identifier byte (RFC 1952) */
int inflate(void *strm, int flush);
int deflate(void *strm, int flush);
int compress(unsigned char *dest, unsigned long *destLen);
#endif
SRC
  cat >"$tmp/zlibish/zstream.cc" <<'SRC'
class ozstream {
  void os_flush() { /* lowercase OS_ should not be a SPACE token */ }
  unsigned char *buf_init(void) { return 0; }
};
SRC

  # Fixture C (R8 real SPACE survives): a cFS-like flight-software repo using the
  # genuine NASA uppercase API `CFE_*` and `OS_*` (NOT OS_CODE). It MUST stay
  # SPACE-primary under case-sensitive matching.
  mkdir -p "$tmp/cfsish/fsw"
  cat >"$tmp/cfsish/fsw/cfe_es.c" <<'SRC'
#include "cfe_es.h"
int32 CFE_ES_RegisterApp(void) {
    OS_TaskCreate(0, "APP", 0, 0, 0, 0);
    OS_printf("registered\n");
    return CFE_ES_RunLoop(0);
}
int32 CFE_EVS_SendEvent(uint16 id) { return OS_MAX_API_LEN + id; }
SRC

  # Fixture F (R8 opcode + R3+ CamelCase test dir): an F´-like repo. The Compilers
  # signal must come ONLY from a CamelCase `FppTestProject/` test dir (excluded by
  # R3+) plus the CamelCase TYPE `FwOpcodeType` (which case-sensitive `\bopcode\b`
  # must NOT match). The shipped code carries genuine SPACE `OS_*`/`CFE_*` tokens.
  # Net: SPACE must win PRIMARY; the `FwOpcodeType`/test-dir Compilers signal must
  # NOT steal it (was: Compilers-primary off `\bopcode\b` matching `FwOpcodeType`).
  mkdir -p "$tmp/fprimeish/Svc/Cmd" "$tmp/fprimeish/FppTestProject/FppTest"
  cat >"$tmp/fprimeish/Svc/Cmd/CmdDispatcher.cpp" <<'SRC'
#include "CmdDispatcher.hpp"
void CmdDispatcher::dispatch(FwOpcodeType opCode) {
    OS_TaskDelay(1);
    CFE_SB_TransmitMsg(opCode);
}
SRC
  cat >"$tmp/fprimeish/FppTestProject/FppTest/Driver.cpp" <<'SRC'
/* Test-only driver: opcode opcode opcode bytecode interpreter codegen llvm:: */
void run_opcode_interpreter() { /* opcode bytecode codegen interpreter */ }
SRC

  # Fixture COMP (R9-vocab): a zlib/lz4-like compression codec. Its defining
  # vocabulary (`deflate`/`inflate`/`compress`/`crc32`/`LZ4_`/`huffman`) must select
  # the NEW Compression pack as PRIMARY — before R9-vocab there was no compression
  # pack, so zlib mis-primaried Networking and lz4 mis-primaried Parser. The file
  # also carries the codec identifier `decode_full_block`: the NARROWED Parser
  # `_decode` token (now format/parser-prefixed) must NOT match it, so Parser does
  # not steal a codec.
  mkdir -p "$tmp/codec/lib"
  cat >"$tmp/codec/lib/deflate.c" <<'SRC'
#include "deflate.h"
typedef enum { decode_full_block = 0, partial_decode = 1 } earlyEnd_directive;
int deflate(void *strm, int flush) { return huffman_encode(strm); }
int inflate(void *strm, int flush) { return LZ4_decompress_safe(strm, flush); }
int inflateBack(void *strm) { return 0; }
int compress(unsigned char *dest, unsigned long *destLen) { return 0; }
int uncompress(unsigned char *dest, unsigned long *srcLen) { return 0; }
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned len) { return crc; }
unsigned long adler32(unsigned long adler, const unsigned char *buf, unsigned len) { return adler; }
SRC
  cat >"$tmp/codec/lib/lz4.h" <<'SRC'
#ifndef LZ4_H
#define LZ4_H
int LZ4_compress_default(const char *src, char *dst, int srcSize, int dstCap);
int LZ4_decompress_safe(const char *src, char *dst, int compressedSize, int dstCap);
#endif
SRC

  # Fixture NET (R9-vocab): a messaging/transport library using the socket/listener/
  # dialer/send/recv idiom — the vocabulary nng is built on. Before R9-vocab the
  # Networking pack only knew ntohl/htons/packed-struct/RFC and scored ~9 on nng,
  # losing PRIMARY to Parser. It must now select Networking PRIMARY.
  mkdir -p "$tmp/net/src"
  cat >"$tmp/net/src/transport.c" <<'SRC'
#include "transport.h"
int sock_open(void) {
    int s = socket(2, 1, 0);
    bind(s, 0, 0);
    listen(s, 5);
    int c = accept(s, 0, 0);
    connect(c, 0, 0);
    send(c, "x", 1, 0);
    recv(c, 0, 0, 0);
    return c;
}
SRC
  cat >"$tmp/net/src/dialer.c" <<'SRC'
#include "dialer.h"
struct listener { int fd; };
struct dialer { int fd; };
void endpoint_init(struct listener *l, struct dialer *d) { (void)l; (void)d; }
SRC

  # Fixture CRY (R9-vocab): a hash/cipher library (blake2-like) whose identity is the
  # primitive names `blake2`/`sha256`/`hmac`/`digest`/`chacha`/`poly1305`/`nonce`,
  # NOT the constant-time/EVP_/FIPS engineering signals. Before R9-vocab a textbook
  # hash lib scored ~10 Crypto (incidental `test.vector`) and lost PRIMARY to HPC off
  # its own SIMD intrinsics. It must now select Crypto PRIMARY.
  mkdir -p "$tmp/cipher"
  cat >"$tmp/cipher/blake2b.c" <<'SRC'
#include "blake2.h"
int blake2b_update(void *S, const void *in, unsigned long inlen) { return 0; }
int blake2b_final(void *S, void *out, unsigned long outlen) { return 0; }
void chacha20_block(unsigned char *keystream, const unsigned char *nonce) { (void)nonce; }
int poly1305_mac(unsigned char *digest, const unsigned char *m) { return 0; }
int hmac_sha256(unsigned char *out, const unsigned char *key) { return 0; }
SRC

  # Fixture FP2 (R9-vocab): an F´/F-Prime flight repo whose vocabulary is fprime's
  # own — `CCSDS`/`Framer`/`Deframer`/`Tlm`/`APID`/`FwOpcode`/`CmdResponse`/`telemetry`
  # — NOT cFE's `OS_*`/`CFE_*`. Before R9-vocab the Space pack was cFE-tuned and blind
  # to F´, so fprime barely cleared Space on incidental `OS_[A-Z]` collisions. It must
  # select Space PRIMARY off the F´ vocabulary alone (no OS_/CFE_ tokens here).
  mkdir -p "$tmp/fprime2/Svc/ComFramer"
  cat >"$tmp/fprime2/Svc/ComFramer/Framer.cpp" <<'SRC'
#include "Framer.hpp"
void Framer::frame(FwOpcodeType opCode) {
    CCSDS_Header hdr;
    hdr.APID = 0x10;
    Deframer deframer;
    TlmChan telemetry;
    CmdResponse resp;
    (void)opCode; (void)hdr; (void)deframer; (void)telemetry; (void)resp;
}
SRC

  # Fixture DB (R12): a storage engine whose identity is SQL/btree/pager/WAL/vdbe/
  # rowid/PRAGMA + redis RDB/AOF/keyspace + LSM compaction/memtable/manifest. Before
  # R12 the Databases pack knew only fsync/WAL/MVCC/pwrite, so sqlite mis-primaried
  # Parser and redis Networking (DB ranked last). It must now select Databases PRIMARY.
  # It ALSO carries one Parser-ish `json_parse` and one Net `socket` so the win is by
  # the DB vocabulary mass, not by being the only pack present.
  mkdir -p "$tmp/db/src"
  cat >"$tmp/db/src/btree.c" <<'SRC'
#include "btree.h"
int sqlite3BtreeOpen(Pager *pPager, int rowid) {
    /* btree pager + WAL + vdbe + rowid + write-ahead log */
    return pPager->pageCache;
}
int sqlite3VdbeExec(void *p) { return 0; }       /* vdbe opcode dispatch */
int rdbSaveRio(void *rdb) { return 0; }           /* redis RDB snapshot */
int aofRewrite(void *aof) { return 0; }           /* redis AOF write-ahead */
int compactMemtable(void *memtable) { return 0; } /* LSM compaction + memtable */
int loadManifest(void *manifest) { return 0; }    /* LSM manifest + sstable */
int doVacuum(void *db) { return 0; }              /* VACUUM */
int beginTransaction(void *db) { return 0; }      /* transaction + commit + rollback */
int json_parse(const char *s) { return 0; }       /* one Parser token (must lose) */
int sock_open(void) { return socket(2, 1, 0); }   /* one Net token (must lose) */
SRC
  cat >"$tmp/db/src/pragma.c" <<'SRC'
#include "pragma.h"
/* SQL PRAGMA handler. PRAGMA is the SQL keyword (case-sensitive), NOT C #pragma. */
int sqlite3Pragma(void *p) { return 0; }
int keyspaceNotify(void *db) { return 0; }   /* redis keyspace */
SRC

  # Fixture DBPRAGMA (R12 over-correction guard): a C++ header that uses `#pragma
  # once`/`#pragma clang` (the C PREPROCESSOR directive) MANY times but has ZERO real
  # DB code. The bare-`pragma` token had matched every `#pragma`, handing a test
  # framework (Catch2) a false Databases primary off 228 `#pragma`s. The case-sensitive
  # `(?-i:PRAGMA|Pragma)` token must NOT match lowercase `#pragma`, so this repo must
  # NOT be Databases-primary (it is a generic parser-ish lib instead).
  mkdir -p "$tmp/pragmaonly"
  cat >"$tmp/pragmaonly/widget.hpp" <<'SRC'
#pragma once
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wfoo"
#pragma once
class Widget { public: int json_decode(const char *s); };
int xml_parse(const char *s);
int parse_token(const char *s);
SRC

  # Fixture DATA (R13): a JS-engine-like Compilers repo (opcode/bytecode/interpreter/
  # codegen + lexer) that ALSO ships a Unicode DATA TABLE `UnicodeData.txt` full of
  # "CYRILLIC LETTER SHA" rows and a `Makefile` with a `# SHA1: …` checksum comment.
  # Before R13 the `\bsha\b` Crypto token matched the data table + Makefile comment and
  # Crypto stole PRIMARY (the duktape failure). With the data-file skip + `#`-comment
  # strip in non-C files, this must select Compilers/interpreters/VMs, NOT Crypto.
  mkdir -p "$tmp/jsvm/src-input"
  cat >"$tmp/jsvm/src-input/compiler.c" <<'SRC'
#include "compiler.h"
int interpreter_dispatch(int opcode, void *bytecode) {
    return codegen(opcode, bytecode);
}
int codegen(int opcode, void *bytecode) { return emitOpcode(opcode); }
int interpreter_step(void *vm) { return 0; }
int bytecode_verify(void *vm) { return 0; }
SRC
  cat >"$tmp/jsvm/src-input/UnicodeData.txt" <<'SRC'
0428;CYRILLIC CAPITAL LETTER SHA;Lu;0;L;;;;;N;;;;0448;
0429;CYRILLIC CAPITAL LETTER SHCHA;Lu;0;L;;;;;N;;;;0449;
0531;ARMENIAN CAPITAL LETTER SHA;Lu;0;L;;;;;N;;;;0561;
SRC
  cat >"$tmp/jsvm/Makefile" <<'MK'
# SHA1: 774be8b65b9b3d2b8b8d md5 digest sha256 hmac nonce blake2 chacha
all:
	$(CC) -c compiler.c
MK

  # Fixture CATCH (R11): a vendored TEST FRAMEWORK that IS the audited repo — its own
  # source lives under `src/catch2/` (the basename the old `!**/catch2/**` glob excluded
  # everywhere). The anchored R11 glob excludes a vendored catch2 only under a vendored
  # parent, so the framework's OWN `src/catch2/` MUST now be scanned (a real risk/code
  # signal must appear from it). A SEPARATE embedded copy under `tests/vendor/catch2/`
  # carries a DECOY token that must STILL be excluded.
  mkdir -p "$tmp/catchfw/src/catch2" "$tmp/catchfw/tests/vendor/catch2"
  cat >"$tmp/catchfw/src/catch2/catch_tostring.cpp" <<'SRC'
#include "catch_tostring.hpp"
/* the framework's own shipped source must be scannable */
int xml_parse(const char *s) { return parse_token(s); }
int parse_token(const char *s) { return 0; }
int json_decode(const char *s) { return 0; }
SRC
  cat >"$tmp/catchfw/tests/vendor/catch2/embedded.cpp" <<'SRC'
/* an EMBEDDED vendored copy under tests/vendor/ — must STILL be excluded */
__global__ void decoy_kernel(void) { cudaMalloc(0, 0); }
SRC

  # Fixture DEPS (R10): a pure-C parser repo whose OWN `src/` is a small JSON parser,
  # but which bundles a large vendored library under the bare `deps/` dir (the redis
  # convention) plus a `singleheader/` amalgam and an `autosetup/jimsh0.c` bootstrap
  # interpreter. Before R10 those vendored trees outvoted the real `src/` signal. The
  # repo's primary must come from `src/` (Parser), and NO anchor may point into deps/,
  # singleheader/, or autosetup/jimsh0.c.
  mkdir -p "$tmp/depsrepo/src" "$tmp/depsrepo/deps/jimtcl" \
           "$tmp/depsrepo/singleheader" "$tmp/depsrepo/autosetup"
  cat >"$tmp/depsrepo/src/json.c" <<'SRC'
#include "json.h"
int json_parse(const char *buf, int len) { return parse_value(buf, len); }
int parse_value(const char *buf, int len) { return tokenize_json(buf, len); }
SRC
  # Vendored bundle: a huge interpreter amalgam that would mis-primary Compilers/VMs.
  cat >"$tmp/depsrepo/deps/jimtcl/jim.c" <<'SRC'
int jim_opcode_interpreter_bytecode_codegen(void) { return 0; }
int jim_opcode_two(void) { return 0; }
int jim_interpreter_three(void) { return 0; }
SRC
  cat >"$tmp/depsrepo/singleheader/amalgam.h" <<'SRC'
int opcode_bytecode_interpreter_codegen_amalgam(void) { return 0; }
SRC
  cat >"$tmp/depsrepo/autosetup/jimsh0.c" <<'SRC'
/* bootstrap version of Jim Tcl */
int jimsh_opcode_bytecode_interpreter(void) { return 0; }
SRC

  local gpu_out kernel_out plain_out hpc_out parser_out generic_out comments_out
  local zlibish_out cfsish_out fprimeish_out
  local codec_out net_out cry_out fp2_out
  local db_out pragmaonly_out data_out catch_out deps_out
  gpu_out="$(run_detect "$tmp/gpu" no)"
  kernel_out="$(run_detect "$tmp/kernel" no)"
  plain_out="$(run_detect "$tmp/plain" no)"
  hpc_out="$(run_detect "$tmp/hpc" no)"
  parser_out="$(run_detect "$tmp/parser" no)"
  generic_out="$(run_detect "$tmp/generic" no)"
  comments_out="$(run_detect "$tmp/comments" no)"
  zlibish_out="$(run_detect "$tmp/zlibish" no)"
  cfsish_out="$(run_detect "$tmp/cfsish" no)"
  fprimeish_out="$(run_detect "$tmp/fprimeish" no)"
  codec_out="$(run_detect "$tmp/codec" no)"
  net_out="$(run_detect "$tmp/net" no)"
  cry_out="$(run_detect "$tmp/cipher" no)"
  fp2_out="$(run_detect "$tmp/fprime2" no)"
  db_out="$(run_detect "$tmp/db" no)"
  pragmaonly_out="$(run_detect "$tmp/pragmaonly" no)"
  data_out="$(run_detect "$tmp/jsvm" no)"
  catch_out="$(run_detect "$tmp/catchfw" no)"
  deps_out="$(run_detect "$tmp/depsrepo" no)"

  # Assertion 1: the CUDA fixture selects the GPU pack as primary, anchored to
  # the .cu file. Output format: "pack[<role>]: <label> | <anchor> (N code matches)".
  if ! printf '%s\n' "$gpu_out" | grep -qE 'pack\[primary\]: GPU \(CUDA / SYCL / HIP\) \| src/kernel\.cu:[0-9]+ \([0-9]+ code matches\)'; then
    printf 'cpp_domain_detect self-test: FAIL (CUDA fixture did not select GPU pack)\n'
    printf '%s\n%s\n' '--- gpu ---' "$gpu_out"
    exit 1
  fi
  # Assertion 2: the kernel fixture selects the Kernel pack, anchored to foo.c.
  if ! printf '%s\n' "$kernel_out" | grep -qE 'pack\[primary\]: Kernel / drivers \| drivers/foo\.c:[0-9]+'; then
    printf 'cpp_domain_detect self-test: FAIL (kernel fixture did not select Kernel pack)\n'
    printf '%s\n%s\n' '--- kernel ---' "$kernel_out"
    exit 1
  fi
  # Assertion 3: the plain fixture reports unknown-domain.
  if ! printf '%s\n' "$plain_out" | grep -qF 'unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md'; then
    printf 'cpp_domain_detect self-test: FAIL (plain repo did not report unknown-domain)\n'
    printf '%s\n%s\n' '--- plain ---' "$plain_out"
    exit 1
  fi
  # Assertion 4: plain fixture must NOT print any pack line.
  if printf '%s\n' "$plain_out" | grep -q '^pack\['; then
    printf 'cpp_domain_detect self-test: FAIL (plain repo matched a pack it should not)\n'
    printf '%s\n%s\n' '--- plain ---' "$plain_out"
    exit 1
  fi
  # Assertion 5 (no absolute paths leak): outputs must not contain the temp dir.
  local out
  for out in "$gpu_out" "$kernel_out" "$plain_out" "$hpc_out" \
             "$parser_out" "$generic_out" "$comments_out" \
             "$zlibish_out" "$cfsish_out" "$fprimeish_out" \
             "$codec_out" "$net_out" "$cry_out" "$fp2_out" \
             "$db_out" "$pragmaonly_out" "$data_out" "$catch_out" "$deps_out"; do
    if printf '%s\n' "$out" | grep -qF "$tmp"; then
      printf 'cpp_domain_detect self-test: FAIL (absolute path leaked into output)\n'
      printf '%s\n%s\n' '--- out ---' "$out"
      exit 1
    fi
  done

  # -------------------------------------------------------------------------
  # R8 assertions: case-sensitive distinctive uppercase-API tokens.
  # -------------------------------------------------------------------------
  # R8.1: the zlib-like compression fixture must NOT be SPACE-primary — its only
  # SPACE-shaped tokens are the gzip `OS_CODE` and lowercase `os_flush`, which the
  # case-sensitive `OS_(?!CODE\b)`/`OS_API` tokens no longer match.
  if printf '%s\n' "$zlibish_out" | grep -qE 'pack\[primary\]: Space / satellites'; then
    printf 'cpp_domain_detect self-test: FAIL (R8: OS_CODE/os_flush case-fold made a compression lib SPACE-primary)\n'
    printf '%s\n%s\n' '--- zlibish ---' "$zlibish_out"
    exit 1
  fi
  # R9-vocab strengthens R8.1: the inflate/deflate/compress vocabulary now selects
  # the Compression pack as PRIMARY (not merely "not SPACE") — the honest classifier
  # for a compression lib, locking zlib's Networking->Compression reclassification.
  if ! printf '%s\n' "$zlibish_out" | grep -qE 'pack\[primary\]: Compression / codec'; then
    printf 'cpp_domain_detect self-test: FAIL (R9-vocab: zlib-like fixture did not select Compression primary)\n'
    printf '%s\n%s\n' '--- zlibish ---' "$zlibish_out"
    exit 1
  fi
  # R8.2: the cFS-like fixture (real CFE_/OS_ API, no OS_CODE) MUST stay SPACE-primary.
  if ! printf '%s\n' "$cfsish_out" | grep -qE 'pack\[primary\]: Space / satellites'; then
    printf 'cpp_domain_detect self-test: FAIL (R8 over-correction: real cFS CFE_/OS_ repo lost SPACE-primary)\n'
    printf '%s\n%s\n' '--- cfsish ---' "$cfsish_out"
    exit 1
  fi
  # R8.3: the F´-like fixture must be SPACE-primary, NOT Compilers — the CamelCase
  # `FwOpcodeType` TYPE must not match the now-case-sensitive `\bopcode\b`, and the
  # `opcode/bytecode/interpreter` prose lives in a CamelCase `FppTestProject/` test
  # dir excluded by R3+. SPACE must not be lost to a bare opcode match.
  if ! printf '%s\n' "$fprimeish_out" | grep -qE 'pack\[primary\]: Space / satellites'; then
    printf 'cpp_domain_detect self-test: FAIL (R8/R3+: F´ Space lost to a FwOpcodeType/test-dir Compilers match)\n'
    printf '%s\n%s\n' '--- fprimeish ---' "$fprimeish_out"
    exit 1
  fi
  # R3+: no anchor may point into the excluded CamelCase FppTestProject/ test dir.
  if printf '%s\n' "$fprimeish_out" | grep -qE 'FppTestProject/'; then
    printf 'cpp_domain_detect self-test: FAIL (R3+: CamelCase FppTestProject/ test dir not excluded)\n'
    printf '%s\n%s\n' '--- fprimeish ---' "$fprimeish_out"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # R9-vocab assertions: each reclassification proved on the real cloned repos
  # (zlib/lz4 -> Compression, nng -> Networking, blake2 -> Crypto, fprime -> Space)
  # is locked here on a synthetic fixture carrying the same defining vocabulary.
  # -------------------------------------------------------------------------
  # R9.1: the codec fixture selects the NEW Compression pack as PRIMARY off
  # deflate/inflate/compress/crc32/LZ4_/huffman (zlib mis-primaried Networking,
  # lz4 mis-primaried Parser before the pack existed).
  if ! printf '%s\n' "$codec_out" | grep -qE 'pack\[primary\]: Compression / codec \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R9-vocab: codec fixture did not select Compression pack)\n'
    printf '%s\n%s\n' '--- codec ---' "$codec_out"
    exit 1
  fi
  # R9.2: the narrowed Parser `_decode` token must NOT fire on the codec
  # identifier `decode_full_block`/`partial_decode` -> the codec is not Parser.
  if printf '%s\n' "$codec_out" | grep -qE 'pack\[primary\]: Parser'; then
    printf 'cpp_domain_detect self-test: FAIL (R9-vocab: narrowed _decode token still snagged a codec into Parser)\n'
    printf '%s\n%s\n' '--- codec ---' "$codec_out"
    exit 1
  fi
  # R9.3: the messaging fixture selects Networking PRIMARY off the
  # socket/listener/dialer/send/recv idiom (nng lost to Parser before).
  if ! printf '%s\n' "$net_out" | grep -qE 'pack\[primary\]: Networking / protocols \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R9-vocab: socket/listener/dialer fixture did not select Networking)\n'
    printf '%s\n%s\n' '--- net ---' "$net_out"
    exit 1
  fi
  # R9.4: the hash/cipher fixture selects Crypto PRIMARY off primitive names
  # (blake2/sha256/hmac/chacha/poly1305/nonce/digest), not HPC (blake2 lost to HPC).
  if ! printf '%s\n' "$cry_out" | grep -qE 'pack\[primary\]: Crypto \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R9-vocab: hash/cipher fixture did not select Crypto)\n'
    printf '%s\n%s\n' '--- cipher ---' "$cry_out"
    exit 1
  fi
  # R9.5: the F´/F-Prime fixture selects Space PRIMARY off the fprime vocabulary
  # (CCSDS/Framer/Deframer/Tlm/APID/FwOpcode/CmdResponse) with NO cFE OS_/CFE_
  # tokens present — the Space pack was cFE-tuned and blind to F´ before.
  if ! printf '%s\n' "$fp2_out" | grep -qE 'pack\[primary\]: Space / satellites \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R9-vocab: F´ CCSDS/Framer/Tlm/APID fixture did not select Space)\n'
    printf '%s\n%s\n' '--- fprime2 ---' "$fp2_out"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # R12 assertions: the enriched Databases vocabulary wins PRIMARY on a storage
  # engine (sqlite→Databases, redis→Databases, leveldb→Databases on the real repos).
  # -------------------------------------------------------------------------
  # R12.1: the storage-engine fixture selects Databases PRIMARY off the SQL/btree/
  # pager/WAL/vdbe/rowid/PRAGMA + RDB/AOF/keyspace + LSM compaction/memtable vocab,
  # beating the single incidental Parser/Net tokens it also carries.
  if ! printf '%s\n' "$db_out" | grep -qE 'pack\[primary\]: Databases / storage engines \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R12: storage-engine vocab fixture did not select Databases)\n'
    printf '%s\n%s\n' '--- db ---' "$db_out"
    exit 1
  fi
  # R12.2 (over-correction guard): the case-sensitive `(?-i:PRAGMA|Pragma)` token must
  # NOT match the C PREPROCESSOR `#pragma once`/`#pragma clang` — a header full of
  # `#pragma`s but no DB code must NOT be Databases-primary (the Catch2 false-DB case).
  if printf '%s\n' "$pragmaonly_out" | grep -qE 'pack\[primary\]: Databases'; then
    printf 'cpp_domain_detect self-test: FAIL (R12: lowercase #pragma matched the SQL PRAGMA token → false Databases primary)\n'
    printf '%s\n%s\n' '--- pragmaonly ---' "$pragmaonly_out"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # R13 assertions: data-file skip + `#`-comment strip keep a Crypto data-table/
  # build-comment from stealing PRIMARY from the real Compilers/VM domain (duktape).
  # -------------------------------------------------------------------------
  # R13.1: the JS-VM fixture selects Compilers/interpreters/VMs, NOT Crypto — the
  # `\bsha\b` hits live only in the skipped `UnicodeData.txt` data table and a
  # `#`-stripped `Makefile` checksum comment.
  if ! printf '%s\n' "$data_out" | grep -qE 'pack\[primary\]: Compilers / interpreters / VMs \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R13: JS-VM fixture did not select Compilers — data-table/Makefile SHA leaked)\n'
    printf '%s\n%s\n' '--- jsvm ---' "$data_out"
    exit 1
  fi
  # R13.2: the JS-VM fixture must NOT be Crypto-primary (the duktape failure mode).
  if printf '%s\n' "$data_out" | grep -qE 'pack\[primary\]: Crypto'; then
    printf 'cpp_domain_detect self-test: FAIL (R13: Crypto stole primary off UnicodeData.txt "LETTER SHA" / Makefile # SHA1)\n'
    printf '%s\n%s\n' '--- jsvm ---' "$data_out"
    exit 1
  fi
  # R13.3: no anchor may point into the skipped UnicodeData.txt data table.
  if printf '%s\n' "$data_out" | grep -qE 'UnicodeData\.txt'; then
    printf 'cpp_domain_detect self-test: FAIL (R13: UnicodeData.txt data table counted as a code signal)\n'
    printf '%s\n%s\n' '--- jsvm ---' "$data_out"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # R11 assertions: vendored-framework globs anchored to vendored locations — the
  # framework's OWN `src/catch2/` is scanned; an embedded copy under tests/ is not.
  # -------------------------------------------------------------------------
  # R11.1: the framework's own `src/catch2/` source IS now scanned — its tokens
  # (xml_parse/parse_token/json_decode) make a real pack fire anchored to src/catch2/.
  if ! printf '%s\n' "$catch_out" | grep -qE 'src/catch2/'; then
    printf 'cpp_domain_detect self-test: FAIL (R11: framework own src/catch2/ self-excluded — never scanned)\n'
    printf '%s\n%s\n' '--- catchfw ---' "$catch_out"
    exit 1
  fi
  # R11.2: the EMBEDDED vendored copy under tests/vendor/catch2/ must STILL be excluded
  # (its decoy `__global__`/cudaMalloc must NOT make the repo GPU-primary).
  if printf '%s\n' "$catch_out" | grep -qE 'tests/vendor/catch2/|pack\[primary\]: GPU'; then
    printf 'cpp_domain_detect self-test: FAIL (R11: embedded tests/vendor/catch2/ copy not excluded)\n'
    printf '%s\n%s\n' '--- catchfw ---' "$catch_out"
    exit 1
  fi

  # -------------------------------------------------------------------------
  # R10 assertions: bare deps/ + singleheader/ + autosetup/jimsh0.c vendored trees
  # are excluded so the repo's OWN src/ decides the primary (sqlite/redis/simdjson).
  # -------------------------------------------------------------------------
  # R10.1: the deps-bundling repo selects Parser off its OWN src/ JSON parser, NOT
  # Compilers/VMs off the vendored jim.c/jimsh0.c/amalgam interpreter bundle.
  if ! printf '%s\n' "$deps_out" | grep -qE 'pack\[primary\]: Parser / text-format / serialization \|'; then
    printf 'cpp_domain_detect self-test: FAIL (R10: vendored deps/jimsh0/singleheader outvoted the real src/ primary)\n'
    printf '%s\n%s\n' '--- depsrepo ---' "$deps_out"
    exit 1
  fi
  # R10.2: NO anchor may point into deps/, singleheader/, or autosetup/jimsh0.c.
  if printf '%s\n' "$deps_out" | grep -qE 'deps/|singleheader/|autosetup/|jimsh0\.c'; then
    printf 'cpp_domain_detect self-test: FAIL (R10: a vendored deps/singleheader/autosetup/jimsh0 anchor leaked)\n'
    printf '%s\n%s\n' '--- depsrepo ---' "$deps_out"
    exit 1
  fi

  # Assertion 6: reproducibility - two consecutive runs byte-match.
  local gpu_out2
  gpu_out2="$(run_detect "$tmp/gpu" no)"
  if [ "$gpu_out" != "$gpu_out2" ]; then
    printf 'cpp_domain_detect self-test: FAIL (two runs did not byte-match)\n'
    diff <(printf '%s\n' "$gpu_out") <(printf '%s\n' "$gpu_out2") || true
    exit 1
  fi

  # Assertion 8 (F2c): the HPC fixture selects HPC. This is the leading-dash
  # `-ffast-math` regression; before the `-e` fix it produced unknown-domain.
  if ! printf '%s\n' "$hpc_out" | grep -qE 'pack\[primary\]: HPC / SIMD / numerics \|'; then
    printf 'cpp_domain_detect self-test: FAIL (HPC -ffast-math/_mm_ fixture did not select HPC: F2c regression)\n'
    printf '%s\n%s\n' '--- hpc ---' "$hpc_out"
    exit 1
  fi
  # Assertion 9 (F2a): the JSON-parser fixture selects the Parser pack as primary.
  if ! printf '%s\n' "$parser_out" | grep -qE 'pack\[primary\]: Parser / text-format / serialization \|'; then
    printf 'cpp_domain_detect self-test: FAIL (JSON parser fixture did not select Parser pack)\n'
    printf '%s\n%s\n' '--- parser ---' "$parser_out"
    exit 1
  fi
  # Assertion 10 (F2a): the container fixture selects Generic as primary.
  if ! printf '%s\n' "$generic_out" | grep -qE 'pack\[primary\]: Generic library / data-structures / strings \|'; then
    printf 'cpp_domain_detect self-test: FAIL (container fixture did not select Generic pack)\n'
    printf '%s\n%s\n' '--- generic ---' "$generic_out"
    exit 1
  fi
  # Assertion 11 (F2b): the single incidental `__packed__` in the container
  # fixture must NOT classify it as Networking (the klib/sds misfire).
  if printf '%s\n' "$generic_out" | grep -qi 'Networking'; then
    printf 'cpp_domain_detect self-test: FAIL (single __packed__ hit misclassified as Networking: F2b)\n'
    printf '%s\n%s\n' '--- generic ---' "$generic_out"
    exit 1
  fi
  # Assertion 12 (F2b): domain tokens that appear only in comments are stripped,
  # so the comment-only fixture reports unknown-domain (no Crypto/Audio/Net pack).
  if ! printf '%s\n' "$comments_out" | grep -qF 'unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md'; then
    printf 'cpp_domain_detect self-test: FAIL (comment-only tokens were not stripped: F2b)\n'
    printf '%s\n%s\n' '--- comments ---' "$comments_out"
    exit 1
  fi
  # Assertion 13 (F2b reproducibility on a ranked output): the HPC fixture's
  # ranked output must byte-match across two consecutive runs.
  local hpc_out2
  hpc_out2="$(run_detect "$tmp/hpc" no)"
  if [ "$hpc_out" != "$hpc_out2" ]; then
    printf 'cpp_domain_detect self-test: FAIL (ranked HPC output not reproducible)\n'
    diff <(printf '%s\n' "$hpc_out") <(printf '%s\n' "$hpc_out2") || true
    exit 1
  fi

  # Assertion 7: JSON mode is well-formed for a match and a non-match.
  local gpu_js plain_js
  gpu_js="$(run_detect "$tmp/gpu" yes)"
  plain_js="$(run_detect "$tmp/plain" yes)"
  case "$gpu_js" in
    \{*\}) : ;;
    *)
      printf 'cpp_domain_detect self-test: FAIL (JSON mode did not emit an object)\n'
      printf '%s\n%s\n' '--- json ---' "$gpu_js"
      exit 1
      ;;
  esac
  if ! printf '%s\n' "$gpu_js" | grep -qF '"matched": true'; then
    printf 'cpp_domain_detect self-test: FAIL (JSON match did not set matched=true)\n'
    printf '%s\n%s\n' '--- json ---' "$gpu_js"
    exit 1
  fi
  if ! printf '%s\n' "$plain_js" | grep -qF '"matched": false'; then
    printf 'cpp_domain_detect self-test: FAIL (JSON non-match did not set matched=false)\n'
    printf '%s\n%s\n' '--- json ---' "$plain_js"
    exit 1
  fi
  if printf '%s\n' "$gpu_js" | grep -qF "$tmp"; then
    printf 'cpp_domain_detect self-test: FAIL (absolute path leaked into JSON)\n'
    printf '%s\n%s\n' '--- json ---' "$gpu_js"
    exit 1
  fi

  printf 'cpp_domain_detect self-test: PASS\n'
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

  run_detect "$repo" "$json"
}

main "$@"
