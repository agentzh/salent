#: genrw.pl
#: Generate the 64-bit word verion of AST of a .rw file randomly
#: Salent v0.13
#: Copyright (c) 2005 Sal Zhong.
#: 2005-07-11 2005-07-25

use strict;
use warnings;
use Template::Ast;

#my $seed = time;
#srand($seed);
#warn "SEED: $seed\n";
my $astfile = 'genrw.ast';
my $word_size = shift() || 32;
my ($mem_size, $times) = (4, 300);
my @items;

my @ram;
foreach(0..$mem_size-1){
    $ram[$_] = "?";
}

foreach (1..$times) {
    my $data;
    my $rw = gen_rw();
    my $addr = gen_addr();
    my $word_addr = to_word_addr($addr);
    if ($rw == 0) { # write mode
        $data = gen_data();
        if ( $word_addr >= $mem_size) {
            $data = "!'h$data";
        } else {
            # print $data . "    ";
            $ram[$word_addr] = $data;
            $data = "'h$data";
            # print $data."\n";
        }
    } else { # read mode
        $word_addr = to_word_addr($addr);
        if ($word_addr >= $mem_size) {
            $data = "!z+";
        } else {
            $data = $ram[$word_addr];
        }
    }

    push @items, {
        rw   => $rw,
        addr => "'d$addr",
        data => $data,
    }
}
# print "\n";

my $ast = {
    word_size => $word_size,
    items     => \@items,
};
Template::Ast->write($ast, $astfile) or
    die Template::Ast->error();
print "$astfile generated.\n";

sub gen_rw {
    return int rand(2);
}

sub gen_addr {
    return int rand(8 * $mem_size);
}

sub gen_data {
    my $hex;
    for (1..$word_size/4) {
        $hex .= sprintf "%x", (int rand(16));
    }
    return $hex;
}

sub to_word_addr {
    my $nbytes = $word_size / 8;
    my $nbits = int (log($nbytes) / log(2));
    return $_[0] / (2 ** $nbits);  # ignore the lower 3 bits
}
