#: ast++.pl
#: Add random timing info to the ALU AST
#: Salent v0.13
#: Copyright (c) Agent Zhang.
#: 2005-07-18 2005-07-18

use strict;
use warnings;
use Template::Ast;

@ARGV == 1 or
    die "Usage: ast++ <ast-file>\n";
my $astfile = shift;

# Read the AST description from the file given:
my $ast = Template::Ast->read($astfile);
die Template::Ast->error() unless $ast;

# Add timing info to the AST:
#die Template::Ast->dump([$ast], ['ast']);
$ast->{alu} = { delay => 10 } unless defined $ast->{alu};
$ast->{alu}->{delay} = 10 unless $ast->{alu}->{delay};
my $ops = $ast->{ops};
foreach my $op (@$ops) {
    my $op_time = genrand(1, 20) if defined $op->{op};
    my $A_time = genrand(1, 20) if defined $op->{A};
    my $B_time = genrand(1, 20) if defined $op->{B};
    my $D_time = genrand(1, 20) if defined $op->{D};
    my $cin_time = genrand(1, 20) if defined $op->{cin};
    #warn $ast->{alu}->{delay};
    my $run_time = genrand(
        max($op_time, $A_time, $B_time, $D_time, $cin_time) +
        $ast->{alu}->{delay} + 1,
        20);
    #warn "op $op_time, A $A_time, B $B_time, D $D_time, cin $cin_time, ".
    #     "run $run_time";

    $op->{op_time} = $op_time;
    $op->{A_time} = $A_time;
    $op->{B_time} = $B_time;
    $op->{D_time} = $D_time;
    $op->{cin_time} = $cin_time;
    $op->{run_time} = $run_time;
}

# Dump the AST to the original file:
Template::Ast->write($ast, $astfile) or
    die Template::Ast->error();
print "$astfile generated.\n";

sub genrand {
    my ($start, $len) = @_;
    return (int rand($len)) + $start;
}

sub max {
    my @vals = grep { defined $_ } @_;
    my $max = shift @vals;
    foreach (@vals) {
        $max = $_ if $_ > $max;
    }
    return $max;
}
