//: hex2bin.c
//: Convert ASCII hex data list to absolutely binary form.
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang.
//: 2005-07-28 2005-07-28

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char* argv[]) {
    FILE* in;
    FILE* out;

    if (argc != 3) {
        fprintf(stderr, "Usage: hex2bin <infile> <outfile>\n");
        return (1);
    }

    if (strcmp(argv[1], "-") == 0) {
        in = stdin;
    } else {
        in  = fopen(argv[1], "r");
        if (in == NULL) {
            fprintf(
                stderr,
                "error: Can't open %s for reading: %s\n",
                argv[1],
                strerror(errno)
            );
            return (1);
        }
    }

    if (strcmp(argv[2], "-") == 0) {
        fprintf(
            stderr,
            "error: Can't use stdout (-) as output file\n"
        );
        return (1);
    }
    out = fopen(argv[2], "wb");
    if (out == NULL) {
        fclose(in);
        fprintf(
            stderr,
            "error: Can't open %s for writing: %s\n",
            argv[2],
            strerror(errno)
        );
        return (1);
    }

    while (1) {
        char byte;
        fscanf(in, "%2x", &byte);
        if (feof(in) || ferror(in)) break;
        fwrite(&byte, 1, 1, out);
    }
    fclose(in);
    fclose(out);
    return 0;
}
