#: Idu/Util.pm
#: Utilities for Idu
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-12 2005-08-25

package inc::Idu::Util;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
    bin2hex bin2dec slice get_imm_len set_bit_fld
);

# Slice the byte:
sub slice {
    my ($byte, $i, $j) = @_;
    $j = $i unless defined $j;
    return substr($byte, 7-$i, $i-$j+1);
}


# derive the length of immediate data (in bytes):
sub get_imm_len {
    my ($s, $w, $bits16) = @_;
    if (defined $s and !defined $w) {
        if ($s == 1) { # 8-bit imm size
            return (1);
        } else { # full size imm size
            return $bits16 ? 2 : 4;
        }
    } elsif (defined $w and !defined $s) {
        if ($w == 0) { # 8-bit imm size
            return (1);
        } else { # full size imm size
            return $bits16 ? 2 : 4;
        }
    } elsif (defined $w and defined $s) {
        if ($s == 1) { # 8-bit imm size
            return (1);
        } elsif ($w == 0) { # 8-bit imm size
            return (1);
        } else {
            return $bits16 ? 2 : 4;
        }
    } else { # both w and s fields are absent
        return $bits16 ? 2 : 4;
    }
}

sub set_bit_fld {
    my ($byte, $i, $val) = @_;
    my @bits = split(//, $byte);
    $bits[7-$i] = $val;
    join('', @bits);
}

# Convert every element in the given array from binary form to hexidecial form:
sub bin2hex {
    my @list = @_;
    foreach my $bin (@list) {
        my $n = length( $bin );
        my $power = $n - 1;
        my $exp = $bin;
        $exp =~ s/[^01]//g;
        $exp =~ s/[01]/my $weight = "2**$power";
                     $power--;
                     "$&*$weight+";
                    /eg;
        chop $exp;
        #print "\t # $exp \n" if $DEBUG;
        $bin = sprintf("%02x", eval($exp));
    }
    return wantarray ? @list : $list[0];
}

sub bin2dec {
    my @dec = map { hex $_ } bin2hex(@_);
    return wantarray ? @dec : $dec[0];
}

1;
