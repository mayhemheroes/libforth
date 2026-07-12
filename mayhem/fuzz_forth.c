/* In-process libFuzzer harness for libforth.
 *
 * Drives the public C API over the interpreter's core code path: initialize a
 * fresh forth environment and evaluate the fuzz input as a Forth program via
 * forth_eval_block() (the NUL-agnostic variant of forth_eval), exercising the
 * reader/parser/virtual-machine on arbitrary bytes. This replaces the old raw
 * `/forth` stdin CLI target (uninstrumented, 0-edge) with an instrumented
 * in-process harness over the same interpreter code (libforth.c). */
#include "libforth.h"

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	FILE *in = fopen("/dev/null", "rb");
	FILE *out = fopen("/tmp/libforth-fuzz-out", "wb");
	if (!in || !out) {
		if (in)
			fclose(in);
		if (out)
			fclose(out);
		return 0;
	}

	forth_t *o = forth_init(DEFAULT_CORE_SIZE, in, out, NULL);
	if (o) {
		forth_eval_block(o, (const char *)data, size);
		forth_free(o);
	}

	fclose(in);
	fclose(out);
	return 0;
}
