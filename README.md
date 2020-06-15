# tinyv
V compiler... but tinier

## What this is / is not
* It is not intended to be a replacement, substitution, or competitor for the main v compiler.
* It is not intended to support all the features of the main v compiler. Somwhere in the high 90% of features. 
* A research project to discover ways to improve the main v compiler.
* It is supposed to be a functioning v compiler.
* Fun, and simple.

## Motivation
Fun. I wanted to see if I could make v compiler which is a simple as possible and with less lines of code. The thing I love about v is its simplicity and the simplicity of the compiler, as more features are added and more edge cases are created the complexity of the compiler increases. My goal is not to support all of the features of the main compiler, but a compromise of simplicity and feature support. If I can acheive in the high 90% of features, with a much smaller codebase I would be happy.
Research. I'm really passionate about v and the comminuity, my main focus is to make the v compiler better. The rapid influx of developers to the project at such an early stage (v2 compiler, now the main one) when a lot of core functionality was unfinished has has led to some fixes/workarounds in different places which can be constraining. Taking what I have learned, and with a fresh drawing board I find it easier to come up with simpler solutions which can then be migrated into the main compiler.

## Status
* Scanner / Lexer - Working (~98%)
* Parser - Working (~60%)
* Generation
-x64 (not started)
-C (not started)

