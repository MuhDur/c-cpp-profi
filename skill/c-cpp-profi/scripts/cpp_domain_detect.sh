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
rg_signal() {
  local mode="${3:-all}"
  local file_globs=(--glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx,cu,cuh,cl}')
  if [ "$mode" = all ]; then
    file_globs+=(
      --glob '*.{cmake,build,mk,txt,json,yml,yaml,ld,ini}'
      --glob 'CMakeLists.txt' --glob 'Makefile' --glob 'GNUmakefile'
      --glob 'meson.build' --glob 'Kconfig' --glob 'Kbuild'
    )
  fi
  rg -ni --no-heading --no-messages \
    "${file_globs[@]}" \
    --glob '!**/.git/**' \
    --glob '!**/build/**' \
    --glob '!**/_deps/**' \
    --glob '!**/third_party/**' \
    --glob '!**/thirdparty/**' \
    --glob '!**/vendor/**' \
    --glob '!**/extern/**' \
    --glob '!**/external/**' \
    --glob '!**/tests/**' \
    --glob '!**/test/**' \
    --glob '!**/docs/**' \
    --glob '!**/doc/**' \
    --glob '!**/examples/**' \
    --glob '!**/example/**' \
    --glob '!**/bench/**' \
    --glob '!**/benches/**' \
    --glob '!**/benchmark/**' \
    --glob '!**/benchmarks/**' \
    --glob '!**/runners/**' \
    --glob '!**/unity*' \
    --glob '!**/utest.h' \
    --glob '!**/catch.hpp' \
    --glob '!**/catch2/**' \
    --glob '!**/gtest/**' \
    --glob '!**/gmock/**' \
    -e "$1" -- "$2" 2>/dev/null || true
}

# Comment post-filter (F2b): rg emits "file:line:content"; drop rows whose
# content field, left-trimmed, begins with a doc/line-comment marker (* // /*).
# This kills "coordinate system", "ideal%", "cat bytes ... from the kernel",
# "gets va_list", and "/* delete */" prose without parsing the language. Same
# approach as cpp_risk_scan.sh's drop_comment_lines so anchors line up.
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

# Repo-relative, comment-stripped, de-duplicated file:line anchors for PATTERN
# under REPO, LC_ALL=C sorted. Args: PATTERN REPO [MODE]
pack_anchors() {
  rg_signal "$1" "$2" "${3:-all}" \
    | drop_comment_lines \
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
    space embedded kernel gpu hpc crypto networking \
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
# documented signals and avoid tokens that fire on unrelated code.
pack_regex() {
  case "$1" in
    space)       printf '%s' '\bMISRA\b|rules? of ten|Power of Ten|\bcFE_|\bOS_[A-Z]|\bwatchdog\b|\bRTEMS\b|EXPORT_SYMBOL_NASA' ;;
    embedded)    printf '%s' '\bFreeRTOS\b|\bZephyr\b|xTaskCreate|-ffreestanding|\bvolatile\b.*(0x[0-9A-Fa-f]+|register)|ISR_HANDLER|\bHAL_' ;;
    kernel)      printf '%s' '__user\b|copy_(to|from)_user|MODULE_LICENSE|EXPORT_SYMBOL\b|\bspin_lock\b|GFP_KERNEL|GFP_ATOMIC' ;;
    gpu)         printf '%s' '__global__|__device__|cudaMalloc|sycl::|hipMalloc|-fsycl|cudaMemcpy|__syncthreads' ;;
    hpc)         printf '%s' '-ffast-math|_mm_[a-z]|vld1|svptrue|Eigen/|highway|#pragma omp|<cfenv>' ;;
    crypto)      printf '%s' 'constant.time|secret-dependent|\bEVP_|crypto_[a-z]|explicit_bzero|memset_s|\bFIPS\b|test.vector' ;;
    networking)  printf '%s' '\bntohl\b|\bhtons\b|\bntohs\b|\bhtonl\b|recvfrom|parse_packet|RFC[0-9]|__attribute__.*packed|#pragma pack' ;;
    compilers)   printf '%s' 'LLVMContext|llvm::|IRBuilder|emitOpcode|\bopcode\b|\bbytecode\b|interpreter|codegen|opt -verify' ;;
    databases)   printf '%s' '\bfsync\b|fdatasync|write-ahead|\bWAL\b|\bMVCC\b|crash.consistency|page_checksum|\bpwrite\b|dm-flakey|\bALICE\b' ;;
    audio)       printf '%s' 'audio_?callback|audio_?buffer|process_block|\bdenormal|\bxrun\b|\bjack_|kAudioUnit|\bVST3\b|\bASIO\b|\bCoreAudio\b|flush.to.zero|samples?_per_(buffer|frame)' ;;
    filesystems) printf '%s' '\bsuperblock\b|\binode\b|on-disk|\bmount\b|\bfsck\b|dm-flakey|\bFUA\b|crash.injection|barrier' ;;
    parser)      printf '%s' '\b(json|xml|yaml|toml|ini|csv|protobuf|msgpack|riff|fourcc)\b|\bhttp_?(parse|request|response)|[a-z0-9]+_parse\b|\bparse_[a-z]|\btokeniz|\blexer\b|\bgrammar\b|[a-z0-9]+_decode\b|\bdeserialize\b|\bphr_|\byy(parse|lex|_)|\bdr(wav|flac|mp3)_' ;;
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
# Detection (F2b ranked): count each pack's distinct, comment-stripped code
# matches, then RANK by (priority tier, count, fixed order). Emits tab-separated
# "id\tlabel\tanchor\tcount\trole" rows, ranked best-first. Roles:
#   primary        - the top-ranked matched pack (the binding classification)
#   secondary      - other confident packs (>=2 code matches): a repo may
#                    legitimately span several packs; union their gates.
# Packs with a single incidental code match (count==1) are NOT emitted: one hit
# (often a struct-packing macro or a stray token) is too weak to gate on, and a
# wrong pack is worse than no pack. `generic` is the honest fallback for a real
# library that matches no domain; it never masks a confident real-domain pack
# but wins by dominance when it is the strongest signal (klib/uthash/sds).
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

  # Stable rank: priority tier desc, count desc, original pack order asc.
  # Generic-dominance rule: `generic` is the least-specific pack ("it's a
  # library"). It only earns `primary` when it strictly DOMINATES every other
  # matched pack (>= 2x the next pack's count) -- the klib/uthash/sds case. When
  # it merely edges out a more-specific pack (e.g. a 2-function JSON header where
  # `*_init` ties `*_parse`), the specific pack stays primary and generic drops
  # to last. Then assign role (first = primary, rest = secondary).
  printf '%b' "$raw" \
    | awk -F'\t' 'NF>=5 { print NR "\t" $0 }' \
    | LC_ALL=C sort -t$'\t' -k2,2nr -k3,3nr -k1,1n \
    | awk -F'\t' '
        { order[NR]=$1; prio[NR]=$2; count[NR]=$3
          id[NR]=$4; label[NR]=$5; anchor[NR]=$6; n=NR }
        END {
          # Find the best non-generic pack (already sorted, so first such row).
          best_other = 0
          for (i = 1; i <= n; i++) if (id[i] != "generic") { best_other = i; break }
          # If generic is rank 1 but does not dominate the best other pack,
          # rotate generic to the end of the ranking.
          rotate = (n >= 2 && id[1] == "generic" && best_other > 0 \
                    && count[1] < 2 * count[best_other])
          # Emit order: rotated (others first, generic last) or as-sorted.
          emitted = 0
          if (rotate) {
            for (i = 1; i <= n; i++) if (id[i] != "generic") emit(++emitted, i)
            for (i = 1; i <= n; i++) if (id[i] == "generic") emit(++emitted, i)
          } else {
            for (i = 1; i <= n; i++) emit(++emitted, i)
          }
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

  local gpu_out kernel_out plain_out hpc_out parser_out generic_out comments_out
  gpu_out="$(run_detect "$tmp/gpu" no)"
  kernel_out="$(run_detect "$tmp/kernel" no)"
  plain_out="$(run_detect "$tmp/plain" no)"
  hpc_out="$(run_detect "$tmp/hpc" no)"
  parser_out="$(run_detect "$tmp/parser" no)"
  generic_out="$(run_detect "$tmp/generic" no)"
  comments_out="$(run_detect "$tmp/comments" no)"

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
             "$parser_out" "$generic_out" "$comments_out"; do
    if printf '%s\n' "$out" | grep -qF "$tmp"; then
      printf 'cpp_domain_detect self-test: FAIL (absolute path leaked into output)\n'
      printf '%s\n%s\n' '--- out ---' "$out"
      exit 1
    fi
  done
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
