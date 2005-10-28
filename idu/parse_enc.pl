#: parse_enc.pl
#: Generate perl AST structure from encoding.txt
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang.
#: 2005-07-08 2005-08-14

use strict;
use warnings;
use Data::Dumper;

my $state = 0;
my ($opname, $des, $encoding, $ins_set);
my @insts;
while (<>) {
    next if /^\s*$/ or /^\s*#/;
    #warn $state if $. == 494;
    if ($state != 1 && m/^\*\*\s*(\w+)\s*\*\*$/) {
        $ins_set = $1;
        #warn $ins_set;
    } elsif ($state != 1 && (m/^([A-Z\/c\d]+(?:\s+[A-Zn]+)?) - (.+)/ ||
                        m/^([A-Z\d]+)\s*$/)) {
        unless (defined $ins_set) {
            die "error: line $.: No instruction set name specified.\n";
        }
        $opname = $1;
        $des = $2;
        if ($des and $des =~ s/ ([01]{3}.*)//s) {
            $encoding = $1;
            push @insts, {
                op_name => $opname,
                des => $des,
                encoding => $encoding,
                ins_set => $ins_set,
            };
            undef $encoding;
            undef $opname;
            undef $des;
            $state = 0;
        } else {
            $state = 1;
        }
    } elsif (($state == 1 or $state == 2) and m/ ([01]{3}.*)/){
        $encoding = $1;
        my $subdes = $`;
        push @insts, {
            op_name => $opname,
            des => $des,
            sub_des => $subdes,
            encoding => $encoding,
            ins_set => $ins_set,
        };
        undef $encoding;
        undef $subdes;
        $state = 2;
    #} elsif (/^Prefix Bytes/) {
    #    last;
    } else {
        chomp;
        die "syntax error: line $.: $_\n";
    }
}

my $vars = {
    insts => \@insts,
};

print Data::Dumper->Dump([$vars], ['vars']);
warn "parse_enc: ", scalar(@insts), " instructions parsed.\n";
