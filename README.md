# tinyv
V compiler... but tinier

## What this is / is not
* It **is not** intended to be a replacement, substitution, or competitor for the main v compiler.
* It **is not** intended to support all the features of the main v compile (idealy high 90% of features).
* It **is** a research project to discover ways to improve the main v compiler.
* It **is** intended to be a functioning v compiler.
* It **is** going to remain simple.
* It **is** for fun.

## Motivation
#### Fun.
I wanted to see if I could make v compiler which is a simple as possible and with less lines of code.
The thing I love about v is its simplicity and the simplicity of the compiler, as more features are added and more edge cases are created the complexity of the compiler increases.
My goal is not to support all of the features of the main compiler, but a compromise beween simplicity and feature support. I would like to acheive high 90% feature support while keeping the codebase as simple as possible.
#### Research.
I'm really passionate about v and the comminuity, my main focus is to make the v compiler better.
The rapid influx of developers to the project at such an early stage (referring to the v2 compiler, now the main one) when a lot of core functionality was unfinished has has led to some fixes/workarounds which are not ideal.
Without any existing constraints, and using what I have learned I am able to easily test ideas & simplifications which can then be migrated into the main compiler.

## Status
1. Scanner / Lexer - Working (~98%)
2. Parser - Working (~60%)
3. Backends / Generation Stage
   - x64 (not started)
   - C (not started)
