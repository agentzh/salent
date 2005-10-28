@echo off

call tpage Config.ast.tt > Config.ast
call astt -o ram.v -t ram\ram.v.tt Config.ast
call astt -o alu.v -t alu\alu.v.tt Config.ast
