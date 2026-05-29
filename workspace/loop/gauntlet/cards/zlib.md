# zlib — gauntlet card

- repo: madler/zlib @ f9dd6009be3ed32415edf1e89d1bc38380ecb95d
- domain: compression (C); core is pure-C, `contrib/` ships optional C++ wrappers
- expected pack: Generic/compression or Parser
- detected pack: **Space / satellites (PRIMARY)** — wrong (see regression)
- size: 5.8M, 79 C/C++ TUs+headers (.c=43, .cc=2, .cpp=3, .h=31)
- clone: ok; all four read-only gates exit 0

## Gate results
- domain-detect: primary `Space/satellites` (20) on contrib/iostream2/zstream.h:219;
  secondary `Networking` (4); secondary `Generic library` (64). The PRIMARY (20) outranks
  the higher-count Generic (64) via priority-tier — but the SPACE signal is phantom (below).
- comprehension: build graph ok (autotools/bazel/cmake/make all detected; compile_commands absent flagged).
  Exported-API lists 40+256 entries; surfaces `compress()/compress2()/adler32()/adler32_z()/adler32_combine*()`,
  internal `_tr_*`, `inflate_table/inflate_fast`, and contrib `set_*`. 21 entry points incl. examples/test/contrib main()s.
- risk-scan (C++ signal: yes — defensible, contrib ships real C++ TUs): strcpy/strcat/sprintf in gzlib.c+gzwrite.c;
  malloc/free pairs in gz*.c; raw new/delete in contrib/iostream*; memcpy in gzread/gzwrite; assert-only in skipset.h.
  No process/shell, no threading hits.
- backlog: api-ergonomics (ptr+len → span — NOISE on C, W2), hardening (no FORTIFY/CFI/stack-protector;
  sprintf/strcpy/strcat migration — fair), portability (CI matrix 12 compilers/14 arch detected — good; Y2038
  time_t note), test-fuzz-coverage (4 "parser entry, no fuzz harness" — all in contrib/minizip+crc32vx).

## Risk-scan triage (spot-read at file:line)
- gzlib.c:586 `strcpy(state->msg, state->path)` + :587/588 strcat — BOUNDED & SAFE. Buffer is
  `malloc(strlen(path)+strlen(msg)+3)`, exactly sized; this is the `#else` fallback only when snprintf
  is unavailable (the live path at :583 uses snprintf). Correct "migrate-to-bounded" candidate, not a bug.
- gzlib.c:224 `strcpy(state->path, path)` — BOUNDED. `state->path = malloc(len+1)` with `len=strlen(path)`. SAFE.
- contrib/iostream3/zfstream.cc:146 `strcpy(c_mode,"w")` — string literal into local; SAFE. Correct class (C++ wrapper).
- Verdict: zero false alarms in the unsafe-API lane; every hit is real-but-bounded → legitimate hardening backlog.

## REGRESSION CHECK (iter-12/13 fixes)
- domainCorrect: **no**. The SPACE pack should fire for fprime/cFE — here it fires on a pure compression lib.
  Root cause: domain-detect matches CASE-INSENSITIVELY (`rg -li`/`-iP`, scripts L172/179), so the SPACE token
  `\bOS_[A-Z]` (meant for NASA uppercase `OS_*`) matches zlib's **`OS_CODE`** — the gzip RFC-1952 header OS-id
  byte (16 hits in zutil.h + deflate.c) — and the lowercase C++ method `os_flush()` in contrib. R5's count-floor
  did NOT save this: the phantom signal cleared the floor (20) and its tier outranks Generic(64). New token-FP class.
- fixesHeld: **mostly**. F1 (comment/string/substring FPs) HELD — risk-scan is clean, no prose/literal hits,
  triage verdicts hold. C++-category gating (R1) HELD CORRECTLY — new/delete enabled because contrib ships
  genuine C++ TUs (not a build-var/test-only trigger). R2 comment-strip HELD. R3 test/example exclusion HELD
  in risk-scan/backlog scope banner. BUT two fixes did NOT hold (= findings): (1) R5 SPACE/token-bound regressed
  via case-folding on `OS_CODE`; (2) R4 macro-API surfacing regressed on zlib's `ZEXTERN ... ZEXPORT` idiom.

## NEW weaknesses (not in F1–F7 / R1–R7)
- N1 (domain-detect, R5-adjacent but NEW token): case-insensitive matching makes SPACE token `\bOS_[A-Z]`
  match `OS_CODE` (gzip header field) and `os_flush()` → SPACE wins PRIMARY on a compression lib.
  Fix: the SPACE `OS_`/`cFE_` tokens are case-SENSITIVE by intent; match them case-sensitively (or anchor to
  `OS_[A-Z][A-Z_]{3,}` excluding the common `OS_CODE`), and/or require a 2nd corroborating SPACE token.
- N2 (comprehension, R4-adjacent but NEW idiom): the headline public API — `deflate()`, `inflate()`,
  `deflateInit*()`, `inflateInit*()`, `crc32()`, `gzopen()`, `gzread()`, `uncompress()` — is NOT surfaced, while
  STRUCTURALLY IDENTICAL `compress()`/`adler32()` (same `ZEXTERN <type> ZEXPORT <name>(…)` form, zlib.h:1271/1809
  vs 254/405/1848) IS. Name extraction parses all three in isolation, so the drop is downstream of parsing —
  a real gap on the single most important C API in the corpus. The R4 export-macro allowlist matches `_EXTERN$`
  but `ZEXTERN` has no underscore, so the double-macro prefix is not stripped uniformly; surfacing is inconsistent.
- N3 (domain-detect, F2a recurrence): no compression-domain pack exists and the Parser pack's tokens
  (`*_decode`/`deserialize`/`json|xml…`) miss zlib's `inflate`/`deflate`/`inflateBack` vocabulary entirely
  (0 `_decode` hits), so the expected Parser fallback cannot fire either.

## Negative evidence (fixes that DID hold)
- risk-scan: no comment/prose/string-literal FPs; no C++ category misfire on the pure-C core (C++ lanes
  fire only on genuine contrib C++). Exit 0 (F4 held). Scope banner correctly excludes test/example/contrib-tests.
- backlog: `.github/workflows` seen (CI matrix portability item). The ptr+len→span item is the known W2 noise on C.

## Verdict: PRODUCTIVE
Three actionable findings: N1 (case-fold SPACE FP on `OS_CODE` → wrong PRIMARY), N2 (deflate/inflate/crc32 —
zlib's defining API — silently dropped from exported-API while identical compress/adler32 surface), N3 (no
compression pack + Parser blind to inflate/deflate). F1/F4/R1/R2/R3 held; R4 and R5 regressed on new idioms.
