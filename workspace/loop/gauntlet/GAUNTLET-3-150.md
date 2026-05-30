# Gauntlet #3 — 160-repo re-validation + deep gap audit (the 100 rating disproven, then largely repaired)

Iteration 40 (workflow `w7rkgwd24`, 22 agents, ~1.6M tokens, ~33 min). The user asked to "check and verify
and close remaining gaps; use workflows to fully cover in depth and test the skill on a total of 150
repositories." The motivation was concrete: the iter-39 paradigm-signal lane, the three new references
(DESIGN-PARADIGMS / LANGUAGE-INTERNALS / STANDARDS-VERSIONS-IDIOMS), the codec fix and the large-repo guards
all landed **after** the last 150-repo gauntlet (iter-34), so they had never been validated at scale.

## What ran

- **160 candidate repos** cloned shallow into `/tmp/cpp-gauntlet-150` (0 clone failures), spanning 15 domain
  families (parsers, codecs, compression, crypto, networking, databases, interpreters/VMs/compilers, embedded/
  RTOS, space/safety-critical, GPU/HPC/SIMD, audio/DSP/media, regex, game/graphics/GUI, allocators/containers/
  test, ML/tensor, emulators/kernels). The full current tool suite was run on each (domain_detect,
  comprehension_map incl. the new paradigm lane + `--exact`, risk_scan, backlog), recording exit code, wall
  time, missing sections, NUL floods, tracebacks, scope leaks, and misclassifications.
- **6 deep adversarial auditors** in parallel (comprehension script, risk/backlog/domain scripts, the four
  Python tools, reference factual accuracy, SKILL.md↔reality contract coherence, capability-vs-the-six-
  requirements), each cloning scratch repos and RUNNING the tools to confirm/refute suspicions.
- A synthesis stage deduped **74 gauntlet anomalies + 34 audit findings → 26 ranked gaps**.

## Verdict from the run: 100/100 was NOT supported

The 150-repo evidence at 2× the post-iter-34 surface found **five distinct high-severity issues plus two
high-severity missing guards** — a tool crash, two safety bypasses, a false-pass contract validator, an
unenforced headline claim, and two unguarded scanners that timed out. Per the loop's honesty contract ("the
score may go DOWN; if a later iteration exposes that an earlier claim was hollow, lower it and log why"), the
composite was dropped from 100 to an honest **~84** at the moment those defects were confirmed, then climbed
back as each was fixed and verified. 94/160 repos were fully clean before fixes (59%); most of the other 66
were low-severity heuristic imprecision (domain mislabels with a correct secondary still present, paradigm
labels skewed by comments/vendored tests).

## The 26 gaps and their disposition (all evidence on the offending repo)

### HIGH — blockers (all FIXED + verified)
| ID | Issue | Fix | Verified |
|----|-------|-----|----------|
| G1 | `--exact` crashed the whole comprehension script (exit 1, dangling header) on header-only AND huge repos | tolerate rg no-match + awk truncation instead of head | jsmn/json.h/utf8.h exit 0 + graceful note, no broken pipe |
| G2 | `@reexec` denylist bypassable via backtick / `$()` / `<<<` substitution (ran real `rm` while reporting PASS) | refuse any command containing nested-exec syntax | backtick-rm report REFUSED, sentinel survives |
| G3 | `@reexec` denylist bypassed by versioned interpreters (python3.11, perl5.36), perl -E, glued `-c` | deny interpreter basenames outright | all four prior bypasses refused |
| G4 | contract validator `bash -n a.sh b.sh …` checked only the FIRST of 8 helpers → false PASS | per-file loop | syntax error in a non-first script now caught + named |
| G5 | proof gates were label-presence only — prose passed `--require-*-proof` | anchor/number/count content validators behind the flags | prose comprehension report FAILS (ANCHORLESS), anchored example PASSES |
| G6 | test-suite HEADERS (tests_impl.h, testutil.h, wycheproof) leaked into risk/backlog despite the `[scope]` banner | anchored test-header globs (identical in both scripts) | secp256k1 test-header leak 88 → 1 (the 1 is real lib code) |
| G8 | risk_scan had no large-repo guard (~87s on nuttx, no note) | file-count guard mirroring backlog | nuttx 87s → 1s with scope note |
| G9 | domain_detect timed out (exit 124) on mongoose/nuttx/betaflight/wolfssl | exclude tutorials/; for huge/amalgam repos strip an evenly-sampled line-capped corpus ONCE | all complete in ≤26s, exit 0 |

### MED — real bugs / accuracy (FIXED + verified)
| ID | Issue | Verified |
|----|-------|----------|
| G7 | unanchored `*test*.c` dropped real shipped code (attestation.c, fastest.c); bench glob dropped public bench.h/benchmark.h | all four scanned again; tests/foo_test.cc still excluded |
| G10 | CMake `Find*.cmake` flooded the Crypto pack | excluded; curl/libcoap re-scored from own code, not find-modules |
| G11 | vendored deps under non-standard dirs overwhelmed identity | mold no longer Compression (third-party/zstd), mgba no longer Databases (sqlite3) |
| G12 | paradigm lane only stripped leading-comment lines, not block-comment interiors/strings | synthetic comment/string fixture → 0 markers; sljit/cglm → procedural |
| G13 | paradigm lane scanned vendored test frameworks / contrib / examples | miniz 911→11 C-OOP, zlib OOP→C-OOP, NNPACK→C-OOP; tinyxml2/fmt/abseil stay OOP |
| G15 | three checkers raised tracebacks on binary/missing input | clean one-line error + exit 2 |
| G16 | contract validator crashed on a bad dir / lacked --help | argparse; --help prints usage, missing dir prints clean FAIL |
| G17 | vacuous empty-needle `@verify-contains`; silently-ignored malformed sha256 | both now error |

### LOW — precision / docs (FIXED)
G14 (≥2-marker threshold for a non-procedural paradigm label — jsmn/BLAKE2/uthash → procedural),
G18 (aligned_alloc DR460 correction), G19 (verify-* path-traversal containment), G20 (idea-card anchor must be
number+unit, not a bare digit), G21 (lambda arm no longer matches `operator[](`), G23 (CRLF / no-trailing-
newline frontmatter), G24-FP (gperftools no longer Space; cFE/fprime stay Space), G26 (SKILL.md states the
checker is a linter, not a gate-runner).

### Deferred / documented residuals (honest, low-severity)
- **G22** (comment stripper does not carry `//` state across a `\` line-continuation): genuinely obscure; the
  three shared `STRIP_COMMENTS_AWK` helpers are calibration-sensitive, so the fix is deferred rather than risk
  the 50-repo calibration for a rare case. Documented here.
- **G24 missing domain packs** (linker / emulator / benchmark-framework / GPU-runtime / windowing): real
  coverage gap — mold→Parser, mgba→Networking are no-pack fallbacks, not regressions. Logged as a feature
  backlog (additive; needs new reference packs + validator updates).
- **Heuristic domain-primary imprecision** for crypto-heavy protocol libs (curl/libcoap/libwebsockets →
  Crypto-primary, Networking-secondary): the correct pack is surfaced as secondary so its gates still apply —
  the documented secondary-pack guarantee. Not over-tuned, to protect the hard-won 50-repo calibration.
- **G25** (exact LLVM-IR callgraph sparse without compile_commands.json): a fundamental static-analysis limit,
  already documented in the tool output — NOT a gap.

## Rating impact (honest)

Composite **100 → 97.5** (recorded only in `workspace/loop/RUBRIC-100.md`/`STATE.md`, never in the skill or
README). The drop is real: the adversarial 160-repo pass proved the 100 was not robust. The climb back to 97.5
is earned — every high-severity blocker (G1–G9) and every med real-bug/accuracy item (G6,G7,G10–G17) is fixed
and verified on the exact offending repo, the calibration self-tests + completion audit are green, and no
regression was introduced (cJSON/secp256k1/zlib/lua/cFE/fprime controls all hold). The residual 2.5 is genuine
and documented (C6 missing-packs + protocol-lib primary imprecision; the deferred G22; the fundamentally best-
effort reexec denylist + lightweight proof-anchor validation in Q1) — not faked back to 100. Twelve commits,
all pushed.
