#: pat_tree.t
#: Test inc::pat_tree
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-22 2005-07-24

use strict;
use warnings;

#use Data::Dumper;
use Test::More tests => 34;
BEGIN { use_ok('inc::pat_tree'); }

{
# Test sub pre_check:
my @insts = (
    {
      'sub_des' => 'register indirect',
      'op_name' => 'CALL',
      'des' => 'Call Procedure (in same segment)',
      'encoding' => '1111 1111 : 11 010 reg'
    },
    {
      'sub_des' => 'direct',
      'op_name' => 'JMP',
      'des' => 'Unconditional Jump (to same segment)',
      'encoding' => '1110 1001 : full displacement'
    },
    {
      'sub_des' => 'memory indirect',
      'op_name' => 'CALL',
      'des' => 'Call Procedure (in same segment)',
      'encoding' => '1111 1111 : mod 010 r/m'
    },
    {
      'sub_des' => 'full displacement',
      'op_name' => 'Jcc',
      'des' => 'Jump if Condition is Met',
      'encoding' => '0000 1111 : 1000 tttn : full displacement'
    },
    {
      'sub_des' => 'reg',
      'op_name' => 'INC',
      'des' => 'Increment by 1',
      'encoding' => '1111 111w : 11 000 reg'
    },
);

my @classes = pre_check(@insts);
#warn Data::Dumper->Dump([\@classes], ['classes']);
is scalar(@classes), 1;
ok eq_set($classes[0], [
  {
    'ins' => 'CALL',
    'pattern' => '11111111',
    'encoding' => '1111 1111 : 11 010 reg'
  },
  {
    'ins' => 'CALL',
    'pattern' => '11111111',
    'encoding' => '1111 1111 : mod 010 r/m'
  },
  {
    'ins' => 'INC',
    'pattern' => '1111111.',
    'encoding' => '1111 111w : 11 000 reg'
  }
]);

}

{# Test sub add_to_tree:

my $ast = {};

my $entry = {encoding => 'a:b', op => 'MOV' };
add_to_tree($ast, $entry);
ok eq_hash($ast, {
    a => {
        next => {
            b => {
                next => {ins => $entry },
            },
        },
    },
});

my $entry2 = {encoding => 'a:e', op => 'ADD' };
add_to_tree($ast, $entry2);
ok eq_hash($ast, {
    a => {
        next => {
            b => {
                next => {ins => $entry },
            },
            e => {
                next => {ins => $entry2 },
            },
        },
    },
});

my $entry3 = {encoding => 'cf', op => 'SUB' };
add_to_tree($ast, $entry3);
ok eq_hash($ast, {
    a => {
        next => {
            b => {
                next => {ins => $entry },
            },
            e => {
                next => {ins => $entry2 },
            },
        },
    },
    cf => { next => { ins => $entry3 }},
});

my $entry4 = {encoding => 'a:h:f', op => 'ADD' };
add_to_tree($ast, $entry4);
ok eq_hash($ast, {
    a => {
        next => {
            b => {
                next => {ins => $entry },
            },
            e => {
                next => {ins => $entry2 },
            },
            h => {
                next => {
                    f => {
                        next => {ins => $entry4 },
                    },
                },
            },
        },
    },
    cf => { next => { ins => $entry3 }},
});

}

{# Test sub parse_enc:

my $enc = '0110 1011';
my %info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '01101011',
});

$enc = '0110 10s1';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '011010.1',
    s => 1,
});
#warn Data::Dumper->Dump([\%info], ['info']);

$enc = '10sw 0110';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '10..0110',
    s => 5,
    w => 4,
});

$enc = '10sd 0110';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '10..0110',
    s => 5,
    d => 4,
});

$enc = 'mod 111 r/m';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '..111...',
    mod => 1,
});

$enc = 'modA reg r/m';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    modA => 1,
    reg => [5, 3],
    pattern => '.' x 8,
});
#warn Data::Dumper->Dump([\%info], ['info']);

$enc = '11 reg1 reg2';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '11......',
    reg2 => [2, 0],
    reg1 => [5, 3],
});
#warn Data::Dumper->Dump([\%info], ['info']);

$enc = '11 eee reg';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '11......',
    reg => [2, 0],
    eee => [5, 3],
});

$enc = '11 eee sreg3';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '11......',
    sreg3 => [2, 0],
    eee => [5, 3],
});

$enc = '11 eee sreg2 1';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '11.....1',
    sreg2 => [2, 1],
    eee => [5, 3],
});

$enc = '1001 tttn';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '1001....',
    tttn => [3, 0],
});

$enc = '11 000 ST(i)';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '11000...',
    ST_i => [2, 0],
});

$enc = '1111 R ST(i)';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '1111....',
    R => 3,
    ST_i => [2, 0],
});

$enc = '11011 d00';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    pattern => '11011.00',
    d => 2,
});

$enc = '8-bit displacement';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});

$enc = 'unsigned full offset, selector';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 'pointer',
});

$enc = 'immediate data';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 'normal',
});

$enc = 'imm8 data';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});

$enc = 'imm8';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});

$enc = 'type';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});

$enc = 'port number';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});
#warn Data::Dumper->Dump([\%info], ['info']);

$enc = '8-bit level (L)';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});
#warn Data::Dumper->Dump([\%info], ['info']);

$enc = '8-bit displacement';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
});

$enc = '16-bit displacement';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 16,
});

$enc = 'full displacement';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 'full',
});

$enc = 'ib';
%info = parse_enc($enc);
ok eq_hash(\%info, {
    imm => 8,
    pattern => '.' x 8,
});

}

{ # Test sub process_tree:

my $ast = {
    '1100 000w' => {
        next => {
            '11 111 reg' => {
                next => {
                    'imm8 data' => {
                        next => {
                          ins => {
                            encoding => '1100 000w : 11 111 reg : imm8 data',
                          },
                        },
                    },
                },
            },
        },
    },
};

process_tree($ast);
ok eq_hash($ast, {
    '1100 000w' => {
        pattern => '1100000.',
        w => 0,
        next => {
            '11 111 reg' => {
                pattern => '11111...',
                reg => [2, 0],
                next => {
                    'imm8 data' => {
                        imm => 8,
                        next => {
                          ins => {
                            encoding => '1100 000w : 11 111 reg : imm8 data',
                          },
                        },
                    },
                },
            },
        },
    },
});

}
