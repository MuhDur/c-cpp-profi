# ftxui — c-cpp-profi gauntlet card

- **Repo:** ArthurSonzogni/FTXUI (terminal UI library, C++)
- **Commit:** `a9ddb31` (tools: Stabilize ABI fingerprinting across compiler environments (#1280))
- **Size:** 3.1M, 264 C/C++ files. `.cpp=215 .hpp=49 .c=0 .h=0` — pure C++17/20, namespaced (`ftxui::`), class-based.
- **Expected pack:** native-ui or Generic. **Detected:** `unknown-domain`.
- **Builds:** bazel + cmake + meson (all three present). No `compile_commands.json` (L2 index blind, as expected for a no-build read-only run).

## Gate results

### domain-detect → `unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`
No pack matched. Verified by hand: the `generic` pack keys on **C-library idioms**
(`KHASH`, `kvec_t`, `sds*(`, `*_init`/`*_free`/`*_destroy`/`*_new` free functions,
`#define *IMPLEMENTATION`, `typedef struct {`) — **zero** of these appear in FTXUI's
namespaced C++ (methods are `Component::Add()`, not `component_add()`). Even the
`parser` pack misses despite a `terminal_input_parser.cpp`, because the code uses
`TerminalInputParser::Parse()` (a method), not a `*_parse`/`parse_*` free function.
So `unknown-domain` is the **honest** output, not a bug. See domainCorrect below.

### comprehension-map
- Build graph: bazel|cmake|meson detected; std hints cxx_std_17 + cxx_std_20.
- **Exported API: ~466 non-static public-header decls** (50 shown + "+426 more; capped").
  Almost all anchored to `include/ftxui/**` real public headers: `Button()` `Checkbox()`
  `Border()` `CatchEvent()` `CaptureMouse()` `App()` etc. This is the genuine FTXUI API.
- Entry points: fuzz harnesses (`LLVMFuzzerTestOneInput`) + ~90 `main()` (all under
  `examples/` and `bazel/test/` — correctly labelled as examples, not lib entry).
- Module map: include(39) / src(134) / examples(89) / bazel(1) / tools(1).

### risk-scan (exit 0 — F4 holds)
C++ signal: yes → new/delete category enabled. Top hits + triage:
- **new/delete (5):** `receiver.hpp:86` `new SenderImpl<T>(this)` → REAL, but wrapped
  immediately in `unique_ptr` (idiomatic, safe). The other **4 are FALSE POSITIVES**
  (see NEW weakness): `app.cpp:657 // …new line…`, `button.cpp:112,129 // May delete this.`,
  `component.cpp:111 // Might delete |this|.` — all the words "new"/"delete" in TRAILING comments.
- **assert (4):** `component.cpp:65`, `task_runner.cpp:14,25`, `component_fuzzer.cpp:182` —
  all REAL `assert()` calls; legit assert-only-validation surface.
- **threading (~18):** `std::atomic` / `std::mutex` / `lock_guard` / `unique_lock` in
  `app.cpp`, `task_queue.*`, `receiver.hpp` — all REAL; correct concurrency surface.
- unsafe-string / raw-alloc / casts / memmove / shell-exec: **no matches** (correct).

### backlog (4 items)
- hardening: no `-D_FORTIFY_SOURCE`, no CFI, no stack-protector in build files (fair, actionable).
- portability: CI matrix covers 6 compilers / 1 arch — "verify it spans intended targets" (fair).
No `api-ergonomics` C-on-C++ noise (W2/F3 gating holds). No span-on-C noise. No fuzz-harness-as-uncovered.

## REGRESSION CHECK
- **domainCorrect = partial.** No `native-ui`/`tui`/`terminal` pack exists in
  `cpp_domain_detect.sh` (NATIVE-UI-GOLDENS.md is a reference doc only, not a pack),
  and `generic` is hard-keyed to C-library idioms so a namespaced C++ TUI lib can't
  hit it. `unknown-domain` is the defensible/honest fallback, but a real domain
  (native-ui) was expected and the tool has no pack for the entire C++/Qt/TUI UI
  family. Gap, not a misclassification.
- **fixesHeld = mostly.** F4 (risk-scan exit 0) holds. F5 (exported C/C++ API)
  holds strongly — 466 real public-header decls surfaced, examples' `main()` not
  mis-counted as lib entry. F1 holds for **comment-only** lines but FAILS for
  **trailing/inline comments** (see NEW weakness) — 4/5 new/delete hits are prose.
  F3 span/api-ergonomics gating holds (no C-idiom noise on this C++ lib).

## NEW weaknesses
- **risk-scan trailing-comment false positives (new/delete lane).**
  `drop_comment_lines()` (cpp_risk_scan.sh:87-104) only drops a row when the matched
  line's content *begins* with `*`/`//`/`/*`. Lines that are real code with a TRAILING
  comment slip through, and the new/delete regex then matches the prose inside the
  trailing comment. Concrete FPs at this commit:
  - `src/ftxui/component/app.cpp:657` — `terminal.c_lflag &= ~ECHONL;  // …new line…`
  - `src/ftxui/component/button.cpp:112` and `:129` — `OnClick();  // May delete this.`
  - `src/ftxui/component/component.cpp:111` — `…children.erase(it);  // Might delete |this|.`
  Fix: strip inline `//…` (and `/* … */`) tails before matching, or require the
  new/delete token to precede a type-ish token / not live after a `//` on the line.
- **(minor) comprehension over-includes a src-private header:** two API entries point at
  `src/ftxui/component/terminal_input_parser.hpp` (under `src/`, not `include/`) — counted
  as exported API though it is internal. Low severity.

## Negative evidence (honest)
- domain-detect produced NO pack — genuine coverage gap for the native-ui/UI family.
- risk-scan over-reports new/delete by 4 (80% of that lane is comment noise here).
- The one real `new` (`receiver.hpp:86`) is immediately `unique_ptr`-wrapped — safe;
  risk-scan has no way to see that nuance (expected; triage is the human/agent's job).

## Verdict: PARTIAL
Gates ran clean (exit 0, no crash); comprehension + backlog are solid and F4/F5/F3
fixes hold. But domain-detect has no native-ui pack (partial), and the F1 comment
fix does NOT cover trailing comments — a real, reproducible new-weakness regression
on this C++ repo. Productive: surfaced one concrete skill fix worth folding back.
