#: catln.pl
#: Concatenate the lines to a single line using space as the line-separator.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-28

use strict;
use warnings;

while (<>) {
    chomp;
    print $_, " ";
}
print "\n";
