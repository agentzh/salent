#: pe2ast.pl
#: Convert PE file (Win32 .exe file) to Perl AST used
#:   in our tester, using PEDasm.exe internally
#: Salent v0.13
#: Copyright (c) Sal Zhong
#: 2005-07-31 2005-07-31

use warnings;
use strict;
use Getopt::Std;
use Template::Ast;

my %opts;
getopts('o:', \%opts);
my $astfile = $opts{o} ? $opts{o} : '-';
my $hexd = qr/[0-9A-F]/i;

@ARGV || die "Usage: pe2ast [-o <outfile>] <infile>\n";
my $file = shift;

#my $astfile = "out.txt";
open my $fh, $file or
    die "cannot open $file: $!\n";

my @items;
my $state = 'START';
while (<$fh>) {
    next if /^\s*$/;
    if (/^\.code\s*$/) {
        $state = 'CODE';
    } elsif (/^\.data\s*$/) {
        $state = 'DATA';
    } elsif ($state eq 'CODE' and /^\s*(.+\S)\s*;\s*($hexd+)\s*$/i) {
        my ($asm, $mac) = ($1, $2);
        my $ins;
        $mac =~ s/$hexd{2}/$& /g;
        $mac =~ s/\s+$//;
        if ($asm eq 'neg ebp') { # Fix a bug in PEDasm:
            $asm = 'byte 0xf7, 0x00';
        }
        push @items, {
            mac => $mac,
            asm => $asm,
        };
    }
}
close $fh;

my $ast = {
    cod_file => $file,
    ops      => \@items,
};

Template::Ast->write($ast, $astfile) or
    die Template::Ast->error();
#print "$mac$asm$op\n\n";
