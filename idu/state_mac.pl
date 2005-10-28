#: state_mac.pl
#: Convert encoding patter tree to state machine AST
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-22 2005-07-24

use strict;
use warnings;
use Template::Ast;
use inc::state_mac;

@ARGV || die "state_mac: No AST file specified";
my $raw_ast = Template::Ast->read(shift) or
    die Template::Ast->error();

my $tree = $raw_ast->{pat_tree};
$tree = { next => $tree };
my $state_mac = [];
build_state_mac($state_mac, $tree);
sort_next_states($state_mac);

my $nstates = scalar(@$state_mac);
die "uncontinuous state ids"
    unless $nstates == $state_mac->[-1]->{state_id} + 1;
print "state_mac: ", $nstates, " states assigned.\n";

my $ast = { idu => { state_machine => $state_mac } };
$Data::Dumper::Indent = 1;
my $outfile = 'state_mac.ast';
Template::Ast->write($ast, $outfile) or
    die Template::Ast->error();
print "state_mac: $outfile generated.\n";
