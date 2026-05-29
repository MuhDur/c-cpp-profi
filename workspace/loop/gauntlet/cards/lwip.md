# lwip — c-cpp-profi gauntlet card

- Repo: https://github.com/lwip-tcpip/lwip @ `ab2f69c` ("mdns: Fix copying of invalid search result domains")
- Expected pack: Networking / Embedded (lwIP is THE canonical embedded TCP/IP stack)
- Size: 478 C/H files (.c=203, .h=275; 0 C++), 12 MB. Build: cmake + make; -std=c99. No compile_commands.json.
- Gates run READ-ONLY (no build): domain-detect, comprehension-map, risk-scan, backlog.

## Gate results

**domain-detect** — PRIMARY: `Generic library / data-structures / strings` (1327 code matches).
Secondaries: Networking/protocols (107), Parser/text-format (99), Compilers/VMs (16), Embedded/real-time (7).
Networking + Embedded both present but demoted below a generic pack that wins on raw C-idiom volume.

**comprehension-map** — Correctly surfaces exported C API from public headers (acd_*, altcp_*,
API_MSG_M_DEF) — F5 fix holds: 1149 total non-static public-header decls found. Build graph (cmake/make),
language breakdown, -std=c99 hint, module map (src 296 / contrib 127 / test 52 / doc 3) all correct.
Entry points correctly tagged (main() in examples/fuzz/unittests; EXPORT-macro hints).

**risk-scan** (exit 0 — F4 holds) — 472 hit lines across 7 categories:
unchecked-memmove 260, raw-alloc 81, unsafe-string 62, threading 41, casts 16, process/shell 7, assert-only 5.
C++ new/delete category correctly SUPPRESSED ("C++ signal: no", pure-C) — F1 gate holds.
Triage of top hits:
- src/apps/smtp/smtp.c:40 `sprintf(bdh->buffer,...)` — REAL, into fixed buffer; legitimate hardening item.
- contrib/.../sio.c:441 `ret = system(buf)` + sio.c:423/371 `execl(...)` — REAL shell-exec (unix port glue).
- src/api/api_lib.c:1304 `strncpy(...,DNS_MAX_NAME_LENGTH-1)` — REAL, bounded; benign.
- eap.c:738 `assert(ts != NULL)` — REAL assert-only validation.

**backlog** — 4 lanes: api-ergonomics 316, test-fuzz-coverage 47, hardening 46, portability 42.
- api-ergonomics uses C-relabeled wording "document the ptr+len ownership/bounds contract" — W2 fix holds (no span/view noise).
- hardening flags no -D_FORTIFY_SOURCE / no CFI in build config — correct.
- portability detects `.github/workflows/ci-linux.yml` CI matrix — F3/F6 (workflow-aware) holds.

## REGRESSION CHECK

- **domainCorrect = PARTIAL.** Networking AND Embedded are both detected, but only as secondary/trailing
  packs; a generic-C pack is PRIMARY. For the textbook embedded TCP/IP stack (178/203 src files carry
  networking tokens; 206 files carry embedded signals) the headline classification is wrong. F2-residual:
  ranking by raw code-match count lets the broad generic pack (memcpy/malloc/struct/string idioms in every
  C file) outscore narrower-but-diagnostic domain packs 12x. Networking is right, just buried.
- **fixesHeld = mostly.** Held: F1 C++-category suppression on pure-C (new/delete suppressed); F4 risk-scan
  exit 0; F5 exported C API surfaced (1149 decls); W2 C ptr+len relabel; F3/F6 workflow/CI awareness.
  Did NOT fully hold: comment/string stripping still leaks a few false positives (see NEW weaknesses).

## NEW weaknesses (not in F1-F7)

- **N1 (string-stripper misses escaped-quote & multi-line literals).** risk-scan process/shell lane fires on
  string literals the stripper didn't neutralize: `contrib/ports/unix/port/netif/sio.c:440` and `tapif.c:188`
  — `system(\"%s\")` inside an LWIP_DEBUGF debug-print string (escaped `\"` defeats the stripper); and
  `src/netif/ppp/auth.c:1482` `"The remote system (%s)..."` — a MULTI-LINE string literal (opened line 1479)
  where "system" rides inside the continued string. 3 of 7 process/shell hits are FPs. F1 handles single-line
  unescaped strings only.
- **N2 (trailing-comment on directive line).** `contrib/ports/win32/sys_arch.c:35`
  `#include <stdio.h> /* sprintf() for task names */` — "sprintf()" inside a trailing `/* */` comment is
  flagged in BOTH risk-scan (unsafe-string) AND backlog (hardening sprintf-migration). F1 comment-stripping
  missed a trailing block-comment on an #include line.
- **N3 (generic pack dominance, severity bump on F2).** Distinct from F2's enumerated sub-bugs: even with all
  F2 fixes in place, the generic pack's broad vocabulary makes it the default PRIMARY for any sizeable C
  library, demoting the true domain. Suggests count-normalization (matches-per-pack-token or TF-IDF-style
  weighting) or a "domain packs outrank generic when within Nx" tiebreak.
- **N4 (fuzz-coverage blind to harness in excluded tree).** test-fuzz-coverage flags 47 "parser/decoder entry
  point with no fuzz harness referencing it," but lwIP ships a real fuzzer (`test/fuzz/fuzz_common.c` 19KB +
  inputs/ corpus) that drives the IP/TCP/UDP/DNS input path. Because `test/` is excluded from scope, the lane
  cannot see the harness and reads every entry point as uncovered. F3-residual (harness recognition is
  scope-local). Advisory still useful for contrib/addons that the fuzzer genuinely does not reach.

## Negative evidence (what did NOT misfire)

- No risk/backlog hits inside `test/` or `examples/` (scope exclusions hold; 0 leaked).
- No C++ span/new/delete categories on this pure-C repo.
- casts lane (16) is real cast/sizeof-of-pointer review items — borderline but defensible, not prose FPs.
- memmove (260) and alloc (81) samples spot-checked are real calls, not comments.

## Verdict: PRODUCTIVE

Most iter-10/11 fixes held (F1 partial, F4, F5, F3/F6, W2). Surfaced 4 NEW honest weaknesses: two real
comment/string-stripper escapes (escaped-quote + multi-line + trailing block-comment), the generic-pack
primary-classification problem on the textbook networking/embedded library, and fuzz-coverage blindness to a
shipped harness in an excluded tree. Negative evidence preserved; gates ran clean (exit 0) with useful output.
