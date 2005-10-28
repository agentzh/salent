#: ast++.pl
#: Add random timing info to RAM AST
#: Salent v0.13
#: Copyright (c) Agent Zhang.
#: 2005-07-12 2005-07-18

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
$ast->{ram} = { delay => 10 } unless defined $ast->{ram};
$ast->{ram}->{delay} = 10 unless defined $ast->{ram}->{delay};
my $ops = $ast->{ops};
foreach my $op (@$ops) {
    my $rw_time = genrand(1, 20) if defined $op->{rw};
    my $addr_time = genrand(1, 20) if defined $op->{addr};
    my $data_time = genrand(1, 20) if defined $op->{data};
    my $strb_up = genrand(max($rw_time, $addr_time, $data_time), 20);
    my $strb_down = genrand($strb_up + $ast->{ram}->{delay} + 1, 20);
    my $run_time = genrand($strb_down + 1, 20);
    #warn "rw $rw_time, addr $addr_time, data $data_time, ".
    #    "strb up $strb_up, down $strb_down, run $run_time\n";

    $op->{rw_time} = $rw_time;
    $op->{addr_time} = $addr_time;
    $op->{data_time} = $data_time;
    $op->{strb_up} = $strb_up;
    $op->{strb_down} = $strb_down;
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
