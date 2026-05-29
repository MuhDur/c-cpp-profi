# libzmq — gauntlet card (final batch → 50/50)

- repo: https://github.com/zeromq/libzmq  (messaging, C++)
- commit: b946c18f676760387276cd095bbdd8c0e18c09bf
- expected pack: Networking / protocols
- gates: READ-ONLY (no build). All four exited 0.

## Gate results

**domain-detect** — PRIMARY = `Networking / protocols` (CMakeLists.txt:1057, 677 code matches). Correct.
Secondaries: Crypto (201), Parser/serialization (18, src/curve_client.cpp:216), Generic library (75).
Crypto is a defensible secondary — libzmq ships the CURVE/NULL/PLAIN/GSSAPI mechanisms + libsodium
(~380 crypto-ish lines in src/: nonce/encrypt/decrypt/crypto_box/curve). See REGRESSION CHECK for its anchor.

**comprehension-map** — exit 0. build systems: autotools+cmake+make. Language breakdown .cpp=287/.hpp=167
(real C++, not a build-var artifact). L2 exported API surfaces the public C ABI cleanly: `zmq_ctx_new`,
`zmq_bind/connect/close`, `zmq_msg_init/data/send/recv`, `zmq_curve_keypair`, `zmq_atomic_counter_*`
(all anchored in include/zmq.h, +1715 more capped). Public headers correctly flagged: include/zmq.h,
include/zmq_utils.h. Entry points: 24 shipped libFuzzer harnesses (tests/test_*_fuzzer.cpp) + perf/ mains
+ test mains all correctly attributed to tests/perf, not library. Module map: src/ (278), tests/ (150).

**risk-scan** — exit 0 (F4 holds). C++ signal: yes (raw new/delete enabled — correct, see R1). Top lanes:
- unsafe string/fmt: src/tipc_address.cpp:68 `sscanf(name_,"{%u,%u,%u}",…)` — TRUE POS, parses untrusted
  TIPC address; thread.cpp strncpy uses `sizeof(_name)-1` (bounded, low sev).
- raw alloc / new-delete: src/socket_base.cpp:149-209 `new (std::nothrow) <socket_t>` factory + zmtp/ws
  engine decoders — TRUE POS but idiomatic (nothrow + checked); RAII candidates, not bugs.
- casts: src/ip.cpp:419/433 `reinterpret_cast<struct sockaddr*>` for bind/connect — TRUE POS, standard
  socket-API cast. No R7 false positives (every cast hit has an lvalue/expr; the 3 `sizeof(trie_t*)`
  appearances at trie.cpp:51/177/201 are inside real `static_cast<trie_t**>(malloc(...))`, not bare casts).
- portability/endian: src/ip.cpp:419-420 `htonl(INADDR_LOOPBACK)`/`htons(...)`, ip_resolver.cpp:42/44
  `ntohs(sin_port)` — TRUE POS byte-order, load-bearing, idiomatic.
- process/shell exec: **no matches** (clean — preserve this negative; no system()/exec FP).

**backlog** — exit 0. Sample lanes:
- api-ergonomics: ptr+len pairs on the public C ABI (include/zmq.h:201/237/450 `zmq_ctx_set`,
  `zmq_msg_init_size`, `zmq_recv`) — for a C ABI this is the idiom (relabel as "document ptr+len
  ownership", per W2); the span suggestion is C++-internal-only noise on the .hpp surface.
- hardening: malloc-with-multiply (trie.cpp:51, generic_mtrie_impl.hpp:60) overflow-guard candidates;
  no _FORTIFY_SOURCE / stack-protector / CFI evidence in build files — legit.
- portability: CI matrix detected (.github/workflows/CI.yaml — F6 holds, not blind to workflows).
- test-fuzz-coverage: flags v1/v2/ws decoders (src/v2_decoder.cpp, ws_decoder.cpp) as parser entries
  with no fuzz harness — but tests/test_*_fuzzer.cpp DO ship 24 harnesses (R6: backlog still doesn't
  map shipped harness→decoder; the harnesses exercise bind/connect/stream paths that reach these
  decoders). Known-open R6, not new.

## REGRESSION CHECK (iter-15/16 fixes)

- **domainCorrect = yes.** Networking/protocols is PRIMARY by a wide margin (677 vs 201/75/18) and is the
  right call. Compression pack correctly did NOT fire (libzmq is not codec-heavy). R8 holds (no
  case-fold FP stealing primary). R9-vocab holds (Networking vocabulary matched 677 — socket/listener/
  send/recv enrichment is working).
- **fixesHeld = mostly.** F1/R2 comment+string strip holds on C/C++ (no prose/`new`/`delete`/`system`
  substring FPs; new/delete fire only on real shipped `new (std::nothrow)`). F4 exit-0 holds on all four.
  R1 holds (122 real .cpp in src/ → C++ signal correctly on). R3/R7 hold (tests/perf excluded; cast lane
  clean). R5 holds (no token-substring domain FP). One miss → see NEW.
- evidence: spot-read src/ip.cpp:419-420, src/tipc_address.cpp:68, src/ip_resolver.cpp:42-44 — all TRUE
  positives with correct triage; cast section scanned for bare-prototype/sizeof — none.

## NEW weakness (not in F1-F7 / R1-R9)

- **domain-detect anchor lands on a `#`-style comment in a CI/config file.** Crypto secondary's reported
  anchor is `.travis.yml:17`, which is a YAML comment: `#  …encrypt it with travis encrypt…`. The pack
  classification is still correct (real src/ crypto dominates the count), but the surfaced file:line is a
  prose comment. Root cause: `cpp_domain_detect.sh` strip() (lines 144-168) blanks only C/C++ `//`,
  `/* */`, and string literals — it does NOT strip `#` comments (YAML/shell/Makefile/CMake/configure.ac).
  In `all` mode the detector scans `.yml`/`.travis.yml`/CI files, so a token inside a `#`-comment survives
  and can win the anchor slot. This is a NARROW, anchor-only variant of F1/R2 (which only fixed C-style
  comment stripping). Fix: extend strip() to blank from an unquoted `#` to EOL for build/CI/config files
  (gate on extension so `#include`/`#define` in C are untouched). Low severity (cosmetic/anchor-quality;
  does not change the primary classification).

## Negative evidence (preserved)
- process/shell exec lane: no matches (no system()/popen/exec FP).
- no R7 cast FPs; no R5 substring-domain FP; no R8 case-fold primary theft; no F2 `-ffast-math`/`-std`
  brittleness abort; Compression pack correctly silent.

## Verdict
**PRODUCTIVE.** Correct Networking primary, clean C ABI surface, all gates exit 0, iter-15/16 fixes hold
on a large real C++ messaging stack — and the breadth surfaced one NEW narrow anchor-quality weakness
(`#`-comment stripping in domain-detect over CI/config files).
