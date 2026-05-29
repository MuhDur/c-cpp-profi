# fprime — c-cpp-profi read-only gauntlet card

- repo: nasa/fprime @ `37931e8ea1ab666a5e948ce21a2ea55082c4b88c` (shallow clone OK)
- size: 57 MB, 1394 C/C++ files (.cpp=725, .hpp=656, .c=3, .h=10 — overwhelmingly C++)
- expected pack: Space / satellites | detected primary: **Compilers / interpreters / VMs** (Space fired SECONDARY)
- gates run read-only (no build): domain-detect, comprehension-map, risk-scan, backlog — all exit 0

## Gate results
- **domain primary**: Compilers/VMs (561 code matches) @ FppTestProject/.../ActiveTest.cpp:100.
  Secondaries: Space/satellites (136), Parser/serialization (35), Networking (9), Databases (2), Generic (43).
- **comprehension**: build=cmake+make; compile_commands absent (noted). Exported API surfaced
  (3209+ decls, capped) — real flight API present: AosDeframer/AosFramer, ActiveTextLogger,
  AppendFile_cmdHandler, BufferAccumulator; module map clean (Svc 486, Fw 233, Os 211, Drv 66).
  Entry points = all test `main()` (no shipped entry — framework, expected).
- **risk-scan** (412 hits, C++ signal=yes correctly): top lanes —
  - casts(review): `Drv/Ip/IpSocket.cpp:97 *reinterpret_cast<unsigned long*>(ip4) = ip` →
    **REAL aliasing+width bug** (writes 4-byte int through 8-byte ulong* into a 4-byte s_addr; VxWorks
    `#ifdef`-gated). Lane correctly caught the klib-class defect from FINDINGS. **TP, ship-worthy.**
  - unsafe-str: `Fw/Types/StringBase.cpp:91 strncat(...)` → **bounded** (`remaining=cap-len-1`, FW_ASSERT'd).
    TP surface, safe-on-triage.
  - shell-exec: `STest/.../Scenario.hpp:147 system("test -f show-rules")` → **test-framework leakage** (STest is
    in-repo unit-test scaffolding, not flight code).
  - placement-new (Fw/DataStructures, FpySequencer): legit RAII-over-static-storage idiom (flight no-heap).
- **backlog**: portability lane strong & correct (endian on Drv/Ip sockets, Y2038 time_t on LinuxTimer);
  hardening (no FORTIFY/CFI/stack-protector) valid; CI matrix detected (.github/workflows). Noise: span/ptr+len
  on `Utils/Hash/openssl/sha.h` (vendored OpenSSL header, should be excluded); fuzz-coverage flags sha.h decoders.

## REGRESSION CHECK (iter-12/13 fixes)
- **domainCorrect: partial.** Space DID fire but only as secondary, and almost entirely by COINCIDENCE:
  136 Space matches = 127 `OS_[A-Z]` (fprime's `Os/` portable-OS layer macros incidentally hitting the cFE
  `OS_*` token) + 4 watchdog. The Space pack is cFE/cFS-tuned (`cFE_|OS_[A-Z]|MISRA|RTEMS|Power of Ten`) and
  is **blind to fprime's actual vocabulary**: CCSDS(49), Framer/Deframer(214), Tlm*(186), FwOpcodeType(201),
  CmdResponse(209), downlink/uplink(38), APID(56) — 700+ unambiguous flight-SW tokens unrecognized.
  Meanwhile **Compilers won primary on a token collision**: pattern `\bopcode\b` (case-insensitive) matched
  fprime's `FwOpcodeType opCode` telecommand field (431 hits) — a Space term, not a bytecode opcode.
- **fixesHeld: mostly.** F1 comment/string-strip HELD (no prose/comment FPs in 412 hits). F4 risk-scan exit=0
  HELD. R1 C++ signal correct (real C++ TUs, not a build-var) HELD. R4 macro/namespaced API surfaced HELD
  (`*_cmdHandler`, namespaced ctors present). BUT **R7 cast-lane FPs persist** (~7): disabled-ctor prototypes
  `InputPortBase(InputPortBase*)`/`PortBase(PortBase*)`/`MemAllocator(MemAllocator*)` (5) read as C-casts, and
  `sizeof(U32)+sizeof(U8*)` arithmetic (2) read as casts. **F7/R3 test-exclusion did NOT hold** on non-standard
  harness names: `STest/` (test framework, 54 risk hits) and `FppTestProject/` ("unit tests for FPP autocoder",
  7 risk hits + 22/40 of the sampled exported-API entries) leak in — neither matches test/ tests/ *_test.* etc.

## NEW weaknesses (not in F1-F7/R1-R7)
- **N1 (domain pack incompleteness — NEW):** the Space pack only models NASA **cFE/cFS** (`OS_*`/`cFE_`/`RTEMS`).
  It has NO **fprime/F´** signal (CCSDS, Framer/Deframer, FwOpcodeType, Tlm*Chan, CmdResponse, APID, ComBuffer,
  FpySequencer). Two distinct NASA flight frameworks; the pack covers one. → add an fprime token set to Space.
- **N2 (cross-pack collision — NEW):** `\bopcode\b` is a shared term between Compilers/VMs and Space telecommand
  handling. It single-handedly flipped primary. → either weaken bare `opcode` in Compilers (require it WITH
  bytecode/interpreter/codegen co-occurrence) or add a domain-over-domain tiebreak when a Space pack also fires.
- **N3 (test-harness name blindlist — NEW, generalizes R3):** exclusion is still name-pattern based; CamelCase
  test-project roots (`STest`, `FppTestProject`, `TestDeploymentsProject`) evade it. → match `*Test*Project`,
  leading/standalone `*Test` dir segments, and read CMake `Builds unit tests` markers.

## Negative evidence (fixes that DID hold — preserve)
- No comment/string-literal/substring FPs (F1). risk-scan exit 0 (F4). C++ categories correctly enabled on real
  C++ (R1). Exported API + macro/namespaced decls surfaced (R4). Backlog portability/hardening/CI lanes accurate.
- The genuine aliasing/width defect class (klib knetfile note in FINDINGS) was CAUGHT here at IpSocket.cpp:97.

## Verdict: PRODUCTIVE
Real defect surfaced (IpSocket.cpp:97), fixes mostly held, and the run exposed 3 concrete NEW weaknesses: the
Space pack models cFE not fprime (N1), an opcode cross-pack collision flips primary (N2), and CamelCase
test-project roots evade exclusion (N3). domainCorrect=partial; this is exactly the breadth the gauntlet is for.
