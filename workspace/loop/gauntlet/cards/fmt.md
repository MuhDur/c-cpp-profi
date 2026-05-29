# fmt — c-cpp-profi gauntlet card

- repo: https://github.com/fmtlib/fmt @ `0acf106c52f5c7f068ce6313f2ca310c7d5e8b63`
- expected pack: Generic library | detected pack: **Parser / text-format / serialization** (defensible alt)
- size: 4.1M, 72 C/C++ files (46 .cc, 25 .h, 1 .c); header-only lib (`include/fmt/`) + 4 src/ TUs; CMake+Android.mk; C++11/14/20
- gates run READ-ONLY (no build); all four EXIT=0

## Gate results
- **domain-detect**: primary `Parser / text-format / serialization` | include/fmt/base.h:1228 (192 code matches). ONLY pack fired (JSON: single pack, no secondary). 192 matches are real: `parse_context`, `parse_nonnegative_int`, `parse_align`, `parse_arg_id`, `parse_dynamic_spec` — fmt's core is a genuine format-string parser + output serializer. Generic pack did NOT fire (its tokens are C-idiom-specific: KHASH/kvec/sds/`_init`-`_free`; modern-C++ fmt uses none).
- **comprehension**: build graph (cmake+make, compile_commands absent flagged); lang breakdown .cc=46/.h=25/.c=1; 14 public headers enumerated; L2 exported-API list 1062 entries (capped, +1048 more); FMT_API macro-wrapped API surfaced via exported-symbol-hint lane (base.h:2882/2883 vprint, 2395 vformat_to, 361 assert_fail, 643 report_error); 8 LLVMFuzzer + 6 main() entries; 3 modules.
- **risk-scan** (top hits + triage):
  - printf.h:599/603 `sprintf` decl — **borderline FP**: fmt's OWN type-safe `string_view`→`std::string` reimpl, NOT libc fixed-buffer sprintf. No `sprintf(buf,...)` exists in shipped code. Name-collision (F1-class). Verdict: SAFE.
  - args.h:59 `new typed_node<T>` — REAL, immediately wrapped in `unique_ptr` (RAII). Verdict: safe-by-construction.
  - os.cc:386 `new char[buffer_size]` — REAL array alloc; matching `delete[] data()` at os.cc:398. Verdict: paired, owner-managed.
  - format.h:274 `memcpy(static_cast<void*>(&to),&from,sizeof(to))` — REAL bit_cast impl (comment at :273 correctly NOT flagged). Verdict: bounded by sizeof.
  - C++ new/delete category correctly ENABLED ("C++ signal: yes") — fmt genuinely is C++.
- **backlog** (sample): api-ergonomics owning-new (format-inl.h:87); hardening: no FORTIFY/CFI/stack-protector, sprintf migration (printf.h:599/603 — same FP); portability: endian assumption (format.h:283/284, real `__BYTE_ORDER__`), time_t/Y2038 (chrono.h:481-504); CI matrix detected (cifuzz.yml, 5 compilers/2 arch); test-fuzz-coverage: 5 parser entries w/o harness ref (format-inl.h:1791, ranges.h:701-728).

## REGRESSION CHECK (iter-12/13 fixes)
- **domainCorrect = partial**. Detected Parser, expected Generic. Parser is the MORE defensible classification — fmt is literally a format-string parser/serializer. Not a misfire off one incidental token (192 real matches across base.h parse_* family). Generic correctly abstained (C-idiom tokens absent). SPACE pack correctly did NOT fire (no fprime/cFE signals) — preserved negative evidence.
- **fixesHeld = mostly**.
  - F1/R2 (comment/string/substring FPs): HOLD. printf.h:596 docstring `sprintf` excluded; only real decls flagged. No prose/literal hits in 3 spot-reads.
  - R1 (C++ category gating): HOLD correctly — fmt IS C++, "C++ signal: yes" rightly enables new/delete (no over-suppression).
  - F4 (exit 0): HOLD — all gates EXIT=0.
  - F7/R3 (test/bench exclusion): HOLD — risk-scan only `include/`+`src/`; lone `test/` string is the scope banner; test/fuzzing + test/c-test.c excluded from risk-scan yet fuzz harnesses surfaced by comprehension's LLVMFuzzer lane.
  - F5/R4 (exported API): MOSTLY. FMT_API macro-wrapped public decls surfaced via exported-symbol-hint lane. But L2 exported-API ranking is dominated by `detail::` template helpers (advance_to/align/narrow/check) — the headline user API `fmt::print`/`fmt::format`/`fmt::vprint` is buried/shown only via peripheral-header overloads (ostream.h/compile.h/std.h). Already catalogued R4 (open); not a new break.

## NEW weaknesses
- none new. The one borderline FP (fmt's safe `sprintf` flagged unsafe) is F1-class name-collision, already known. R4 API-ranking-buries-headline-names already open. No new concrete weakness beyond F1-F7/R1-R7.

## Negative evidence (preserved)
- SPACE pack did NOT fire (correct — no flight-software signal).
- Generic pack did NOT fire (correct — no C-container idioms).
- No comment/string/prose FP in risk-scan across 3 spot-reads.
- No libc fixed-buffer sprintf/strcpy/gets in shipped code.
- compile_commands.json absent — correctly flagged (L2 index-blind note), not silently ignored.

## Verdict: PRODUCTIVE
Clean run, 4/4 gates EXIT=0. Defensible domain (Parser over expected Generic — arguably the better label for a format engine). FPs minimal and all F1-class. Fixes hold; R4 API-ranking weakness reconfirmed on a large header-only C++ lib (detail:: helpers outrank headline names), reinforcing the open R4 fold-back.
