#: bin2asm.pl
#: Convert flat binary file to NASM code using Ndisasam internally.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-30

use strict;
use warnings;

@ARGV == 1 || die "Usage: bin2asm <infile>";

my $infile = shift;
my $pipe;
open $pipe, "ndisasmw -b 32 $infile |" or
    die "Can't spawn ndisasmw.exe: $!";

my $hexd = qr/[A-F0-9]/i;
print "bits 32\n";
my $prev;
while (<$pipe>) {
    #warn $_;
    if (/^\s+-($hexd+)/) {
        my $mac = $1;
        $mac =~ s/$hexd{2}/$& /g;
        $mac =~ s/\s+$//;
        $prev->[1] .= " $mac";
    } elsif (/^$hexd+\s+($hexd+)\s+(.*)/) {
        my ($mac, $asm) = ($1, $2);
        $mac =~ s/$hexd{2}/$& /g;
        $mac =~ s/\s+$//;
        printf "%-45s;%s\n", @$prev if $prev;
        $prev = [$asm, $mac];
    }
}
printf "%-45s;%s\n", @$prev if $prev;

close $pipe;
