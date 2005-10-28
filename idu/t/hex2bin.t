#: hex2bin.t
#: Test hex2bin.c
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-28

use strict;
use warnings;

use Test::More tests => 8;

my $exe = 'hex2bin.exe';
ok((-f $exe), "$exe exists");
my ($infile, $outfile) = qw(t/test.hex t/tmp.bin);
unlink $outfile if -f $outfile;
is(system("$exe $infile $outfile"), 0);
my $in;
ok open($in, "$outfile"), $!;
is(<$in>, join('', 'a'..'z'));
ok close $in;

my $pipe;
$outfile = 't/tmp';
unlink $outfile if -f $outfile;
ok open($pipe, "| $exe - $outfile");
print $pipe "30 31 32 33 34 35 36 37 38 39";
close $pipe;
ok open($in, $outfile);
is <$in>, '0123456789';
close $in;
