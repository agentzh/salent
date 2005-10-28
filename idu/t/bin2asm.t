#: bin2asm.t
#: Test bin2asm.pl
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-28

use strict;
use warnings;

use File::Compare 'compare_text';
use Test::More tests => 4;

my $bin2asm = 'perl bin2asm.pl';
my $nasm = 'nasmw';
is system("$bin2asm t/bin2asm.bin > t/bin2asm.asm"), 0;
is system("$nasm t/bin2asm.asm"), 0;
is system("$bin2asm t/bin2asm > t/tmp"), 0;
is compare_text('t/tmp', 't/bin2asm.asm'), 0;
