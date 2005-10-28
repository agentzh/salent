#: pat_tree.pl
#: Generate the ecoding pattern tree from which
#:   the state machine for the instruction decoder
#:   will be obtained.
#: Salent v0.13
#: 2005-07-21 2005-08-14

use strict;
use warnings;

use inc::pat_tree;
use Template::Ast;

@ARGV || die "pat_tree: No ast file specified";
my $raw_ast = Template::Ast->read(shift) or
    die Template::Ast->error();
my $insts = $raw_ast->{insts};

#=begin comment

my @classes = pre_check(@$insts);
if (@classes) {
    warn "pat_tree: I've found ", scalar(@classes), " equivalence class(es):\n";
    my $i = 1;
    #$Data::Dumper::Indent = 1;
    foreach my $class (@classes) {
        warn Template::Ast->dump([$class],["Class$i"]);
        ++$i;
    }
}

#=cut

my $pat_tree = {};
foreach my $inst (@$insts) {
    add_to_tree($pat_tree, $inst);
}
process_tree($pat_tree);
my $ast = { pat_tree => $pat_tree };
$Data::Dumper::Indent = 1;
Template::Ast->write($ast, 'pat_tree.ast') or
    die Template::Ast->error();
print "pat_tree: pat_tree.ast generated.\n";
