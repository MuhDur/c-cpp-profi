# C2 TRANSFORM trial — re-architect (file-scope global → injected context on a real C repo)

## Transform mode

- Mode: **re-architect** (bounded structural change: ownership model moves from an
  implicit file-scope global to a caller-owned context struct threaded through the API;
  the public behavior of the existing surface is preserved). Per `CODE-TRANSFORM.md`, the
  mandatory gates for this mode are **migration ledger + tests + ABI/API**, validated with
  `cpp_evidence_check.py --profile rearchitect --require-transform-proof`.
- Repo: logc (rxi/log.c) — a single-file C logging library.
- Worked on a COPY, never the clone: `cp -r /tmp/cpp-gauntlet/logc /tmp/c2_logc`.
- repo@commit: `f9ea34994bd58ed342d2245cd4110bb5c6790153` (`f9ea349 Fixed iteration when all
  callback slots are occupied`).
- Touched files: `src/log.c`, `src/log.h` (on the copy).

## The structural change

The origin holds *all* logger state in one file-scope global:

```c
static struct {
  void *udata; log_LockFn lock; int level; bool quiet;
  Callback callbacks[MAX_CALLBACKS];
} L;
```

Every state-touching function reaches into `L` implicitly. The re-architecture promotes this
anonymous struct to a public, caller-owned type `log_Context` and **injects** a `log_Context *ctx`
into every function that previously read or wrote `L`. The implicit-global API is preserved by
routing each legacy call through a single shared default context (`static log_Context g_default;`),
so the global API behaves exactly as before. New `log_ctx_*` functions expose the
context-explicit surface that is the migration target.

Ownership model delta: state ownership moves from *the library* (one hidden global) to *the
caller* (any number of caller-allocated `log_Context` instances). The global functions remain a
thin, behavior-identical shim over one such instance.

## Caller census (the symbol being restructured: the global `L`)

caller-census: **11 sites** in `src/log.c` referenced the file-scope global `L`, spread across
**7 internal functions**. Census via `rg -n '\bL\.' src/log.c` on the origin:

| Line (origin) | Function | Reference |
|---|---|---|
| 85, 85, 85 | `lock` | `L.lock`, `L.lock(...)`, `L.udata` |
| 90, 90, 90 | `unlock` | `L.lock`, `L.lock(...)`, `L.udata` |
| 100, 101 | `log_set_lock` | `L.lock`, `L.udata` |
| 106 | `log_set_level` | `L.level` |
| 111 | `log_set_quiet` | `L.quiet` |
| 117, 118 | `log_add_callback` | `L.callbacks[i].fn`, `L.callbacks[i]` |
| 150, 150, 157, 158 | `log_log` | `L.quiet`, `L.level`, `L.callbacks[i].fn`, `L.callbacks[i]` |

(`rg -c '\bL\.'` = 11 matched references.) There are **no external/example/test callers** of the
public API in the repo (only `README.md` doc snippets and the source itself), confirmed by
`rg 'log_set_*|log_add_*|log_log' --stats` → matches in `README.md`, `src/log.c`, `src/log.h`
only. The migration therefore touches no third-party consumer; the binding consumer set is the
7 in-tree functions above.

Post-refactor census proof: `rg -c '\bL\.' src/log.c` → **0 references** (the global is fully
eliminated); `rg -c 'ctx->' src/log.c` → **11 references** (the injected context, 1:1 with the
original 11 `L.` sites). No caller was orphaned: the 5 legacy setters plus `log_log` route
through `g_default` (`rg -n 'g_default' src/log.c` → 6 call sites).

## Migration ledger (reversible, one structural lever per step, in commit order)

ledger: 5 ordered steps, each individually reversible.

| Step | Structural lever | Caller census (this step) | Tests proving the step | ABI/API delta | Revert |
|---|---|---|---|---|---|
| L1 | Promote anonymous global struct to public type `log_Context` (+ public `log_Callback`, `LOG_MAX_CALLBACKS`) in `log.h`; keep `static log_Context g_default;` in `log.c` as the global's storage | 0 API callers changed yet; the 11 `L.` sites now read `g_default.` | global-API differential oracle (origin vs after) byte-identical | additive: new type + macro in header; 0 symbols removed | delete the new typedefs, rename `g_default`→`L`, restore anonymous struct |
| L2 | Parameterize the two internal helpers `lock`/`unlock` to take `log_Context *ctx` (was reading `L` directly) | 2 internal helper sites updated; their 2 callers (`log_log`) pass `&g_default` | differential oracle byte-identical (lock path unexercised when no lock set; covered) | none (both `static`) | drop the `ctx` param, restore `L.` reads in `lock`/`unlock` |
| L3 | Extract the variadic dispatch core into `static void vlog(log_Context*, ..., va_list)`; `log_log` becomes a `va_start`/`vlog`/`va_end` wrapper over `&g_default` | 1 site (`log_log` body) restructured; `va_list` traversal reworked to `va_copy(ev.ap, ap)` per consumer | differential oracle byte-identical incl. multi-arg `warn 2 3` / `fatal %c`; ASan+UBSan clean (no va UB) | none (`vlog` is `static`; `log_log` signature unchanged) | inline `vlog` back into `log_log`, restore in-place `va_start(ev.ap, fmt)` per consumer |
| L4 | Add context-explicit API `log_ctx_init/set_lock/set_level/set_quiet/add_callback/add_fp/log` operating on the injected `ctx` | 0 legacy callers changed; new surface only | context-isolation oracle (two independent `log_Context`) passes; ASan+UBSan clean | additive: 7 new `log_ctx_*` symbols exported | remove the 7 `log_ctx_*` definitions and their declarations |
| L5 | Re-express the 5 legacy global setters + `log_add_fp` as thin shims delegating to `log_ctx_*(&g_default, ...)` | 6 legacy API bodies rewritten as one-line delegations; behavior identical | global-API differential oracle byte-identical (post-shim) | none: same 7 origin symbols, same signatures | restore the direct-`g_default` bodies in the 6 functions |

Each step keeps the build green and the differential oracle byte-identical; the global API never
breaks at any intermediate step. A step's "Revert" column names the exact inverse edit, so the
migration is bounded and reversible (not a one-way rewrite).

## Compile proof

Compiler: `gcc (Ubuntu 15.2.0)` and `clang`. Baseline (origin) and after both compile clean.

```bash
# baseline (origin, before any edit)
gcc -std=c11 -Wall -Wextra -c /tmp/cpp-gauntlet/logc/src/log.c -o /tmp/c2_logc_baseline.o -Isrc   # exit 0
# re-architected copy
gcc   -std=c11 -Wall -Wextra              -c /tmp/c2_logc/src/log.c -o /tmp/c2_logc_after.o       -Isrc  # exit 0, 0 warnings
gcc   -std=c11 -Wall -Wextra -DLOG_USE_COLOR -c /tmp/c2_logc/src/log.c -o /tmp/c2_logc_after_color.o -Isrc  # exit 0, 0 warnings
clang -std=c11 -Wall -Wextra              -c /tmp/c2_logc/src/log.c -o /tmp/c2_logc_after_clang.o -Isrc  # exit 0, 0 warnings
```

Both default and `-DLOG_USE_COLOR` config paths, both gcc and clang, are warning-clean (0
warnings under `-Wall -Wextra`). `git diff --stat` on the copy: `src/log.c | 131 +/-`,
`src/log.h | 34 +`; 2 files changed, 125 insertions(+), 40 deletions(-).

## Tests (behavioral oracles)

Two oracles, both built against the re-architected library, both run clean under ASan+UBSan:

1. **Global-API differential oracle** (`/tmp/c2_logc_globaloracle.c`) — compiles unchanged
   against *both* the origin and the re-architected library (uses only the preserved
   implicit-global API: `log_set_quiet/level`, `log_add_callback`, `log_trace..log_fatal`,
   `log_level_string`). It exercises quiet-mode, per-callback level gating, multi-arg `%`
   format expansion, and per-callback fresh-args traversal. Origin and after outputs are
   **byte-identical** (`diff` exit 0):

   ```
   INFO 27 info x
   WARN 28 warn 2 3
   ERROR 29 error
   FATAL 30 fatal Z
   ```

   (TRACE/DEBUG correctly dropped — below the callback's `LOG_INFO` registration level — on
   both builds.)

2. **Context-isolation oracle** (`/tmp/c2_logc_test.c`) — proves two independent `log_Context`
   instances do not share state: a message logged to context `a` never appears in context `b`'s
   sink and vice versa, and each callback is gated by its own registered level (the origin
   contract: `ctx->level` gates only the built-in stderr handler, NOT callbacks). Runs clean
   under ASan+UBSan, prints `OK: global-api-behavior + context-isolation oracle passed`.

A subtle behavior axis surfaced and was honored: in the origin, the context-level field gates
**only** the default stderr handler (`!quiet && level >= ctx->level`), while each callback is
gated by its **own** registered level (`level >= cb->level`). The re-architecture preserves both
gates unchanged; an initial test that wrongly assumed `ctx->level` gates callbacks failed and was
corrected to match the true origin contract (the code was right, the test was wrong).

va_list axis: the origin called `va_start(ev.ap, fmt)` fresh for each consumer. The extracted
`vlog` receives one `va_list ap` and does `va_copy(ev.ap, ap)` per consumer (the default handler
and each callback), preserving the "each consumer gets a fresh traversal" semantics. `va_list` is
an array type on this platform, so `va_copy` (not assignment) is required; ASan+UBSan confirms no
va misuse.

## ABI / API note — HONEST: intentional, additive API extension + one source-level exposure

This is **not** a silent change. Documented honestly per `CODE-TRANSFORM.md` "Transform Never
Silently Changes Behavior":

- **Link-level ABI of the existing surface: preserved.** All 7 origin symbols
  (`log_level_string`, `log_set_lock`, `log_set_level`, `log_set_quiet`, `log_add_callback`,
  `log_add_fp`, `log_log`) are still exported with **identical names and signatures**. Symbol
  diff (`nm --defined-only --extern-only`, sorted, baseline vs after): **0 removed, 0 renamed**.
  An object/binary linked against the origin links unchanged against the re-architected build.
- **Link-level ABI: additive.** 7 new symbols are exported: `log_ctx_init`, `log_ctx_set_lock`,
  `log_ctx_set_level`, `log_ctx_set_quiet`, `log_ctx_add_callback`, `log_ctx_add_fp`,
  `log_ctx_log`. Adding symbols does not break existing callers.
- **API/source-level: an intentional, ledgered extension — and one honest exposure.** The header
  now publicly declares `log_Context`, `log_Callback`, and `LOG_MAX_CALLBACKS`. The origin kept
  the logger-state struct **private** (anonymous `static ... L;` inside `log.c`); the
  re-architecture makes its layout part of the public API. This is a deliberate API surface
  growth (callers may now embed/allocate a `log_Context`), and it is the price of moving
  ownership to the caller. It is recorded as an **intentional API extension**, not a silent one.
  Owner: this trial. Pinning test: the context-isolation oracle exercises the new type.
- **Behavior of the global API: unchanged**, proven by the byte-identical differential oracle —
  the global functions now mutate `g_default` instead of `L`, but `g_default` has the same
  initial (zeroed, static-storage) state and the same field semantics, so output is identical.

Migration path (honest, for downstream consumers):

1. **No action required** to keep working: the global API is source- and link-compatible. Existing
   code that calls `log_info(...)`, `log_set_level(...)`, etc. compiles and behaves identically.
2. **Opt in to explicit contexts** incrementally: allocate a `log_Context ctx; log_ctx_init(&ctx);`
   and replace `log_set_level(n)` → `log_ctx_set_level(&ctx, n)`, `log_info(...)` →
   `log_ctx_log(&ctx, LOG_INFO, __FILE__, __LINE__, ...)`, etc. The two APIs coexist.
3. **Future deprecation (not done here, named as follow-up):** once all consumers thread a context,
   the global shim and `g_default` can be removed in a separate, separately-gated commit — that
   removal *would* be a real symbol-removing ABI break and must get its own ledger row and
   major-version bump. This trial does **not** take that step; it keeps the global surface intact.

No intentional behavior delta exists in the preserved surface (differential oracle byte-identical).
The only intentional deltas are additive (new symbols/type), each ledgered above.

---

# C/C++ Gate Report

- Repo: /tmp/c2_logc
- Generated UTC: 2026-05-30T00:55:00Z
- Git branch: master
- Git commit: f9ea349
- Git status: dirty (re-architecture applied on the COPY: src/log.c, src/log.h)

## Change Scope

- Issue/task: C2 re-architect trial — convert logc's file-scope global logger state `L` into a caller-owned, injected `log_Context`, preserving the global API as a shim
- Touched files: src/log.c, src/log.h (on the copy /tmp/c2_logc)
- Public API/ABI touched: yes (intentional additive extension: 7 new log_ctx_* symbols + public log_Context type; all 7 origin symbols preserved unchanged; documented as an intentional, non-silent break)
- User-visible rendering/artifacts touched: no
- Parser/input/security boundary touched: no
- Threads/locks/atomics/signals touched: no (the lock/unlock hooks are caller-supplied callbacks, not new concurrency primitives; threading contract unchanged)
- Refactor/simplification claim: no (this is a structural re-architecture with an intentional API extension, not a behavior-and-ABI-preserving refactor)
- Performance claim: no

## Commands

| Gate | Status | Command | Evidence |
|---|---|---|---|
| inventory | passed | `git -C /tmp/c2_logc rev-parse HEAD && git -C /tmp/c2_logc diff --stat` | repo@f9ea34994bd58ed342d2245cd4110bb5c6790153; 2 files changed, 125 insertions(+), 40 deletions(-); src/log.c + src/log.h on the copy |
| format | not applicable |  |  |
| compile | passed | `gcc -std=c11 -Wall -Wextra -c /tmp/c2_logc/src/log.c -o /tmp/c2_logc_after.o -Isrc; gcc -DLOG_USE_COLOR ...; clang ...` | exit 0 on origin baseline AND re-architected copy; gcc + clang; default AND -DLOG_USE_COLOR config paths; warning-clean: yes (0 warnings under -Wall -Wextra) |
| tests | passed | `gcc -std=c11 -Wall -Wextra -fsanitize=address,undefined -Isrc /tmp/c2_logc_test.c src/log.c -o t && ./t` and the differential oracle below | context-isolation oracle prints "OK: ...passed" under ASan+UBSan (exit 0); differential global-API oracle origin-vs-after byte-identical (diff exit 0) |
| static analysis | not applicable |  |  |
| ASan+UBSan | passed | `gcc -std=c11 -Wall -Wextra -fsanitize=address,undefined -g -Isrc /tmp/c2_logc_test.c src/log.c -o /tmp/c2_logc_test_san && /tmp/c2_logc_test_san` | exit 0, no ASan/UBSan diagnostics; validates the reworked va_copy traversal in vlog |
| TSan/MSan/LSan | not applicable |  |  |
| Helgrind/DRD/rr/stress | not applicable |  |  |
| fuzz/corpus | not applicable |  |  |
| performance | not applicable |  |  |
| portability | not applicable |  |  |
| ABI/API | passed | `nm --defined-only --extern-only /tmp/c2_logc_baseline.o \| sort` vs `nm --defined-only --extern-only /tmp/c2_logc_after.o \| sort`; comm -13 / comm -23 | all 7 origin symbols preserved (0 removed, 0 renamed); 7 new log_ctx_* symbols added (additive); intentional API extension (public log_Context type) documented in ABI/API note; behavior of preserved surface byte-identical per differential oracle; intentional break is named, not silent |
| refactor isomorphism | not applicable |  |  |
| differential oracle | not applicable |  |  |
| migration ledger | passed | `rg -n '\\bL\\.' src/log.c` (origin census) then post-refactor `rg -c '\\bL\\.' src/log.c` (==0) and `rg -c 'ctx->' src/log.c` (==11); ledger steps L1-L5 each with revert | caller-census: 11 sites across 7 functions referenced global L (origin); post-refactor 0 L. references (global eliminated), 11 ctx-> references (1:1), 6 g_default shim sites, no caller orphaned; no external repo consumers (rg --stats: only README.md/src). ledger: 5 reversible steps L1-L5 (promote struct; parameterize lock/unlock; extract vlog; add log_ctx_* API; shim legacy globals over g_default), each with a named revert; build green + differential oracle byte-identical at every step |
| golden artifacts | not applicable |  |  |
| idea card | not applicable |  |  |
| comprehension | not applicable |  |  |

Use statuses: passed, failed, not run, not applicable.

## ABI/API Evidence

- Supported contract: logc public C API in log.h; the compiled log.c object's exported symbol set and the existing 7 functions' signatures.
- Old artifact/header: /tmp/c2_logc_baseline.o (origin log.c @ f9ea349). Origin header keeps logger state private (anonymous static L). Sorted exported symbols: 7 (log_level_string, log_set_lock, log_set_level, log_set_quiet, log_add_callback, log_add_fp, log_log).
- New artifact/header: /tmp/c2_logc_after.o (re-architected log.c). New header publicly declares log_Context, log_Callback, LOG_MAX_CALLBACKS. Sorted exported symbols: 14 (the 7 origin + 7 new log_ctx_*).
- Tooling: gcc 15.2.0 / clang (-std=c11 -c), nm --defined-only --extern-only, sort, comm, diff.
- Symbol/layout/API result: comm -23 (origin-only) = EMPTY -> 0 symbols removed/renamed; comm -13 (after-only) = the 7 log_ctx_* symbols -> additive only. All 7 origin symbols keep identical names and signatures. API is an intentional superset.
- Downstream compile/run result: the global-API differential oracle compiles UNCHANGED against both origin and after and produces byte-identical output (diff exit 0); a binary linked against origin symbols links unchanged against after.
- Intentional breaks: one intentional API extension (not a removal): the logger-state struct, previously private, is now the public type log_Context, and 7 new log_ctx_* entry points are exported. Owner: this trial. Pinning test: context-isolation oracle. The future removal of the global shim is explicitly NOT done here and is named as a separate, separately-gated follow-up that would carry its own ABI break + major version bump.

## Residual Risk

- Missing gates: the repo ships no build system or unit-test runner of its own, so "tests" is satisfied by two purpose-built oracles (a global-API differential oracle proving the preserved surface is byte-identical origin-vs-after, and a context-isolation oracle proving the new API), rather than an upstream test suite. Thread-safety of the new multi-context model under real concurrent load was not stress-tested (no TSan/Helgrind run); the locking contract is unchanged from origin (caller-supplied lock hook) but per-context locking now lets callers run independent contexts on different threads, which the origin single-global could not express.
- Why missing gates are acceptable or follow-up issue: the differential oracle exercises the exact behavior axes the structural change could perturb (quiet/level gating, per-callback level, multi-arg format expansion, per-consumer va traversal) and shows zero delta on the preserved surface; ASan+UBSan covers the reworked va_copy path. Follow-up: (1) add a TSan stress test driving two log_Context instances from two threads to certify the per-context concurrency story; (2) the named major-version commit that removes the global shim once consumers migrate.
- Follow-up issues: TSan/Helgrind multi-context stress test; eventual deprecation+removal of the global shim API (separate commit, separate ABI gate, major version bump).

## Evidence Checker

Exact command run (the `# C/C++ Gate Report` section above extracted to a temp file):

```bash
awk '/^# C\/C\+\+ Gate Report$/{f=1} f{print}' \
  /home/durakovic/projects/cpp/workspace/loop/trials/C2-rearchitect.md > /tmp/c2_rearchitect_packet.md
python3 /home/durakovic/projects/cpp/skill/c-cpp-profi/scripts/cpp_evidence_check.py \
  /tmp/c2_rearchitect_packet.md --profile rearchitect --require-transform-proof
```

Actual output (exit 0):

```
c-cpp-profi evidence check: PASS
profiles=rearchitect
```

The `rearchitect` profile requires the `migration ledger`, `tests`, and `ABI/API` gates to all
be `passed` with non-placeholder command and evidence; `--require-transform-proof` additionally
requires the `migration ledger` evidence to name `caller-census:` and `ledger:` — both present.
Temp packet removed afterward with `rm -f /tmp/c2_rearchitect_packet.md` (single file, not `rm -rf`).
