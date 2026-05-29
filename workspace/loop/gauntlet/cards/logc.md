# logc — c-cpp-profi gauntlet card

- Repo: https://github.com/rxi/log.c @ f9ea349 ("Fixed iteration when all callback slots are occupied")
- Domain pack: unknown-domain (detector found no pack signal)
- Size: 2 source files, 217 LOC (src/log.c 168, src/log.h 49). No build system, no CI, no compile_commands.json — meant to be vendored.
- Std: unspecified by repo. Uses C99/C11-era features (bool via stdbool, designated initializers, variadic macros).

## Gate results

### domain-detect
`unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`. Reasonable: a generic logging lib matches no
specialized pack. Honest miss is acceptable here — but note it offers no "generic-c-library" fallback profile.

### comprehension-map
- L1: correctly flags compile_commands.json absent; language breakdown .c=1 .h=1 (accurate).
- L2 entry points: **"none detected"** — true (it's a library, no main), but the map gives no signal that the
  public API surface is the 7 `log_*` functions in log.h. A library-aware mode would list exported symbols.
- L2 module map: "src module (2 source files)" — accurate.

### risk-scan  (riskHitCount ≈ 0)
ALL eight checks returned "no matches". Most are genuine negatives (no malloc/free, no new/delete, no memcpy,
no system/popen, no assert, no pthread, no casts). BUT this is NOT a clean formatting bill of health:
- log.c:66 `vfprintf(ev->udata, ev->fmt, ev->ap)` and log.c:78 (same) feed a **runtime-propagated format
  string** (`ev->fmt` originates from the variadic `log_log(...,const char*fmt,...)` at log.c:140). The
  `unsafe string or formatting APIs` pattern only matches `sprintf|vsprintf`, never the `vf*printf`/`vsnprintf`
  family or `va_list` forwarding — so a real format-string surface scores zero. (In practice callers pass
  literal fmts, so severity is low, but the gate is blind to it.)

### backlog (sample)
- `api-ergonomics | pointer+length parameter pair ... | src/log.c:140` — **FALSE POSITIVE** (see W1).
- `api-ergonomics | pointer+length parameter pair ... | src/log.h:47` — **FALSE POSITIVE**, same signature.
- `portability | at most one language standard exercised | inventory:ci.matrix` — vacuously true (no CI at all).
- `portability | no CI matrix detected | inventory:ci.matrix` — true; repo has no CI.
- `portability | time_t width assumption | src/log.c:133` — **TRUE POSITIVE**: `time_t t = time(NULL)` →
  `localtime(&t)` at log.c:134; legitimate Y2038/32-bit width note.

## Observed skill weaknesses (W-list)

- **W1 (false positive, backlog, log.c:140 & log.h:47):** the pointer+length heuristic regex
  `\*name\s*,\s*(int|...)\s+[A-Za-z_]*(len|size|count|n)...` matched `const char *file, int line`. Root cause:
  the length-token alternative includes bare `n`, and "li**n**e" contains an "n", so `int line` (a source line
  number) is misread as a buffer length and `*file` (a NUL-terminated string) as a counted buffer. No span/view
  is applicable; the advice is noise. The bare-`n` token makes this trigger on any `*ptr, int <word-with-n>`.
- **W2 (risk-scan blind spot, log.c:66/78):** formatting-API check omits `vfprintf`/`vsnprintf`/`snprintf`/
  `fprintf` and does not track `va_list` propagation, so a runtime format string forwarded through a struct is
  invisible. "no matches" overstates safety for a printf-style logger.
- **W3 (comprehension gap):** for a header-only/vendored library the map reports "entry points: none detected"
  and never surfaces the exported API (7 `log_*` symbols in log.h) — the actual thing a reviewer needs first.
- **W4 (domain-detect, minor):** no generic-C-library fallback; "unknown-domain" forces a manual pack build for
  a trivially recognizable category (single .c/.h logging lib).

## Negative evidence preserved
- risk-scan genuinely found NOTHING for allocation, new/delete, memcpy/memmove/memset, system/popen/exec,
  assert, threading, and casts — all correct: the code uses none of these. Only static `level_strings[]` /
  `level_colors[]` array indexing by `ev->level` exists, which the scanner does not (and is not meant to) flag.
- comprehension-map L1 language breakdown and module map are fully accurate.
- backlog time_t hit (log.c:133) is a real, correctly-located finding.

## Verdict
PARTIAL. Gates ran cleanly (exit 0, no crashes, non-empty output) and produced 2 genuine findings (time_t
width; no-CI/no-std). But on 217 LOC the skill emitted a reproducible false positive (W1, the bare-`n`
length-token bug) and missed the one real (if low-severity) risk surface in the file (W2, vfprintf format-string
forwarding). Useful triage, not trustworthy unattended.
