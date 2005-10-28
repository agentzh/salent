//: bin2hex.c
//: Convert absolutely binary data to ASCII hex form.
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang.
//: 2005-07-28 2005-07-28

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char* argv[]) {
    FILE* in;
    FILE* out;
    int firstTime = 1;

    if (argc != 3) {
        fprintf(stderr, "Usage: bin2hex <infile> <outfile>\n");
        return (1);
    }

    in  = fopen(argv[1], "rb");
    if (in == NULL) {
        fprintf(
            stderr,
            "error: Can't open %s for reading: %s\n",
            argv[1],
            strerror(errno)
        );
        return (1);
    }

    if (strcmp(argv[2], "-") == 0) {
        out = stdout;
    } else {
        out = fopen(argv[2], "w");
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
    }

    while (1) {
        unsigned char byte;
        fread(&byte, 1, 1, in);
        if (feof(in) || ferror(in)) break;
        if (firstTime)
            firstTime = 0;
        else
            fprintf(out, " ");
        fprintf(out, "%02x", byte);
    }
    fclose(in);
    fclose(out);
    return 0;
}
