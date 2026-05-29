# C5 Documentation Trial: inih

This artifact applies the `c-cpp-profi` DOCUMENTATION.md methodology to a real C
library: **inih** (`/tmp/cpp-gauntlet/inih`, Ben Hoyt, BSD-3-Clause, version 62).
It contains (a) a real README section with the required sections and a compiling
snippet, and (b) a header API-contract block for one real public function. Both
were verified with `cpp_docs_check.py`; the commands and outputs are at the end.

The facts below are copied from the repo, not invented:
build system `meson.build` (version 62, license `BSD-3-Clause`), public header
`ini.h`, and the `ini_parse_string` return contract from its own header comment.

---

## (a) README section

# inih -- simple .INI file parser

inih reads `[section]` `name = value` INI files by calling a handler callback
for each parsed pair. It is for C and C++ application authors who need a small,
dependency-free config parser they can vendor as two files (`ini.c`, `ini.h`).

## Build from source

inih ships a Meson build (`meson.build`, project version 62, language C). Build
and run the test suite with:

```sh
meson setup build
meson compile -C build
meson test -C build
```

Toolchain matrix from the repo: any C99 compiler (GCC, Clang, MSVC); the C++
wrapper under `cpp/` targets `cpp_std=c++11` as set in `meson.build`. Meson
`>= 0.56.0` is required. The library has no third-party runtime dependencies.

Vendoring without Meson works too: drop `ini.c` and `ini.h` into your project
and compile `ini.c` with your own rules. Compile-time behavior is selected with
`-D` macros such as `-DINI_ALLOW_MULTILINE=0` or `-DINI_USE_STACK=0`.

## Install

With Meson and the `distro_install` option set, the build installs the shared
library, the `ini.h` header, and a `pkg-config` `inih.pc` file:

```sh
meson setup build -Ddistro_install=true
meson install -C build
```

Consumers then link via `pkg-config --cflags --libs inih`. The default build is
a static convenience library intended to be vendored rather than installed.

## Usage / quickstart

The smallest program that links against inih, parses an in-memory INI string,
and prints each pair. Compile and run by vendoring `ini.c`:

```c
#include <stdio.h>
#include "ini.h"

static int dump(void* user, const char* section,
                const char* name, const char* value) {
    (void)user;
    printf("[%s] %s = %s\n", section, name, value);
    return 1; /* nonzero = continue parsing */
}

int main(void) {
    const char* cfg = "[net]\nhost = localhost\nport = 8080\n";
    int rc = ini_parse_string(cfg, dump, NULL);
    if (rc != 0) {
        fprintf(stderr, "parse error at line %d\n", rc);
        return 1;
    }
    return 0;
}
```

Compile and link line (vendored single-file build):

```sh
cc -std=c99 -I/tmp/cpp-gauntlet/inih main.c /tmp/cpp-gauntlet/inih/ini.c -o demo && ./demo
```

Expected output:

```
[net] host = localhost
[net] port = 8080
```

## Capability table

| Capability | Status | Entry point | Notes |
|---|---|---|---|
| Parse file by path | stable | `ini_parse()` | opens and closes the file itself |
| Parse open `FILE*` | stable | `ini_parse_file()` | caller owns and closes the `FILE*` |
| Parse in-memory string | stable | `ini_parse_string()` | no I/O; touches no shared state |
| Parse with custom reader | stable | `ini_parse_stream()` | caller supplies an `ini_reader` |
| Per-line numbers in handler | opt-in | `INI_HANDLER_LINENO=1` | changes the handler signature |

## Versioning / ABI policy

inih is released as numbered versions (currently 62) and is most often vendored,
so the consumer recompiles `ini.c` against the matching `ini.h`. When consumed as
a shared library, a change to the `ini_handler` signature (for example enabling
`INI_HANDLER_LINENO`) is an ABI break and requires recompiling every caller. See
the project changelog for per-version notes.

## License and contributing

inih is distributed under the New BSD license (`BSD-3-Clause`), Copyright (c)
2009-2025 Ben Hoyt; see `LICENSE.txt`. Contributions go through pull requests on
the upstream GitHub project.

---

## (b) Header API contract (Doxygen) for one real public function

The contract below documents `ini_parse_string` from `ini.h`. Ownership,
lifetime, thread-safety, the error/return contract, and preconditions are all
stated. The return values are taken verbatim from the `ini.h` header comment
(0 on success, line number on parse error, -2 on allocation failure).

```c
/**
 * @fn ini_parse_string
 * @brief Parse a zero-terminated in-memory INI @p string, invoking @p handler
 *        once per parsed name=value pair.
 *
 * @param string   Zero-terminated INI text. Must not be NULL. Read-only input:
 *                  the parser does not modify or retain it.
 * @param handler  Callback invoked for each pair. Must not be NULL. It receives
 *                  section, name, and value pointers; ownership: those pointers
 *                  are owned by the parser, not the handler. The value buffer
 *                  may be cast to char* and modified in place, but section and
 *                  name must not be modified, and none may be retained.
 * @param user     Opaque pointer passed through unchanged to @p handler; may be
 *                  NULL. The parser does not dereference or free it.
 *
 * @return 0 on success; the 1-based line number of the first parse error
 *         (parsing continues past it); -1 on file open error (not reachable for
 *         the string variant); -2 on memory allocation error when INI_USE_STACK
 *         is 0.
 * @retval 0  All pairs parsed and every @p handler call returned nonzero.
 * @retval -2 errno-independent allocation failure (heap build only).
 *
 * @threadsafety Thread-safe for concurrent calls on distinct @p string and
 *               @p user arguments: ini_parse_string touches no shared mutable
 *               state of its own. Concurrent access to whatever @p user points
 *               at requires the caller's own external synchronization.
 *
 * @lifetime The section, name, and value pointers passed to @p handler are
 *           valid only for the duration of that single handler call. They are
 *           invalidated as soon as the handler returns; copy what you need.
 *
 * @pre  @p string is non-NULL and zero-terminated.
 * @pre  @p handler is non-NULL.
 * @pre  Each line is shorter than INI_MAX_LINE (default 200) unless the library
 *       was built with INI_ALLOW_REALLOC.
 */
INI_API int ini_parse_string(const char* string, ini_handler handler, void* user);
```

---

## Gate commands and outputs

Both gate kinds were run against this file. Both PASS and are slop-free.

```text
$ python3 /home/durakovic/projects/cpp/skill/c-cpp-profi/scripts/cpp_docs_check.py \
    /home/durakovic/projects/cpp/workspace/loop/trials/C5-docs.md --kind readme
c-cpp-profi docs check: PASS
kind=readme

$ python3 /home/durakovic/projects/cpp/skill/c-cpp-profi/scripts/cpp_docs_check.py \
    /home/durakovic/projects/cpp/workspace/loop/trials/C5-docs.md --kind api
c-cpp-profi docs check: PASS
kind=api
```
