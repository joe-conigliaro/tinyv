# tinyv
V compiler... but tinier

A simplistic compiler for the V language: https://github.com/vlang/v

## What this is / is not
* It **is not** intended to be a replacement, substitution, or competitor for the main v compiler.
* It **is not** intended to support all the features of the main v compiler (idealy high 90% of features).
* It **is** a research project to discover ways to improve the main v compiler.
* It **is** intended to be a functioning v compiler.
* It **is** going to remain simple.
* It **is** for fun.

## Motivation
#### Fun.
I want to make a v compiler which is as simple as possible and with minimal lines of code (no frills).
The thing I love about v is its simplicity and the simplicity of the compiler, as more features are added and more edge cases are created the complexity of the compiler increases.

My goal is not to support all of the features of the main compiler, but a compromise beween simplicity and feature support. I would like to acheive high 90% feature support while keeping the codebase as simple as possible.
#### Research.
I'm really passionate about the v project and it's community, my main focus is to make the v compiler better.

Without any existing constraints, and using what I have learned I am able to easily test new ideas & simplifications which could end up being migrated into the main compiler.

## Status
1. Scanner / Lexer - Working (almost complete)
2. Parser - Working (incomplete, stub methods & nodes)
3. Backends / Generation Stage
   - x64 (not started)
   - C (not started)
