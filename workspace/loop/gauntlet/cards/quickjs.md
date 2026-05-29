# quickjs (quickjs-ng) — c-cpp-profi gauntlet card

- repo: https://github.com/quickjs-ng/quickjs
- commit: f7830186043e4488f2998759d60a514faf07cbc9 ("Update projects.md (#1514)")
- what it is: QuickJS-ng — a small, embeddable JavaScript engine in C (~63k-line `quickjs.c`,
  bytecode reader/writer, regexp engine, unicode normalizer, dtoa). Pure C, header `quickjs.h`.
- batch: final gauntlet (50/50). Gates run READ-ONLY, no build.

## Gate results

### domain-detect (exit 0)
- PRIMARY: **Compilers / interpreters / VMs** | CMakeLists.txt:360 (191 code matches) — correct.
- secondary: Parser/serialization (161), Crypto (84), Space (50), Filesystems (17), Networking (2),
  Generic (785 raw — correctly demoted below the real domain, R5 floor/tiebreak holds).
- Compression/codec pack did NOT fire — correct (quickjs is not a codec lib; the new pack is for
  libjpeg/libpng-class repos). No misfire.

### comprehension-map (exit 0)
- build systems: cmake + make + meson; `compile_commands.json` absent (noted). lang: .c=22 .h=16, .cc=1.
- L2 exported API surfaced correctly: `JS_AddIntrinsicBaseObjects` (real `JS_EXTERN`, quickjs.h:529),
  `JS_AddIntrinsicBigInt`, `lre_compile/lre_exec/lre_get_capture_count` (libregexp.h), `cr_init/cr_op`
  (libunicode.h), `js_dtoa/js_atod/i32toa` (dtoa.h), `js_init_module_{std,os,bjson}` (quickjs-libc.h).
  ~313 entries (40 shown + 273 capped). Public-header roster + entry points (qjs.c, qjsc.c main;
  LLVMFuzzerTestOneInput@fuzz.c:17) all detected.

### risk-scan (exit 0; ~620 hits across 9 lanes)
- C++ new/delete lane: **skipped — "no C++ signal (pure-C repo)"** (R1 holds; no FP explosion).
- top hits WITH triage:
  - `quickjs-libc.c:653-654` strcpy("./") then strcpy(filename+2, module_name) into
    `js_malloc(ctx, len+2+1)` → **benign, alloc is exactly sized** (W3 triage).
  - `cutils.h:856` `vsnprintf((char *)(s->buf+s->size), allocated-size,…)` → real cast w/ value,
    correctly matched, **benign** (bounded by allocated_size).
  - `quickjs.c:107` `(JSValueConst *)vals` → genuine cast (R7 holds: not a prototype param).
  - `quickjs-libc.c:4254` `msg->data = malloc(data_len); memcpy(msg->data, data, data_len)` →
    **benign** (size-matched). Most memcpy hits are `sizeof()`-sized struct/array copies.
- popen@quickjs-libc.c:1313,1798 (os.exec) — real shell-exec surface, by-design embeddable API.

### backlog (exit 0; 323 entries)
- api-ergonomics 302 — relabeled to "C: document ptr+len ownership/bounds contract" (W2/F1 hold;
  NOT span/view on C). HIGH VOLUME though (see new weakness N-qjs1).
- hardening 12: no FORTIFY/stack-protector/CFI in build, malloc-with-multiply ×4, strcpy ×5.
- portability 4: CI matrix present (5 compilers / 9 arches detected — F3/F6 hold), Y2038 time_t ×3.
- test-fuzz-coverage 5: parser entries (libregexp.h:60 lre_parse_escape, quickjs-libc.c:342/910/4930)
  flagged "no fuzz harness" — see negative/R6 below.

## REGRESSION CHECK (iter-15/16 fixes)
- domainCorrect: **yes** — Compilers/VMs PRIMARY is exactly right; Generic(785) correctly demoted (R5).
- fixesHeld: **mostly**.
  - R1 (pure-C → suppress new/delete): HELD — lane skipped, no FP storm. ✓
  - F4 (risk-scan exit 0): HELD — exit 0 verified. ✓
  - F1 (comment/string/substring): HELD — no prose FPs; `(void *)sh->proto` etc. are real code. ✓
  - F3/F6 (.github/workflows): HELD — CI matrix + FORTIFY/stack-protector surfaced. ✓
  - R7 (cast lane: no prototype-param / sizeof FPs): HELD — spot-checked casts all have a value. ✓
  - R8 (case-sensitive distinctive tokens): HELD — no Space/Crypto false-primary on this engine. ✓
  - R9 (Compression pack): correct NON-fire (not codec-heavy). ✓

## NEW weakness (not in F1-F7 / R1-R9)
- **N-qjs1 (comprehension L2 export false positives in inline-heavy public headers):**
  the L2 "non-static decls in public headers" extractor reads goto-label-prefixed STATEMENTS inside
  `static inline` function bodies in `cutils.h` as exported declarations:
  `if() | cutils.h:982,1000,1184,1371` (a `need2:`/`overflow:`/`default:` label then `if (...)`),
  and `free() | cutils.h:1655`, `pthread_attr_destroy() | cutils.h:1978` (an `error:`/`fail:` label
  then a call). Distinct from F5 (main()/doc-comment) and R4 (macro-wrapped decls) — this is
  label+keyword/call statement bodies misread as decls. Fix: in export extraction, skip lines where
  the "return type" token is a C keyword (if/for/while/switch/return/else/case/do) or where the line
  is preceded on the same logical block by a `^\s*\w+:` goto-label; require a real type token before
  the name. Low magnitude (4 visible of ~313) but a real over-match.

## Negative evidence (preserved)
- R6 STILL OPEN (confirmed here, not new): quickjs SHIPS `fuzz.c` with `LLVMFuzzerTestOneInput`
  (comprehension correctly surfaced it as a fuzz entry), yet backlog test-fuzz-coverage still emits 5
  "no fuzz harness referencing it" entries — the shipped harness is not credited against parser
  entries. Matches the open R6 finding (backlog blind to shipped libFuzzer harness mapping); no
  oss-fuzz/cifuzz.yml in this repo, so only the harness-mapping half of R6 applies.
- No comment/string FP, no C++-on-C FP, no cast-prototype FP, no domain misclassification observed.

## Verdict
**PRODUCTIVE** — domain PRIMARY correct on a marquee VM/interpreter; iter-15/16 fixes held across
R1/F1/F3/F4/F6/R7/R8/R9; one NEW low-magnitude comprehension export FP (N-qjs1) and a clean
re-confirmation of the open R6 shipped-fuzzer-credit gap.
