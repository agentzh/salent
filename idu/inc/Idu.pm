#: Idu.pm
#: Perl implementation of IA-32 instruction decoding unit
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-24 2005-11-24

package Idu;

use strict;
use warnings;
use inc::Idu::Util;

our $source;   # input file handle
our @oldbytes; # stores the bytes processed
our $error;    # stores the error info
our $debug = 0;
our $token;
our $token_error = 0;

# Return the error info:
sub error {
    return $error;
}

# Read the specified number of bytes from input:
sub readbytes {
    $token_error = 0;
    my $count = shift;
    $count ||= 1;
    my @bytes;
    for (1..$count) {
        local $/ = ' ';
        do {
            $token = <$source>;
        } while ($token and $token =~ m/^\s+$/);
        return () unless $token;
        $token =~ s/\s+|\n//g;
        push @oldbytes, $token;
        if ($token =~ m/^[01]{8}$/o) {
            push @bytes, sprintf("%08s", $token);
        } elsif ($token =~ m/^[0-9a-f]{2}$/io) {
            push @bytes, sprintf("%08b", hex($token));
        } else {
            $token_error = 1;
            return wantarray ? () : undef;
        }
    }
    return wantarray ? @bytes : $bytes[0];
}

# Process the ModR/M byte:
sub process_ModRM {
    my ($res, $byte) = @_;
    my $mod = slice($byte, 7, 6);
    my $rm  = slice($byte, 2, 0);
    $res->{mod} = $mod;
    $res->{rm}  = $rm;
    if ($mod eq '00') {
        if ($rm eq '101') { # Direct: EA = Disp32
            # Get 32-bit displacement:
            my @bytes = readbytes(4);
            return undef unless @bytes;
            $res->{disp} = [bin2hex @bytes];
        } elsif ($rm eq '100') { # Base with index (uses SIB byte)
            # Get SIB byte:
            my $byte = readbytes(1);
            return undef unless defined $byte;
            $res->{scale} = slice($byte, 7, 6);
            $res->{index_reg} = slice($byte, 5, 3);
            my $base = slice($byte, 2, 0);
            if ($base eq '101') { # Base == EBP: EA = [Index] x Scale + Disp32
                # Get 32-bit displacement:
                my @bytes = readbytes(4);
                return undef unless @bytes;
                $res->{disp} = [bin2hex @bytes];
            } else { # EA = [Base] + [Index] x Scale
                $res->{base_reg} = $base;
            }
        }
    } elsif ($mod eq '01') {
        if ($rm eq '100') { # EA = [Base] + [Index] x Scale + Disp8
            # Get SIB byte:
            my $byte = readbytes(1);
            return undef unless defined $byte;
            $res->{scale} = slice($byte, 7, 6);
            $res->{index_reg} = slice($byte, 5, 3);
            $res->{base_reg}  = slice($byte, 2, 0);
            # Get 8-bit displacement:
            my @bytes = readbytes(1);
            return undef unless @bytes;
            $res->{disp} = [bin2hex @bytes];
        } else { # EA = [Reg] + Disp8
            # Get 8-bit displacement:
            my @bytes = readbytes(1);
            return undef unless @bytes;
            $res->{disp} = [bin2hex @bytes];
        }
    } elsif ($mod eq '10') {
        if ($rm eq '100') { # EA = [Base] + [Index] x Scale + Disp32
            # Get SIB byte:
            my $byte = readbytes(1);
            return undef unless defined $byte;
            $res->{scale} = slice($byte, 7, 6);
            $res->{index_reg} = slice($byte, 5, 3);
            $res->{base_reg}  = slice($byte, 2, 0);
            # Get 32-bit displacement:
            my @bytes = readbytes(4);
            return undef unless @bytes;
            $res->{disp} = [bin2hex @bytes];
        } else { # EA = [Reg] + Disp32
            # Get 32-bit displacement:
            my @bytes = readbytes(4);
            return undef unless @bytes;
            $res->{disp} = [bin2hex @bytes];
        }
    }
    return 1;
}

# Decode one instruction:
sub decode {
    shift;
    if (@_) {
        unless (open $Idu::source, '<', \$_[0]) {
            $error = "file error - $!";
            return undef;
        }
    }
    @oldbytes = ();
    my $byte;
    my $res = {};
    my $state = 'S_START';
    while (1) {
        if ($debug) {
            my $val = $byte || '';
            warn "Switching to state $state with byte $val...\n";
        }
        if ($state eq 'S_START' or $state eq 'S_PREFIX') {
            if ($state eq 'S_START') {
                $byte = readbytes(1);
                unless (defined $byte) { # Check the valid end of input
                    if ($token_error) {
                        $state = 'S_SYN_ERROR';
                        next;
                    } else {
                        $error = '';
                        return undef;
                    }
                }
            }
            # Process preffix byte (if any):
            if ($byte eq '11110010') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['f2'] ;
                } else {
                    push @{$res->{prefix}}, 'f2';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '11110011') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['f3'] ;
                } else {
                    push @{$res->{prefix}}, 'f3';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '11110000') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['f0'] ;
                } else {
                    push @{$res->{prefix}}, 'f0';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '01100111') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['67'] ;
                } else {
                    push @{$res->{prefix}}, '67';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '01100110') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['66'] ;
                } else {
                    push @{$res->{prefix}}, '66';
                }
                
                $res->{bits16} = 1;
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '00101110') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['2e'] ;
                } else {
                    push @{$res->{prefix}}, '2e';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '00110110') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['36'] ;
                } else {
                    push @{$res->{prefix}}, '36';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '00111110') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['3e'] ;
                } else {
                    push @{$res->{prefix}}, '3e';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '00100110') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['26'] ;
                } else {
                    push @{$res->{prefix}}, '26';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '01100100') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['64'] ;
                } else {
                    push @{$res->{prefix}}, '64';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } elsif ($byte eq '01100101') {
                if ($state eq 'S_START') {
                    $res->{prefix} = ['65'] ;
                } else {
                    push @{$res->{prefix}}, '65';
                }
                
                $byte = readbytes(1);
                unless (defined $byte) { # Check the unexpected end of input
                    $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                    next;
                }
                $state = 'S_PREFIX';
            } else {
                $state = 'S_0';
            }
        } elsif ($state eq 'S_0') {

            if ($byte =~ m/^11011101$/o) {
                $state = 'S_1';
            } elsif ($byte =~ m/^11111110$/o) {
                $state = 'S_14';
            } elsif ($byte =~ m/^11101010$/o) {
                $state = 'S_19';
            } elsif ($byte =~ m/^0010100[01]$/o) {
                $state = 'S_21';
            } elsif ($byte =~ m/^1010110[01]$/o) {
                $state = 'S_24';
            } elsif ($byte =~ m/^10011011$/o) {
                $state = 'S_25';
            } elsif ($byte =~ m/^00100111$/o) {
                $state = 'S_26';
            } elsif ($byte =~ m/^1010101[01]$/o) {
                $state = 'S_27';
            } elsif ($byte =~ m/^1111011[01]$/o) {
                $state = 'S_28';
            } elsif ($byte =~ m/^0010101[01]$/o) {
                $state = 'S_45';
            } elsif ($byte =~ m/^11101011$/o) {
                $state = 'S_48';
            } elsif ($byte =~ m/^11111000$/o) {
                $state = 'S_50';
            } elsif ($byte =~ m/^11000101$/o) {
                $state = 'S_51';
            } elsif ($byte =~ m/^11111001$/o) {
                $state = 'S_53';
            } elsif ($byte =~ m/^01100010$/o) {
                $state = 'S_54';
            } elsif ($byte =~ m/^0010110[01]$/o) {
                $state = 'S_56';
            } elsif ($byte =~ m/^0011000[01]$/o) {
                $state = 'S_58';
            } elsif ($byte =~ m/^0000110[01]$/o) {
                $state = 'S_61';
            } elsif ($byte =~ m/^1110010[01]$/o) {
                $state = 'S_63';
            } elsif ($byte =~ m/^0001000[01]$/o) {
                $state = 'S_65';
            } elsif ($byte =~ m/^1010111[01]$/o) {
                $state = 'S_68';
            } elsif ($byte =~ m/^11111011$/o) {
                $state = 'S_69';
            } elsif ($byte =~ m/^011010[01]1$/o) {
                $state = 'S_70';
            } elsif ($byte =~ m/^11001010$/o) {
                $state = 'S_75';
            } elsif ($byte =~ m/^0001001[01]$/o) {
                $state = 'S_77';
            } elsif ($byte =~ m/^1110111[01]$/o) {
                $state = 'S_80';
            } elsif ($byte =~ m/^1010000[01]$/o) {
                $state = 'S_81';
            } elsif ($byte =~ m/^11110101$/o) {
                $state = 'S_83';
            } elsif ($byte =~ m/^10011111$/o) {
                $state = 'S_84';
            } elsif ($byte =~ m/^0000010[01]$/o) {
                $state = 'S_85';
            } elsif ($byte =~ m/^11100000$/o) {
                $state = 'S_87';
            } elsif ($byte =~ m/^10011100$/o) {
                $state = 'S_89';
            } elsif ($byte =~ m/^1000010[01]$/o) {
                $state = 'S_90';
            } elsif ($byte =~ m/^0010010[01]$/o) {
                $state = 'S_93';
            } elsif ($byte =~ m/^0111[01][01][01][01]$/o) {
                $state = 'S_95';
            } elsif ($byte =~ m/^10011001$/o) {
                $state = 'S_97';
            } elsif ($byte =~ m/^0001101[01]$/o) {
                $state = 'S_98';
            } elsif ($byte =~ m/^0000101[01]$/o) {
                $state = 'S_101';
            } elsif ($byte =~ m/^01100000$/o) {
                $state = 'S_104';
            } elsif ($byte =~ m/^10011101$/o) {
                $state = 'S_105';
            } elsif ($byte =~ m/^11100001$/o) {
                $state = 'S_106';
            } elsif ($byte =~ m/^10001101$/o) {
                $state = 'S_108';
            } elsif ($byte =~ m/^01000[01][01][01]$/o) {
                $state = 'S_110';
            } elsif ($byte =~ m/^10010[01][01][01]$/o) {
                $state = 'S_111';
            } elsif ($byte =~ m/^11011011$/o) {
                $state = 'S_112';
            } elsif ($byte =~ m/^11010110$/o) {
                $state = 'S_122';
            } elsif ($byte =~ m/^0000100[01]$/o) {
                $state = 'S_123';
            } elsif ($byte =~ m/^100000[01][01]$/o) {
                $state = 'S_126';
            } elsif ($byte =~ m/^0011110[01]$/o) {
                $state = 'S_159';
            } elsif ($byte =~ m/^10001111$/o) {
                $state = 'S_161';
            } elsif ($byte =~ m/^1010100[01]$/o) {
                $state = 'S_164';
            } elsif ($byte =~ m/^11001000$/o) {
                $state = 'S_166';
            } elsif ($byte =~ m/^01001[01][01][01]$/o) {
                $state = 'S_168';
            } elsif ($byte =~ m/^10001110$/o) {
                $state = 'S_169';
            } elsif ($byte =~ m/^1011[01][01][01][01]$/o) {
                $state = 'S_172';
            } elsif ($byte =~ m/^01100011$/o) {
                $state = 'S_174';
            } elsif ($byte =~ m/^1010011[01]$/o) {
                $state = 'S_177';
            } elsif ($byte =~ m/^1010010[01]$/o) {
                $state = 'S_178';
            } elsif ($byte =~ m/^1101000[01]$/o) {
                $state = 'S_179';
            } elsif ($byte =~ m/^01011[01][01][01]$/o) {
                $state = 'S_194';
            } elsif ($byte =~ m/^0011001[01]$/o) {
                $state = 'S_195';
            } elsif ($byte =~ m/^1100000[01]$/o) {
                $state = 'S_198';
            } elsif ($byte =~ m/^1110110[01]$/o) {
                $state = 'S_227';
            } elsif ($byte =~ m/^00110111$/o) {
                $state = 'S_228';
            } elsif ($byte =~ m/^00111111$/o) {
                $state = 'S_229';
            } elsif ($byte =~ m/^11011100$/o) {
                $state = 'S_230';
            } elsif ($byte =~ m/^11111010$/o) {
                $state = 'S_245';
            } elsif ($byte =~ m/^1110011[01]$/o) {
                $state = 'S_246';
            } elsif ($byte =~ m/^10011000$/o) {
                $state = 'S_248';
            } elsif ($byte =~ m/^1100011[01]$/o) {
                $state = 'S_249';
            } elsif ($byte =~ m/^01100001$/o) {
                $state = 'S_254';
            } elsif ($byte =~ m/^0001110[01]$/o) {
                $state = 'S_255';
            } elsif ($byte =~ m/^0000001[01]$/o) {
                $state = 'S_257';
            } elsif ($byte =~ m/^11111101$/o) {
                $state = 'S_260';
            } elsif ($byte =~ m/^0110110[01]$/o) {
                $state = 'S_261';
            } elsif ($byte =~ m/^1000011[01]$/o) {
                $state = 'S_262';
            } elsif ($byte =~ m/^00011111$/o) {
                $state = 'S_265';
            } elsif ($byte =~ m/^0110111[01]$/o) {
                $state = 'S_266';
            } elsif ($byte =~ m/^11001101$/o) {
                $state = 'S_267';
            } elsif ($byte =~ m/^11111100$/o) {
                $state = 'S_269';
            } elsif ($byte =~ m/^11100011$/o) {
                $state = 'S_270';
            } elsif ($byte =~ m/^011010[01]0$/o) {
                $state = 'S_272';
            } elsif ($byte =~ m/^11011000$/o) {
                $state = 'S_274';
            } elsif ($byte =~ m/^0000000[01]$/o) {
                $state = 'S_291';
            } elsif ($byte =~ m/^11001111$/o) {
                $state = 'S_294';
            } elsif ($byte =~ m/^0011010[01]$/o) {
                $state = 'S_295';
            } elsif ($byte =~ m/^10011110$/o) {
                $state = 'S_297';
            } elsif ($byte =~ m/^0011101[01]$/o) {
                $state = 'S_298';
            } elsif ($byte =~ m/^10001100$/o) {
                $state = 'S_301';
            } elsif ($byte =~ m/^00000111$/o) {
                $state = 'S_304';
            } elsif ($byte =~ m/^11001001$/o) {
                $state = 'S_305';
            } elsif ($byte =~ m/^01010[01][01][01]$/o) {
                $state = 'S_306';
            } elsif ($byte =~ m/^11000100$/o) {
                $state = 'S_307';
            } elsif ($byte =~ m/^11010101$/o) {
                $state = 'S_309';
            } elsif ($byte =~ m/^1000100[01]$/o) {
                $state = 'S_312';
            } elsif ($byte =~ m/^11010111$/o) {
                $state = 'S_315';
            } elsif ($byte =~ m/^11100010$/o) {
                $state = 'S_316';
            } elsif ($byte =~ m/^11101001$/o) {
                $state = 'S_318';
            } elsif ($byte =~ m/^11001011$/o) {
                $state = 'S_320';
            } elsif ($byte =~ m/^11110100$/o) {
                $state = 'S_321';
            } elsif ($byte =~ m/^11011001$/o) {
                $state = 'S_322';
            } elsif ($byte =~ m/^11010100$/o) {
                $state = 'S_360';
            } elsif ($byte =~ m/^11111111$/o) {
                $state = 'S_363';
            } elsif ($byte =~ m/^11011010$/o) {
                $state = 'S_376';
            } elsif ($byte =~ m/^0011100[01]$/o) {
                $state = 'S_386';
            } elsif ($byte =~ m/^11000010$/o) {
                $state = 'S_389';
            } elsif ($byte =~ m/^11001100$/o) {
                $state = 'S_391';
            } elsif ($byte =~ m/^1101001[01]$/o) {
                $state = 'S_392';
            } elsif ($byte =~ m/^000[01][01]110$/o) {
                $state = 'S_407';
            } elsif ($byte =~ m/^0010001[01]$/o) {
                $state = 'S_408';
            } elsif ($byte =~ m/^1000101[01]$/o) {
                $state = 'S_411';
            } elsif ($byte =~ m/^11000011$/o) {
                $state = 'S_414';
            } elsif ($byte =~ m/^11101000$/o) {
                $state = 'S_415';
            } elsif ($byte =~ m/^0010000[01]$/o) {
                $state = 'S_417';
            } elsif ($byte =~ m/^11011110$/o) {
                $state = 'S_420';
            } elsif ($byte =~ m/^00101111$/o) {
                $state = 'S_436';
            } elsif ($byte =~ m/^00001111$/o) {
                $state = 'S_437';
            } elsif ($byte =~ m/^0001100[01]$/o) {
                $state = 'S_567';
            } elsif ($byte =~ m/^1010001[01]$/o) {
                $state = 'S_570';
            } elsif ($byte =~ m/^00010111$/o) {
                $state = 'S_572';
            } elsif ($byte =~ m/^10011010$/o) {
                $state = 'S_573';
            } elsif ($byte =~ m/^0001010[01]$/o) {
                $state = 'S_575';
            } elsif ($byte =~ m/^11001110$/o) {
                $state = 'S_577';
            } elsif ($byte =~ m/^11011111$/o) {
                $state = 'S_578';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_1') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_4';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_5';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_6';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_10';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_2';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_12';
            } elsif ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_9';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_3';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_7';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_13';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_11';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_8';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_2') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FFREE";
            $res->{des} = "Free ST(i) Register";
            $res->{encoding} = "11011 101 : 1100 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_3') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSTP";
            $res->{des} = "Store Real and Pop";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 101 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_4') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISTTP";
            $res->{des} = "Store Integer with Truncation";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 101 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_5') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FNSAVE";
            $res->{des} = "Store FPU State";
            $res->{encoding} = "11011 101 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_6') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FUCOMP";
            $res->{des} = "Unordered Compare Real and Pop";
            $res->{encoding} = "11011 101 : 1110 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_7') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FST";
            $res->{des} = "Store Real";
            $res->{subdes} = "ST(i)";
            $res->{encoding} = "11011 101 : 11 010 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_8') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FRSTOR";
            $res->{des} = "Restore FPU State";
            $res->{encoding} = "11011 101 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_9') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSTP";
            $res->{des} = "Store Real and Pop";
            $res->{subdes} = "ST(i)";
            $res->{encoding} = "11011 101 : 11 011 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_10') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FNSTSW";
            $res->{des} = "Store Status Word into Memory";
            $res->{encoding} = "11011 101 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_11') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FUCOM";
            $res->{des} = "Unordered Compare Real";
            $res->{encoding} = "11011 101 : 1110 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_12') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FLD";
            $res->{des} = "Load Real";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 101 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_13') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FST";
            $res->{des} = "Store Real";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 101 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_14') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_17';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_15';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_16';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_18';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_15') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "DEC";
            $res->{des} = "Decrement by 1";
            $res->{subdes} = "mem8";
            $res->{encoding} = "1111 1110 : mod 001 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_16') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "INC";
            $res->{des} = "Increment by 1";
            $res->{subdes} = "reg8";
            $res->{encoding} = "1111 1110 : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_17') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "DEC";
            $res->{des} = "Decrement by 1";
            $res->{subdes} = "reg8";
            $res->{encoding} = "1111 1110 : 11 001 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_18') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "INC";
            $res->{des} = "Increment by 1";
            $res->{subdes} = "mem8";
            $res->{encoding} = "1111 1110 : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_19') {

            $state = 'S_20';
        } elsif ($state eq 'S_20') {
            # Get immediate data:
            my $len = $res->{bits16} ? 4 : 6;
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "JMP";
            $res->{des} = "Unconditional Jump (to other segment)";
            $res->{subdes} = "direct intersegment";
            $res->{encoding} = "1110 1010 : unsigned full offset, selector";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_21') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_22';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_23';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_22') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0010 100w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_23') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0010 100w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_24') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "LODS/LODSB/LODSW/LODSD";
            $res->{des} = "Load String Operand";
            $res->{encoding} = "1010 110w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_25') {

            $res->{ins} = "WAIT";
            $res->{des} = "Wait";
            $res->{encoding} = "1001 1011";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_26') {

            $res->{ins} = "DAA";
            $res->{des} = "Decimal Adjust AL after Addition";
            $res->{encoding} = "0010 0111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_27') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "STOS/STOSB/STOSW/STOSD";
            $res->{des} = "Store String Data";
            $res->{encoding} = "1010 101w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_28') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_29';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_30';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_31';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_40';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_36';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_33';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_34';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_42';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_35';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_39';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_37';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_38';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_44';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_43';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_29') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "NEG";
            $res->{des} = "Two's Complement Negation";
            $res->{subdes} = "register";
            $res->{encoding} = "1111 011w : 11 011 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_30') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "NEG";
            $res->{des} = "Two's Complement Negation";
            $res->{subdes} = "memory";
            $res->{encoding} = "1111 011w : mod 011 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_31') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_32';
        } elsif ($state eq 'S_32') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "TEST";
            $res->{des} = "Logical Compare";
            $res->{subdes} = "immediate and register";
            $res->{encoding} = "1111 011w : 11 000 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_33') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "DIV";
            $res->{des} = "Unsigned Divide";
            $res->{subdes} = "AL, AX, or EAX by memory";
            $res->{encoding} = "1111 011w : mod 110 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_34') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "IMUL";
            $res->{des} = "Signed Multiply";
            $res->{subdes} = "AL, AX, or EAX with register";
            $res->{encoding} = "1111 011w : 11 101 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_35') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "IDIV";
            $res->{des} = "Signed Divide";
            $res->{subdes} = "AL, AX, or EAX by register";
            $res->{encoding} = "1111 011w : 11 111 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_36') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "DIV";
            $res->{des} = "Unsigned Divide";
            $res->{subdes} = "AL, AX, or EAX by register";
            $res->{encoding} = "1111 011w : 11 110 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_37') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "MUL";
            $res->{des} = "Unsigned Multiply";
            $res->{subdes} = "AL, AX, or EAX with register";
            $res->{encoding} = "1111 011w : 11 100 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_38') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "MUL";
            $res->{des} = "Unsigned Multiply";
            $res->{subdes} = "AL, AX, or EAX with memory";
            $res->{encoding} = "1111 011w : mod 100 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_39') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "IDIV";
            $res->{des} = "Signed Divide";
            $res->{subdes} = "AL, AX, or EAX by memory";
            $res->{encoding} = "1111 011w : mod 111 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_40') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_41';
        } elsif ($state eq 'S_41') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "TEST";
            $res->{des} = "Logical Compare";
            $res->{subdes} = "immediate and memory";
            $res->{encoding} = "1111 011w : mod 000 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_42') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "IMUL";
            $res->{des} = "Signed Multiply";
            $res->{subdes} = "AL, AX, or EAX with memory";
            $res->{encoding} = "1111 011w : mod 101 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_43') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "NOT";
            $res->{des} = "One's Complement Negation";
            $res->{subdes} = "memory";
            $res->{encoding} = "1111 011w : mod 010 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_44') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "NOT";
            $res->{des} = "One's Complement Negation";
            $res->{subdes} = "register";
            $res->{encoding} = "1111 011w : 11 010 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_45') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_46';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_47';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_46') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0010 101w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_47') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0010 101w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_48') {

            $state = 'S_49';
        } elsif ($state eq 'S_49') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "JMP";
            $res->{des} = "Unconditional Jump (to same segment)";
            $res->{subdes} = "short";
            $res->{encoding} = "1110 1011 : 8-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_50') {

            $res->{ins} = "CLC";
            $res->{des} = "Clear Carry Flag";
            $res->{encoding} = "1111 1000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_51') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_52';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_52') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LDS";
            $res->{des} = "Load Pointer to DS";
            $res->{encoding} = "1100 0101 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_53') {

            $res->{ins} = "STC";
            $res->{des} = "Set Carry Flag";
            $res->{encoding} = "1111 1001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_54') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_55';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_55') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BOUND";
            $res->{des} = "Check Array Against Bounds";
            $res->{encoding} = "0110 0010 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_56') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_57';
        } elsif ($state eq 'S_57') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0010 110w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_58') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_59';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_60';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_59') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0011 000w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_60') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0011 000w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_61') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_62';
        } elsif ($state eq 'S_62') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0000 110w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_63') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_64';
        } elsif ($state eq 'S_64') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "IN";
            $res->{des} = "Input From Port";
            $res->{subdes} = "fixed port";
            $res->{encoding} = "1110 010w : port number";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_65') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_66';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_67';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_66') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0001 000w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_67') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0001 000w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_68') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "SCAS/SCASB/SCASW/SCASD";
            $res->{des} = "Scan String";
            $res->{encoding} = "1010 111w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_69') {

            $res->{ins} = "STI";
            $res->{des} = "Set Interrupt Flag";
            $res->{encoding} = "1111 1011";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_70') {
            # Get the s field from the current byte:
            $res->{'s'} = slice($byte, 1);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_71';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_73';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_71') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $state = 'S_72';
        } elsif ($state eq 'S_72') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "IMUL";
            $res->{des} = "Signed Multiply";
            $res->{subdes} = "register1 with immediate to register2";
            $res->{encoding} = "0110 10s1 : 11 reg1 reg2 : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_73') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $state = 'S_74';
        } elsif ($state eq 'S_74') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "IMUL";
            $res->{des} = "Signed Multiply";
            $res->{subdes} = "memory with immediate to register";
            $res->{encoding} = "0110 10s1 : mod reg r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_75') {

            $state = 'S_76';
        } elsif ($state eq 'S_76') {
            # Get 16-bit immediate data:
            my @bytes = readbytes(2);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "RET";
            $res->{des} = "Return from Procedure (to other segment)";
            $res->{subdes} = "adding immediate to SP";
            $res->{encoding} = "1100 1010 : 16-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_77') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_78';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_79';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_78') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0001 001w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_79') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0001 001w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_80') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "OUT";
            $res->{des} = "Output to Port";
            $res->{subdes} = "variable port";
            $res->{encoding} = "1110 111w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_81') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_82';
        } elsif ($state eq 'S_82') {
            # Get 32-bit immediate data:
            my @bytes = readbytes(4);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "memory to AL, AX, or EAX";
            $res->{encoding} = "1010 000w : disp32";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_83') {

            $res->{ins} = "CMC";
            $res->{des} = "Complement Carry Flag";
            $res->{encoding} = "1111 0101";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_84') {

            $res->{ins} = "LAHF";
            $res->{des} = "Load Flags into AHRegister";
            $res->{encoding} = "1001 1111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_85') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_86';
        } elsif ($state eq 'S_86') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0000 010w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_87') {

            $state = 'S_88';
        } elsif ($state eq 'S_88') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "LOOPNZ/LOOPNE";
            $res->{des} = "Loop Count while not Zero/Equal";
            $res->{encoding} = "1110 0000 : 8-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_89') {

            $res->{ins} = "PUSHF/PUSHFD";
            $res->{des} = "Push Flags Register onto the Stack";
            $res->{encoding} = "1001 1100";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_90') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_91';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_92';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_91') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "TEST";
            $res->{des} = "Logical Compare";
            $res->{subdes} = "register1 and register2";
            $res->{encoding} = "1000 010w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_92') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "TEST";
            $res->{des} = "Logical Compare";
            $res->{subdes} = "memory and register";
            $res->{encoding} = "1000 010w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_93') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_94';
        } elsif ($state eq 'S_94') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0010 010w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_95') {
            # Get the tttn field from the current byte:
            $res->{'tttn'} = slice($byte, 3, 0);

            $state = 'S_96';
        } elsif ($state eq 'S_96') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "Jcc";
            $res->{des} = "Jump if Condition is Met";
            $res->{subdes} = "8-bit displacement";
            $res->{encoding} = "0111 tttn : 8-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_97') {

            $res->{ins} = "CDQ";
            $res->{des} = "Convert Doubleword to Qword";
            $res->{encoding} = "1001 1001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_98') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_99';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_100';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_99') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0001 101w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_100') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0001 101w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_101') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_102';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_103';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_102') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 101w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_103') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0000 101w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_104') {

            $res->{ins} = "PUSHA/PUSHAD";
            $res->{des} = "Push All General Registers";
            $res->{encoding} = "0110 0000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_105') {

            $res->{ins} = "POPF/POPFD";
            $res->{des} = "Pop Stack into FLAGS or EFLAGS Register";
            $res->{encoding} = "1001 1101";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_106') {

            $state = 'S_107';
        } elsif ($state eq 'S_107') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "LOOPZ/LOOPE";
            $res->{des} = "Loop Count while Zero/Equal";
            $res->{encoding} = "1110 0001 : 8-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_108') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_109';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_109') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LEA";
            $res->{des} = "Load Effective Address";
            $res->{encoding} = "1000 1101 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_110') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "INC";
            $res->{des} = "Increment by 1";
            $res->{subdes} = "reg (alternate encoding)";
            $res->{encoding} = "0100 0 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_111') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "XCHG";
            $res->{des} = "Exchange Register/Memory with Register";
            $res->{subdes} = "AX or EAX with reg";
            $res->{encoding} = "1001 0 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_112') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11100011$/o) {
                $state = 'S_113';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_115';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_116';
            } elsif ($byte =~ m/^11100010$/o) {
                $state = 'S_117';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_118';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_120';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_121';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_119';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_114';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_113') {

            $res->{ins} = "FNINIT";
            $res->{des} = "Initialize Floating-Point Unit Without Checking for Pending Unmasked Exceptions";
            $res->{encoding} = "11011 011 : 1110 0011";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_114') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FLD";
            $res->{des} = "Load Real";
            $res->{subdes} = "80-bit memory";
            $res->{encoding} = "11011 011 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_115') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISTTP";
            $res->{des} = "Store Integer with Truncation";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 011 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_116') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISTP";
            $res->{des} = "Store Integer and Pop";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 011 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_117') {

            $res->{ins} = "FNCLEX";
            $res->{des} = "Clear Exceptions";
            $res->{encoding} = "11011 011 : 1110 0010";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_118') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSTP";
            $res->{des} = "Store Real and Pop";
            $res->{subdes} = "80-bit memory";
            $res->{encoding} = "11011 011 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_119') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FUCOMI";
            $res->{des} = "Unorderd Compare Real and Set EFLAGS";
            $res->{encoding} = "11011 011 : 11 101 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_120') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FILD";
            $res->{des} = "Load Integer";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 011 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_121') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIST";
            $res->{des} = "Store Integer";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 011 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_122') {

            $res->{ins} = "SALC";
            $res->{des} = "Set AL from Carry Flag";
            $res->{encoding} = "1101 0110";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_123') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_124';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_125';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_124') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0000 100w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_125') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0000 100w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_126') {
            # Get the s field from the current byte:
            $res->{'s'} = slice($byte, 1);
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_139';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_127';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_149';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_129';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_131';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_141';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_151';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_133';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_147';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_135';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_145';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_137';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_143';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_153';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_157';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_155';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_127') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_128';
        } elsif ($state eq 'S_128') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 011 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_129') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_130';
        } elsif ($state eq 'S_130') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 110 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_131') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_132';
        } elsif ($state eq 'S_132') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 001 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_133') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_134';
        } elsif ($state eq 'S_134') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 100 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_135') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_136';
        } elsif ($state eq 'S_136') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "immediate with memory";
            $res->{encoding} = "1000 00sw : mod 111 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_137') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_138';
        } elsif ($state eq 'S_138') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 101 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_139') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_140';
        } elsif ($state eq 'S_140') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 011 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_141') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_142';
        } elsif ($state eq 'S_142') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "OR";
            $res->{des} = "Logical Inclusive OR";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 001 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_143') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_144';
        } elsif ($state eq 'S_144') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 000 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_145') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_146';
        } elsif ($state eq 'S_146') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SUB";
            $res->{des} = "Integer Subtraction";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 101 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_147') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_148';
        } elsif ($state eq 'S_148') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "immediate with register";
            $res->{encoding} = "1000 00sw : 11 111 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_149') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_150';
        } elsif ($state eq 'S_150') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 110 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_151') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_152';
        } elsif ($state eq 'S_152') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 100 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_153') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_154';
        } elsif ($state eq 'S_154') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 000 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_155') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_156';
        } elsif ($state eq 'S_156') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1000 00sw : mod 010 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_157') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_158';
        } elsif ($state eq 'S_158') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1000 00sw : 11 010 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_159') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_160';
        } elsif ($state eq 'S_160') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "immediate with AL, AX, or EAX";
            $res->{encoding} = "0011 110w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_161') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_162';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_163';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_162') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "POP";
            $res->{des} = "Pop a Word from the Stack";
            $res->{subdes} = "register";
            $res->{encoding} = "1000 1111 : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_163') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "POP";
            $res->{des} = "Pop a Word from the Stack";
            $res->{subdes} = "memory";
            $res->{encoding} = "1000 1111 : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_164') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_165';
        } elsif ($state eq 'S_165') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "TEST";
            $res->{des} = "Logical Compare";
            $res->{subdes} = "immediate and AL, AX, or EAX";
            $res->{encoding} = "1010 100w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_166') {

            $state = 'S_167';
        } elsif ($state eq 'S_167') {
            # Get 24-bit immediate data:
            my @bytes = readbytes(3);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ENTER";
            $res->{des} = "Make Stack Frame for High Level Procedure";
            $res->{encoding} = "1100 1000 : 24-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_168') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "DEC";
            $res->{des} = "Decrement by 1";
            $res->{subdes} = "register (alternate encoding)";
            $res->{encoding} = "0100 1 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_169') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_171';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_170';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_170') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the sreg3 field from the current byte:
            $res->{'sreg3'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Segment Registers";
            $res->{subdes} = "memory to segment reg";
            $res->{encoding} = "1000 1110 : mod sreg3 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_171') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);
            # Get the sreg3 field from the current byte:
            $res->{'sreg3'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Segment Registers";
            $res->{subdes} = "register to segment register";
            $res->{encoding} = "1000 1110 : 11 sreg3 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_172') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 3);
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_173';
        } elsif ($state eq 'S_173') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "immediate to register (alternate encoding)";
            $res->{encoding} = "1011 w reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_174') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_175';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_176';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_175') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "ARPL";
            $res->{des} = "Adjust RPL Field of Selector";
            $res->{subdes} = "from register";
            $res->{encoding} = "0110 0011 : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_176') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "ARPL";
            $res->{des} = "Adjust RPL Field of Selector";
            $res->{subdes} = "from memory";
            $res->{encoding} = "0110 0011 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_177') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "CMPS/CMPSB/CMPSW/CMPSD";
            $res->{des} = "Compare String Operands";
            $res->{encoding} = "1010 011w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_178') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "MOVS/MOVSB/MOVSW/MOVSD";
            $res->{des} = "Move Data from String to String";
            $res->{encoding} = "1010 010w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_179') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_185';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_180';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_181';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_186';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_190';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_182';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_189';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_183';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_188';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_184';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_187';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_191';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_192';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_193';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_180') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "RCR";
            $res->{des} = "Rotate thru Carry Right";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 011 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_181') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "ROR";
            $res->{des} = "Rotate Right";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 001 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_182') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SHL";
            $res->{des} = "Shift Left";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 100 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_183') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SAR";
            $res->{des} = "Shift Arithmetic Right";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 111 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_184') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SHR";
            $res->{des} = "Shift Right";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 101 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_185') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "RCR";
            $res->{des} = "Rotate thru Carry Right";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 011 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_186') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "ROR";
            $res->{des} = "Rotate Right";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 001 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_187') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "ROL";
            $res->{des} = "Rotate Left";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_188') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SHR";
            $res->{des} = "Shift Right";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 101 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_189') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SAR";
            $res->{des} = "Shift Arithmetic Right";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 111 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_190') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SHL";
            $res->{des} = "Shift Left";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 100 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_191') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "ROL";
            $res->{des} = "Rotate Left";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_192') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "RCL";
            $res->{des} = "Rotate thru Carry Left";
            $res->{subdes} = "register by 1";
            $res->{encoding} = "1101 000w : 11 010 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_193') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "RCL";
            $res->{des} = "Rotate thru Carry Left";
            $res->{subdes} = "memory by 1";
            $res->{encoding} = "1101 000w : mod 010 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_194') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "POP";
            $res->{des} = "Pop a Word from the Stack";
            $res->{subdes} = "register (alternate encoding)";
            $res->{encoding} = "0101 1 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_195') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_196';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_197';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_196') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0011 001w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_197') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0011 001w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_198') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_209';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_199';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_201';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_211';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_219';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_203';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_217';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_205';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_215';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_207';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_213';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_221';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_223';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_225';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_199') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_200';
        } elsif ($state eq 'S_200') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "RCR";
            $res->{des} = "Rotate thru Carry Right";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 011 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_201') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_202';
        } elsif ($state eq 'S_202') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ROR";
            $res->{des} = "Rotate Right";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 001 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_203') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_204';
        } elsif ($state eq 'S_204') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHL";
            $res->{des} = "Shift Left";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 100 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_205') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_206';
        } elsif ($state eq 'S_206') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SAR";
            $res->{des} = "Shift Arithmetic Right";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 111 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_207') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_208';
        } elsif ($state eq 'S_208') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHR";
            $res->{des} = "Shift Right";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 101 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_209') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_210';
        } elsif ($state eq 'S_210') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "RCR";
            $res->{des} = "Rotate thru Carry Right";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 011 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_211') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_212';
        } elsif ($state eq 'S_212') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ROR";
            $res->{des} = "Rotate Right";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 001 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_213') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_214';
        } elsif ($state eq 'S_214') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ROL";
            $res->{des} = "Rotate Left";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 000 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_215') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_216';
        } elsif ($state eq 'S_216') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHR";
            $res->{des} = "Shift Right";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 101 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_217') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_218';
        } elsif ($state eq 'S_218') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SAR";
            $res->{des} = "Shift Arithmetic Right";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 111 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_219') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_220';
        } elsif ($state eq 'S_220') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHL";
            $res->{des} = "Shift Left";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 100 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_221') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_222';
        } elsif ($state eq 'S_222') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ROL";
            $res->{des} = "Rotate Left";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 000 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_223') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_224';
        } elsif ($state eq 'S_224') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "RCL";
            $res->{des} = "Rotate thru Carry Left";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "1100 000w : 11 010 reg : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_225') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_226';
        } elsif ($state eq 'S_226') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "RCL";
            $res->{des} = "Rotate thru Carry Left";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "1100 000w : mod 010 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_227') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "IN";
            $res->{des} = "Input From Port";
            $res->{subdes} = "variable port";
            $res->{encoding} = "1110 110w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_228') {

            $res->{ins} = "AAA";
            $res->{des} = "ASCII Adjust after Addition";
            $res->{encoding} = "0011 0111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_229') {

            $res->{ins} = "AAS";
            $res->{des} = "ASCII Adjust AL after Subtraction";
            $res->{encoding} = "0011 1111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_230') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_231';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_244';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_232';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_233';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_234';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_239';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_242';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_235';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_241';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_236';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_240';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_237';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_238';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_243';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_231') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FCOMP";
            $res->{des} = "Compare Real and Pop";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 100 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_232') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FDIVR";
            $res->{des} = "Reverse Divide";
            $res->{subdes} = "ST(i) <- ST(0) / ST(i)";
            $res->{encoding} = "11011 100 : 1111 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_233') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FDIV";
            $res->{des} = "Divide";
            $res->{subdes} = "ST(0) <- ST(0) / 64-bit memory";
            $res->{encoding} = "11011 100 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_234') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FMUL";
            $res->{des} = "Multiply";
            $res->{subdes} = "ST(i) <- ST(0) * ST(i)";
            $res->{encoding} = "11011 100 : 1100 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_235') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSUB";
            $res->{des} = "Subtract";
            $res->{subdes} = "ST(0) <- ST(0) - 64-bit memory";
            $res->{encoding} = "11011 100 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_236') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FDIVR";
            $res->{des} = "Reverse Divide";
            $res->{subdes} = "ST(0) <- 64-bit memory / ST(0)";
            $res->{encoding} = "11011 100 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_237') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSUBR";
            $res->{des} = "Reverse Subtract";
            $res->{subdes} = "ST(0) <- 64-bit memory - ST(0)";
            $res->{encoding} = "11011 100 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_238') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FADD";
            $res->{des} = "Add";
            $res->{subdes} = "ST(i) <- ST(0) + ST(i)";
            $res->{encoding} = "11011 100 : 11 000 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_239') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FMUL";
            $res->{des} = "Multiply";
            $res->{subdes} = "ST(0) <- ST(0) * 64-bit memory";
            $res->{encoding} = "11011 100 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_240') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSUB";
            $res->{des} = "Subtract";
            $res->{subdes} = "ST(i) <- ST(i) - ST(0)";
            $res->{encoding} = "11011 100 : 1110 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_241') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FDIV";
            $res->{des} = "Divide";
            $res->{subdes} = "ST(i) <- ST(i) / ST(0)";
            $res->{encoding} = "11011 100 : 1111 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_242') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSUBR";
            $res->{des} = "Reverse Subtract";
            $res->{subdes} = "ST(i) <- ST(0) - ST(i)";
            $res->{encoding} = "11011 100 : 1110 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_243') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FADD";
            $res->{des} = "Add";
            $res->{subdes} = "ST(0) <- ST(0) + 64-bit memory";
            $res->{encoding} = "11011 100 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_244') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FCOM";
            $res->{des} = "Compare Real";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 100 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_245') {

            $res->{ins} = "CLI";
            $res->{des} = "Clear Interrupt Flag";
            $res->{encoding} = "1111 1010";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_246') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_247';
        } elsif ($state eq 'S_247') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "OUT";
            $res->{des} = "Output to Port";
            $res->{subdes} = "fixed port";
            $res->{encoding} = "1110 011w : port number";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_248') {

            $res->{ins} = "CWDE";
            $res->{des} = "Convert Word to Doubleword";
            $res->{encoding} = "1001 1000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_249') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_250';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_252';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_250') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_251';
        } elsif ($state eq 'S_251') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "immediate to register";
            $res->{encoding} = "1100 011w : 11 000 reg : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_252') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_253';
        } elsif ($state eq 'S_253') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "immediate to memory";
            $res->{encoding} = "1100 011w : mod 000 r/m : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_254') {

            $res->{ins} = "POPA/POPAD";
            $res->{des} = "Pop All General Registers";
            $res->{encoding} = "0110 0001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_255') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_256';
        } elsif ($state eq 'S_256') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0001 110w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_257') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_258';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_259';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_258') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 001w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_259') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0000 001w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_260') {

            $res->{ins} = "STD";
            $res->{des} = "Set Direction Flag";
            $res->{encoding} = "1111 1101";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_261') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "INS";
            $res->{des} = "Input from DX Port";
            $res->{encoding} = "0110 110w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_262') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_263';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_264';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_263') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "XCHG";
            $res->{des} = "Exchange Register/Memory with Register";
            $res->{subdes} = "register1 with register2";
            $res->{encoding} = "1000 011w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_264') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "XCHG";
            $res->{des} = "Exchange Register/Memory with Register";
            $res->{subdes} = "memory with reg";
            $res->{encoding} = "1000 011w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_265') {

            $res->{ins} = "POP";
            $res->{des} = "Pop a Segment Register from the Stack (Note: CS cannot be sreg2 in this usage.)";
            $res->{subdes} = "segment register DS";
            $res->{encoding} = "000 11 111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_266') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $res->{ins} = "OUTS";
            $res->{des} = "Output to DX Port";
            $res->{encoding} = "0110 111w";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_267') {

            $state = 'S_268';
        } elsif ($state eq 'S_268') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "INT n";
            $res->{des} = "Interrupt Type n";
            $res->{encoding} = "1100 1101 : type";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_269') {

            $res->{ins} = "CLD";
            $res->{des} = "Clear Direction Flag";
            $res->{encoding} = "1111 1100";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_270') {

            $state = 'S_271';
        } elsif ($state eq 'S_271') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "JCXZ/JECXZ";
            $res->{des} = "Jump on CX/ECX Zero";
            $res->{subdes} = "Address-size prefix differentiates JCXZ and JECXZ";
            $res->{encoding} = "1110 0011 : 8-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_272') {
            # Get the s field from the current byte:
            $res->{'s'} = slice($byte, 1);

            $state = 'S_273';
        } elsif ($state eq 'S_273') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "PUSH";
            $res->{des} = "Push Operand onto the Stack";
            $res->{subdes} = "immediate";
            $res->{encoding} = "0110 10s0 : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_274') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_287';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_275';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_276';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_277';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_278';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_283';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_289';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_279';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_285';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_280';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_281';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_288';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_286';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_282';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_284';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_290';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_275') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FCOMP";
            $res->{des} = "Compare Real and Pop";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 000 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_276') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FDIV";
            $res->{des} = "Divide";
            $res->{subdes} = "ST(0) <- ST(0) / ST(i)";
            $res->{encoding} = "11011 000 : 1111 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_277') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FDIV";
            $res->{des} = "Divide";
            $res->{subdes} = "ST(0) <- ST(0) / 32-bit memory";
            $res->{encoding} = "11011 000 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_278') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FMUL";
            $res->{des} = "Multiply";
            $res->{subdes} = "ST(0) <- ST(0) * ST(i)";
            $res->{encoding} = "11011 000 : 1100 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_279') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSUB";
            $res->{des} = "Subtract";
            $res->{subdes} = "ST(0) <- ST(0) - 32-bit memory";
            $res->{encoding} = "11011 000 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_280') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FDIVR";
            $res->{des} = "Reverse Divide";
            $res->{subdes} = "ST(0) <- 32-bit memory / ST(0)";
            $res->{encoding} = "11011 000 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_281') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FADD";
            $res->{des} = "Add";
            $res->{subdes} = "ST(0) <- ST(0) + ST(i)";
            $res->{encoding} = "11011 000 : 11 000 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_282') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSUBR";
            $res->{des} = "Reverse Subtract";
            $res->{subdes} = "ST(0) <- 32-bit memory - ST(0)";
            $res->{encoding} = "11011 000 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_283') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FMUL";
            $res->{des} = "Multiply";
            $res->{subdes} = "ST(0) <- ST(0) * 32-bit memory";
            $res->{encoding} = "11011 000 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_284') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FCOM";
            $res->{des} = "Compare Real";
            $res->{subdes} = "ST(i)";
            $res->{encoding} = "11011 000 : 11 010 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_285') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FDIVR";
            $res->{des} = "Reverse Divide";
            $res->{subdes} = "ST(0) <- ST(i) / ST(0)";
            $res->{encoding} = "11011 000 : 1111 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_286') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSUBR";
            $res->{des} = "Reverse Subtract";
            $res->{subdes} = "ST(0) <- ST(i) - ST(0)";
            $res->{encoding} = "11011 000 : 1110 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_287') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FCOMP";
            $res->{des} = "Compare Real and Pop";
            $res->{subdes} = "ST(i)";
            $res->{encoding} = "11011 000 : 11 011 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_288') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FADD";
            $res->{des} = "Add";
            $res->{subdes} = "ST(0) <- ST(0) + 32-bit memory";
            $res->{encoding} = "11011 000 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_289') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSUB";
            $res->{des} = "Subtract";
            $res->{subdes} = "ST(0) <- ST(0) - ST(i)";
            $res->{encoding} = "11011 000 : 1110 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_290') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FCOM";
            $res->{des} = "Compare Real";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 000 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_291') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_292';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_293';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_292') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0000 000w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_293') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "ADD";
            $res->{des} = "Add";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0000 000w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_294') {

            $res->{ins} = "IRET/IRETD";
            $res->{des} = "Interrupt Return";
            $res->{encoding} = "1100 1111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_295') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_296';
        } elsif ($state eq 'S_296') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "XOR";
            $res->{des} = "Logical Exclusive OR";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0011 010w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_297') {

            $res->{ins} = "SAHF";
            $res->{des} = "Store AH into Flags";
            $res->{encoding} = "1001 1110";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_298') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_299';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_300';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_299') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "register2 with register1";
            $res->{encoding} = "0011 101w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_300') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "register with memory";
            $res->{encoding} = "0011 101w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_301') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_303';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_302';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_302') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the sreg3 field from the current byte:
            $res->{'sreg3'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Segment Registers";
            $res->{subdes} = "segment register to memory";
            $res->{encoding} = "1000 1100 : mod sreg3 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_303') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);
            # Get the sreg3 field from the current byte:
            $res->{'sreg3'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Segment Registers";
            $res->{subdes} = "segment register to register";
            $res->{encoding} = "1000 1100 : 11 sreg3 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_304') {

            $res->{ins} = "POP";
            $res->{des} = "Pop a Segment Register from the Stack (Note: CS cannot be sreg2 in this usage.)";
            $res->{subdes} = "segment register ES";
            $res->{encoding} = "000 00 111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_305') {

            $res->{ins} = "LEAVE";
            $res->{des} = "High Level Procedure Exit";
            $res->{encoding} = "1100 1001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_306') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "PUSH";
            $res->{des} = "Push Operand onto the Stack";
            $res->{subdes} = "register (alternate encoding)";
            $res->{encoding} = "0101 0 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_307') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_308';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_308') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LES";
            $res->{des} = "Load Pointer to ES";
            $res->{encoding} = "1100 0100 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_309') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^00001010$/o) {
                $state = 'S_310';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_311';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_310') {

            $res->{ins} = "AAD";
            $res->{des} = "ASCII Adjust AX before Division";
            $res->{subdes} = "AX";
            $res->{encoding} = "1101 0101 : 0000 1010";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_311') {
            # Get 8-bit immediate data:
            $res->{imm} = [bin2hex $byte];

            $res->{ins} = "AAD";
            $res->{des} = "ASCII Adjust AX before Division";
            $res->{subdes} = "imm8 data";
            $res->{encoding} = "1101 0101 : ib";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_312') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_313';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_314';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_313') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "1000 100w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_314') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "reg to memory";
            $res->{encoding} = "1000 100w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_315') {

            $res->{ins} = "XLAT/XLATB";
            $res->{des} = "Table Look-up Translation";
            $res->{encoding} = "1101 0111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_316') {

            $state = 'S_317';
        } elsif ($state eq 'S_317') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "LOOP";
            $res->{des} = "Loop Count";
            $res->{encoding} = "1110 0010 : 8-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_318') {

            $state = 'S_319';
        } elsif ($state eq 'S_319') {
            # Get full immediate data:
            my $len = $res->{bits16} ? 2 : 4;
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "JMP";
            $res->{des} = "Unconditional Jump (to same segment)";
            $res->{subdes} = "direct";
            $res->{encoding} = "1110 1001 : full displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_320') {

            $res->{ins} = "RET";
            $res->{des} = "Return from Procedure (to other segment)";
            $res->{subdes} = "intersegment";
            $res->{encoding} = "1100 1011";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_321') {

            $res->{ins} = "HLT";
            $res->{des} = "Halt";
            $res->{encoding} = "1111 0100";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_322') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11111010$/o) {
                $state = 'S_324';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_327';
            } elsif ($byte =~ m/^11110001$/o) {
                $state = 'S_328';
            } elsif ($byte =~ m/^11101011$/o) {
                $state = 'S_330';
            } elsif ($byte =~ m/^11111000$/o) {
                $state = 'S_331';
            } elsif ($byte =~ m/^11111001$/o) {
                $state = 'S_332';
            } elsif ($byte =~ m/^11111101$/o) {
                $state = 'S_333';
            } elsif ($byte =~ m/^11111100$/o) {
                $state = 'S_335';
            } elsif ($byte =~ m/^11111011$/o) {
                $state = 'S_336';
            } elsif ($byte =~ m/^11110101$/o) {
                $state = 'S_338';
            } elsif ($byte =~ m/^11100000$/o) {
                $state = 'S_340';
            } elsif ($byte =~ m/^11100101$/o) {
                $state = 'S_342';
            } elsif ($byte =~ m/^11101001$/o) {
                $state = 'S_343';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_344';
            } elsif ($byte =~ m/^11101101$/o) {
                $state = 'S_345';
            } elsif ($byte =~ m/^11110100$/o) {
                $state = 'S_346';
            } elsif ($byte =~ m/^11100001$/o) {
                $state = 'S_347';
            } elsif ($byte =~ m/^11111111$/o) {
                $state = 'S_348';
            } elsif ($byte =~ m/^11101100$/o) {
                $state = 'S_352';
            } elsif ($byte =~ m/^11101000$/o) {
                $state = 'S_353';
            } elsif ($byte =~ m/^11110110$/o) {
                $state = 'S_354';
            } elsif ($byte =~ m/^11101110$/o) {
                $state = 'S_355';
            } elsif ($byte =~ m/^11110111$/o) {
                $state = 'S_356';
            } elsif ($byte =~ m/^11110000$/o) {
                $state = 'S_358';
            } elsif ($byte =~ m/^11110011$/o) {
                $state = 'S_359';
            } elsif ($byte =~ m/^11111110$/o) {
                $state = 'S_323';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_334';
            } elsif ($byte =~ m/^11110010$/o) {
                $state = 'S_325';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_329';
            } elsif ($byte =~ m/^11101010$/o) {
                $state = 'S_326';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_350';
            } elsif ($byte =~ m/^11010000$/o) {
                $state = 'S_337';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_341';
            } elsif ($byte =~ m/^11100100$/o) {
                $state = 'S_339';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_349';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_351';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_357';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_323') {

            $res->{ins} = "FSIN";
            $res->{des} = "Sine";
            $res->{encoding} = "11011 001 : 1111 1110";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_324') {

            $res->{ins} = "FSQRT";
            $res->{des} = "Square Root";
            $res->{encoding} = "11011 001 : 1111 1010";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_325') {

            $res->{ins} = "FPTAN";
            $res->{des} = "Partial Tangent";
            $res->{encoding} = "11011 001 : 1111 0010";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_326') {

            $res->{ins} = "FLDL2E";
            $res->{des} = "Load log2(¦Å) into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1010";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_327') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FSTP";
            $res->{des} = "Store Real and Pop";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 001 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_328') {

            $res->{ins} = "FYL2X";
            $res->{des} = "ST(1) * log2(ST(0))";
            $res->{encoding} = "11011 001 : 1111 0001";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_329') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FNSTENV";
            $res->{des} = "Store FPU Environment";
            $res->{encoding} = "11011 001 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_330') {

            $res->{ins} = "FLDPI";
            $res->{des} = "Load ¦Ð into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1011";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_331') {

            $res->{ins} = "FPREM";
            $res->{des} = "Partial Remainder";
            $res->{encoding} = "11011 001 : 1111 1000";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_332') {

            $res->{ins} = "FYL2XP1";
            $res->{des} = "ST(1) * log2(ST(0) + 1.0)";
            $res->{encoding} = "11011 001 : 1111 1001";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_333') {

            $res->{ins} = "FSCALE";
            $res->{des} = "Scale";
            $res->{encoding} = "11011 001 : 1111 1101";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_334') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FNSTCW";
            $res->{des} = "Store Control Word";
            $res->{encoding} = "11011 001 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_335') {

            $res->{ins} = "FRNDINT";
            $res->{des} = "Round to Integer";
            $res->{encoding} = "11011 001 : 1111 1100";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_336') {

            $res->{ins} = "FSINCOS";
            $res->{des} = "Sine and Cosine";
            $res->{encoding} = "11011 001 : 1111 1011";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_337') {

            $res->{ins} = "FNOP";
            $res->{des} = "No Operation";
            $res->{encoding} = "11011 001 : 1101 0000";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_338') {

            $res->{ins} = "FPREM1";
            $res->{des} = "Partial Remainder (IEEE)";
            $res->{encoding} = "11011 001 : 1111 0101";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_339') {

            $res->{ins} = "FTST";
            $res->{des} = "Test";
            $res->{encoding} = "11011 001 : 1110 0100";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_340') {

            $res->{ins} = "FCHS";
            $res->{des} = "Change Sign";
            $res->{encoding} = "11011 001 : 1110 0000";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_341') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FST";
            $res->{des} = "Store Real";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 001 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_342') {

            $res->{ins} = "FXAM";
            $res->{des} = "Examine";
            $res->{encoding} = "11011 001 : 1110 0101";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_343') {

            $res->{ins} = "FLDL2T";
            $res->{des} = "Load log2(10) into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1001";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_344') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FXCH";
            $res->{des} = "Exchange ST(0) and ST(i)";
            $res->{encoding} = "11011 001 : 1100 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_345') {

            $res->{ins} = "FLDLN2";
            $res->{des} = "Load log¦Å(2) into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1101";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_346') {

            $res->{ins} = "FXTRACT";
            $res->{des} = "Extract Exponent and Significand";
            $res->{encoding} = "11011 001 : 1111 0100";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_347') {

            $res->{ins} = "FABS";
            $res->{des} = "Absolute Value";
            $res->{encoding} = "11011 001 : 1110 0001";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_348') {

            $res->{ins} = "FCOS";
            $res->{des} = "Cosine of ST(0)";
            $res->{encoding} = "11011 001 : 1111 1111";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_349') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FLDENV";
            $res->{des} = "Load FPU Environment";
            $res->{encoding} = "11011 001 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_350') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FLDCW";
            $res->{des} = "Load Control Word";
            $res->{encoding} = "11011 001 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_351') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FLD";
            $res->{des} = "Load Real";
            $res->{subdes} = "ST(i)";
            $res->{encoding} = "11011 001 : 11 000 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_352') {

            $res->{ins} = "FLDLG2";
            $res->{des} = "Load log10(2) into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1100";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_353') {

            $res->{ins} = "FLD1";
            $res->{des} = "Load +1.0 into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1000";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_354') {

            $res->{ins} = "FDECSTP";
            $res->{des} = "Decrement Stack-Top Pointer";
            $res->{encoding} = "11011 001 : 1111 0110";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_355') {

            $res->{ins} = "FLDZ";
            $res->{des} = "Load +0.0 into ST(0)";
            $res->{encoding} = "11011 001 : 1110 1110";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_356') {

            $res->{ins} = "FINCSTP";
            $res->{des} = "Increment Stack Pointer";
            $res->{encoding} = "11011 001 : 1111 0111";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_357') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FLD";
            $res->{des} = "Load Real";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 001 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_358') {

            $res->{ins} = "F2XM1";
            $res->{des} = "Compute 2ST(0) - 1";
            $res->{encoding} = "11011 001 : 1111 0000";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_359') {

            $res->{ins} = "FPATAN";
            $res->{des} = "Partial Arctangent";
            $res->{encoding} = "11011 001 : 1111 0011";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_360') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^00001010$/o) {
                $state = 'S_361';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_362';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_361') {

            $res->{ins} = "AAM";
            $res->{des} = "ASCII Adjust AX after Multiply";
            $res->{subdes} = "AX";
            $res->{encoding} = "1101 0100 : 0000 1010";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_362') {
            # Get 8-bit immediate data:
            $res->{imm} = [bin2hex $byte];

            $res->{ins} = "AAM";
            $res->{des} = "ASCII Adjust AX after Multiply";
            $res->{subdes} = "imm8 data";
            $res->{encoding} = "1101 0100 : ib";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_363') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_364';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_372';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_369';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_365';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_366';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_367';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_368';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_374';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_375';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_370';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_373';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_371';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_364') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "CALL";
            $res->{des} = "Call Procedure (in other segment)";
            $res->{subdes} = "indirect";
            $res->{encoding} = "1111 1111 : mod 011 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_365') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "PUSH";
            $res->{des} = "Push Operand onto the Stack";
            $res->{subdes} = "memory";
            $res->{encoding} = "1111 1111 : mod 110 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_366') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "DEC";
            $res->{des} = "Decrement by 1";
            $res->{subdes} = "full register";
            $res->{encoding} = "1111 1111 : 11 001 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_367') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "DEC";
            $res->{des} = "Decrement by 1";
            $res->{subdes} = "full memory";
            $res->{encoding} = "1111 1111 : mod 001 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_368') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "INC";
            $res->{des} = "Increment by 1";
            $res->{subdes} = "full register";
            $res->{encoding} = "1111 1111 : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_369') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "PUSH";
            $res->{des} = "Push Operand onto the Stack";
            $res->{subdes} = "register";
            $res->{encoding} = "1111 1111 : 11 110 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_370') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "CALL";
            $res->{des} = "Call Procedure (in same segment)";
            $res->{subdes} = "memory indirect";
            $res->{encoding} = "1111 1111 : mod 010 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_371') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "JMP";
            $res->{des} = "Unconditional Jump (to same segment)";
            $res->{subdes} = "memory indirect";
            $res->{encoding} = "1111 1111 : mod 100 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_372') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "JMP";
            $res->{des} = "Unconditional Jump (to other segment)";
            $res->{subdes} = "indirect intersegment";
            $res->{encoding} = "1111 1111 : mod 101 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_373') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "JMP";
            $res->{des} = "Unconditional Jump (to same segment)";
            $res->{subdes} = "register indirect";
            $res->{encoding} = "1111 1111 : 11 100 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_374') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "INC";
            $res->{des} = "Increment by 1";
            $res->{subdes} = "full memory";
            $res->{encoding} = "1111 1111 : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_375') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "CALL";
            $res->{des} = "Call Procedure (in same segment)";
            $res->{subdes} = "register indirect";
            $res->{encoding} = "1111 1111 : 11 010 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_376') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_377';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_378';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_379';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_380';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_381';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_383';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_385';
            } elsif ($byte =~ m/^11101001$/o) {
                $state = 'S_382';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_384';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_377') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FICOMP";
            $res->{des} = "Compare Integer and Pop";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 010 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_378') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIDIV";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- ST(0) / 32-bit memory";
            $res->{encoding} = "11011 010 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_379') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIDIVR";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- 32-bit memory / ST(0)";
            $res->{encoding} = "11011 010 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_380') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIMUL";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- ST(0) * 32-bit memory";
            $res->{encoding} = "11011 010 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_381') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FICOM";
            $res->{des} = "Compare Integer";
            $res->{subdes} = "32-bit memory";
            $res->{encoding} = "11011 010 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_382') {

            $res->{ins} = "FUCOMPP";
            $res->{des} = "Unordered Compare Real and Pop Twice";
            $res->{encoding} = "11011 010 : 1110 1001";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_383') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISUB";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- ST(0) - 32-bit memory";
            $res->{encoding} = "11011 010 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_384') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISUBR";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- 32-bit memory ? ST(0)";
            $res->{encoding} = "11011 010 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_385') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIADD";
            $res->{des} = "Add Integer";
            $res->{subdes} = "ST(0) <- ST(0) + 32-bit memory";
            $res->{encoding} = "11011 010 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_386') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_387';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_388';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_387') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "register1 with register2";
            $res->{encoding} = "0011 100w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_388') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "CMP";
            $res->{des} = "Compare Two Operands";
            $res->{subdes} = "memory with register";
            $res->{encoding} = "0011 100w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_389') {

            $state = 'S_390';
        } elsif ($state eq 'S_390') {
            # Get 16-bit immediate data:
            my @bytes = readbytes(2);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "RET";
            $res->{des} = "Return from Procedure (to same segment)";
            $res->{subdes} = "adding immediate to SP";
            $res->{encoding} = "1100 0010 : 16-bit displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_391') {

            $res->{ins} = "INT";
            $res->{des} = "Single-Step Interrupt 3";
            $res->{encoding} = "1100 1100";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_392') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_396';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_393';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_394';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_397';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_400';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_395';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_398';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_405';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_399';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_403';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_406';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_401';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_404';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_402';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_393') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "RCR";
            $res->{des} = "Rotate thru Carry Right";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 011 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_394') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "ROR";
            $res->{des} = "Rotate Right";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 001 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_395') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SAR";
            $res->{des} = "Shift Arithmetic Right";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 111 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_396') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "RCR";
            $res->{des} = "Rotate thru Carry Right";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 011 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_397') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "ROR";
            $res->{des} = "Rotate Right";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 001 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_398') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "ROL";
            $res->{des} = "Rotate Left";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_399') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SHR";
            $res->{des} = "Shift Right";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 101 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_400') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SAR";
            $res->{des} = "Shift Arithmetic Right";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 111 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_401') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "RCL";
            $res->{des} = "Rotate thru Carry Left";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 010 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_402') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SHL";
            $res->{des} = "Shift Left";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 100 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_403') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SHR";
            $res->{des} = "Shift Right";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 101 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_404') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SHL";
            $res->{des} = "Shift Left";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 100 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_405') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "ROL";
            $res->{des} = "Rotate Left";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "1101 001w : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_406') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "RCL";
            $res->{des} = "Rotate thru Carry Left";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "1101 001w : 11 010 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_407') {
            # Get the sreg2 field from the current byte:
            $res->{'sreg2'} = slice($byte, 4, 3);

            $res->{ins} = "PUSH";
            $res->{des} = "Push Segment Register onto the Stack";
            $res->{subdes} = "segment register CS,DS,ES,SS";
            $res->{encoding} = "000 sreg2 110";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_408') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_409';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_410';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_409') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0010 001w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_410') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0010 001w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_411') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_412';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_413';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_412') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "1000 101w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_413') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "memory to reg";
            $res->{encoding} = "1000 101w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_414') {

            $res->{ins} = "RET";
            $res->{des} = "Return from Procedure (to same segment)";
            $res->{subdes} = "no argument";
            $res->{encoding} = "1100 0011";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_415') {

            $state = 'S_416';
        } elsif ($state eq 'S_416') {
            # Get full immediate data:
            my $len = $res->{bits16} ? 2 : 4;
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "CALL";
            $res->{des} = "Call Procedure (in same segment)";
            $res->{subdes} = "direct";
            $res->{encoding} = "1110 1000 : full displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_417') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_418';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_419';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_418') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0010 000w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_419') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "AND";
            $res->{des} = "Logical AND";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0010 000w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_420') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_425';
            } elsif ($byte =~ m/^11011001$/o) {
                $state = 'S_426';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_421';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_427';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_422';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_433';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_423';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_428';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_424';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_434';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_429';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_432';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_430';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_431';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_435';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_421') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FICOMP";
            $res->{des} = "Compare Integer and Pop";
            $res->{subdes} = "16-bit memory";
            $res->{encoding} = "11011 110 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_422') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIDIV";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- ST(0) / 16-bit memory";
            $res->{encoding} = "11011 110 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_423') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIDIVR";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- 16-bit memory / ST(0)";
            $res->{encoding} = "11011 110 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_424') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIMUL";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- ST(0) * 16-bit memory";
            $res->{encoding} = "11011 110 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_425') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FICOM";
            $res->{des} = "Compare Integer";
            $res->{subdes} = "16-bit memory";
            $res->{encoding} = "11011 110 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_426') {

            $res->{ins} = "FCOMPP";
            $res->{des} = "Compare Real and Pop Twice";
            $res->{encoding} = "11011 110 : 11 011 001";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_427') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FDIVRP";
            $res->{des} = "Reverse Divide and Pop";
            $res->{subdes} = "ST(0) <- ST(i) / ST(0)";
            $res->{encoding} = "11011 110 : 1111 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_428') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FMULP";
            $res->{des} = "Multiply";
            $res->{subdes} = "ST(i) <- ST(0) * ST(i)";
            $res->{encoding} = "11011 110 : 1100 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_429') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISUB";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- ST(0) - 16-bit memory";
            $res->{encoding} = "11011 110 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_430') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISUBR";
            $res->{des} = "";
            $res->{subdes} = "ST(0) <- 16-bit memory ? ST(0)";
            $res->{encoding} = "11011 110 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_431') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FADDP";
            $res->{des} = "Add and Pop";
            $res->{subdes} = "ST(0) <- ST(0) + ST(i)";
            $res->{encoding} = "11011 110 : 11 000 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_432') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSUBP";
            $res->{des} = "Subtract and Pop";
            $res->{subdes} = "ST(0) <- ST(0) - ST(i)";
            $res->{encoding} = "11011 110 : 1110 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_433') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FDIVP";
            $res->{des} = "Divide and Pop";
            $res->{subdes} = "ST(0) <- ST(0) / ST(i)";
            $res->{encoding} = "11011 110 : 1111 1 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_434') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FSUBRP";
            $res->{des} = "Reverse Subtract and Pop";
            $res->{subdes} = "ST(i) <- ST(i) - ST(0)";
            $res->{encoding} = "11011 110 : 1110 0 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_435') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIADD";
            $res->{des} = "Add Integer";
            $res->{subdes} = "ST(0) <- ST(0) + 16-bit memory";
            $res->{encoding} = "11011 110 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_436') {

            $res->{ins} = "DAS";
            $res->{des} = "Decimal Adjust AL after Subtraction";
            $res->{encoding} = "0010 1111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_437') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^00110001$/o) {
                $state = 'S_438';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_439';
            } elsif ($byte =~ m/^00110011$/o) {
                $state = 'S_440';
            } elsif ($byte =~ m/^10101101$/o) {
                $state = 'S_441';
            } elsif ($byte =~ m/^00000011$/o) {
                $state = 'S_444';
            } elsif ($byte =~ m/^00000000$/o) {
                $state = 'S_447';
            } elsif ($byte =~ m/^00000010$/o) {
                $state = 'S_460';
            } elsif ($byte =~ m/^10111011$/o) {
                $state = 'S_463';
            } elsif ($byte =~ m/^10110101$/o) {
                $state = 'S_466';
            } elsif ($byte =~ m/^10100101$/o) {
                $state = 'S_468';
            } elsif ($byte =~ m/^10111100$/o) {
                $state = 'S_471';
            } elsif ($byte =~ m/^00100000$/o) {
                $state = 'S_474';
            } elsif ($byte =~ m/^10111101$/o) {
                $state = 'S_476';
            } elsif ($byte =~ m/^10100010$/o) {
                $state = 'S_479';
            } elsif ($byte =~ m/^00100010$/o) {
                $state = 'S_480';
            } elsif ($byte =~ m/^00000110$/o) {
                $state = 'S_482';
            } elsif ($byte =~ m/^10100100$/o) {
                $state = 'S_483';
            } elsif ($byte =~ m/^10101010$/o) {
                $state = 'S_488';
            } elsif ($byte =~ m/^10100011$/o) {
                $state = 'S_489';
            } elsif ($byte =~ m/^1011000[01]$/o) {
                $state = 'S_492';
            } elsif ($byte =~ m/^1000[01][01][01][01]$/o) {
                $state = 'S_495';
            } elsif ($byte =~ m/^10110100$/o) {
                $state = 'S_497';
            } elsif ($byte =~ m/^00001000$/o) {
                $state = 'S_499';
            } elsif ($byte =~ m/^10101100$/o) {
                $state = 'S_500';
            } elsif ($byte =~ m/^00100011$/o) {
                $state = 'S_505';
            } elsif ($byte =~ m/^10100001$/o) {
                $state = 'S_507';
            } elsif ($byte =~ m/^10101011$/o) {
                $state = 'S_508';
            } elsif ($byte =~ m/^10101000$/o) {
                $state = 'S_511';
            } elsif ($byte =~ m/^10111010$/o) {
                $state = 'S_512';
            } elsif ($byte =~ m/^00001011$/o) {
                $state = 'S_529';
            } elsif ($byte =~ m/^00100001$/o) {
                $state = 'S_530';
            } elsif ($byte =~ m/^1011111[01]$/o) {
                $state = 'S_532';
            } elsif ($byte =~ m/^10101001$/o) {
                $state = 'S_535';
            } elsif ($byte =~ m/^00000001$/o) {
                $state = 'S_536';
            } elsif ($byte =~ m/^10101111$/o) {
                $state = 'S_546';
            } elsif ($byte =~ m/^1011011[01]$/o) {
                $state = 'S_549';
            } elsif ($byte =~ m/^10100000$/o) {
                $state = 'S_552';
            } elsif ($byte =~ m/^00110000$/o) {
                $state = 'S_553';
            } elsif ($byte =~ m/^1001[01][01][01][01]$/o) {
                $state = 'S_554';
            } elsif ($byte =~ m/^00110010$/o) {
                $state = 'S_557';
            } elsif ($byte =~ m/^10110010$/o) {
                $state = 'S_558';
            } elsif ($byte =~ m/^00001001$/o) {
                $state = 'S_560';
            } elsif ($byte =~ m/^1100000[01]$/o) {
                $state = 'S_561';
            } elsif ($byte =~ m/^10110011$/o) {
                $state = 'S_564';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_438') {

            $res->{ins} = "RDTSC";
            $res->{des} = "Read Time-Stamp Counter";
            $res->{encoding} = "0000 1111 : 0011 0001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_439') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "BSWAP";
            $res->{des} = "Byte Swap";
            $res->{encoding} = "0000 1111 : 1100 1 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_440') {

            $res->{ins} = "RDPMC";
            $res->{des} = "Read Performance Monitoring Counters";
            $res->{encoding} = "0000 1111 : 0011 0011";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_441') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_443';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_442';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_442') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "SHRD";
            $res->{des} = "Double Precision Shift Right";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "0000 1111 : 1010 1101 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_443') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "SHRD";
            $res->{des} = "Double Precision Shift Right";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "0000 1111 : 1010 1101 : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_444') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_446';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_445';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_445') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LSL";
            $res->{des} = "Load Segment Limit";
            $res->{subdes} = "from memory";
            $res->{encoding} = "0000 1111 : 0000 0011 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_446') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "LSL";
            $res->{des} = "Load Segment Limit";
            $res->{subdes} = "from register";
            $res->{encoding} = "0000 1111 : 0000 0011 : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_447') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_453';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_448';
            } elsif ($byte =~ m/^11011[01][01][01]$/o) {
                $state = 'S_449';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_451';
            } elsif ($byte =~ m/^11001[01][01][01]$/o) {
                $state = 'S_454';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_450';
            } elsif ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_452';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_457';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_456';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_455';
            } elsif ($byte =~ m/^11010[01][01][01]$/o) {
                $state = 'S_458';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_459';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_448') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "VERW";
            $res->{des} = "Verify a Segment for Writing";
            $res->{subdes} = "memory";
            $res->{encoding} = "0000 1111 : 0000 0000 : mod 101 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_449') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "LTR";
            $res->{des} = "Load Task Register";
            $res->{subdes} = "from register";
            $res->{encoding} = "0000 1111 : 0000 0000 : 11 011 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_450') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "STR";
            $res->{des} = "Store Task Register";
            $res->{subdes} = "to memory";
            $res->{encoding} = "0000 1111 : 0000 0000 : mod 001 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_451') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "LTR";
            $res->{des} = "Load Task Register";
            $res->{subdes} = "from memory";
            $res->{encoding} = "0000 1111 : 0000 0000 : mod 011 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_452') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SLDT";
            $res->{des} = "Store Local Descriptor Table Register";
            $res->{subdes} = "to register";
            $res->{encoding} = "0000 1111 : 0000 0000 : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_453') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "VERW";
            $res->{des} = "Verify a Segment for Writing";
            $res->{subdes} = "register";
            $res->{encoding} = "0000 1111 : 0000 0000 : 11 101 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_454') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "STR";
            $res->{des} = "Store Task Register";
            $res->{subdes} = "to register";
            $res->{encoding} = "0000 1111 : 0000 0000 : 11 001 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_455') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "VERR";
            $res->{des} = "Verify a Segment for Reading";
            $res->{subdes} = "memory";
            $res->{encoding} = "0000 1111 : 0000 0000 : mod 100 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_456') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "VERR";
            $res->{des} = "Verify a Segment for Reading";
            $res->{subdes} = "register";
            $res->{encoding} = "0000 1111 : 0000 0000 : 11 100 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_457') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SLDT";
            $res->{des} = "Store Local Descriptor Table Register";
            $res->{subdes} = "to memory";
            $res->{encoding} = "0000 1111 : 0000 0000 : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_458') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "LLDT";
            $res->{des} = "Load Local Descriptor Table Register";
            $res->{subdes} = "LDTR from register";
            $res->{encoding} = "0000 1111 : 0000 0000 : 11 010 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_459') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "LLDT";
            $res->{des} = "Load Local Descriptor Table Register";
            $res->{subdes} = "LDTR from memory";
            $res->{encoding} = "0000 1111 : 0000 0000 : mod 010 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_460') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_461';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_462';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_461') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "LAR";
            $res->{des} = "Load Access Rights Byte";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0000 1111 : 0000 0010 : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_462') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LAR";
            $res->{des} = "Load Access Rights Byte";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0000 1111 : 0000 0010 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_463') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_465';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_464';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_464') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BTC";
            $res->{des} = "Bit Test and Complement";
            $res->{subdes} = "memory, reg";
            $res->{encoding} = "0000 1111 : 1011 1011 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_465') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "BTC";
            $res->{des} = "Bit Test and Complement";
            $res->{subdes} = "register1, register2";
            $res->{encoding} = "0000 1111 : 1011 1011 : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_466') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_467';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_467') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LGS";
            $res->{des} = "Load Pointer to GS";
            $res->{encoding} = "0000 1111 : 1011 0101 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_468') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_470';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_469';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_469') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "SHLD";
            $res->{des} = "Double Precision Shift Left";
            $res->{subdes} = "memory by CL";
            $res->{encoding} = "0000 1111 : 1010 0101 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_470') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "SHLD";
            $res->{des} = "Double Precision Shift Left";
            $res->{subdes} = "register by CL";
            $res->{encoding} = "0000 1111 : 1010 0101 : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_471') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_472';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_473';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_472') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "BSF";
            $res->{des} = "Bit Scan Forward";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 1111 : 1011 1100 : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_473') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BSF";
            $res->{des} = "Bit Scan Forward";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0000 1111 : 1011 1100 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_474') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_475';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_475') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);
            # Get the eee field from the current byte:
            $res->{'eee'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Control Registers";
            $res->{subdes} = "register from CR0-CR4";
            $res->{encoding} = "0000 1111 : 0010 0000 : 11 eee reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_476') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_477';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_478';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_477') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "BSR";
            $res->{des} = "Bit Scan Reverse";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 1111 : 1011 1101 : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_478') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BSR";
            $res->{des} = "Bit Scan Reverse";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0000 1111 : 1011 1101 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_479') {

            $res->{ins} = "CPUID";
            $res->{des} = "CPU Identification";
            $res->{encoding} = "0000 1111 : 1010 0010";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_480') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_481';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_481') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);
            # Get the eee field from the current byte:
            $res->{'eee'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Control Registers";
            $res->{subdes} = "CR0-CR4 from register";
            $res->{encoding} = "0000 1111 : 0010 0010 : 11 eee reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_482') {

            $res->{ins} = "CLTS";
            $res->{des} = "Clear Task-Switched Flag in CR0";
            $res->{encoding} = "0000 1111 : 0000 0110";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_483') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_486';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_484';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_484') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $state = 'S_485';
        } elsif ($state eq 'S_485') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHLD";
            $res->{des} = "Double Precision Shift Left";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "0000 1111 : 1010 0100 : mod reg r/m : imm8";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_486') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $state = 'S_487';
        } elsif ($state eq 'S_487') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHLD";
            $res->{des} = "Double Precision Shift Left";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "0000 1111 : 1010 0100 : 11 reg2 reg1 : imm8";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_488') {

            $res->{ins} = "RSM";
            $res->{des} = "Resume from System Management Mode";
            $res->{encoding} = "0000 1111 : 1010 1010";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_489') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_491';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_490';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_490') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BT";
            $res->{des} = "Bit Test";
            $res->{subdes} = "memory, reg";
            $res->{encoding} = "0000 1111 : 1010 0011 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_491') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "BT";
            $res->{des} = "Bit Test";
            $res->{subdes} = "register1, register2";
            $res->{encoding} = "0000 1111 : 1010 0011 : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_492') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_494';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_493';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_493') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "CMPXCHG";
            $res->{des} = "Compare and Exchange";
            $res->{subdes} = "memory, register";
            $res->{encoding} = "0000 1111 : 1011 000w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_494') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "CMPXCHG";
            $res->{des} = "Compare and Exchange";
            $res->{subdes} = "register1, register2";
            $res->{encoding} = "0000 1111 : 1011 000w : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_495') {
            # Get the tttn field from the current byte:
            $res->{'tttn'} = slice($byte, 3, 0);

            $state = 'S_496';
        } elsif ($state eq 'S_496') {
            # Get full immediate data:
            my $len = $res->{bits16} ? 2 : 4;
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "Jcc";
            $res->{des} = "Jump if Condition is Met";
            $res->{subdes} = "full displacement";
            $res->{encoding} = "0000 1111 : 1000 tttn : full displacement";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_497') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_498';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_498') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LFS";
            $res->{des} = "Load Pointer to FS";
            $res->{encoding} = "0000 1111 : 1011 0100 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_499') {

            $res->{ins} = "INVD";
            $res->{des} = "Invalidate Cache";
            $res->{encoding} = "0000 1111 : 0000 1000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_500') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_503';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_501';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_501') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $state = 'S_502';
        } elsif ($state eq 'S_502') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHRD";
            $res->{des} = "Double Precision Shift Right";
            $res->{subdes} = "memory by immediate count";
            $res->{encoding} = "0000 1111 : 1010 1100 : mod reg r/m : imm8";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_503') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $state = 'S_504';
        } elsif ($state eq 'S_504') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "SHRD";
            $res->{des} = "Double Precision Shift Right";
            $res->{subdes} = "register by immediate count";
            $res->{encoding} = "0000 1111 : 1010 1100 : 11 reg2 reg1 : imm8";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_505') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_506';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_506') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);
            # Get the eee field from the current byte:
            $res->{'eee'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Debug Registers";
            $res->{subdes} = "DR0-DR7 from register";
            $res->{encoding} = "0000 1111 : 0010 0011 : 11 eee reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_507') {

            $res->{ins} = "POP";
            $res->{des} = "Pop a Segment Register from the Stack (Note: CS cannot be sreg2 in this usage.)";
            $res->{subdes} = "segment register FS";
            $res->{encoding} = "0000 1111: 10 100 001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_508') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_510';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_509';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_509') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BTS";
            $res->{des} = "Bit Test and Set";
            $res->{subdes} = "memory, reg";
            $res->{encoding} = "0000 1111 : 1010 1011 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_510') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "BTS";
            $res->{des} = "Bit Test and Set";
            $res->{subdes} = "register1, register2";
            $res->{encoding} = "0000 1111 : 1010 1011 : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_511') {

            $res->{ins} = "PUSH";
            $res->{des} = "Push Segment Register onto the Stack";
            $res->{subdes} = "segment register GS";
            $res->{encoding} = "0000 1111: 10 101 000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_512') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_517';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_513';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_521';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_515';
            } elsif ($byte =~ m/^11111[01][01][01]$/o) {
                $state = 'S_519';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_527';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_525';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_523';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_513') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_514';
        } elsif ($state eq 'S_514') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BTS";
            $res->{des} = "Bit Test and Set";
            $res->{subdes} = "memory, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : mod 101 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_515') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_516';
        } elsif ($state eq 'S_516') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BTR";
            $res->{des} = "Bit Test and Reset";
            $res->{subdes} = "memory, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : mod 110 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_517') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_518';
        } elsif ($state eq 'S_518') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BTS";
            $res->{des} = "Bit Test and Set";
            $res->{subdes} = "register, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : 11 101 reg: imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_519') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_520';
        } elsif ($state eq 'S_520') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BTC";
            $res->{des} = "Bit Test and Complement";
            $res->{subdes} = "register, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : 11 111 reg: imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_521') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_522';
        } elsif ($state eq 'S_522') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BTR";
            $res->{des} = "Bit Test and Reset";
            $res->{subdes} = "register, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : 11 110 reg: imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_523') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_524';
        } elsif ($state eq 'S_524') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BT";
            $res->{des} = "Bit Test";
            $res->{subdes} = "memory, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : mod 100 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_525') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $state = 'S_526';
        } elsif ($state eq 'S_526') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BT";
            $res->{des} = "Bit Test";
            $res->{subdes} = "register, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : 11 100 reg: imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_527') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $state = 'S_528';
        } elsif ($state eq 'S_528') {
            # Get 8-bit immediate data:
            my @bytes = readbytes(1);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "BTC";
            $res->{des} = "Bit Test and Complement";
            $res->{subdes} = "memory, immediate";
            $res->{encoding} = "0000 1111 : 1011 1010 : mod 111 r/m : imm8 data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_529') {

            $res->{ins} = "UD2";
            $res->{des} = "Undefined instruction";
            $res->{encoding} = "0000 1111 : 0000 1011";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_530') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_531';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_531') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);
            # Get the eee field from the current byte:
            $res->{'eee'} = slice($byte, 5, 3);

            $res->{ins} = "MOV";
            $res->{des} = "Move to/from Debug Registers";
            $res->{subdes} = "register from DR0-DR7";
            $res->{encoding} = "0000 1111 : 0010 0001 : 11 eee reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_532') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_533';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_534';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_533') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "MOVSX";
            $res->{des} = "Move with Sign-Extend";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 1111 : 1011 111w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_534') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "MOVSX";
            $res->{des} = "Move with Sign-Extend";
            $res->{subdes} = "memory to reg";
            $res->{encoding} = "0000 1111 : 1011 111w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_535') {

            $res->{ins} = "POP";
            $res->{des} = "Pop a Segment Register from the Stack (Note: CS cannot be sreg2 in this usage.)";
            $res->{subdes} = "segment register GS";
            $res->{encoding} = "0000 1111: 10 101 001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_536') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_537';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_538';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_543';
            } elsif ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_544';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_545';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_540';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_539';
            } elsif ($byte =~ m/^11100[01][01][01]$/o) {
                $state = 'S_542';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_541';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_537') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "LGDT";
            $res->{des} = "Load Global Descriptor Table Register";
            $res->{encoding} = "0000 1111 : 0000 0001 : modA 010 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_538') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SGDT";
            $res->{des} = "Store Global Descriptor Table Register";
            $res->{encoding} = "0000 1111 : 0000 0001 : modA 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_539') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "LMSW";
            $res->{des} = "Load Machine Status Word";
            $res->{subdes} = "from memory";
            $res->{encoding} = "0000 1111 : 0000 0001 : mod 110 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_540') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "LMSW";
            $res->{des} = "Load Machine Status Word";
            $res->{subdes} = "from register";
            $res->{encoding} = "0000 1111 : 0000 0001 : 11 110 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_541') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SMSW";
            $res->{des} = "Store Machine Status Word";
            $res->{subdes} = "to memory";
            $res->{encoding} = "0000 1111 : 0000 0001 : mod 100 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_542') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SMSW";
            $res->{des} = "Store Machine Status Word";
            $res->{subdes} = "to register";
            $res->{encoding} = "0000 1111 : 0000 0001 : 11 100 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_543') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SIDT";
            $res->{des} = "Store Interrupt Descriptor Table Register";
            $res->{encoding} = "0000 1111 : 0000 0001 : modA 001 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_544') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "LIDT";
            $res->{des} = "Load Interrupt Descriptor Table Register";
            $res->{encoding} = "0000 1111 : 0000 0001 : modA 011 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_545') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "INVLPG";
            $res->{des} = "Invalidate TLB Entry";
            $res->{encoding} = "0000 1111 : 0000 0001 : mod 111 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_546') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_547';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_548';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_547') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "IMUL";
            $res->{des} = "Signed Multiply";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 1111 : 1010 1111 : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_548') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "IMUL";
            $res->{des} = "Signed Multiply";
            $res->{subdes} = "register with memory";
            $res->{encoding} = "0000 1111 : 1010 1111 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_549') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_550';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_551';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_550') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "MOVZX";
            $res->{des} = "Move with Zero-Extend";
            $res->{subdes} = "register2 to register1";
            $res->{encoding} = "0000 1111 : 1011 011w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_551') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "MOVZX";
            $res->{des} = "Move with Zero-Extend";
            $res->{subdes} = "memory to register";
            $res->{encoding} = "0000 1111 : 1011 011w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_552') {

            $res->{ins} = "PUSH";
            $res->{des} = "Push Segment Register onto the Stack";
            $res->{subdes} = "segment register FS";
            $res->{encoding} = "0000 1111: 10 100 000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_553') {

            $res->{ins} = "WRMSR";
            $res->{des} = "Write to Model-Specific Register";
            $res->{encoding} = "0000 1111 : 0011 0000";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_554') {
            # Get the tttn field from the current byte:
            $res->{'tttn'} = slice($byte, 3, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11000[01][01][01]$/o) {
                $state = 'S_555';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_556';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_555') {
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 2, 0);

            $res->{ins} = "SETcc";
            $res->{des} = "Byte Set on Condition";
            $res->{subdes} = "register";
            $res->{encoding} = "0000 1111 : 1001 tttn : 11 000 reg";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_556') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "SETcc";
            $res->{des} = "Byte Set on Condition";
            $res->{subdes} = "memory";
            $res->{encoding} = "0000 1111 : 1001 tttn : mod 000 r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_557') {

            $res->{ins} = "RDMSR";
            $res->{des} = "Read from Model-Specific Register";
            $res->{encoding} = "0000 1111 : 0011 0010";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_558') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_559';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_559') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "LSS";
            $res->{des} = "Load Pointer to SS";
            $res->{encoding} = "0000 1111 : 1011 0010 : modA reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_560') {

            $res->{ins} = "WBINVD";
            $res->{des} = "Writeback and Invalidate Data Cache";
            $res->{encoding} = "0000 1111 : 0000 1001";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_561') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_563';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_562';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_562') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "XADD";
            $res->{des} = "Exchange and Add";
            $res->{subdes} = "memory, reg";
            $res->{encoding} = "0000 1111 : 1100 000w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_563') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "XADD";
            $res->{des} = "Exchange and Add";
            $res->{subdes} = "register1, register2";
            $res->{encoding} = "0000 1111 : 1100 000w : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_564') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_566';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_565';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_565') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "BTR";
            $res->{des} = "Bit Test and Reset";
            $res->{subdes} = "memory, reg";
            $res->{encoding} = "0000 1111 : 1011 0011 : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_566') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 2, 0);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 5, 3);

            $res->{ins} = "BTR";
            $res->{des} = "Bit Test and Reset";
            $res->{subdes} = "register1, register2";
            $res->{encoding} = "0000 1111 : 1011 0011 : 11 reg2 reg1";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_567') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^11[01][01][01][01][01][01]$/o) {
                $state = 'S_568';
            } elsif ($byte =~ m/^[01][01][01][01][01][01][01][01]$/o) {
                $state = 'S_569';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_568') {
            # Get the reg1 field from the current byte:
            $res->{'reg1'} = slice($byte, 5, 3);
            # Get the reg2 field from the current byte:
            $res->{'reg2'} = slice($byte, 2, 0);

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "register1 to register2";
            $res->{encoding} = "0001 100w : 11 reg1 reg2";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_569') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            # Get the reg field from the current byte:
            $res->{'reg'} = slice($byte, 5, 3);

            $res->{ins} = "SBB";
            $res->{des} = "Integer Subtraction with Borrow";
            $res->{subdes} = "register to memory";
            $res->{encoding} = "0001 100w : mod reg r/m";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_570') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_571';
        } elsif ($state eq 'S_571') {
            # Get 32-bit immediate data:
            my @bytes = readbytes(4);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "MOV";
            $res->{des} = "Move Data";
            $res->{subdes} = "AL, AX, or EAX to memory";
            $res->{encoding} = "1010 001w : disp32";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_572') {

            $res->{ins} = "POP";
            $res->{des} = "Pop a Segment Register from the Stack (Note: CS cannot be sreg2 in this usage.)";
            $res->{subdes} = "segment register SS";
            $res->{encoding} = "000 10 111";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_573') {

            $state = 'S_574';
        } elsif ($state eq 'S_574') {
            # Get immediate data:
            my $len = $res->{bits16} ? 4 : 6;
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "CALL";
            $res->{des} = "Call Procedure (in other segment)";
            $res->{subdes} = "direct";
            $res->{encoding} = "1001 1010 : unsigned full offset, selector";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_575') {
            # Get the w field from the current byte:
            $res->{'w'} = slice($byte, 0);

            $state = 'S_576';
        } elsif ($state eq 'S_576') {
            # Get immediate data:
            my $len = get_imm_len($res->{s}, $res->{w}, $res->{bits16});
            my @bytes = readbytes($len);
            unless (@bytes) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }
            $res->{imm} = [bin2hex @bytes];

            $res->{ins} = "ADC";
            $res->{des} = "ADD with Carry";
            $res->{subdes} = "immediate to AL, AX, or EAX";
            $res->{encoding} = "0001 010w : immediate data";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_577') {

            $res->{ins} = "INTO";
            $res->{des} = "Interrupt 4 on Overflow";
            $res->{encoding} = "1100 1110";
            $res->{ins_set} = "General";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_578') {
            $byte = readbytes(1);
            unless (defined $byte) { # Check the unexpected end of input
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            if ($byte =~ m/^[01][01]011[01][01][01]$/o) {
                $state = 'S_579';
            } elsif ($byte =~ m/^[01][01]111[01][01][01]$/o) {
                $state = 'S_581';
            } elsif ($byte =~ m/^[01][01]001[01][01][01]$/o) {
                $state = 'S_583';
            } elsif ($byte =~ m/^[01][01]010[01][01][01]$/o) {
                $state = 'S_586';
            } elsif ($byte =~ m/^[01][01]000[01][01][01]$/o) {
                $state = 'S_589';
            } elsif ($byte =~ m/^11110[01][01][01]$/o) {
                $state = 'S_582';
            } elsif ($byte =~ m/^[01][01]110[01][01][01]$/o) {
                $state = 'S_580';
            } elsif ($byte =~ m/^11100000$/o) {
                $state = 'S_584';
            } elsif ($byte =~ m/^[01][01]100[01][01][01]$/o) {
                $state = 'S_587';
            } elsif ($byte =~ m/^11101[01][01][01]$/o) {
                $state = 'S_585';
            } elsif ($byte =~ m/^[01][01]101[01][01][01]$/o) {
                $state = 'S_588';
            } else {
                $state = 'S_SYN_ERROR';
            }
        } elsif ($state eq 'S_579') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISTP";
            $res->{des} = "Store Integer and Pop";
            $res->{subdes} = "16-bit memory";
            $res->{encoding} = "11011 111 : mod 011 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_580') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FBSTP";
            $res->{des} = "Store Binary Coded Decimal and Pop";
            $res->{encoding} = "11011 111 : mod 110 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_581') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISTP";
            $res->{des} = "Store Integer and Pop";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 111 : mod 111 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_582') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FCOMIP";
            $res->{des} = "Compare Real, Set EFLAGS, and Pop";
            $res->{encoding} = "11011 111 : 11 110 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_583') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FISTTP";
            $res->{des} = "Store Integer with Truncation";
            $res->{subdes} = "16-bit memory";
            $res->{encoding} = "11011 111 : mod 001 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_584') {

            $res->{ins} = "FNSTSW";
            $res->{des} = "Store Status Word into AX";
            $res->{encoding} = "11011 111 : 1110 0000";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_585') {
            # Get the ST_i field from the current byte:
            $res->{'ST_i'} = slice($byte, 2, 0);

            $res->{ins} = "FUCOMIP";
            $res->{des} = "Unorderd Compare Real, Set EFLAGS, and Pop";
            $res->{encoding} = "11011 111 : 11 101 ST(i)";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_586') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FIST";
            $res->{des} = "Store Integer";
            $res->{subdes} = "16-bit memory";
            $res->{encoding} = "11011 111 : mod 010 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_587') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FBLD";
            $res->{des} = "Load Binary Coded Decimal";
            $res->{encoding} = "11011 111 : mod 100 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_588') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FILD";
            $res->{des} = "Load Integer";
            $res->{subdes} = "64-bit memory";
            $res->{encoding} = "11011 111 : mod 101 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_589') {
            # Process the current ModR/M byte:
            unless (process_ModRM($res, $byte)) {
                $state = $token_error ? 'S_SYN_ERROR' : 'S_END_ERROR';
                next;
            }

            $res->{ins} = "FILD";
            $res->{des} = "Load Integer";
            $res->{subdes} = "16-bit memory";
            $res->{encoding} = "11011 111 : mod 000 r/m";
            $res->{ins_set} = "FPU";
            $res->{bytes} = [@oldbytes];
            close($Idu::source) if @_;
            return $res;
        } elsif ($state eq 'S_SYN_ERROR') { # Syntax error
            $error = "syntax error ($.) - unexpected byte \"$token\": @oldbytes";
            last;
        } elsif ($state eq 'S_END_ERROR') {
            $error = "syntax error ($.) - unexpected end of input: @oldbytes";
            last;
        } else {
            $error = "core error ($.) - unknown state $state reached: @oldbytes";
            last;
        }
    }
    close($Idu::source) if @_;
    return undef;
}

1;
