#: gen_asm_tpl.pl
#: Generate ASM template AST for our Disasm
#: Copyright (c) 2005 Zhang Xing
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-21 2005-08-28

use strict;
use warnings;
use Template::Ast;

@ARGV || die "pat_tree: No ast file specified";
my $raw_ast = Template::Ast->read(shift) or
    die Template::Ast->error();
my $insts = $raw_ast->{insts};

my %subdes_map = (
    qr/reg8/ => "[% ins %] [% reg_8 %]",

    qr/mem8/ => "[% ins %] byte [% mem %]",

    qr/full memory/ => "[% ins %] [% pref_mem %]",

    qr/full register|register|reg(?:ister)? \(alternate encoding\)|to register|register by 1|reg|reg\(alternate encoding\)|register by CL|AL,AX or EAX with register|register indirect|LDTR from register/
        => "[% ins %] [% reg %]",

    qr/memory|to memory|memory by 1/ 
        => "[% ins %] [% pref_mem %]",

    qr/from memory/ => "[% ins %] [% reg %],[% mem %]",

    qr/indriect|memory indriect/ => "[% ins %] near [% mem %]",

    qr/memory by CL/ => "[% ins %] [% pref_mem %],cl",

    qr/register1, register2|register2 with register1|register2 to register1/
        => "[% ins %] [% reg1 %],[% reg2 %]",

    qr/register2, register1|register1 to register2|register1 and register2|register1 with register2/
        => "[% ins %] [% reg2 %],[% reg1 %]",
    
    qr/memory to register|memory with reg|memory to reg|register with memory/
        =>  "[% ins %] [% reg %],[% mem %]",
    
    qr/memory, register|memory with register|memory and register|register to memory|memory, reg|reg to memory/
        => "[% ins %] [% mem %],[% reg %]",

    qr/immediate and memory|memory, immediate|immediate to memory/ => "[% ins %] [% pref_mem %],[% imm %]",

    qr/immediate with register|immediate and register|register, immediate|immediate to register|immediate to register \(alternate encoding\)|register by immediate count/
        => "[% ins %] [% reg %],[% imm %]",
    
    qr/immediate to AL, AX, or EAX|immediate and AL, AX, or EAX|immediate with AL, AX, or EAX|fixed port/
        => "[% ins %] [% eax_var %],[% imm %]",

    qr/AL, AX, or EAX by register/ => "[% ins %] [% reg %]",

    qr/AL,AX or EAX with memory/ => "[% ins %] [% pref_mem %]",

    qr/immediate|short|direct intersegment|adding immediate to SP/ => "[% ins %] [% imm %]",

    qr/memory by immediate count|immediate with memory/ => "[% ins %] [% pref_mem %],[% imm %]",

    qr/register1 with immediate to register2/ => "[% ins %] [% reg1 %],[% reg2 %],[% pref_imm %]",

    qr/memory with immediate to register/ => "[% ins %] [% reg %],[% mem %],[% pref_imm %]",

    qr/variable port/ => "[% ins %] [% eax_var %],dx",

    qr/no argument|intersegment/ => "[% ins %]",

    qr/AX or EAX with reg/ => "[% ins %] [% eax_var %],[% reg %]",

    qr/AL, AX, or EAX with register/ => "[% ins %] [% reg %]",

    qr/AL, AX, or EAX by memory|AL, AX, or EAX with memory/
        => "[% ins %] [% pref_mem %]",
    
    qr/AL, AX, or EAX to memory/ => "[% ins %] [[% imm %]],[% eax_var %]",

    qr/memory to AL, AX, or EAX/ => "[% ins %] [% eax_var %],[[% imm %]]",

    qr/memory indirect/ => "[% ins %] [% GET 'word ' IF bits16 %]near [% mem %]",

    qr/ST\(i\)/ => '[% ins %] [% ST_i %]',

    qr/16-bit memory|ST\(0\) <- ST\(0\) .+ 16-bit memory|ST\(0\) <- 16-bit memory .+ ST\(0\)/
        => "[% ins %] word [% mem %]",

    qr/32-bit memory|ST\(0\) <- ST\(0\) .+ 32-bit memory|ST\(0\) <- 32-bit memory .+ ST\(0\)/
        => "[% ins %] dword [% mem %]",

    qr/64-bit memory|ST\(0\) <- ST\(0\) .+ 64-bit memory|ST\(0\) <- 64-bit memory .+ ST\(0\)/
        => "[% ins %] qword [% mem %]",

    qr/80-bit memory/ => "[% ins %] tword [% mem %]",

    qr/ST\(0\) <- ST\(0\) .+ ST\(i\)|ST\(0\) <- ST\(i\) .+ ST\(0\)/ => "[% ins %] [% ST_i %]",

    qr/ST\(i\) <- ST\(i\) .+ ST\(0\)|ST\(i\) <- ST\(0\) .+ ST\(i\)/ => "[% ins %] to [% ST_i %]",
   
);


my %tpls;
foreach my $inst (@$insts) {
    my ($regex, $tpl);
    while (($regex, $tpl) = each %subdes_map) {
        if ($inst->{sub_des} and $inst->{sub_des} =~ m/^$regex$/) {
            $tpls{$inst->{encoding}} = $tpl
        }
    }
}
print scalar(keys %tpls), " templates generated.\n";

my $ast = { tpls => \%tpls };
$Data::Dumper::Indent = 1;
Template::Ast->write($ast, 'asm_tpl.ast') or
    die Template::Ast->error();
