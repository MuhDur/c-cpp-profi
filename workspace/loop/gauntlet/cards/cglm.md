# cglm — c-cpp-profi gauntlet card

- **Repo:** https://github.com/recp/cglm @ `83d5b2c` ("docs: add infinite perspective")
- **Domain (actual):** SIMD math (C) — vectors/matrices/quaternions with SSE/NEON/WASM intrinsics
- **Domain pack (detected):** `unknown-domain` (WRONG — see W1)
- **Size / std:** 54 `.c`, 223 `.h` (header-heavy / mostly header-only); `-std=gnu11` (Makefile.am:11,23), `CMAKE_C_STANDARD` (CMakeLists.txt:9,31). Builds: autotools + cmake + meson. No compile_commands.json.

## Gate results

**domain-detect:** `unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`. Misfire — repo has 297 `_mm_*` SSE intrinsics and 40 `vld1*` NEON intrinsics that directly match the `hpc` (HPC/SIMD/numerics) pack regex. Root cause W1.

**comprehension-map:** Solid. L1 caught all 3 build systems + std + missing compile_commands. L2 module map (include 187 / src 48 / test 42 files) is accurate. BUT L2 "entry points" = 1511 "exported-symbol hint" lines — every `CGLM_*` API macro on every header line. Useful as a symbol census, useless as an "entry point" list (W2); output is 114KB / 1535 lines for a single read.

**risk-scan:** ~233 hits, essentially ALL false positives (triage below).
- `[process or shell execution]` ~220 hits, e.g. `clipspace/ortho_lh_no.h:37` "left-hand coordinate **system**" — regex `\b(system|popen|...)\b` matches English "system" in doc comments. NOISE. (W3)
- `[raw C++ new/delete]` clipspace/*.h, sphere.h:49 "creates a **new** one" — matches the word "new" in comments; cglm is C, has no `new`/`delete`. NOISE. (W4)
- `[unsafe string or formatting APIs]` noise.h:216 "gets **amplified**" — substring match on a numerical-accuracy comment. NOISE.
- `[assert-only validation]` mat4.h:381 `assert(len > 1 && ...)` in `glm_mat4_mulN` — REAL hit, correctly flagged: input count guarded only by assert, compiled out under NDEBUG. Genuine triage value.
- raw allocation / casts / memmove / threading: `no matches` — accurate (header-only math, no alloc/threads).

**backlog:** 5 items, all build-config:
- `hardening | no -D_FORTIFY_SOURCE / no CFI / no -fsanitize / no stack-protector` — all TRUE for the build files (grep across CMakeLists/Makefile.am/meson.build confirms zero hardening/sanitizer flags). Fair findings, though low-relevance for a header-only lib consumed by callers who set their own flags.
- `api-ergonomics | pointer+length pair with no span/view | struct/quat.h:15` — pattern is REAL (`versor *q, size_t count`, confirmed at quat.h:98 and quat.h:116) but the anchor lands on a doc-comment line (quat.h:15), not the declaration. Citation is misleading (W5).

## Observed skill weaknesses (W-list)

- **W1 (high):** `cpp_domain_detect.sh` silently misclassifies every SIMD/HPC repo. The `hpc` pack regex begins with `-ffast-math`; passed as a positional arg to `rg`, the leading `-f` is parsed as rg's `--file` flag, rg errors "No such file or directory", and `--no-messages`+`|| true` swallow it → empty anchor → pack dropped. Verified: `rg ... "$PATTERN"` fails, `rg ... -e "$PATTERN"` succeeds and matches mat4.h:144. The `hpc` pack is the ONLY one of 12 whose regex starts with a dash, so this bug uniquely sinks SIMD detection. Fix: use `-e` / `--` before the pattern in `rg_signal` (cpp_domain_detect.sh:52-67, first_anchor:90).
- **W2 (med):** comprehension-map L2 equates "exported-symbol hint" with "entry point"; on an API-macro-per-line header lib this yields 1511 hits and a 114KB dump — no ranking, no dedup to function names.
- **W3 (med):** risk-scan `process or shell execution` regex `\bsystem\b` fires on prose "coordinate system" — ~220 of 233 hits are this single comment phrase. Should exclude comment lines or require a call-site `(` .
- **W4 (low):** risk-scan `raw C++ new/delete` fires on the English word "new" in comments; also category is C++-only advice on a pure-C repo.
- **W5 (low):** backlog api-ergonomics anchor points at a function-list comment (quat.h:15) rather than the real declaration (quat.h:98/116).

## Negative evidence preserved

- risk-scan `raw allocation`, `casts requiring review`, `unchecked memory movement`, `threading primitives` all = `no matches` — accurate for a header-only, alloc-free, single-threaded math lib.
- The one genuine risk hit (mat4.h:381 assert-gated count) and the backlog hardening findings are all TRUE and correctly grounded.
- comprehension-map L1 (build systems, std, language breakdown, missing compile_commands) is fully correct.

## Verdict

**PARTIAL.** comprehension-map and the backlog were productive and accurate. But the headline gate — domain-detect — is broken for this entire domain class (W1), and risk-scan was ~95% noise on a C math library (W3/W4). The skill mostly failed to add value here; its accurate findings came from the comprehension map and a single assert hit, not from the domain/risk machinery.
