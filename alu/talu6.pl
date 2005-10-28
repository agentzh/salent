#: talu6.pl
#: Generate talu6.op.ast directly.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang.
#: 2005-07-21 2005-07-21

use strict;
use warnings;
use Template::Ast;

my $op_file = 'talu6.op';
my @ops;
my $ast = {
         c_file => $op_file . '.c',
         vlog_file => $op_file . '.v',
         perl_file => $op_file . '.pl',
         list_file => $op_file . '.lst',
         solu_file => $op_file . '.exe.out',

         alu => { delay => 5 },
         ops => \@ops,
};

gen_op('add');
gen_op('sub');
gen_op('mul');
gen_op('imul');

Template::Ast->write($ast, "$op_file.ast") or
    die Template::Ast->error();
#print "$op_file.ast generated.\n";

sub gen_op {
    my $op = shift;
    foreach my $i (1..100) {
        my $A = rand_hex(8);
        my $B = rand_hex(8);
        my $cin = int(rand(2));
        push @ops, {
            op => $op,
            A => $A,
            B => $B,
        };
        unless ($op =~ m/mul/) {
            $ops[-1]->{cin} = $cin;
        }
    }
}

sub rand_hex {
    my $len = shift;
    my $hex_val;
    for (1..$len) {
        my $digit = int(rand(16));
        $hex_val .= sprintf("%1x", $digit);
    }
    return $hex_val;
}
