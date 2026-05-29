# lua — c-cpp-profi gauntlet card

- Repo: https://github.com/lua/lua @ `53b41d0` ("Avoid warning in some compilers")
- Expected pack: Compilers / interpreters / VMs
- Detected primary: Generic library / data-structures / strings
- Size: 2.6 MB, 68 C/H files (40 `.c`, 28 `.h`), flat root layout + `testes/` test corpus
- Gates run READ-ONLY, no build. All four exited 0.

## Gate results

### domain-detect
- primary: Generic library / data-structures / strings | lapi.c:1127 (111 code matches)
- secondary: Compilers / interpreters / VMs | lcode.c:1095 (50) — anchored on real codegen (`codeABRK(FuncState*, OpCode, ...)`)
- secondary: Filesystems / block storage | lapi.c:1015 (49) — incidental: liolib/loslib stdio (`fopen/fread/fseek`)
- secondary: Space / satellites | loslib.c:143 (22) — SPURIOUS: anchored on `os_execute` (exec/command token); correctly ranked low
- secondary: Parser / text-format / serialization | lutf8lib.c:102 (4)

### comprehension-map
- L1: compile_commands.json absent (noted); language breakdown .c=40 .h=28, .cc/.cpp/.cxx/.hpp=0 (pure C confirmed)
- L2 exported API: **BROKEN on Lua's idiom** — 39 of 40 public-header entries render as `int()` / `void()` (return-type only, name lost). Only `debug_realloc()` (ltests.h, normal style) keeps its name. ZERO `lua_*`/`luaL_*` names surfaced. Cause below.
- L2 entry points: `main()` @ lua.c:777 (correct); all 28 public headers listed; ~330 "exported-symbol hint" lines (LUA_API macro), capped
- L2 module map: (root) 63 files; testes/ 5 files

### risk-scan (C++ new/delete category correctly suppressed: "C++ signal: no")
- unsafe string/format: strcpy lstrlib.c:1277, lobject.c:326/521/523, loslib.c:116; sprintf cluster in ltests.c
- raw alloc: free/realloc lauxlib.c:1052/1056 (the default allocator — expected); malloc ltests.c:249
- process/shell: `system(cmd)` loslib.c:138, `popen` liolib.c:58 — both real macro defs gating the os.* library
- memcpy/memset: large cluster (string lib, pack lib, GC) — all sized copies
- TRIAGE: spot-read 3 hits — lstrlib.c:1277 `strcpy(form+l-1, lenmod)` REAL call (format-spec assembly, bounded by prior strlen); lobject.c:326 `strcpy(buff, s)` REAL call (guarded by `strlen(s) > L_MAXLENNUM` check on line 324); loslib.c:138 `#define l_system(cmd) system(cmd)` REAL macro def. **No comment/prose false positives.**

### backlog (sample)
- api-ergonomics: ptr+len pair → "document ownership/bounds contract" (C-relabeled, NOT span — F2/W2 fix held). ~190 hits, the dominant lane.
- hardening: sprintf/strcpy/strcat bounded-copy candidates (mostly ltests.c + luaconf.h macros)
- portability: no CI matrix detected (true — lua/lua has no .github/workflows); time_t Y2038 width @ loslib.c
- test-fuzz-coverage: parser/decoder entries w/o fuzz harness (luaD_protectedparser @ lapi.c:1128, lparser.c:2180, lutf8lib) — fair: no in-tree fuzzer

## REGRESSION CHECK
- domainCorrect = **partial**. Expected VM pack is a strong #1 *secondary* (50, real codegen anchor) but lost primary to Generic-library (111). Defensible — Lua genuinely IS a large C library with a stable C API (lapi.c surface), so generic-library primary is not wrong; but the canonical identity "the Lua VM" sits at #2. The spurious "Space / satellites" off `os_execute` is a mild residual F2 over-match, harmless (ranked 4th).
- fixesHeld = **mostly**. F1 (comment/substring + C++-on-C): HELD — risk hits are all real calls; new/delete category explicitly suppressed ("pure-C"). F2/W2 (span→C ptr+len relabel): HELD. F4 (exit 0): HELD (all gates exit 0). F3/F6 (.github/workflows): N/A (repo has none; backlog correctly reports "no CI matrix"). **F5 did NOT fully hold here** — see new weakness W-LUA-1.

## NEW weakness (beyond F1–F7)
- **W-LUA-1 (comprehension L2 exported-API name extraction):** Lua declares every public function with the name in parens to dodge macro expansion: `LUA_API int (lua_absindex) (lua_State *L, int idx);` (lua.h:177). The extractor grabs the return type and stops at the first `(`, emitting `int()` — the function name is destroyed. Result: 39/40 public-header entries are `int()`/`void()`, the entire `lua_*`/`luaL_*` API surface (the single most useful comprehension output for this repo) is unusable. This is a NEW, distinct failure mode from F5 (F5 = API omitted / doc-comment main); here the API is *found but every identifier is mangled*. Fix: when the token after the return type is `(`, treat the parenthesized identifier as the function name (handle `TYPE (name) (args)` and `TYPE (*name)(args)`).
- Minor: `ltests.c`/`ltests.h` (Lua's internal debug/test harness, 58 KB) lives in the flat root, not a `tests/` dir, so it is NOT excluded — it dominates the sprintf/assert risk lanes (e.g. ltests.c:730-755, the assert wall at 382-707). Not wrong per the exclude rules (it's root-level shipped code), but it skews the risk profile toward test scaffolding. Candidate: name-based exclude for `*tests.c`/`ltests.*` debug builds.

## Negative evidence (what did NOT misfire)
- risk-scan produced NO comment/string-literal false positives (F1 held under spot-check).
- C++ categories (new/delete, span) correctly suppressed on this pure-C repo.
- backlog did NOT propose C++ span; used the C ptr+len relabel (W2 held).
- All four gates exited 0; no crash, no exit-1-on-success (F4 held).
- domain-detect did NOT misclassify off one incidental token — the spurious Space pack is present but correctly ranked last.

## Verdict
PRODUCTIVE. Gates ran clean, the F1/F2/F4 fixes held under spot-check on a real pure-C VM, and the run surfaced one concrete, fixable NEW weakness (W-LUA-1: paren-wrapped function-name idiom defeats exported-API extraction — high value since it silences the whole Lua C API). Domain classification is defensible but ranks the VM identity second (partial).
