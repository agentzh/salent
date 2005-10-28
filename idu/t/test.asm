dec ebp                                      ;4D
pop edx                                      ;5A
nop                                          ;90
fadd dword [eax]                             ;D8 00
add [eax],al                                 ;00 00
push cs                                      ;0E
pop ds                                       ;1F
mov edx,0x9b4000e                            ;BA 0E 00 B4 09
int 0x21                                     ;CD 21
mov eax,0x21cd4c01                           ;B8 01 4C CD 21
push esp                                     ;54
push dword 0x70207369                        ;68 69 73 20 70
jc 0xc5                                      ;72 6F
a16 jc 0xba                                  ;67 72 61
insd                                         ;6D
and [ebx+0x61],ah                            ;20 63 61
outsb                                        ;6E
outsb                                        ;6E
outsd                                        ;6F
jz 0x82                                      ;74 20
bound esp,[ebp+0x20]                         ;62 65 20
jc 0xdc                                      ;72 75
outsb                                        ;6E
and [ecx+0x6e],ch                            ;20 69 6E
and [edi+ecx*2+0x53],al                      ;20 44 4F 53
and [ebp+0x6f],ch                            ;20 6D 6F
cs or eax,0x240a0d                           ;64 65 2E 0D 0D 0A 24 00
add [eax],al                                 ;00 00
add [eax],al                                 ;00 00
add [eax],al                                 ;00 00
stosb                                        ;AA
sbb [eax-0x62],ecx                           ;19 48 9E
out dx,al                                    ;EE
