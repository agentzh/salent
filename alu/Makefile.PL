#: Makefile.PL
#: Generate the Makefile via TT2 template
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-11 2005-08-25

use strict;
use warnings;

use Template;

my $tpl = Template->new;
$tpl->process('Makefile.tt', undef, 'Makefile') or
    die Template->error();
