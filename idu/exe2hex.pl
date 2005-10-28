#: exe2hex.pl
#: Export the machine instructions embedded in .exe, .dll,
#:   .obj, and .lib to ASCII hex format, using dumpbin.exe
#:  internally.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-28 2005-07-30

use strict;
use warnings;

my $hexd = qr/[A-F0-9]/i;
@ARGV || die "Usage: exe2hex <infile1> <infile2> ...\n";
foreach (@ARGV) {
    process_file($_);
}

sub process_file {
    my $infile = shift;
    open my $in, "dumpbin /ALL \"$infile\" |" or
        die "Can't invoke dumpbin.exe: $!\n";
    my $state = 0;
    while (<$in>) {
        if (/^\d{8}\s+flags\s*$/i) {
            $state = 1;
        } elsif ($state == 1) {
            if (m/^\s+Code\s*$/i) {
                #warn "Yah!";
                $state = 2;
            } else {
                $state = 0;
            }
        } elsif ($state == 2 && m/^\s+$hexd{8}:\s*((?:$hexd{2} ){1,16})/) {
            my $data = $1;
            $data =~ s/\s+$//o;
            print $data, "\n";
        } else {
            # skip...
        }
    }
    close $in;
}
