#: Ndisasm.pm
#: ndisasmw module(Disassembler shipped with NASM Windows version)
#: Salent v0.12
#: Copyright (c) 2005 Sal Zhong
#: 2005-08-26  2005-08-26

package inc::Ndisasm;

use strict;
use warnings;
require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(disasm);

my $error;

my $hextmp = 'tmp.hex';
my $bintmp = 'tmp.bin';

sub disasm {
    shift if @_ > 1;
    $| = 1;
    $_ = shift;

    my $hexd = qr/[0-9a-f]/i;
    if (/^\s*$/) {
        $error = "error: Empty input";
        return undef;
    }
    if (/^\s*(?:$hexd{2}\s+)*$hexd{2}\s*$/i){
          my $hexbyte = $_;
          my $in;
          unless (open $in, ">$hextmp") {
             $error = "error: Cannot open $hextmp for writing: $!";
             return undef;
          }
          print $in $hexbyte;
          close $in;

          unless (system("hex2bin $hextmp $bintmp") == 0) {
              $error = "error: Cannot spawn hex2bin";
              return undef;
          }
          unless (open $in, "ndisasmw -b 32 $bintmp |") {
             $error = "Cannot spawn ndisasmw: $!";
             return undef;
          }
          my $res = <$in>;
          close $in;

          if ($res =~ m/^\s*$hexd+\s+$hexd+\s+(.*\S)\s*$/) {
              undef $error;
              return $1;
          } else {
              $error = "ndisasmw returned invalid result: $res";
              return undef;
          }
      } else {
          $error = "error: Invalid user input.";
          return undef;
      }
}

sub error {
    return $error;
}

END {
      unlink $hextmp;
      unlink $bintmp;
}


1;
