@echo off
rgbasm main.asm -o main.o
rgblink main.o -o k15_gbtest.gb
rgbfix -v -p 0 k15_gbtest.gb