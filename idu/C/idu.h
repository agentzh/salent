//: idu.h
//: C header file for Instruction Decoding Unit (IDU)
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang
//: 2005-08-17 2005-08-22

#ifndef _IDU_H_
#define _IDU_H_

#include <stdio.h>

enum {
    BYTES_LEN = 256,
    NBYTES_MAX = 6,
    DISP_LEN   = 4 // in bytes
};

typedef unsigned char Byte;

typedef struct {
    int w, s, d, R;
    int reg, reg1, reg2, tttn, sreg2, sreg3, eee, ST_i;
    int mod, rm;
    int bits16;
    int base_reg, scale, index_reg;
    int disp_len;
    int nprefs;
    int imm_len;
    Byte disp [DISP_LEN];
    Byte prefix [NBYTES_MAX];
    Byte imm [NBYTES_MAX];
    char bytes [BYTES_LEN];
    char *ins, *des, *subdes, *encoding, *ins_set;
} Result;

void set_source(char* buf);

char* get_source(void);

char* get_cur_token(void);

char* get_error_info(void);

int set_debug(int value);

int readbytes(Byte* outbuf, int len);

Byte slice(Byte byte, int i, int j);

int match(Byte byte, const char* pat);

int get_imm_len(int s, int w, int bits16);

int process_ModRM(Result* res, Byte byte);

Result* decode(char* src);

void dump_byte(Byte byte, char* outbuf);

void dump_res(Result* res, FILE* fh);

char* dump_res_to_perl(Result* res);

void free_ptr(void* p);

#endif // _IDU_H_
