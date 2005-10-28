#: cod2ast.pl
#: Convert Visual C/C++ Compiler's .cod file to the
#:   Perl AST used in the IDU tester
#: Salent v0.13
#: Copyright (c) 2005 Sal Zhong
#: 2005-07-27 2005-07-31

use strict;
use warnings;

use Getopt::Std;
use Template::Ast;

my %opts;
getopts('o:', \%opts);
my $astfile = $opts{o} ? $opts{o} : '-';

@ARGV || die "Usage: cod2ast [-o <outfile>] <infile>\n";
my $codfile = shift;
my $hexd = qr/[0-9a-f]/i;

open my $fh, $codfile or
    die "cannot open $codfile to read: $!\n";

my ($mac, @items);
my $state = 'S_START';
while (<$fh>) {
    chomp($_);
    #warn $_;
    next if /^\s*$/;
    if ($state eq 'S_START') {
        if (/^\s+$hexd{5}\t((?:$hexd{2} )*$hexd{2})\s*(.*)/) {
            #warn $.;
            $mac = $1;
            my $asm = $2;
            $mac =~ s/^\s+|\s+$//g;
            if ($asm) {
                push @items, {
                    mac => $mac,
                    asm => $asm,
                };
            } else {
                $state = 'S_MORE';
            }
        }
    } elsif ($state eq 'S_MORE') {
        if (/^\s+((?:$hexd{2} )*$hexd{2})\s+(.+)/) {
            $mac .= " $1";
            push @items, {
                mac => $mac,
                asm => $2,
            };
        } else {
            warn "Syntax error: line $.: $_\n";
        }
        $state = 'S_START';
    }
}
close $fh;

warn "cod2ast: ", scalar(@items), " instructions parsed.\n";
my $ast = {
    cod_file => $codfile,
    ops      => \@items,
};

Template::Ast->write($ast, $astfile) or
    die Template::Ast->error();
