//: idui.c
//: Interactive C-version IDU
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang
//: 2005-08-18 2005-08-24

#include <idu.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define CARP(fmt,val) \
    fprintf(stderr, fmt##" - %s(line %d)\n", (val), __FILE__, __LINE__);


int main(void) {
    enum {
        BUFSIZE = 256,
        FMTSIZE = 10,
    };
    char line[BUFSIZE];
    char c;
    char *p = line;
    Result* res;
    int perl_mode = 0;

    printf("Interactive x86 Instruction Decoding Unit (C Version)\n"
           "Copyright (c) 2005 Agent Zhang. All rights reserved.\n\n"
           "- Use command 'set d' to enter debug mode or 'unset d' to leave.\n"
           "- Type 'set p' to output Perl code or 'unset p' to cancel this.\n"
           "- Type 'q' or 'Ctrl-Z' to quit the shell.\n\n"
           ">> ");

    while (1) {
        p = line;
        while ((c = getchar()) != EOF) {
            // CARP("%c", c);
            if (c == '\n' || p - line >= BUFSIZE) break;
            *(p++) = c;
        }
        if (c == EOF) return 0;
        *p = '\0';

        if (strcmp(line, "q") == 0) break;
        if (strcmp(line, "set d") == 0) {
            printf("Enter debug mode...\n>> ");
            fflush(stdout);
            set_debug(1);
            continue;
        }
        if (strcmp(line, "unset d") == 0) {
            printf("Leaving debug mode...\n>> ");
            fflush(stdout);
            set_debug(0);
            continue;
        }
        if (strcmp(line, "set p") == 0) {
            printf("Enter perl format mode...\n>> ");
            fflush(stdout);
            perl_mode = 1;
            continue;
        }
        if (strcmp(line, "unset p") == 0) {
            printf("Leaving perl format mode...\n>> ");
            fflush(stdout);
            perl_mode = 0;
            continue;
        }
        //CARP("%s", line);
        //set_source(line);
        //CARP("%s", get_source());
        res = decode(line);
        //CARP("%s", get_source());
        if (res == NULL) {
            char* msg;
            msg = get_error_info();
            if (strcmp(msg, "") != 0)
                printf("%s\n", msg);
            printf(">> ");
            fflush(stdout);
            continue;
        }
        if (perl_mode) {
            p = dump_res_to_perl(res);
            printf(p);
            free_ptr(p);
        } else {
            dump_res(res, stdout);
        }
        free_ptr(res);
        printf(">> ");
        fflush(stdout);
    }
    return 0;
}
