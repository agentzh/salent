#: bin2hex.t
#: Test bin2hex.c
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-28

use strict;
use warnings;

use Test::More tests => 6;

my $exe = 'bin2hex.exe';
ok((-f $exe), "$exe exists");
my ($infile, $outfile) = qw(t/test.bin t/tmp.hex);
unlink $outfile if -f $outfile;
is(system("$exe $infile $outfile"), 0);
my $in;
ok open($in, "$outfile"), $!;
my @ords;
foreach ('a'..'z') {
    push @ords, sprintf('%02x', ord($_));
}
is <$in>, join(' ', @ords);
close $in;

my $pipe;
ok open($pipe, "$exe t/bin2hex.bin - |");
is(<$pipe>, '30 31 32 33 34 35 36 37 38 39');
close $pipe;

#ok system("$exe - tmp");
