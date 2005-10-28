#: ndisasm.t
#: Test the inc::Disasm module.
#: Salent v0.12
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-23 2005-08-25

use strict;
use warnings;

package Disasm;

use Test::More tests => 138;
use inc::Ndisasm;

my $mac = '37';
is disasm($mac), 'aaa';

$mac = '66 62 23';
is disasm($mac), 'bound sp,[ebx]';

$mac = 'D5 0A';
is disasm($mac), 'aad';

$mac = 'D4 0A';
is disasm($mac), 'aam';

$mac = '66 3F';
is disasm($mac), 'o16 aas';

$mac = '66 98';
is disasm($mac), 'cbw';

$mac = '98';
is disasm($mac), 'cwde';

$mac = '99';
is disasm($mac), 'cdq';

$mac = '66 99';
is disasm($mac), 'cwd';

$mac = '3F';
is disasm($mac), 'aas';

$mac = '0F CD';
is disasm($mac), 'bswap ebp';

$mac = 'F8';
is disasm($mac), 'clc';

$mac = 'FC';
is disasm($mac), 'cld';

$mac = 'FA';
is disasm($mac), 'cli';

$mac = '0F 06';
is disasm($mac), 'clts';

$mac = 'F5';
is disasm($mac), 'cmc';

$mac = 'A6';
is disasm($mac),'cmpsb';

$mac = '0F A2';
is disasm($mac),'cpuid';

$mac = '27';
is disasm($mac),'daa';

$mac = '2F';
is disasm($mac),'das';

$mac = 'F4';
is disasm($mac), 'hlt';

$mac = '6C';
is disasm($mac), 'insb';

$mac = '6D';
is disasm($mac), 'insd';

$mac = '66 6D';
is disasm($mac), 'insw';

$mac = '66 6C';
is disasm($mac), 'o16 insb';

$mac = 'CC';
is disasm($mac), 'int3';

$mac = 'CD 96';
is disasm($mac), 'int 0x96';

$mac = 'CE';
is disasm($mac), 'into';

$mac = '0F 08';
is disasm($mac), 'invd';

$mac = '0F 01 39';
is disasm($mac), 'invlpg [ecx]';

$mac = 'CF';
is disasm($mac), 'iret';

$mac = '66 CF';
is disasm($mac), 'iretw';

$mac = '9F';
is disasm($mac), 'lahf';

$mac = 'C5 81 53 BC C2 45';
is disasm($mac), 'lds eax,[ecx+0x45c2bc53]';

$mac = '8D 5D 8E';
is disasm($mac), 'lea ebx,[ebp-0x72]';

$mac = 'C9';
is disasm($mac), 'leave';

$mac = '66 C4 A1 41 A4 9A 05';
is disasm($mac), 'les sp,[ecx+0x59aa441]';

$mac = '0F B4 6A C6';
is disasm($mac), 'lfs ebp,[edx-0x3a]';

$mac = '0F 01 97 49 4D 7F DC';
is disasm($mac), 'lgdt [edi+0xdc7f4d49]';

$mac = '66 0F B5 15 B5 8B C0 1D';
is disasm($mac), 'lgs dx,[0x1dc08bb5]';

$mac = '0F 01 5A 39';
is disasm($mac), 'lidt [edx+0x39]';

$mac = 'AC';
is disasm($mac), 'lodsb';

$mac = 'AD';
is disasm($mac), 'lodsd';

$mac = '66 AD';
is disasm($mac), 'lodsw';

$mac = 'E8 84 64 B8 3B';
is disasm($mac), 'call 0x3bb86489';

$mac = '7F D5';
is disasm($mac), 'jg 0xffffffd7';

$mac = '0F 88 9F 86 14 87';
is disasm($mac), 'js near 0x871486a5';

$mac = 'E2 C4';
is disasm($mac), 'loop 0xffffffc6';

$mac = 'E1 B8';
is disasm($mac), 'loope 0xffffffba';

$mac = 'E0 1C';
is disasm($mac), 'loopne 0x1e';

$mac = 'E3 2E';
is disasm($mac), 'jecxz 0x30';

$mac = 'C8 67 37 0B';
is disasm($mac), 'enter 0x3767,0xb';

$mac = '66 0F B2 72 4A';
is disasm($mac), 'lss si,[edx+0x4a]';

$mac = '6E';
is disasm($mac), 'outsb';

$mac = '66 6F';
is disasm($mac), 'outsw';

$mac = '6F';
is disasm($mac), 'outsd';

$mac = '0F 22 C2';
is disasm($mac), 'mov cr0,edx';

$mac = '0F 20 CE';
is disasm($mac), 'mov esi,cr1';

$mac = '0F 23 D2';
is disasm($mac), 'mov dr2,edx';

$mac = '0F 21 D2';
is disasm($mac), 'mov edx,dr2';

$mac = 'A4';
is disasm($mac), 'movsb';

$mac = '66 A5';
is disasm($mac), 'movsw';

$mac= 'A5';
is disasm($mac), 'movsd';

$mac = '61';
is disasm($mac), 'popa';

$mac = '66 61';
is disasm($mac), 'popaw';

$mac = '9D';
is disasm($mac), 'popf';

$mac = '66 9D';
is disasm($mac), 'popfw';

$mac = '60';
is disasm($mac), 'pusha';

$mac = '66 60';
is disasm($mac), 'pushaw';

$mac = '9C';
is disasm($mac), 'pushf';

$mac = '66 9C';
is disasm($mac), 'pushfw';

$mac = '0F 32';
is disasm($mac), 'rdmsr';

$mac = '0F 33';
is disasm($mac), 'rdpmc';

$mac = '0F 31';
is disasm($mac), 'rdtsc';

$mac = '0F AA';
is disasm($mac), 'rsm';

$mac = '9E';
is disasm($mac), 'sahf';

$mac = 'D6';
is disasm($mac), 'salc';

$mac = '0F 01 87 7B 69 C1 D2';
is disasm($mac), 'sgdt [edi+0xd2c1697b]';

$mac = '0F 01 48 78';
is disasm($mac), 'sidt [eax+0x78]';

$mac = 'F9';
is disasm($mac), 'stc';

$mac = 'FD';
is disasm($mac), 'std';

$mac = 'FB';
is disasm($mac), 'sti';

$mac = '9B';
is disasm($mac), 'wait';

$mac = '0F 09';
is disasm($mac), 'wbinvd';

$mac = '0F 30';
is disasm($mac), 'wrmsr';

$mac = 'D7';
is disasm($mac), 'xlatb';

$mac = '63 C1';
is disasm($mac), 'arpl cx,ax';

$mac = '0F 03 C2';
is disasm($mac), 'lsl eax,edx';

$mac = '0F 02 FE';
is disasm($mac), 'lar edi,esi';

$mac = '0F 01 F4';
is disasm($mac), 'lmsw sp';

my %data = (
    '8F 04 F7' => 'pop dword [edi+esi*8]',
    '66 0f 00 0b' => 'o16 str [ebx]',
    '0f 00 8a 58 02 3c 90' => 'str [edx+0x903c0258]',
    '85 df' => 'test edi,ebx',
    '66 d3 0e' => 'ror word [esi],cl',
    'd2 0b' => 'ror byte [ebx],cl',
    '8E 37' => 'mov segr6,[edi]',
    '8C DF' => 'mov edi,ds',
    '8E D9' => 'mov ds,cx',
    '8C 0A' => 'mov [edx],cs',
    '1F' => 'pop ds',
    '07' => 'pop es',
    '17' => 'pop ss',
    '0F A1' => 'pop fs',
    '0F A9' => 'pop gs',
    '16' => 'push ss',
    '0F A0' => 'push fs',
    '0F A8' => 'push gs',
    '0F 0B' => 'ud2',
    'D8 42 86' => 'fadd dword [edx-0x7a]',
    'DC 05 77 7C 2B FD' => 'fadd qword [0xfd2b7c77]',
    'D8 10' => 'fcom dword [eax]',
    'DC 54 26 D6' => 'fcom qword [esi-0x2a]',
    'D8 5F 41' => 'fcomp dword [edi+0x41]',
    'DC 1A' => 'fcomp qword [edx]',
    'D8 31' => 'fdiv dword [ecx]',
    'DC 36' => 'fdiv qword [esi]',
    'D8 BF 8F DD 5F 67' => 'fdivr dword [edi+0x675fdd8f]',
    'DC BB 67 D3 9C 18' => 'fdivr qword [ebx+0x189cd367]',
    'DE 84 35 08 E4 BB 48' => 'fiadd word [ebp+esi+0x48bbe408]',
    'DA 87 BF 79 B3 F9' => 'fiadd dword [edi+0xf9b379bf]',
    'DE 54 15 8A' => 'ficom word [ebp+edx-0x76]',
    'DA 54 40 FD' => 'ficom dword [eax+eax*2-0x3]',
    'DE 20' => 'fisub word [eax]',
    'DA 20' => 'fisub dword [eax]',
    'DE AA D5 A1 D6 44' => 'fisubr word [edx+0x44d6a1d5]',
    'DA A9 EC 01 B0 8C' => 'fisubr dword [ecx+0x8cb001ec]',
    'DE 0D C2 62 29 84' => 'fimul word [0x842962c2]',
    'DA 89 62 44 60 41' => 'fimul dword [ecx+0x41604462]',
    'DE B7 E7 62 76 54' => 'fidiv word [edi+0x547662e7]',
    'DA 36' => 'fidiv dword [esi]',
    'DA 7A 8E' => 'fidivr dword [edx-0x72]',
    'DF 40 79' => 'fild word [eax+0x79]',
    'DC 0C 49' => 'fmul qword [ecx+ecx*2]',
    'D8 20' => 'fsub dword [eax]',
    'DC 23' => 'fsub qword [ebx]',
    'D8 2F' => 'fsubr dword [edi]',
    'DC AB 66 E5 06 94' => 'fsubr qword [ebx+0x9406e566]',





);

my $asm;
while (($mac, $asm) = each %data) {
  is disasm($mac), $asm;
}  











