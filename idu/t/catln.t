#: catln.t
#: Test catln.pl
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-28

use strict;
use warnings;

use File::Compare 'compare_text';
use Test::More tests => 2;

is system('perl catln.pl t/catln.dat > t/tmp'), 0;
is compare_text('t/tmp', 't/catln.dat~'), 0;
