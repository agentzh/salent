#: rwc.pl
#: Compile .rw file to perl AST (.ast file)
#: Salent v0.13
#: Copyright (C) 2005 Agent Zhang.
#: 2005-07-03 2005-07-21

use strict;
use warnings;
use Template::Ast;

@ARGV ||
    die "Usage: rwc <input-file>\n";

my $rwfile = shift;
my $astfile = "$rwfile.ast";

my $fh;
unless (open $fh, $rwfile) {
    die "error: Can't open $rwfile for reading: $!\n";
}

my ($word_size, $addr_size, $delay, $capacity);
while (<$fh>) {
    next if /^\s*$/;
    if (/^\s*delay\s*:\s*(\d+)/oi) {
        $delay = $1;
    } elsif (/^\s*capacity\s*:\s*(\d+)/oi) {
        $capacity = $1;
    } elsif (/^\s*word_size\s*:\s*(\d+)/oi) {
        $word_size = $1;
    } elsif (/^\s*addr_size\s*:\s*(\d+)/oi) {
        $addr_size = $1;
    } else {
        last;
    }
}

my @ops;
do {{
    next if /^\s*$/o;
    if (/^\s*([wr])\s+(\S+)\s+(\S+)\s*$/oi) {
        my $rw = ($1 eq 'r')? 1 : 0;
        my $addr = $2;
        my $data = $3;
        
        my ($overflow, $uninit);
        if ($data =~ s/^!//) {
            $overflow = 1;
        } elsif ($data =~ s/^?$//) {
            $uninit = 1;
        }
        my $src = $_;
        chomp($src);
        $src =~ s/'/\\'/g;
        push @ops, {
            rw   => $rw,    addr => $addr,
            data => $data,  overflow => $overflow, uninit => $uninit,
            des => "$rwfile: line $.: $src",
        };
    } else {
        die "$rwfile($.): error: Syntax error\n";
    }
}} while (<$fh>);
close $fh;

my $ast = {
    vlog_file => "$rwfile.v",
    list_file => "$rwfile.lst",
    perl_file => "$rwfile.pl",

    word_size => $word_size,
    addr_size => $addr_size,
    ram => {
        capacity => $capacity,
        delay    => $delay,
    },
    ops => \@ops,
};
Template::Ast->write($ast, $astfile) or
    die Template::Ast->error();

0;
