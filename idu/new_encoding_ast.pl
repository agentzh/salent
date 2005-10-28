#: new_encodig_ast.pl
#: Generate the new version of encoding AST.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-09-07 2005-09-07

use strict;
use warnings;
use Template::Ast;

@ARGV == 2 or
    die "Usage: new_encoding_ast.pl <asm_tpl 1> <ast_tpl 2>\n";
my $ast1 = Template::Ast->read(shift) or
    die Template::Ast->error;
my $ast2 = Template::Ast->read(shift) or
    die Template::Ast->error;
my $ast = Template::Ast->merge($ast1, $ast2);

my $raw_ast = Template::Ast->read('encoding.ast') or
    die Template::Ast->error;

my @list;
my $i = 0;
my $insts = $raw_ast->{insts};
foreach my $inst (@$insts) {
    my $item = {
		id        => $i++,
        op_name   => $inst->{op_name},
        ins_set   => $inst->{ins_set},
        des       => $inst->{des},
        encoding  => $inst->{encoding},
        asm_tpl   => $ast->{tpls}->{$inst->{encoding}},
    };
    $item->{sub_des} = $inst->{sub_des} if $inst->{sub_des};
    push @list, $item;
}

my $new_ast = { insts => \@list };
Template::Ast->write($new_ast, '-') or
    die Template::Ast->error();
