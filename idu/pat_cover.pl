#: pat_cover.pl
#: Machine instruction generator for
#:   encoding pattern coverage test
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-12 2005-08-21

use strict;
use warnings;

use inc::pat_tree;
use inc::Idu::Util;
use Template::Ast;
#use XBase;
#use Getopt::Std;

#my %opts;
#getopts('b', \%opts);
#my $gen_pref = $opts{b} ? 1 : 0;

@ARGV == 2 || die "Usage: pat_cover <encoding-ast> <config-ast>\n";
my $raw_ast = Template::Ast->read(shift) or
    die Template::Ast->error();
my $insts = $raw_ast->{insts};

my $config_ast = Template::Ast->read(shift) or
    die Template::Ast->error();
my $idu = $config_ast->{idu};
die unless ref $idu;

my @rand_insts;
my $firstTime = 1;
foreach my $inst (@$insts) {
    my $enc = $inst->{encoding};
    my @bytes = split(/\s*:\s*/, $enc);
    my (@mac, $res);
    $res = {};

    # generate BITS prefix byte in the second pass:
    if (!$firstTime) {
        push @mac, '66';
        $res->{preffix} = ['66'];
        $res->{bits16} = 1;
    }

    foreach (@bytes) {
        #warn $_;
        my %flds = parse_enc($_);
        my $imm = $flds{imm};

        # generate immediate data:
        if ($imm) {
            if ($imm eq 'full') {
                # Get full immediate data:
                if ($res->{bits16}) { # 16-bit operand size
                    push @mac, gen_bytes(2);
                } else { # 32-bit operand size
                    push @mac, gen_bytes(4);
                }
            } elsif ($imm eq 'normal') {
                # Get immediate data:
                my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
                push @mac, gen_bytes($len);
            } elsif ($imm eq 'pointer') {
                my $len = $res->{bits16} ? 4 : 6;
                push @mac, gen_bytes($len);
            } else {
                my $nbytes = int ($imm/8);
                if ($nbytes == 1 and $flds{pattern}) {
                    #warn "00 generated";
                    push @mac, '00';  # Escape potential conflicts for AAM and AAD.
                } else {
                    push @mac, gen_bytes($nbytes);
                }
            }
            next;
        }

        my $byte_mac = $flds{pattern};
        $byte_mac =~ s/\./int rand(2)/ego;

        #my $flag = 0;
        #if ($inst->{op_name} =~ m/adc/i and defined $flds{w} and defined $flds{s}) {
            #foreach my $key (keys %flds) {
            #    warn "$key => ", $flds{$key};
            #}
            #warn "Hey, I'm here!";
            #$byte_mac = '10000010';
            #$flag = 1;
        #}

        # Set the fields properly:

        my @bit_flds = @{$idu->{bit_fields}};
        foreach my $bit (@bit_flds) {
            next unless defined $flds{$bit};
            # Get the current field from the current byte:
            $res->{$bit} = slice($byte_mac, $flds{$bit});
            #warn "$bit - $res->{$bit} => $byte_mac => $flds{$bit}" if $byte_mac eq '10000010';
        }
		
        my ($w, $s) = ($res->{w}, $res->{s});
        if (defined $w and defined $s and $w == 0 and $s == 1) {
            #warn "Hey!!! Got to this line! cool";
            $s = 0;
            $byte_mac = set_bit_fld($byte_mac, $flds{s}, $s);
            $res->{s} = $s;
            #warn "After mod byte_mac is now $byte_mac";
        }

        my $mod = $flds{mod} || $flds{modA};
        if ($mod) {
            my $temp = slice($byte_mac, 7, 6);
            if ($temp eq '11') { # 11H must be filtered out
                $temp = '00';
                $byte_mac =~ s/^../$temp/;
                #warn $byte_mac;
            }
            $res->{mod} = $temp;
            $res->{rm} = slice($byte_mac, 2, 0);
            # Process the current ModR/M byte:
            my $hex = bin2hex($byte_mac);
            push @mac, sprintf("%02x", hex($hex));
            push @mac, gen_ModRM($res);
        } else {
            my $hex = bin2hex($byte_mac);
            push @mac, sprintf("%02x", hex($hex));
        }
    }
    my $mac = join(' ', @mac);
    my $hexd = qr/[0-9a-f]/i;
    die $mac unless $mac =~ m/^(?:$hexd{2} )*$hexd{2}$/i;
    my $ins = $inst->{op_name};
    #if ($mac eq '90' and $ins !~ m/^NOP$/i) {
    #    $ins = 'NOP';
    #    $enc = '1001 0000';
    #}
    push @rand_insts, {
        mac => $mac,
        encoding => $enc,
        ins => $ins,
    };

    if ($firstTime and $inst->{ins_set} eq 'General') {
        if ($ins !~ m/^bswap|movsx|movzx/i) {
            undef $firstTime;
            redo;
        }
    } else {
        $firstTime = 1;
    }
}

warn "pat_cover: ", scalar(@rand_insts), " instructions generated.\n";
my $out_ast = { ops => \@rand_insts };
Template::Ast->write($out_ast, '-') or
    die Template::Ast->error();

sub gen_bytes {
    my $len = shift;
    my @vals;
    for (1..$len) {
        push @vals, gen_byte();
    }
    return wantarray ? @vals : $vals[0];
}

sub gen_byte {
    my $val = int rand(256);
    return sprintf("%02x", $val);
}

sub gen_ModRM {
    my $res = shift;
    my $mod = $res->{mod};
    my $rm  = $res->{rm};
    my @bytes; # ret val
    if ($mod eq '00') {
        if ($rm eq '101') { # Direct: EA = Disp32
            # Get 32-bit displacement:
            push @bytes, gen_bytes(4);
            return undef unless @bytes;
        } elsif ($rm eq '100') { # Base with index (uses SIB byte)
            # Get SIB byte:
            my $byte = gen_byte();
            #warn $byte;
            push @bytes, $byte;
            my $bin = sprintf("%08b", hex($byte));
            my $base = slice($bin, 2, 0);
            if ($base eq '101') { # Base == EBP: EA = [Index] x Scale + Disp32
                # Get 32-bit displacement:
                push @bytes, gen_bytes(4);
            }
        }
    } elsif ($mod eq '01') {
        if ($rm eq '100') { # EA = [Base] + [Index] x Scale + Disp8
            # Get SIB byte:
            my $byte = gen_byte();
            push @bytes, $byte;
            # Get 8-bit displacement:
            push @bytes, gen_byte();
        } else { # EA = [Reg] + Disp8
            # Get 8-bit displacement:
            push @bytes, gen_byte();
        }
    } elsif ($mod eq '10') {
        if ($rm eq '100') { # EA = [Base] + [Index] x Scale + Disp32
            # Get SIB byte:
            push @bytes, gen_byte();
            # Get 32-bit displacement:
            push @bytes, gen_bytes(4);
        } else { # EA = [Reg] + Disp32
            # Get 32-bit displacement:
            push @bytes, gen_bytes(4);
        }
    }
    return @bytes;
}
