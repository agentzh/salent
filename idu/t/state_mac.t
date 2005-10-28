#: state_mac.t
#: Test script for state_mac.pm
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-23 2005-10-22

use strict;
use warnings;

use Template::Ast;
use Test::More tests => 9;
use Test::Deep;
BEGIN { use_ok('inc::state_mac'); }

is cmp_pat(undef, '.'), 1;
is cmp_pat('1.0', ''), -1;
is cmp_pat('11..', '1...'), -1;
is cmp_pat('.101..', '1101..'), 1;

my $mac = [
    {
        next => [ { pattern => '..11' }, { pattern => '1.11' },
                  { pattern => '...1' }, { pattern => '1011' },
                  { pattern => '' } ],
    },
    {
        next => [ { pattern => '.11..'}, { pattern => '011..' } ]
    },
];

sort_next_states($mac);
cmp_deeply($mac, [
    {
        next => [ { pattern => '1011' }, { pattern => '1.11' },
                  { pattern => '..11' }, { pattern => '...1' },
                  { pattern => '' } ],
    },
    {
        next => [ { pattern => '011..' }, { pattern => '.11..' } ]
    },
]);
#warn Template::Ast->dump([$mac], ['mac']);

my $dir = -d 't' ? 't' : '.';
my $raw_ast = Template::Ast->read("$dir/pat_tree.ast");
ok($raw_ast);

my $tree = $raw_ast->{pat_tree};
$tree = { next => $tree };
my $state_mac = [];
build_state_mac($state_mac, $tree);
sort_next_states($state_mac);

my $ast = { idu => { state_machine => $state_mac } };
my $ast2 = Template::Ast->read("$dir/state_mac.ast~");
ok($ast2);
cmp_deeply($ast, $ast2);
#warn Template::Ast->dump([$ast], ['ast']);
