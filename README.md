## What is this repository?
This is meant as a record of my progress in learning 65C816 Assembly.
The goal of this project is technically to make a game for the SNES,
but I'm moreso doing this to learn how to program in assembly.

## How do you turn this assembly into a SNES game?
This repo requires the ca65 assembler, and the ld65 linker.
ca65 can be run on "Animation.asm", and the resulting object file must be linked with "map.cfg".

## What are all these other files?
The following files are automatically included when "Animation.asm" is assembled
- Header.inc | Information about the cartridge, such as size and interrupt vector locations
- Snes_Init.asm | An initialization script that sets registers from random to a corresponding default value. (Often $00)
- SnesRegisterShorthand.inc | Establishes gives named values for register locations to the assembler, which makes coding much more intuitive

## Where is the game in all of this?
The final product is the file with a ".smc" or ".sfc" ending. 
That is currently "Animation.smc", but this name may change in the future.

