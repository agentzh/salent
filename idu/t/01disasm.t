#: 01Disasm.t
#: Test the inc::Disasm module.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-23 2005-08-25

package Disasm;

use strict;
use warnings;

use C::Idu;
use Test::More tests => 110;
BEGIN { use_ok('inc::Disasm'); }

is enc2name('reg', '000'), 'eax';
is enc2name('reg1', '000', {w=>undef}), 'eax';
is enc2name('reg2', '000', {w=>undef,bits16=>undef}), 'eax';
is enc2name('reg', '001'), 'ecx';
is enc2name('reg', '010'), 'edx';
is enc2name('reg', '011'), 'ebx';
is enc2name('reg', '100'), 'esp';
is enc2name('reg', '101'), 'ebp';
is enc2name('reg', '110'), 'esi';
is enc2name('reg', '111'), 'edi';

is enc2name('reg2', '000', {bits16=>1}), 'ax';
is enc2name('reg', '001', {bits16=>1}), 'cx';
is enc2name('reg', '010', {bits16=>1}), 'dx';
is enc2name('reg', '011', {bits16=>1}), 'bx';
is enc2name('reg', '100', {bits16=>1}), 'sp';
is enc2name('reg', '101', {bits16=>1}), 'bp';
is enc2name('reg', '110', {bits16=>1}), 'si';
is enc2name('reg', '111', {bits16=>1}), 'di';

is enc2name('reg2', '000', {w=>1}), 'eax';
is enc2name('reg', '001', {w=>1}), 'ecx';
is enc2name('reg', '010', {w=>1}), 'edx';
is enc2name('reg', '011', {w=>1}), 'ebx';
is enc2name('reg', '100', {w=>1}), 'esp';
is enc2name('reg', '101', {w=>1}), 'ebp';
is enc2name('reg', '110', {w=>1}), 'esi';
is enc2name('reg', '111', {w=>1}), 'edi';

is enc2name('reg2', '000', {bits16=>1,w=>1}), 'ax';
is enc2name('reg', '001', {bits16=>1,w=>1}), 'cx';
is enc2name('reg', '010', {bits16=>1,w=>1}), 'dx';
is enc2name('reg', '011', {bits16=>1,w=>1}), 'bx';
is enc2name('reg', '100', {bits16=>1,w=>1}), 'sp';
is enc2name('reg', '101', {bits16=>1,w=>1}), 'bp';
is enc2name('reg', '110', {bits16=>1,w=>1}), 'si';
is enc2name('reg', '111', {bits16=>1,w=>1}), 'di';

is enc2name('reg1', '000', {w=>0}), 'al';
is enc2name('reg', '001', {w=>0}), 'cl';
is enc2name('reg', '010', {w=>0}), 'dl';
is enc2name('reg', '011', {w=>0}), 'bl';
is enc2name('reg', '100', {w=>0}), 'ah';
is enc2name('reg', '101', {w=>0}), 'ch';
is enc2name('reg', '110', {w=>0}), 'dh';
is enc2name('reg', '111', {w=>0,bits16=>undef}), 'bh';

is enc2name('reg2', '000', {bits16=>1,w=>0}), 'al';
is enc2name('reg', '001', {bits16=>1,w=>0}), 'cl';
is enc2name('reg', '010', {bits16=>1,w=>0}), 'dl';
is enc2name('reg', '011', {bits16=>1,w=>0}), 'bl';
is enc2name('reg', '100', {bits16=>1,w=>0}), 'ah';
is enc2name('reg', '101', {bits16=>1,w=>0}), 'ch';
is enc2name('reg', '110', {bits16=>1,w=>0}), 'dh';
is enc2name('reg', '111', {bits16=>1,w=>0}), 'bh';

is enc2name('sreg2', '00'), 'es';
is enc2name('sreg2', '00', {bits16=>1,w=>0}), 'es';
is enc2name('sreg2', '01'), 'cs';
is enc2name('sreg2', '10'), 'ss';
is enc2name('sreg2', '11'), 'ds';

is enc2name('sreg3', '000'), 'es';
is enc2name('sreg3', '000', {bits16=>1,w=>0}), 'es';
is enc2name('sreg3', '001'), 'cs';
is enc2name('sreg3', '010'), 'ss';
is enc2name('sreg3', '011'), 'ds';
is enc2name('sreg3', '100'), 'fs';
is enc2name('sreg3', '101'), 'gs';
is enc2name('sreg3', '110'), 'segr6';
is enc2name('sreg3', '111'), 'segr7';

is enc2name('tttn', '0000'), 'o';
is enc2name('tttn', '0001'), 'no';
is enc2name('tttn', '0010'), 'c';
is enc2name('tttn', '0111'), 'a';
is enc2name('tttn', '1000'), 's';
is enc2name('tttn', '1001'), 'ns';
is enc2name('tttn', '1110'), 'ng';
is enc2name('tttn', '1111'), 'g';

ok !defined enc2name('eee', '000');
is enc2name('eee', '000', {eee_type=>'CR'}), 'cr0';
is enc2name('eee', '001', {eee_type=>'cr'}), 'cr1';
is enc2name('eee', '010', {eee_type=>'cr'}), 'cr2';
is enc2name('eee', '011', {eee_type=>'cr'}), 'cr3';
is enc2name('eee', '100', {eee_type=>'cr'}), 'cr4';
is enc2name('eee', '101', {eee_type=>'cr'}), 'cr5';
is enc2name('eee', '110', {eee_type=>'cr'}), 'cr6';
is enc2name('eee', '111', {eee_type=>'cr'}), 'cr7';

ok !defined enc2name('eee', '011');
is enc2name('eee', '000', {eee_type=>'dr'}), 'dr0';
is enc2name('eee', '001', {eee_type=>'dr'}), 'dr1';
is enc2name('eee', '010', {eee_type=>'dr'}), 'dr2';
is enc2name('eee', '011', {eee_type=>'dr'}), 'dr3';
is enc2name('eee', '100', {eee_type=>'dr'}), 'dr4';
is enc2name('eee', '101', {eee_type=>'dr'}), 'dr5';
is enc2name('eee', '110', {eee_type=>'dr'}), 'dr6';
is enc2name('eee', '111', {eee_type=>'dr'}), 'dr7';

is signed('0xff'), '-0x1';
is signed('ff'), '-0x1';
is signed('0x53'), '+0x53';
is signed('53'), '+0x53';

# add ebx,[edi] - 0000 001w : mod reg r/m
my $mac = '03 1F';
my $res = Idu->decode($mac);
is enc2name('reg', $res->{reg}, $res), 'ebx';
is enc2name('reg', $res->{rm}, $res), 'edi';
is gen_mem($res), '[edi]';

# add [0x6d0b5f4f],edx - 0000 000w : mod reg r/m
$mac = '01 15 4F 5F 0B 6D';
$res = Idu->decode($mac);
is gen_mem($res), '[0x6d0b5f4f]';

# add [ebx+0x11],bp - 0000 000w : mod reg r/m
$mac = '66 01 6B 11';
$res = Idu->decode($mac);
is gen_mem($res), '[ebx+0x11]';

# add word [eax-0xf],0x92c - 1000 00sw : mod 000 r/m : immediate data
$mac = '66 81 40 F1 2C 09';
$res = Idu->decode($mac);
is gen_mem($res), '[eax-0xf]';

$mac = '66 81 40 01 2C 09';
$res = Idu->decode($mac);
is gen_mem($res), '[eax+0x1]';

# bsf si,[ecx+ecx*2+0x42fcd77f] - 0000 1111 : 1011 1100 : mod reg r/m
$mac = '66 0F BC B4 49 7F D7 FC 42';
$res = Idu->decode($mac);
is enc2name('reg', $res->{reg}, $res), 'si';
is gen_mem($res), '[ecx+ecx*2+0x42fcd77f]';

# bsf si,[ecx+ecx*2+0xfffcd77f] - 0000 1111 : 1011 1100 : mod reg r/m
$mac = '66 0F BC B4 49 7F D7 FC ff';
$res = Idu->decode($mac);
is enc2name('reg', $res->{reg}, $res), 'si';
is gen_mem($res), '[ecx+ecx*2+0xfffcd77f]';

# bsr esp,[edx+0x15f8d6bb] - 0000 1111 : 1011 1101 : mod reg r/m
$mac = '0F BD A2 BB D6 F8 15';
$res = Idu->decode($mac);
is enc2name('reg', $res->{reg}, $res), 'esp';
is gen_mem($res), '[edx+0x15f8d6bb]';

# add dword [ebx+ebx],byte +0x8 - 1000 00sw : mod 000 r/m : immediate data
$mac = '83 04 1b 08';
$res = Idu->decode($mac);
is gen_mem($res), '[ebx+ebx]';

# adc word [eax],byte -0x11 - 1000 00sw : mod 010 r/m : immediate data
$mac = '66 83 14 E0 EF';
$res = Idu->decode($mac);
is gen_mem($res), '[eax]';

