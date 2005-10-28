@echo off

del vsim.wlf transcript
del *.v

pushd ram
perl Makefile.PL
nmake clean
popd

pushd alu
perl Makefile.PL
nmake clean
popd

pushd idu
nmake clean
popd

del *.html
