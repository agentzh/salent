#: ast2hex.pl
#: Generate hex listing from AST structures
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-12 2005-08-12

use strict;
use warnings;
use Template::Ast;

@ARGV || die "No ast file specified.\n";
my $ast = Template::Ast->read(shift);
$ast or die Template::Ast->error();
my @insts = @{$ast->{ops}};
my $first = 1;
foreach (@insts) {
    if ($first) {
        $first = 0;
    } else {
        print ' ';
    }
    print $_->{mac};
}
