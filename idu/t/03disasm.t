#: 02Disasm.t
#: Test the inc::Disasm module.
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-23 2005-08-28

package Disasm;

use strict;
use warnings;

use C::Idu;

my @data;
BEGIN {
    @data = (
        '8F 04 F7' => 'pop dword [edi+esi*8]',
        '66 0f 00 0b' => 'str [ebx]',
        '0f 00 8a 58 02 3c 90' => 'str [edx+0x903c0258]',
        '85 df' => 'test edi,ebx',
        '66 d3 0e' => 'ror word [esi],cl',
        'd2 0b' => 'ror byte [ebx],cl',
        '9A 13 A6 71 21 8F 45' => 'call 0x458f:0x2171a613',
        '66 9A 41 1B 23 BE' => 'call word 0xbe23:0x1b41',
        '66 9A 41 B1 23 0f' => 'call word 0xf23:0xb141',
        '66 9A 41 00 23 BE' => 'call word 0xbe23:0x41',
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
        '0F BF FE' => 'movsx edi,si',
        '0F BF 07' => 'movsx eax,word [edi]',
        '0F B7 DA' => 'movzx ebx,dx',
        '0F B6 08' => 'movzx ecx,byte [eax]',
        '0F B6 64 85 74' => 'movzx esp,byte [ebp+eax*4+0x74]',
        'FF 16' => 'call near [esi]',
        'D8 73 09' => 'fdiv dword [ebx+0x9]',
        '83 C4 0D' => 'add esp,byte +0xd',
        '66 6B EF A5' => 'imul bp,di,byte -0x5b',
        '75 90' => 'jnz 0xffffff92',
        '0F 82 EC 61 41 D0' => 'jc near 0xd04161f2',
        'A0 A7 67 B6 C9' => 'mov al,[0xc9b667a7]',
        '66 A2 9C 6C 55 5E' => 'mov [0x5e556c9c],al',
        '66 76 32' => 'jna 0x35',
        '68 80 60 C8 84' => 'push dword 0x84c86080',
        '66 E2 FE' => 'loop 0x1',
        '90' => 'nop',
        '66 90' => 'nop',
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
}

use Test::More tests => scalar(@data)/2;
use inc::Disasm;

my ($mac, $asm);
while (@data) {
   ($mac, $asm) = (shift(@data), shift(@data));
   is disasm($mac), $asm, "mac: $mac";
}  
