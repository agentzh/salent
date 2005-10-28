#: idu.pl
#: IA-32 Instruction Decoding Unit in Perl
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-25 2005-07-25

use strict;
use warnings;

use inc::Idu;
use Template::Ast;
use Getopt::Std;

my %opts;
getopts('o:', \%opts);
my $outfile = $opts{o} || '-';

@ARGV || die "No input file specified";
my $infile = shift;
open my $fh, $infile or
    die "Can't open $infile: $!";
$Idu::source = $fh;

my (@records, $record);
while(1) {
    $record = Idu->decode();
    last unless defined $record;
    push @records, $record;
};
close $fh;
my $info = Idu->error();
die $info if defined $info;
print scalar(@records), " instructions parsed.\n";

Template::Ast->write({ insts => \@records }, $outfile) or
    Template::Ast->error();
print "$outfile generated.\n" unless $outfile eq '-';
