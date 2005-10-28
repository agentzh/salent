#: Idu.pm
#: Perl wrapper for the C IDU
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-17 2005-08-19

package Idu;

use strict;
use warnings;
use Data::Dumper;

my ($lib, $inc);
BEGIN {
    require 'File/Spec.pm';
    $lib = File::Spec->rel2abs("C/idu.lib");
    $inc = File::Spec->rel2abs("C");
    $ENV{PATH} .= ";$inc";
}

use Inline C => Config =>
    ENABLE => AUTOWRAP =>
    MYEXTLIB => $lib =>
    INC => "-I $inc";
use Inline C => <<'_EOC_';
#include <idu.h>

enum { BUFSIZE = 8 };

void set_source(char* buf);

char* get_source();

char* get_cur_token();

char* get_error_info();

int set_debug(int value);

int readbytes2(SV* rlist, int len) {
    int retval, i;
    Byte outbuf[BUFSIZE];
    AV* array;
    array = newAV();
    sv_setsv(rlist, newRV_noinc((SV*)array));

    retval = readbytes(outbuf, len);
    if (retval != len) return retval;
    for (i = 0; i < len; i++)
        av_push(array, newSViv(*(outbuf+i)));
    return len;
}

int slice2(int byte, int i, int j) {
    return slice((Byte)byte, i, j);
};

int match2(int byte, char* pat) {
    return match((Byte)byte, pat);
}

int get_imm_len(int s, int w, int bits16);

int process_ModRM2(SV* rhash, Byte byte) {
    Result res;
    return process_ModRM(&res, byte);
}

SV* dump_byte2(int byte) {
    enum { BUFSIZE = 10 };
    char buf[BUFSIZE];
    dump_byte((Byte)byte, buf);
    return newSVpv(buf, 0);
}

SV* decode2(char* src) {
    Result* res;
    char* code;
    SV* sv;
    //printf("src - %s\n", src);
    set_source(src);
    res = decode(NULL);
    //printf("res - %x\n", res);
    if (res == NULL) return &PL_sv_undef;
    code = dump_res_to_perl(res);
    /*
    if (code) {
        printf("---------------\n");
        printf("code - %s", code);
        printf("---------------\n");
    }
    */
    sv = newSVpv(code, 0);
    free_ptr(code);
    return sv;
}

_EOC_

our $debug = 0;
my $max_code_len = 0;

sub decode {
    shift if @_ > 1;
    my $src = shift;
    my $code = decode2($src);
    #die $code;
    return undef unless $code;
    #print "----------------\n";
    #print $code;
    #print "================\n";
    my $res = eval $code;
    #warn Data::Dumper->Dump([$res], ['res']);
    die $@ if $@;
    if ($debug and length($code) > $max_code_len) {
        $max_code_len = length($code);
    }
    #warn "Hey!";
    return $res;
}

sub error {
    return get_error_info();
}

END {
    warn "Maximal code size: $max_code_len" if $debug;
}

1;
