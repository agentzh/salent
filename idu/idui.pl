#: idui.pl
#: Interactive Instruction Decoding Unit
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-24 2005-08-20

use strict;
use warnings;

use inc::Idu;
use Data::Dumper;

$| = 1;
$Data::Dumper::Indent = 1;

print "Interactive x86 Instruction Decoding Unit\n";
print "Copyright (c) 2005 Agent Zhang. All rights reserved.\n\n";
print "- Use command 'set d' to enter debug mode or 'unset d' to leave.\n";
print "- Type 'q' or 'Ctrl-Z' to quit the shell.\n\n";
print ">> ";
while (<STDIN>) {
    chomp;
    if (/^\s*$/) {
        print ">> ";
        next;
    }
    last if /^\s*q\s*$/i;
    if (/^\s*(un)?set\s+d\s*$/) {
        $Idu::debug = $1 ? 0 : 1;
        print $1 ? 'Leav' : 'Enter', "ing debug mode...\n>> ";
        next;
    }
    open($Idu::source, '<', \$_) or die;
    my $res = Idu->decode;
    close $Idu::source;
    unless ($res) {
        warn Idu->error(), "\n";
        print ">> ";
        next;
    }
    print Data::Dumper->Dump([$res], ['res']);
    print ">> ";
}
