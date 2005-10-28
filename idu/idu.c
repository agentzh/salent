//: idu.c
//: C implemetation of Instruction Decoding Unit (IDU)
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang
//: 2005-08-17 2005-08-17

#include <idu.h>
#include <assert.h>
#include <stdio.h>

#define READ_BYTE \
    if (readbytes(bytes, 1) != 1) { \
        state = S_END_ERROR; \
        break; \
    } \
    byte = bytes[0];

#define READ_BYTES(len) \
    if (readbytes(bytes, (len)) != (len)) { \
        state = S_END_ERROR; \
        break; \
    }

#define SET_IMM_DATA(len) \
    memcpy(res->imm, bytes, (len)); \
    res->imm_len = (len);

#define CARP(fmt,val) \
    fprintf(stderr, fmt##" - line %d\n", (val), __LINE__);

enum {
    TOKENSIZE = 2,
    BUFSIZE = 256,
    UNDEF = -1
};

static const char* Source;
static char Token[TOKENSIZE+1];
static char Error[BUFSIZE];
static char OldBytes[BUFSIZE];
static int Debug = 0;

void set_source(char* buf) {
    Source = buf;
    strcpy(Token, "");
}

char* get_source(void) {
    return (char*) Source;
}

// get the current token:
char* get_cur_token(void) {
    return Token;
}

// get the error info:
char* error(void) {
    return Error;
}

// set the debug mode:
int set_debug(int value) {
    int oldval;
    oldval = Debug;
    Debug = value;
    return oldval;
}

// read one or more bytes from the source:
int readbytes(Byte* outbuf, int len) {
    int i;
    for (i = 0; i < len; i++) {
        int retval;
        while (*Source == ' ' || *Source == '\t' || *Source == '\n')
            Source++;
        retval = sscanf(Source, "%2s", Token);
        //CARP("%d", retval);
        if (retval == 0 || retval == EOF) {
            Source = "";
            return retval;
        }
        Source += strlen(Token);
        //CARP("%s", Token);
        //CARP("%s", Source);
        retval = sscanf(Token, "%02x", outbuf+i);
        //CARP("%02x", outbuf[0]);
        if (retval == 0 || retval == EOF)
            return retval;
    }
    return len;
}

// slice the byte via subscripts:
Byte slice(Byte byte, int i, int j) {
    Byte retval = 0;
    assert(i >= j);
    while (i >= j) retval += byte & (1 << i--);
    return retval >>= j;
}

// match the byte against the pattern:
int match(Byte byte, const char* pat) {
    Byte filter, c;
    for (filter = 0x80; (c = *pat) != '\0'; filter >>= 1, pat++) {
        //printf("%c", c);
        if (c == '.') continue;
        if (byte & filter) {
            if (c == '0') return 0;
        } else {
            if (c == '1') return 0;
        }
    }
    return 1;
}


static int defined(int fld) {
    return fld != UNDEF;
}

// derive the length of immediate data (in bytes):
int get_imm_len(int s, int w, int bits16) {
    if (defined(s) && !defined(w)) {
        if (s == 1) { // 8-bit imm size
            return (1);
        } else { // full size imm size
            if (bits16 == 1) { // 16-bit imm size
                return (2);
            } else { // 32-bit imm size
                return (4);
            }
        }
    } else if (defined(w) && !defined(s)) {
        if (w == 0) { // 8-bit imm size
            return (1);
        } else { // full size imm size
            if (bits16 == 1) { // 16-bit imm size
                return (2);
            } else { // 32-bit imm size
                return (4);
            }
        }
    } else if (defined(w) && defined(s)) {
        if (s == 1) { // 8-bit imm size
            return (1);
        } else if (w == 0) { // 8-bit imm size
            return (1);
        } else {
            if (bits16 == 1) { // 16-bit imm size
                return (2);
            } else { // 32-bit imm size
                return (4);
            }
        }
    } else { // both w and s fields are absent
        if (bits16 == 1) { // 16-bit imm size
            return (2);
        } else { // 32-bit imm size
            return (4);
        }
    }
}

// Process the ModR/M byte:
int process_ModRM(Result* res, Byte byte) {
    int mod, rm, base;
    Byte bytes[NBYTES_MAX];
    mod = slice(byte, 7, 6);
    rm  = slice(byte, 2, 0);
    res->mod = mod;
    res->rm  = rm;
    if (mod == 0 /* 00 */) {
        if (rm == 5 /* 101 */) { // Direct: EA = Disp32
            // Get 32-bit displacement:
            if (readbytes(bytes, 4) != 4)
                return 0;
            memcpy(res->disp, bytes, 4);
        } else if (rm == 4 /* 100 */) { // Base with index (uses SIB byte)
            // Get SIB byte:
            if (readbytes(bytes, 1) != 1)
                return 0;
            res->scale = slice(bytes[0], 7, 6);
            res->index_reg = slice(bytes[0], 5, 3);
            base = slice(bytes[0], 2, 0);
            if (base == 5 /* 101 */) { // Base == EBP: EA = [Index] x Scale + Disp32
                // Get 32-bit displacement:
                if (readbytes(bytes, 4) != 4)
                    return 0;
                memcpy(res->disp, bytes, 4);
            } else { // EA = [Base] + [Index] x Scale
                res->base_reg = base;
            }
        }
    } else if (mod == 1 /* 01 */) {
        if (rm == 4 /* 100 */) { // EA = [Base] + [Index] x Scale + Disp8
            // Get SIB byte:
            if (readbytes(bytes, 1) != 1)
                return 0;
            res->scale     = slice(bytes[0], 7, 6);
            res->index_reg = slice(bytes[0], 5, 3);
            res->base_reg  = slice(bytes[0], 2, 0);
            // Get 8-bit displacement:
            if (readbytes(bytes, 1) != 1)
                return 0;
            memcpy(res->disp, 0, 4);
            res->disp[0] = bytes[0];
        } else { // EA = [Reg] + Disp8
            // Get 8-bit displacement:
            if (readbytes(bytes, 1) != 1)
                return 0;
            res->disp[0] = bytes[0];
            res->disp_len = 1;
        }
    } else if (mod == 2 /* 10 */) {
        if (rm == 4 /* 100 */) { // EA = [Base] + [Index] x Scale + Disp32
            // Get SIB byte:
            if (readbytes(bytes, 1) != 1)
                return 0;
            res->scale     = slice(bytes[0], 7, 6);
            res->index_reg = slice(bytes[0], 5, 3);
            res->base_reg  = slice(bytes[0], 2, 0);
            // Get 32-bit displacement:
            if (readbytes(bytes, 4) != 4)
                return 0;
            memcpy(res->disp, bytes, 4);
        } else { // EA = [Reg] + Disp32
            // Get 32-bit displacement:
            if (readbytes(bytes, 4) != 4)
                return 0;
            memcpy(res->disp, bytes, 4);
        }
    }
    return 1;
}

Result* new_res() {
    Result* res = (Result*) malloc(sizeof(Result));
    assert(res);
    res->s = UNDEF;
    res->w = UNDEF;
    res->d = UNDEF;
    res->R = UNDEF;
    res->reg = UNDEF;
    res->reg1 = UNDEF;
    res->reg2 = UNDEF;
    res->sreg2 = UNDEF;
    res->sreg3 = UNDEF;
    res->eee = UNDEF;
    res->tttn = UNDEF;
    res->ST_i = UNDEF;    return res;
}

enum {
    S_START,
    S_PREFIX,
    S_END_ERROR,
    S_SYN_ERROR,
    S_TOO_MANY_PREF,
    S_0,
    S_1,
    S_2,
    S_3,
    S_4,
    S_5,
    S_6,
    S_7,
    S_8,
    S_9,
    S_10,
    S_11,
    S_12,
    S_13,
};

// Decode one instruction:
Result* decode(char* src) {
    Byte byte = UNDEF;
    Byte bytes[NBYTES_MAX];
    Result* res;
    int state, len;

    res = new_res();
    if (src != NULL) set_source(src);
    memset(res, 0, sizeof(Result));
    state = S_START;
    while (1) {
        if (Debug) {
            int val = byte;
            fprintf(stderr, "Switching to state %d with byte %d...\n", state, val);
        }
        switch (state) {
        case S_START:
            if (readbytes(bytes, 1) != 1) {
                strcpy(Error, "");
                return 0;
            }
            byte = bytes[0];
        case S_PREFIX:
            // Process preffix byte (if any):
            if (byte == 0xf2) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0xf2;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0xf3) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0xf3;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0xf0) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0xf0;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x67) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x67;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x66) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x66;
                
                res->bits16 = 1;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x2e) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x2e;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x36) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x36;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x3e) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x3e;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x26) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x26;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x64) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x64;
                
                READ_BYTE
                state = S_PREFIX;
            } else if (byte == 0x65) {
                if (res->nprefs == NBYTES_MAX) {
                    state = S_TOO_MANY_PREF;
                    break;
                }
                res->prefix[res->nprefs++] = 0x65;
                
                READ_BYTE
                state = S_PREFIX;
            } else {
                state = S_0;
            }
            break;
        case S_0:

            if (match(byte, "100000..")) {
                state = S_1;
            } else if (match(byte, "0001001.")) {
                state = S_6;
            } else if (match(byte, "0001010.")) {
                state = S_9;
            } else if (match(byte, "0001000.")) {
                state = S_11;
            } else {
                state = S_SYN_ERROR;
            }
            break;
        case S_1:
            // Get the s field from the current byte:
            res->s = slice(byte, 1, 1);
            // Get the w field from the current byte:
            res->w = slice(byte, 0, 0);

            READ_BYTE
            if (match(byte, "11010...")) {
                state = S_4;
            } else if (match(byte, "..010...")) {
                state = S_2;
            } else {
                state = S_SYN_ERROR;
            }
            break;
        case S_2:
            // Process the current ModR/M byte:
            if (process_ModRM(res, byte) != 1) {
                state = S_END_ERROR;
                break;
            }

            state = S_3;
            break;
        case S_3:
            // Get immediate data:
            len = get_imm_len(res->s, res->w, res->bits16);
            READ_BYTES(len)
            SET_IMM_DATA(len)

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "immediate to memory";
            res->encoding = "1000 00sw : mod 010 r/m : immediate data";
            res->ins_set = "General";
            return res;
            break;
        case S_4:
            // Get the reg field from the current byte:
            res->reg = slice(byte, 2, 0);

            state = S_5;
            break;
        case S_5:
            // Get immediate data:
            len = get_imm_len(res->s, res->w, res->bits16);
            READ_BYTES(len)
            SET_IMM_DATA(len)

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "immediate to register";
            res->encoding = "1000 00sw : 11 010 reg : immediate data";
            res->ins_set = "General";
            return res;
            break;
        case S_6:
            // Get the w field from the current byte:
            res->w = slice(byte, 0, 0);

            READ_BYTE
            if (match(byte, "11......")) {
                state = S_8;
            } else if (match(byte, "........")) {
                state = S_7;
            } else {
                state = S_SYN_ERROR;
            }
            break;
        case S_7:
            // Process the current ModR/M byte:
            if (process_ModRM(res, byte) != 1) {
                state = S_END_ERROR;
                break;
            }
            // Get the reg field from the current byte:
            res->reg = slice(byte, 5, 3);

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "memory to register";
            res->encoding = "0001 001w : mod reg r/m";
            res->ins_set = "General";
            return res;
            break;
        case S_8:
            // Get the reg1 field from the current byte:
            res->reg1 = slice(byte, 5, 3);
            // Get the reg2 field from the current byte:
            res->reg2 = slice(byte, 2, 0);

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "register2 to register1";
            res->encoding = "0001 001w : 11 reg1 reg2";
            res->ins_set = "General";
            return res;
            break;
        case S_9:
            // Get the w field from the current byte:
            res->w = slice(byte, 0, 0);

            state = S_10;
            break;
        case S_10:
            // Get immediate data:
            len = get_imm_len(res->s, res->w, res->bits16);
            READ_BYTES(len)
            SET_IMM_DATA(len)

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "immediate to AL, AX, or EAX";
            res->encoding = "0001 010w : immediate data";
            res->ins_set = "General";
            return res;
            break;
        case S_11:
            // Get the w field from the current byte:
            res->w = slice(byte, 0, 0);

            READ_BYTE
            if (match(byte, "11......")) {
                state = S_13;
            } else if (match(byte, "........")) {
                state = S_12;
            } else {
                state = S_SYN_ERROR;
            }
            break;
        case S_12:
            // Process the current ModR/M byte:
            if (process_ModRM(res, byte) != 1) {
                state = S_END_ERROR;
                break;
            }
            // Get the reg field from the current byte:
            res->reg = slice(byte, 5, 3);

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "register to memory";
            res->encoding = "0001 000w : mod reg r/m";
            res->ins_set = "General";
            return res;
            break;
        case S_13:
            // Get the reg1 field from the current byte:
            res->reg1 = slice(byte, 5, 3);
            // Get the reg2 field from the current byte:
            res->reg2 = slice(byte, 2, 0);

            res->ins = "ADC";
            res->des = "ADD with Carry";
            res->subdes = "register1 to register2";
            res->encoding = "0001 000w : 11 reg1 reg2";
            res->ins_set = "General";
            return res;
            break;
        case S_SYN_ERROR: // Syntax error
            sprintf(Error,
                    "syntax error - unexpected byte \"%s\": @oldbytes",
                    Token
            );
            break;
        case S_END_ERROR:
            sprintf(Error,
                    "syntax error - unexpected end of input: @oldbytes"
            );
            break;
        default:
            sprintf(Error,
                    "core error - unknown state state reached: %d",
                    state
            );
            break;
        }
    }
    return NULL;
}
