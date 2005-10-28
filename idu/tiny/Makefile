GLOB_AST = ..\..\Config.ast
STAT_AST = ..\t\state_mac.ast
CIDU_LIB = idu.lib
CIDU_DLL = idu.dll
CIDU_TT  = ..\C\idu.c.tt
IDUI = ..\C\idui.c

all : $(CIDU_DLL) $(CIDU_LIB) idui.exe

$(CIDU_DLL) : idu.obj ..\C\idu.def
	link /dll /nologo /debug /out:$@ /def:..\C\idu.def idu.obj

$(CIDU_LIB) : $(CIDU_DLL)

idu.obj : idu.c ..\C\idu.h
	cl /nologo /TP /c /I ..\C idu.c

idu.c : $(CIDU_TT) $(GLOB_AST) $(STAT_AST)
	astt -o $@ -t $(CIDU_TT) $(GLOB_AST) $(STAT_AST)

idui.exe : $(IDUI) ..\C\idu.h $(CIDU_LIB) $(CIDU_DLL)
	cl /nologo /o $@ /TP /I ..\C $(IDUI) /link $(CIDU_LIB)

clean :
	del idu.obj idu.c idu.pdb idu.ilk idui.exe idui.obj idu.exp idu.lib idu.dll
