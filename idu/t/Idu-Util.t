#: Idu-Util.t
#: Test inc::Util
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-12 2005-08-12

use strict;
use warnings;

use Test::More tests => 40;
BEGIN { use_ok('inc::Idu::Util'); }

{
# Test sub slice
is slice('10001011', 2, 0), '011';
is slice('10001011', 3, 0), '1011';
is slice('10001011', 3, 1), '101';
is slice('10001011', 3, 3), '1';
is slice('10001011', 3), '1';
is slice('10001011', 2), '0';
is slice('10001011', 7), '1';
is slice('10001011', 7, 7), '1';
is slice('10001011', 7, 0), '10001011';
is slice('10001011', 7, 1), '1000101';
is slice('10001011', 7, 2), '100010';
is slice('10001011', 6, 2), '00010';
}

{
# Test sub get_imm_len
is get_imm_len(1,1,1), 1;
is get_imm_len(1,1), 1;

is get_imm_len(1,0,1), 1;
is get_imm_len(1,0), 1;

is get_imm_len(0,1,1), 2;
is get_imm_len(0,1), 4;

is get_imm_len(0,0,1), 1;
is get_imm_len(0,0), 1;

is get_imm_len(undef,0,1), 1;
is get_imm_len(undef,0), 1;

is get_imm_len(undef,1,1), 2;
is get_imm_len(undef,1), 4;

is get_imm_len(0,undef,1), 2;
is get_imm_len(0,undef), 4;

is get_imm_len(1,undef,1), 1;
is get_imm_len(1,undef), 1;

is get_imm_len(undef,undef,1), 2;
is get_imm_len(undef,undef,0), 4;
}

{ # Test sub set_bit_fld:
is set_bit_fld("00000000", 7, 1), "10000000";
is set_bit_fld("00000000", 6, 1), "01000000";
is set_bit_fld("00000000", 5, 1), "00100000";
is set_bit_fld("00000000", 3, 1), "00001000";
is set_bit_fld("00000000", 1, 1), "00000010";
is set_bit_fld("00000000", 0, 1), "00000001";
}

{ # Test sub hex2dec:
my @lst = bin2hex qw(110 011);
is $lst[0], '06';
is $lst[1], '03';
my $elem = bin2hex qw(11111111 001);
is $elem, 'ff';
}
