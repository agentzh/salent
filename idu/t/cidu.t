#: cidu.t
#: Test the C implementation for IDU
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-17 2005-08-22

package Idu;

use strict;
use warnings;

use C::Idu;
use inc::Idu::Util 'bin2dec';
use Test::More tests => 158;

# Test sub slice2
my $val = +bin2dec '10001011';
is slice2($val, 2, 0), bin2dec('011');
is slice2($val, 3, 0), bin2dec('1011');
is slice2($val, 3, 1), bin2dec('101');
is slice2($val, 3, 3), bin2dec('1');
is slice2($val, 2, 2), '0';
is slice2($val, 7, 7), '1';
is slice2($val, 7, 7), '1';
is slice2($val, 7, 0), bin2dec('10001011');
is slice2($val, 7, 1), bin2dec('1000101');
is slice2($val, 7, 2), bin2dec('100010');
is slice2($val, 6, 2), bin2dec('00010');

is slice2(0x80, 7, 7), 1;
is slice2(0x80, 7, 5), 4;
is slice2(0xD5, 4, 2), 5;
is slice2(0xD5, 1, 1), 0;
is slice2(0xD5, 0, 0), 1;

# Test sub match2:
is match2(0x88, '100..000'), 1;
is match2(0xD5, '11010101'), 1;
is match2(0xD5, '11010.01'), 1;
is match2(0xD5, '1.01..01'), 1;
is match2(0xD5, '1001..01'), 0;
is match2(1, '.......0'), 0;
is match2(0, '.......1'), 0;
is match2(0, '......1.'), 0;

# Test subs set_source, get_source, get_cur_token, and readbytes2:
my $buf = "A1 B2 32";
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
my $rlist;
is readbytes2($rlist, 2), 2;
ok $rlist;
is ref $rlist, 'ARRAY';
my @list = @$rlist;
is scalar(@list), 2;
is $list[0], 0xA1;
is $list[1], 0xB2;
is get_source(), ' 32';
is get_cur_token(), 'B2';

is readbytes2($rlist, 1), 1;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 1;
is $list[0], 0x32;
is get_source(), '';
is get_cur_token(), '32';

undef $rlist;
is readbytes2($rlist, 1), -1;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), '32';

$buf = "00 01 3A";
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 3), 3;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 3;
is $list[0], 0x00;
is $list[1], 0x01;
is $list[2], 0x3A;
is get_source(), '';
is get_cur_token(), '3A';

$buf = "00 01 3A";
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 4), '-1';
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), '3A';

$buf = 'ZZZZZ';
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 1), 0;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), $buf;

$buf = 'Z';
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 1), 0;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), $buf;

$buf = '7';
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 1), 0;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), $buf;

$buf = '787';
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 2), 0;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), '787';

$buf = '32 I';
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 2), 0;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 0;
is get_source(), '';
is get_cur_token(), 'I';

$buf = ' 0c 01';
set_source($buf);
is get_source(), $buf;
is get_cur_token(), '';
is readbytes2($rlist, 2), 2;
ok $rlist;
is ref $rlist, 'ARRAY';
@list = @$rlist;
is scalar(@list), 2;
is get_source(), '';
is get_cur_token(), '01';

# Test sub get_imm_len:
is get_imm_len(1,1,1), 1;
is get_imm_len(1,1,-1), 1;
is get_imm_len(1,1,0), 1;

is get_imm_len(1,0,1), 1;
is get_imm_len(1,0,-1), 1;
is get_imm_len(1,0,0), 1;

is get_imm_len(0,1,1), 2;
is get_imm_len(0,1,-1), 4;
is get_imm_len(0,1,0), 4;

is get_imm_len(0,0,1), 1;
is get_imm_len(0,0,-1), 1;
is get_imm_len(0,0,0), 1;

is get_imm_len(-1,0,1), 1;
is get_imm_len(-1,0,-1), 1;
is get_imm_len(-1,0,0), 1;

is get_imm_len(-1,1,1), 2;
is get_imm_len(-1,1,-1), 4;
is get_imm_len(-1,1,0), 4;

is get_imm_len(0,-1,1), 2;
is get_imm_len(0,-1,-1), 4;
is get_imm_len(0,-1,0), 4;

is get_imm_len(1,-1,1), 1;
is get_imm_len(1,-1,-1), 1;
is get_imm_len(1,-1,0), 1;

is get_imm_len(-1,-1,1), 2;
is get_imm_len(-1,-1,-1), 4;
is get_imm_len(-1,-1,0), 4;

# Test sub error:
is error(), '';

# Test sub set_debug:
is set_debug(1), 0;
is set_debug(1), 1;
is set_debug(0), 1;
is set_debug(0), 0;
is set_debug(1), 0;
is set_debug(0), 1;

# Test sub dump_byte2:
like dump_byte2(0), qr/^0{8}$/;
like dump_byte2(1), qr/^0{7}1$/;
like dump_byte2(2), qr/^0{6}10$/;
like dump_byte2(3), qr/^0{6}11$/;
like dump_byte2(4), qr/^0{5}100$/;
like dump_byte2(5), qr/^0{5}101$/;
like dump_byte2(255), qr/^1{8}$/;
like dump_byte2(-128), qr/^10{7}$/;
like dump_byte2(-127), qr/^10{6}1$/;
like dump_byte2(-1), qr/^1{8}$/;
