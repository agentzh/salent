#: genrw2.pl
#: Generate an AST file, which works with genrw.tt,
#:   to get .rw file randomly. (evolved from genrw.pl)
#: Salent v0.13
#: Copyright (c) 2005 Sal Zhong.
#: 2005-07-11 2005-07-26

use strict;
use warnings;
use Template::Ast;

my ($word_size, $capacity, $delay) = @ARGV;
$word_size = 32 unless defined $word_size;
$delay     = 10 unless defined $delay;
my $bytes_perword = $word_size / 8;

#my $astfile;
#if (defined $capacity) {
#   #print "arrive\n";
#   $astfile = gen_astn2($word_size);
#}else {
#   $astfile = gen_astn($word_size);
#}
#warn "no ast file will be generated\n:$!" unless defined $astfile;
$capacity  = 4  unless defined $capacity;

my @ram;
foreach (0..$capacity - 1) {
    $ram[$_] = "?";
}

my @items;
my $times  = 100;
foreach (1..$times) { 
    my $data;
    my $rw        = gen_rw();
    my $addr      = gen_addr();
    my $word_addr = $addr / $bytes_perword;

    if($rw == 0) {            #rw == 0 - write mode        
        $data = gen_data();        
        if ($word_addr >= $capacity) {
            $data = "!'h$data";
        }else {
              # print $val."\t";
              $ram[$word_addr] = $data;
              $data = "'h$data";
              #print $val."\n";
        }
    }else {        
        if ($word_addr >= $capacity) {
            $data = "!z+";
        }else {
            $data = $ram[$word_addr];
        }
    }
    $addr = "'d$addr";

    push @items, {
        rw     => $rw,
        addr   => $addr,
        data   => $data,
    }
}

my $ast = {
    delay     => $delay,	
    word_size => $word_size,
    capacity  => $capacity,
    items     => \@items,
};
Template::Ast->write($ast, '-') or
    die Template::Ast->error();
#print "$astfile generated.\n";

sub gen_rw {
    return int rand(2);
}

sub gen_addr {
    return int rand(1.3 * $capacity * $bytes_perword); #make sure why did I choose 2
}

sub gen_data {
    my $hval;
    my $n = $word_size / 4;	
    foreach(1..$n) {
        $hval .= sprintf "%x", (int rand(16));
    }
    return $hval;
}

=begin dull

sub gen_astn {                                      #gen_astn abbreviation of generate ast file name
    my $word_size = shift;
    return 'genrw1.ast' if $word_size == 8;
    return 'genrw2.ast' if $word_size == 16;
    return 'genrw3.ast' if $word_size == 32;
    return 'genrw4.ast' if $word_size == 64;
    return ;
}
        
sub gen_astn2 {
    my $word_size = shift;
    return 'genrw5.ast' if $word_size == 8;
    return 'genrw6.ast' if $word_size == 16;
    return 'genrw7.ast' if $word_size == 32;
    return 'genrw8.ast' if $word_size == 64;
    return ;
}

=end
