#: disasm_cover.t
#: Test the disassembler
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-24 2005-08-25

use strict;
use warnings;

use Template::Ast;
use Test::More tests => 744;
use inc::Disasm;

my $astfile = 't/pat_cover.ast.ast';
ok -f $astfile, "$astfile exists";
my $ast = Template::Ast->read($astfile);
ok $ast, "Ast read ok";
$ast or die Template::Ast->error();

my @insts = @{$ast->{ops}};
foreach (@insts) {
    my $mac = $_->{mac};
    my $asm = Disasm->disasm($mac);
    unless ($asm) {
        ok(0, "$mac - $_->{asm}: (null)");
        next;
    }
    $_->{asm} =~ s/^o16\s+//g;
    SKIP: {
        skip "Ndisasm can't disassemble 'fisttp' correctly", 1
            if $asm =~ m/fisttp/i;
        is($asm, $_->{asm}, "$mac - $_->{asm}: $asm");
    }
    #warn "ASM: $_->{asm}";
    #warn "MAC: $mac";
}
