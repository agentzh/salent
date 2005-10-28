VIDU = idu.v
VIDU_TT = ..\idu.v.tt
IDU_LIB = Idu.pm
RAW_AST = encoding.ast
NEW_AST = encoding2.ast
GLOB_AST = ..\..\Config.ast
STAT_AST = state_mac.ast
PAT_AST = pat_tree.ast
IDU_TT = ..\inc\Idu.pm.tt
PERL = perl
RM_F = $(PERL) -MExtUtils::Command -e rm_f

all: $(IDU_LIB) $(VIDU)

$(VIDU) : $(VIDU_TT) $(STAT_AST)
	astt -o $@ -t $(VIDU_TT) $(GLOB_AST) $(STAT_AST)

$(IDU_LIB): $(IDU_TT) $(GLOB_AST) $(STAT_AST)
	astt -o $(IDU_LIB) -t $(IDU_TT) $(GLOB_AST) $(STAT_AST)

$(STAT_AST): ..\state_mac.pl ..\inc\state_mac.pm $(PAT_AST)
	perl -I.. ..\state_mac.pl $(PAT_AST)

$(PAT_AST): ..\pat_tree.pl ..\inc\pat_tree.pm ..\inc\state_mac.pm $(NEW_AST)
	perl -I.. ..\pat_tree.pl $(NEW_AST)

$(RAW_AST): encoding.txt ..\parse_enc.pl
	perl ..\parse_enc.pl encoding.txt > $(RAW_AST)

$(NEW_AST) : ..\asm_tpl.ast ..\asm_tpl2.ast ..\new_encoding_ast.pl $(RAW_AST)
	perl ..\new_encoding_ast.pl ..\asm_tpl.ast ..\asm_tpl2.ast > $@

clean :
	$(RM_F) tmp* \
		*.exe.t *.exe.ast *.exe.bin *.exe.hex *.exe.asm \
		*.cod.t *.cod.ast \
		encoding.ast pat_tree.ast state_mac.ast \
		Idu.pm \
		bin2asm bin2asm.asm bin2asm.hex
