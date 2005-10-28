#: ndisasmi.t
#: Test ndisasmi.pl
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-03 2005-08-03

use strict;
use warnings;

use File::Compare 'compare_text';
use Test::More tests => 5;

my $tmp = 't/tmp';
my $prog = 'ndisasmi';
my $infile = "t/$prog.in";
my $outfile = "t/$prog.out";

ok -f "$prog.pl";
ok -f $infile;
ok -f $outfile;
is system("perl $prog.pl < $infile > $tmp 2>&1"), 0;
is compare_text($tmp, $outfile), 0;
unlink $tmp;
