#: Idu.t
#: Test Idu.pm
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-24 2005-08-20

use strict;
use warnings;

#use Data::Dumper;
use Test::More tests => 10;
BEGIN { use_ok('inc::Idu'); }

{
# Test sub Idu::readbytes
my $buf = " 00000101 6b  00 66 11 10001011 fa ";
ok open($Idu::source, '<', \$buf);
ok eq_array([Idu::readbytes(2)], [qw(00000101 01101011)]);
ok eq_array(\@Idu::oldbytes, [qw(00000101 6b)]);
#ok eq_array([Idu::readbytes(1)], [qw(00000000)]);
is Idu::readbytes(1), '00000000';
ok eq_array(\@Idu::oldbytes, [qw(00000101 6b 00)]);
#ok eq_array([Idu::readbytes], [qw(01100110)]);
is Idu::readbytes, '01100110';
ok eq_array(\@Idu::oldbytes, [qw(00000101 6b 00 66)]);
my @bytes = Idu::readbytes(3);
#warn Data::Dumper->Dump([\@bytes], ['bytes']);
ok eq_array(\@bytes, [qw(00010001 10001011 11111010)]);
ok eq_array(\@Idu::oldbytes, [qw(00000101 6b 00 66 11 10001011 fa)]);
close $Idu::source;
undef @Idu::oldbytes;
}
