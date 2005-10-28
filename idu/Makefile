VIDU = idu.v
IDU_LIB = inc\Idu.pm
DISASM_LIB = inc\Disasm.pm
CIDU_DLL = C\idu.dll
CIDU_LIB = C\idu.lib

RAW_AST = encoding.ast
NEW_AST = encoding2.ast
GLOB_AST = ..\Config.ast
STAT_AST = state_mac.ast
PAT_AST = pat_tree.ast

VIDU_TT = idu.v.tt
IDU_TT = inc\Idu.pm.tt
CIDU_TT = C\idu.c.tt

RM_F = perl -MExtUtils::Command -e rm_f

PAT_COVER_FILES = t\pat_cover.ast.t t\pat_cover.t
MIN_T_FILES = $(PAT_COVER_FILES) t\optest.t t\my_perl.exe.t t\types.cod.t \
	t\catln.t t\exe2hex.t t\hex2bin.t t\bin2hex.t t\bin2asm.t t\ndisasmi.t \
	t\Idu.t t\pat_tree.t t\state_mac.t t\Idu-Util.t t\cidu.t \
	t\opname.t t\error.t t\operand.t t\01disasm.t t\02disasm.t t\03disasm.t \
	t\disasm_cover.t t\ndisasm.t
T_FILES = t\main.cod.t t\bin2hex.exe.t t\hex2bin.exe.t $(MIN_T_FILES)

C_PAT_COVER_FILES = t\cpat_cover.ast.t t\cpat_cover.t
C_MIN_T_FILES = $(C_PAT_COVER_FILES) t\cmy_perl.exe.t t\ctypes.cod.t \
	t\cidu.t t\copname.t t\cerror.t t\coperand.t
C_T_FILES = $(C_MIN_T_FILES) t\cmain.cod.t t\cbin2hex.exe.t t\chex2bin.exe.t

# ---------------------------------------------------------
# nmake
# ---------------------------------------------------------

all : $(VIDU) $(IDU_LIB) hex2bin.exe bin2hex.exe t_dir $(CIDU_DLL) $(CIDU_LIB) \
	C\idui.exe $(DISASM_LIB) encoding2.ast

$(VIDU) : $(VIDU_TT) $(STAT_AST)
	astt -o $@ -t $(VIDU_TT) $(GLOB_AST) $(STAT_AST)

$(IDU_LIB) : $(IDU_TT) $(GLOB_AST) $(STAT_AST)
	astt -o $@ -t $(IDU_TT) $(GLOB_AST) $(STAT_AST)

$(STAT_AST) : state_mac.pl inc\state_mac.pm $(PAT_AST)
	perl state_mac.pl $(PAT_AST)

$(PAT_AST) : pat_tree.pl inc\pat_tree.pm inc\state_mac.pm $(NEW_AST)
	perl pat_tree.pl $(NEW_AST)

$(NEW_AST) : asm_tpl.ast asm_tpl2.ast new_encoding_ast.pl $(RAW_AST)
	perl new_encoding_ast.pl asm_tpl.ast asm_tpl2.ast > $@

$(RAW_AST) : encoding.txt parse_enc.pl
	perl parse_enc.pl encoding.txt > $@

hex2bin.exe : hex2bin.c
	cl /nologo /O2 hex2bin.c

bin2hex.exe : bin2hex.c
	cl /nologo /O2 bin2hex.c

t_dir :
	cd t
	$(MAKE) /nologo
	cd..

$(CIDU_DLL) : C\idu.obj C\idu.def
	link /dll /nologo /debug /out:$@ /def:C\idu.def C\idu.obj

$(CIDU_LIB) : $(CIDU_DLL)

C\idu.obj : C\idu.c C\idu.h
	cd C
	cl /nologo /c /I . idu.c
	cd ..

C\idu.c : $(CIDU_TT) $(GLOB_AST) $(STAT_AST)
	astt -o $@ -t $(CIDU_TT) $(GLOB_AST) $(STAT_AST)

C\idui.exe : C\idui.c C\idu.h $(CIDU_LIB) $(CIDU_DLL)
	cl /nologo /I C /o $@ C\idui.c /link $(CIDU_LIB)

$(DISASM_LIB) : $(DISASM_LIB).tt $(GLOB_AST) $(NEW_AST)
	astt -o $@ -t $(DISASM_LIB).tt $(GLOB_AST) $(NEW_AST)

asm_tpl.ast : encoding.ast gen_asm_tpl.pl
	perl gen_asm_tpl.pl encoding.ast

asm_tpl2.ast : asm_tpl2.ast.tt
	tpage asm_tpl2.ast.tt > $@

# ---------------------------------------------------------
# nmake install
# ---------------------------------------------------------

install: idu.v
	copy idu.v ..\

# ---------------------------------------------------------
# nmake doc
# ---------------------------------------------------------

doc : encoding.html pat_cover.html state_mac.png t\state_mac.png

encoding.html : encoding.pod
	podhtm -s docstyle.css encoding.pod
	del *.tmp

encoding.pod : encoding.pod.tt $(NEW_AST)
	astt -o $@ -t encoding.pod.tt $(NEW_AST)

pat_cover.html: pat_cover.pod
	podhtm -o $@ -s docstyle.css pat_cover.pod
	del *.tmp

pat_cover.pod : ast_doc.tt t\pat_cover.ast.ast
	astt -o $@ -t ast_doc.tt t\pat_cover.ast.ast

state_mac.png : draw_graph.pl state_mac.xml
	perl draw_graph.pl -b state_mac.xml

t\state_mac.png : draw_graph.pl state_mac.xml
	perl draw_graph.pl t\state_mac.xml

state_mac.xml : state_mac.xml.tt state_mac.ast
	astt -o $@ -t state_mac.xml.tt state_mac.ast

t\state_mac.xml : state_mac.xml.tt t\state_mac.ast
	astt -o $@ -t state_mac.xml.tt t\state_mac.ast



# ---------------------------------------------------------
# nmake test
# ---------------------------------------------------------

test : all tester run_test

tester : $(MIN_T_FILES) pat_cover $(T_FILES)

##

# Test the tester back-end separately:

t\optest.t : optest.tt t\optest.ast
	astt -o $@ -t optest.tt t\optest.ast

optest.tt : optest.tt.tt
	tpage --define lang=Perl optest.tt.tt > $@

t\optest.ast : t\optest.ast.tt
	tpage t\optest.ast.tt > $@

##

# Applying the CL tester front-end to types.c

BASE = types
COD = $(BASE).cod
C_FILE = $(BASE).c

t\$(COD).t : optest.tt t\$(COD).ast
	echo $ast = { 'ast_file', 't/$(COD).ast' }; > t\tmp
	astt -o $@ -t optest.tt t\tmp t\$(COD).ast
	del t\tmp

t\$(COD).ast : cod2ast.pl $(COD)
	perl cod2ast.pl $(COD) > $@

$(COD): $(C_FILE)
	cl /nologo /c /FAsc $(C_FILE)
	del $(BASE).obj

##

# Applying the CL tester front-end to main.c and bstree.h:

COD = main.cod

t\$(COD).t : optest.tt t\$(COD).ast
	echo $ast = { 'ast_file', 't/$(COD).ast' }; > t\tmp
	astt -o $@ -t optest.tt t\tmp t\$(COD).ast
	del t\tmp

t\$(COD).ast : cod2ast.pl $(COD)
	perl cod2ast.pl $(COD) > $@

$(COD): main.c bstree.h optest.tt
	cl /nologo /c /FAsc main.c
	del main.obj

##

# Applying the Ndisasm tester front-end to bin2hex.exe:

EXE = bin2hex.exe

t\$(EXE).t : optest.tt t\$(EXE).ast
	echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
	astt -o $@ -t optest.tt t\tmp t\$(EXE).ast
	del t\tmp

t\$(EXE).ast : asm2ast.pl t\$(EXE).asm
	perl asm2ast.pl t\$(EXE).asm > $@

t\$(EXE).asm : bin2asm.pl t\$(EXE).bin
	perl bin2asm.pl t\$(EXE).bin > $@

t\$(EXE).bin : hex2bin.exe t\$(EXE).hex
	hex2bin.exe t\$(EXE).hex $@

t\$(EXE).hex : exe2hex.pl $(EXE)
	perl exe2hex.pl $(EXE) > $@

##

# Applying the Ndisasm tester front-end to my_perl.exe:

EXE = my_perl.exe

t\$(EXE).t : optest.tt t\$(EXE).ast
	echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
	astt -o $@ -t optest.tt t\tmp t\$(EXE).ast
	del t\tmp

t\$(EXE).ast : asm2ast.pl t\$(EXE).asm
	perl asm2ast.pl t\$(EXE).asm > $@

t\$(EXE).asm : bin2asm.pl t\$(EXE).bin
	perl bin2asm.pl t\$(EXE).bin > $@

t\$(EXE).bin : hex2bin.exe t\$(EXE).hex
	hex2bin.exe t\$(EXE).hex $@

t\$(EXE).hex : exe2hex.pl $(EXE)
	perl exe2hex.pl $(EXE) > $@

##

# Applying the PEDasm tester front-end to my_perl.exe:

EXE = hex2bin.exe

t\$(EXE).t : t\$(EXE).ast optest.tt
    echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
    astt -o $@ -t optest.tt t\tmp t\$(EXE).ast
    del t\tmp

t\$(EXE).ast : pe2ast.pl t\$(EXE).asm
	perl pe2ast.pl -o $@ t\$(EXE).asm

t\$(EXE).asm : $(EXE)
	pedasm -o $@ -r $(EXE) > tmp
	del tmp

##

# Applying the Ndisasm tester front-end to the instructions
#   generated by pat_cover.pl:

BASE = pat_cover
EXE = $(BASE).ast

t\$(EXE).t : optest.tt t\$(EXE).ast
	echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
	astt -o $@ -t optest.tt t\tmp t\$(EXE).ast
	del t\tmp

t\$(EXE).ast : asm2ast.pl t\$(EXE).asm
	perl asm2ast.pl -d t\$(EXE).asm > $@

t\$(EXE).asm : bin2asm.pl t\$(EXE).bin
	perl bin2asm.pl t\$(EXE).bin > $@

t\$(EXE).bin : hex2bin.exe t\$(EXE).hex
	hex2bin.exe t\$(EXE).hex $@

t\$(EXE).hex : ast2hex.pl $(BASE).ast
	perl ast2hex.pl $(BASE).ast > $@

$(BASE).ast : pat_cover

pat_cover :
	perl $(BASE).pl $(NEW_AST) $(GLOB_AST) > $(BASE).ast

##

t\pat_cover.t : t\pat_cover.t.tt
	tpage --define lang=Perl t\pat_cover.t.tt > $@

t\opname.t : t\opname.t.tt
	tpage --define lang=Perl t\opname.t.tt > $@

t\error.t : t\error.t.tt
	tpage --define lang=Perl t\error.t.tt > $@

t\operand.t : t\operand.t.tt
	echo $ast = { 'lang', 'Perl' }; > t\tmp
	astt -o $@ -t t\operand.t.tt t\tmp $(GLOB_AST)
	del t\tmp

##

run_test:
	set HARNESS_OK_SLOW = 1
	perl -MExtUtils::Command::MM \
		-e "@ARGV = map glob, @ARGV; test_harness(0, '.', '.');" $(T_FILES)

# ---------------------------------------------------------
# nmake mintest
# ---------------------------------------------------------

mintest : all min_tester run_min_test

min_tester : $(MIN_T_FILES) pat_cover

run_min_test :
	set HARNESS_OK_SLOW = 1
	perl -MExtUtils::Command::MM \
	-e "@ARGV = map glob, @ARGV; test_harness(0, '.', '.');" $(MIN_T_FILES)

# ---------------------------------------------------------
# nmake ctest
# ---------------------------------------------------------

ctest : all ctester run_ctest

ctester : pat_cover $(C_T_FILES) $(C_PAT_COVER_FILES)

run_ctest :
	set HARNESS_OK_SLOW = 1
	perl -MExtUtils::Command::MM \
	-e "@ARGV = map glob, @ARGV; test_harness(0, '.', '.');" $(C_T_FILES)

BASE = cpat_cover
EXE = pat_cover.ast

t\cpat_cover.ast.t : coptest.tt t\$(EXE).ast
	echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
	astt -o $@ -t coptest.tt t\tmp t\$(EXE).ast
	del t\tmp

coptest.tt : optest.tt.tt
	tpage --define lang=C optest.tt.tt > $@

##

# Applying the CL tester front-end to types.c

BASE = types
COD = $(BASE).cod
C_FILE = $(BASE).c

t\c$(COD).t : coptest.tt t\$(COD).ast
	echo $ast = { 'ast_file', 't/$(COD).ast' }; > t\tmp
	astt -o $@ -t coptest.tt t\tmp t\$(COD).ast
	del t\tmp

##

# Applying the CL tester front-end to main.c and bstree.h:

COD = main.cod

t\c$(COD).t : coptest.tt t\$(COD).ast
	echo $ast = { 'ast_file', 't/$(COD).ast' }; > t\tmp
	astt -o $@ -t coptest.tt t\tmp t\$(COD).ast
	del t\tmp

##

# Applying the Ndisasm tester front-end to bin2hex.exe:

EXE = bin2hex.exe

t\c$(EXE).t : coptest.tt t\$(EXE).ast
	echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
	astt -o $@ -t coptest.tt t\tmp t\$(EXE).ast
	del t\tmp

##

# Applying the Ndisasm tester front-end to my_perl.exe:

EXE = my_perl.exe

t\c$(EXE).t : coptest.tt t\$(EXE).ast
	echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
	astt -o $@ -t coptest.tt t\tmp t\$(EXE).ast
	del t\tmp

##

# Applying the PEDasm tester front-end to my_perl.exe:

EXE = hex2bin.exe

t\c$(EXE).t : t\$(EXE).ast coptest.tt
    echo $ast = { 'ast_file', 't/$(EXE).ast' }; > t\tmp
    astt -o $@ -t coptest.tt t\tmp t\$(EXE).ast
    del t\tmp

##

t\cpat_cover.t : t\pat_cover.t.tt
	tpage --define lang=C t\pat_cover.t.tt > $@

t\copname.t : t\opname.t.tt
	tpage --define lang=C t\opname.t.tt > $@

t\cerror.t : t\error.t.tt
	tpage --define lang=C t\error.t.tt > $@

t\coperand.t : t\operand.t.tt
	echo $ast = { 'lang', 'C' }; > t\tmp
	astt -o $@ -t t\operand.t.tt t\tmp $(GLOB_AST)
	del t\tmp

# ---------------------------------------------------------
# nmake cmintest
# ---------------------------------------------------------

cmintest : all cmintester run_cmintest

cmintester : pat_cover $(C_MIN_T_FILES)

run_cmintest :
	set HARNESS_OK_SLOW = 1
	perl -MExtUtils::Command::MM \
	-e "@ARGV = map glob, @ARGV; test_harness(0, '.', '.');" \
	$(C_MIN_T_FILES)

# ---------------------------------------------------------
# nmake smoke
# ---------------------------------------------------------

smoke : all pat_cover t\pat_cover.t t/pat_cover.ast.ast
	perl util\run-smoke.pl . smoke.html
	perl txt2html.pl t\*.t t\*.ast

# ---------------------------------------------------------
# nmake clean
# ---------------------------------------------------------

clean:
	copy t\pat_cover.ast.ast.html ..\ /Y 
	$(RM_F) encoding.html encoding.pod state_mac.xml encoding.ast \
		pat_tree.ast state_mac.ast \
		main.cod pat_cover.pod pat_cover.html types.cod \
		hex2bin.exe hex2bin.obj \
		bin2hex.exe bin2hex.obj \
		*tmp* \
		t\optest.t t\optest.ast \
		*.def *.inc pat_cover.ast* t\pat_cover.ast* \
		$(CIDU_DLL) C\idu.obj C\idu.exp $(CIDU_LIB) C\idu.ilk \
		C\idu.pdb C\idu.c C\idui.obj idui.obj C\idui.exe \
		t\cpat_cover.ast.t t\cmy_perl.exe.t t\ctypes.cod.t \
		t\cmain.cod.t t\cbin2hex.exe.t t\chex2bin.exe.t \
		optest.tt coptest.tt $(C_PAT_COVER_FILES) $(PAT_COVER_FILES) \
		t\error.t t\cerror.t t\opname.t t\copname.t t\operand.t t\coperand.t \
		$(DISASM_LIB) tests.yml asm_tpl2.ast asm_tpl.ast encoding2.ast $(VIDU)

		cd t
		$(MAKE) /nologo clean
		cd ..
		copy ..\pat_cover.ast.ast.html t\ /Y
