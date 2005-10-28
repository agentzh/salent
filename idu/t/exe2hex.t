#: exe2hex.t
#: Test exe2hex.pl
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-28

use strict;
use warnings;

use File::Compare 'compare_text';
use Test::More tests => 2;

my $prog = "perl exe2hex.pl";
is system("$prog t/test.exe > tmp"), 0;
is compare_text('tmp', "t/exe2hex.hex"), 0;
