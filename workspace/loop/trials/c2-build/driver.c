/* C2 PORT differential-oracle driver for cJSON.
 *
 * For each corpus file given on argv, this driver exercises a deterministic
 * slice of cJSON behavior and writes a stable textual report to stdout. The
 * same driver is compiled by every toolchain under test; the differential
 * oracle asserts the stdout is byte-identical across toolchains for the same
 * corpus. Port hazards this surfaces: double<->string rounding (printf/strtod),
 * integer width on number parsing, struct layout via cJSON_GetArraySize, and
 * any UB the origin compiler "defined" in cJSON's number/string paths.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cJSON.h"

static char *slurp(const char *path, long *out_len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char *)malloc((size_t)len + 1);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)len, f);
    buf[got] = '\0';
    fclose(f);
    *out_len = (long)got;
    return buf;
}

/* Recursively emit a deterministic type/value digest so the oracle binds the
 * parse tree, not just the re-serialized text. */
static void digest(const cJSON *node, int depth) {
    for (const cJSON *c = node; c; c = c->next) {
        printf("%*s", depth * 2, "");
        if (c->string) printf("[%s] ", c->string);
        switch (c->type & 0xFF) {
            case cJSON_False:  printf("bool=false\n"); break;
            case cJSON_True:   printf("bool=true\n"); break;
            case cJSON_NULL:   printf("null\n"); break;
            case cJSON_Number:
                /* %.17g pins the double round-trip; valueint pins width. */
                printf("num d=%.17g i=%d\n", c->valuedouble, c->valueint);
                break;
            case cJSON_String: printf("str=<%s>\n", c->valuestring ? c->valuestring : ""); break;
            case cJSON_Array:  printf("array n=%d\n", cJSON_GetArraySize(c)); digest(c->child, depth + 1); break;
            case cJSON_Object: printf("object n=%d\n", cJSON_GetArraySize(c)); digest(c->child, depth + 1); break;
            case cJSON_Raw:    printf("raw\n"); break;
            default:           printf("type?=%d\n", c->type); break;
        }
    }
}

int main(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        long len = 0;
        char *data = slurp(argv[i], &len);
        const char *name = strrchr(argv[i], '/');
        name = name ? name + 1 : argv[i];
        printf("== %s len=%ld ==\n", name, len);
        if (!data) { printf("read-error\n"); continue; }

        const char *parse_end = NULL;
        cJSON *root = cJSON_ParseWithLengthOpts(data, (size_t)len, &parse_end, 0);
        if (!root) {
            const char *err = cJSON_GetErrorPtr();
            long off = err ? (long)(err - data) : -1;
            printf("parse-fail err_off=%ld\n", off);
            free(data);
            continue;
        }

        long consumed = parse_end ? (long)(parse_end - data) : -1;
        printf("parse-ok consumed=%ld\n", consumed);

        char *printed = cJSON_PrintUnformatted(root);
        printf("unformatted=<%s>\n", printed ? printed : "(null)");
        if (printed) free(printed);

        char *pretty = cJSON_Print(root);
        if (pretty) {
            printf("formatted-bytes=%zu\n", strlen(pretty));
            free(pretty);
        } else {
            printf("formatted-bytes=null\n");
        }

        printf("digest:\n");
        digest(root, 0);

        cJSON_Delete(root);
        free(data);
    }
    return 0;
}
