#: filter.pl

use strict;
use warnings;

local $/;
local $_ = <>;
s/^Table B-33[^\n]+\nInstruction[^\n]+\nVol\. [^\n]+\nINSTRUCTION FORMATS[^\n]+\n//gsm;
print;
