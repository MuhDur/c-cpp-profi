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

# rg over the repo's source + build/config surface, vendored/build trees
# excluded. Case-insensitive (signals are matched loosely). Args: PATTERN REPO
rg_signal() {
  rg -ni --no-heading --no-messages \
    --glob '*.{c,cc,cpp,cxx,h,hh,hpp,hxx,cu,cuh,cl}' \
    --glob '*.{cmake,build,mk,txt,json,yml,yaml,ld,ini}' \
    --glob 'CMakeLists.txt' --glob 'Makefile' --glob 'GNUmakefile' \
    --glob 'meson.build' --glob 'Kconfig' --glob 'Kbuild' \
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

# First repo-relative file:line anchor for PATTERN under REPO, or empty.
# Args: PATTERN REPO
first_anchor() {
  rg_signal "$1" "$2" \
    | strip_repo_prefix "$2" \
    | awk -F: 'NF>=2 { print $1 ":" $2 }' \
    | LC_ALL=C sort \
    | head -n1
}

# ---------------------------------------------------------------------------
# Pack table. Each pack is "id|label|signal-regex". The regex is the union of
# the pack's Pack-Selection signals from DOMAIN-AGNOSTIC-MASTERY.md. Order is
# fixed so output is deterministic.
# ---------------------------------------------------------------------------
pack_ids() {
  printf '%s\n' \
    space embedded kernel gpu hpc crypto networking \
    compilers databases audio filesystems
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
    audio)       printf '%s' 'ring_?buffer|audio_callback|process_block|\bdenormal|\bxrun\b|jack_|kAudioUnit|\bVST3\b|flush.to.zero' ;;
    filesystems) printf '%s' '\bsuperblock\b|\binode\b|on-disk|\bmount\b|\bfsck\b|dm-flakey|\bFUA\b|crash.injection|barrier' ;;
    *)           printf '%s' 'a^' ;;   # never matches
  esac
}

# ---------------------------------------------------------------------------
# Detection: for each pack, if its signal regex matches, record the first
# repo-relative anchor. Emits "id\tlabel\tanchor" lines (tab-separated).
# ---------------------------------------------------------------------------
detect() {
  local repo="$1"
  local id label rx anchor
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    rx="$(pack_regex "$id")"
    anchor="$(first_anchor "$rx" "$repo")"
    if [ -n "$anchor" ]; then
      label="$(pack_label "$id")"
      printf '%s\t%s\t%s\n' "$id" "$label" "$anchor"
    fi
  done < <(pack_ids)
}

emit_text() {
  # tab-separated id/label/anchor -> "pack: <label> | <anchor>", or the
  # unknown-domain line when there were no matches.
  local rows="$1"
  if [ -z "$rows" ]; then
    printf 'unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md\n'
    return 0
  fi
  printf '%s\n' "$rows" \
    | awk -F'\t' 'NF>=3 { printf "pack: %s | %s\n", $2, $3 }'
}

emit_json() {
  # tab-separated id/label/anchor -> {"matched": bool, "packs": [...]}.
  local rows="$1"
  printf '%s\n' "$rows" | awk -F'\t' '
    function esc(s,   r) {
      r = s
      gsub(/\\/, "\\\\", r)
      gsub(/"/, "\\\"", r)
      return r
    }
    BEGIN { n = 0 }
    NF>=3 {
      n++
      id[n] = $1; label[n] = $2; anchor[n] = $3
    }
    END {
      printf "{\n"
      printf "  \"matched\": %s,\n", (n > 0 ? "true" : "false")
      printf "  \"packs\": ["
      for (i = 1; i <= n; i++) {
        if (i > 1) printf ","
        printf "\n    {\"id\": \"%s\", \"pack\": \"%s\", \"anchor\": \"%s\"}", \
          esc(id[i]), esc(label[i]), esc(anchor[i])
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

  local gpu_out kernel_out plain_out
  gpu_out="$(run_detect "$tmp/gpu" no)"
  kernel_out="$(run_detect "$tmp/kernel" no)"
  plain_out="$(run_detect "$tmp/plain" no)"

  # Assertion 1: the CUDA fixture selects the GPU pack, anchored to the .cu file.
  if ! printf '%s\n' "$gpu_out" | grep -qE 'pack: GPU \(CUDA / SYCL / HIP\) \| src/kernel\.cu:[0-9]+'; then
    printf 'cpp_domain_detect self-test: FAIL (CUDA fixture did not select GPU pack)\n'
    printf '%s\n%s\n' '--- gpu ---' "$gpu_out"
    exit 1
  fi
  # Assertion 2: the kernel fixture selects the Kernel pack, anchored to foo.c.
  if ! printf '%s\n' "$kernel_out" | grep -qE 'pack: Kernel / drivers \| drivers/foo\.c:[0-9]+'; then
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
  if printf '%s\n' "$plain_out" | grep -q '^pack: '; then
    printf 'cpp_domain_detect self-test: FAIL (plain repo matched a pack it should not)\n'
    printf '%s\n%s\n' '--- plain ---' "$plain_out"
    exit 1
  fi
  # Assertion 5 (no absolute paths leak): outputs must not contain the temp dir.
  local out
  for out in "$gpu_out" "$kernel_out" "$plain_out"; do
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
