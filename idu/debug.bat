nmake /nologo
perl t\disasm_cover.t > out 2>&1
grep -P %1 out