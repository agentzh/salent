#: ndisasmi.pl
#: Interactive ndisasmw (Disassembler shipped with NASM Windows version)
#: Salent v0.12
#: Copyright (c) 2005 Sal Zhong
#: 2005-08-02  2005-08-24

use strict;
use warnings;
use inc::Ndisasm;

$| = 1;

print <<"_EOC_";
Interactive disassembler by using ndisasmw
Copyright (c) 2005 Sal Zhong. All rights reserved.

- Type 'q' or 'Ctrl-Z' to quit the shell

_EOC_

print ">> ";

my $hexd = qr/[0-9a-f]/i;
while (<STDIN>) {
    if (/^\s*$/) {
        print ">> ";
        next;
    }
    last if /^\s*q\s*$/;
    chomp;
    my $ret = disasm($_);
    unless (defined $ret) {
        print inc::Ndisasm->error(), "\n";
    } else {
        print "\t" x 4, $ret, "\n";
    }
    print ">> ";
}

0;
