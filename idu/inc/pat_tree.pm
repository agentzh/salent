#: pat_tree.pm
#: Library for pat_tree.pl
#: Salent v0.13
#: 2005-07-21 2005-08-26

use strict;
use warnings;
use inc::state_mac;
#use Data::Dumper;

# Rre-check for potential op-code byte conflicts:
sub pre_check {
    my @insts = @_;
    my @classes;
    my @firstbytes = map {
        my @bytes = split(/\s*:\s*/, $_->{encoding});
        my %info = parse_enc($bytes[0]);
        { pattern => $info{pattern},
          encoding => $_->{encoding},
          ins => $_->{op_name},
        }
    } @insts;
    @classes = group(@firstbytes);
    pop @classes;  # pop \@null
    pop @classes;  # pop \@others
    return @classes;
}

# Add one instruction record to the pattern tree:
sub add_to_tree {
    my ($tree, $ins) = @_;
    my @bytes = split(/\s*:\s*/, $ins->{encoding});
    my $next = $tree;
    foreach my $byte (@bytes) {
        if ($next->{$byte}) {
            $next = $next->{$byte}->{next};
            next;
        }
        my $temp = {};
        $next->{$byte} = { next => $temp };
        $next = $temp;
    }
    if ($next->{ins}) {
        warn "Instruction $ins->{op_name} and $next->{ins}->{op_name} conflicted";
    }
    $next->{ins} = $ins;
}

# Parse the byte-encoding pattern of the every node:
sub process_tree {
    my $tree = shift;
    return unless $tree;
    return if $tree->{ins}; # encounter a leaf
    foreach my $enc (keys %$tree) {
        my %enc_info = parse_enc($enc);
        $tree->{$enc} = { %{$tree->{$enc}}, %enc_info };
        process_tree( $tree->{$enc}->{next} );
    }
}

# Parse a single byte-encoding and return the corresponding info:
sub parse_enc {
    local $_ = shift;
    #warn $_;
    if (/^\s*immediate data\s*$/o) {
        return (imm => 'normal');
    } elsif (/^\s*imm8(?: data)?\s*$/o or
             /^\s*8-bit level \(L\)\s*$/o or
             /^\s*type\s*$/o or
             /^\s*port number\s*$/o) {
        return (imm => 8);
    } elsif (/^\s*(\d+)-bit displacement\s*$/o) {
        return (imm => $1);
    } elsif (/^\s*full displacement\s*$/o) {
        return (imm => 'full');
    } elsif (/^\s*disp32\s*$/o) {
        return (imm => 32);
    } elsif (/^\s*unsigned full offset, selector\s*$/o) {
        return (imm => 'pointer');
    } elsif (/^\s*ib\s*$/) {
        return (pattern => '.' x 8, imm => 8);
    }

    my $i = 7;
    my $pat = '';
    my %info;
    while (1) {
        if (/\G([01]+)\s*/gco) {
            $pat .= $1;
            $i -= length($1);
        } elsif (/\G(reg[12]?)\s*/gco) {
            $info{$1} = [ $i, $i-3+1 ];
            $pat .= '.' x 3;
            $i -= 3;
        } elsif (/\G(sreg([23]))\s*/gco) {
            $info{$1} = [ $i, $i-$2+1 ];
            $pat .= '.' x $2;
            $i -= $2;
        } elsif (/\G(eee)\s*/gco) {
            $info{$1} = [ $i, $i-3+1 ];
            $pat .= '.' x 3;
            $i -= 3;
        } elsif (/\G(tttn)\s*/gco) {
            $info{$1} = [ $i, $i-4+1 ];
            $pat .= '.' x 4;
            $i -= 4;
        } elsif (/\G(modA?)\s*/gco) {
            $info{$1} = 1;
            $pat .= '.' x 2;
            $i -= 2;
        } elsif (/\Gr\/m\s*/gco) {
            $pat .= '.' x 3;
            $i -= 3;
        } elsif (/\GST\(i\)\s*/gco) {
            $info{ST_i} = [ $i, $i-3+1 ];
            $pat .= '.' x 3;
            $i -= 3;
        } elsif (/\G([wsdR])\s*/gco) {
            $info{$1} = $i;
            $pat .= '.';
            $i--;
        } elsif (/\G./gco) {
            die "Unrecognized symbol in byte encoding: '$&$''";
        } else {
            last;
        }
    }
    die "$. $_ $pat $i" unless length($pat) == 8 and $i == -1;
    $info{pattern} = $pat;
    return %info;
}

1;
