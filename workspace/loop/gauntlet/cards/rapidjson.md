# rapidjson — gauntlet card

- repo: Tencent/rapidjson @ `24b5e7a8b27f42fa16b96fc70aade9106cf7102f` (shallow clone OK)
- expected pack: Parser / text-format / serialization
- detected primary: **HPC / SIMD / numerics** (Parser demoted to secondary) — partial
- size: header-only C++ JSON library; 96 C/C++ files, ~40k LOC; public API in `include/rapidjson/*.h` (document.h 131KB, reader.h 92KB, schema.h 144KB); `.cpp` only under `example/` + `test/`
- build: CMake; std hints c++0x..c++20; no compile_commands.json

## Gate results

- **domain-detect**: primary HPC/SIMD (71, anchor reader.h:1094 = SSE2 SkipWhitespace); secondary Parser (11, anchor prettywriter.h:201); secondary Generic (19). SPACE pack correctly absent.
- **comprehension**: language breakdown .cpp=55/.h=41 (correct); L2 exported-API surfaced well — Parse/Accept/AddMember (document.h), Bool/StartObject across reader/writer/prettywriter, all 37 public headers enumerated; 1291 symbols capped. Entry points list example/ + test/ `main()`s (expected for a header lib with sample programs — not noise, but they are non-shipped).
- **risk-scan**: exit 0. unsafe-string=none, process/shell=none, threading=none. casts (~150) and unchecked memmove/memcpy (~70, mostly uri.h/document.h/schema.h `Malloc`+`memcpy`) dominate.
  - triage reader.h:1094 `reinterpret_cast<const __m128i*>(&dquote[0])` — SAFE, legit SIMD load over a local aligned 16-byte array.
  - triage allocators.h:408 `reinterpret_cast<uintptr_t>(buf)` — SAFE, standard alignment cast, bounds-guarded by adjacent `RAPIDJSON_ASSERT(size >= abuf-ubuf)`.
  - cast/memmove lanes are clean (no comment/string/prose FPs); the `std::malloc/realloc/free` macro hits (rapidjson.h:696-704) are accurate.
- **backlog**: hardening (no FORTIFY/CFI/stack-protector — fair for header-only), portability endian/packing rapidjson.h:247-250 (real, load-bearing), 23 test-fuzz-coverage parser-entry rows (reader.h/document.h/pointer.h — defensible; rapidjson does ship fuzzers under test/fuzz but they are excluded from scan scope).

## REGRESSION CHECK

- **domainCorrect: partial.** HPC-primary is *defensible* (90 SIMD-intrinsic lines in reader.h — rapidjson genuinely ships hand-vectorized SSE2/NEON scanning) but WRONG as the headline: the library's purpose is JSON parsing. Parser token set under-counts (11; matched prettywriter, missed the obvious reader.h `Parse`/`GenericReader`/SAX `Handler` surface = 77 raw hits). Also secondary order is by-print not by-count: Parser(11) printed before Generic(19). F2/R5-class: an optimization detail outranks the real domain.
- **fixesHeld: mostly — with one real miss (R1 extension).**
  - R1 (C++ signal) did NOT hold for a **header-only C++ library**. `detect_cpp()` (risk_scan L75-90, backlog L145) deliberately excludes `.h` ("a C header is not a C++ signal") and counts only shipped `.cc/.cpp/.hpp/...`. rapidjson ships ALL code in `.h`; `.cpp` lives only in excluded example/test → verdict `C++ signal: no`. Consequences: (a) risk-scan prints `[scope] C++ signal: no (pure-C)` and **suppresses the new/delete category** on a repo with real placement-new (writer.h:219/243, prettywriter.h:125/159) and `RAPIDJSON_NEW`/`RAPIDJSON_DELETE` macros (rapidjson.h:712/716); (b) backlog emits the **C-flavored** api-ergonomics row "(C: document the ptr+len ownership/bounds contract)" (allocators.h:201, memorystream.h:43) instead of the correct C++ `std::span/string_view` advice — exactly backwards for a C++ template lib. Evidence: 32 shipped headers contain `template<`/`namespace`; document.h has 301 `::`/template/class hits. A `.h` whose CONTENT is unambiguous C++ (templates/namespaces/classes/`reinterpret_cast`) IS a C++ signal; the R1 fix over-corrected.
  - R2 (comment/string strip): HELD. No prose/literal/`__m128i`-array FPs in any lane.
  - R3 (test/suffix exclusion): HELD. example/, test/, thirdparty/ all excluded; scope banner accurate.
  - R4 (exported API incl. namespaced/macro): HELD. C++ namespaced + RAPIDJSON_-macro-wrapped decls surfaced (Parse, AddMember, GetParseError_En).
  - R7 (cast-lane FPs): HELD. Spot-checked casts are real reinterpret/static_cast, not arithmetic/proto FPs.

## NEW weakness (not in F1-F7 / R1-R7)

- **N-rapidjson**: R1's C++-signal heuristic produces a **false NEGATIVE on header-only C++ libraries** — the dominant shipping form for modern C++ (rapidjson, nlohmann/json, Eigen, fmt, Catch). Because the signal is extension-only (`.h` excluded) and `.cc/.cpp` live solely in excluded example/test trees, a pure-C++ template library is mislabeled `pure-C`, suppressing the new/delete risk category AND flipping the backlog api-ergonomics recommendation to the C ptr+len phrasing. Fix: treat a `.h`/`.hpp` whose content carries unambiguous C++ tokens (`template<`, `namespace`, `class`/`struct` with methods, `reinterpret_cast`/`static_cast`, `::`) as a C++ signal — a content probe, not just an extension probe. This is distinct from R1 (which was about a C lib with a CXX *build target*); the inverse failure was never exercised because every prior C++ repo in the gauntlet shipped at least one `.cc/.cpp`.

## Negative evidence

- No unsafe-string/format, no process/shell, no threading hits — accurate for a JSON parser. Cast/memmove lanes fired heavily but spot-triage found no false positives. SPACE pack correctly did not fire. Comprehension exported-API and entry-point enumeration are solid. Risk-scan exit 0 (F4 held).

## Verdict: PRODUCTIVE

Breadth gates ran clean and surfaced real structure. The regression check earned its keep: it exposed a genuine inverse-of-R1 gap (header-only C++ misclassified as pure-C) that propagates the wrong language assumptions into two gates. domainCorrect partial (HPC-over-Parser ranking). fixesHeld mostly; one fix (R1) did not hold for this repo shape — recorded as N-rapidjson for fold-back.
