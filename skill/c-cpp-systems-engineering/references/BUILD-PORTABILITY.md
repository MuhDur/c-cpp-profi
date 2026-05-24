# Build, ABI, And Portability

## Build System Discipline

- Preserve the existing build system and presets.
- Do not create a parallel build system unless requested.
- Keep generated files out of hand edits.
- Export `compile_commands.json` when using Clang tooling.
- Prefer target-based CMake over global flags when editing CMake.
- Keep local developer settings out of committed presets.
- For sanitizer/fuzz scaffolds, read [TOOLCHAIN-TEMPLATES.md](TOOLCHAIN-TEMPLATES.md) and adapt the assets instead of inventing flags from memory.

## Standards

If unspecified, treat ISO/IEC 9899:2024 as the current C standard and ISO/IEC 14882:2024 as the current published C++ standard. Project constraints may require older standards. Document any feature that raises the required standard.

## Portability Checklist

- Compiler: Clang, GCC, MSVC, embedded vendor compiler.
- OS: Linux, macOS, Windows, BSD, RTOS, bare metal.
- CPU: x86_64, arm64, 32-bit, endian assumptions, alignment traps.
- Libc/STL: glibc, musl, MSVC STL, libc++, libstdc++, embedded libraries.
- Exceptions, RTTI, threads, dynamic allocation, locale, filesystem availability.
- Warning and sanitizer support differences.

## ABI/API Checklist

For public libraries:

- C ABI or C++ ABI boundary?
- Symbol visibility and export map.
- Struct/class layout, padding, alignment, enum size.
- Exception crossing boundary.
- Allocator crossing boundary.
- Ownership transfer and lifetime of returned pointers/views.
- Thread-safety guarantees.
- Versioning and deprecation policy.

## Header Hygiene

- Minimize transitive includes in public headers.
- Use forward declarations where correct.
- Keep macros scoped and prefixed.
- Avoid leaking platform headers through public API.
- Ensure C headers are C++ compatible when intended:

```c
#ifdef __cplusplus
extern "C" {
#endif

/* declarations */

#ifdef __cplusplus
}
#endif
```

## Cross Compilation

For cross builds, record:

- Toolchain file or cross file.
- Sysroot.
- Target triple.
- Emulator or hardware test path.
- Which tests were compiled only versus executed.
