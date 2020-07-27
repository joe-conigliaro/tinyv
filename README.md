# tinyv
V compiler... but tinier

A simplistic compiler for the V language: https://github.com/vlang/v

*Please ***no PR's for code***, thanks. This is an experiment & may change drastically at any moment.*

## Foreword
Although this aims to be a functioning V compiler, it is not intended to be an alternative to the main V compiler, nor will it support all the features the main compiler does.

It was started as a research project to discover ways to simplify & improve the main V compiler.

## Essence
* Fun
* Research
* Simplicity
* Stability

## Motivation
The thing I love about V is the simplicity of the language and the simplicity of the compiler. As more features are added the complexity of the compiler increases, and more edge cases are created.

I would like to create a V compiler with the fundamental goals of simplicity and stability. Rather than supporting all the features of the main compiler, I may choose to exclude more complicated features, and instead focus on making the supported subset as stable as possible.

I'm really passionate about the V project and its community. Making the V compiler the best it can be has always been my highest priority. This project allows me to easily test new ideas & simplifications without any existing constraints.

## Status
1. Scanner / Lexer - Working (almost complete)
2. Parser - Working (almost complete)
3. Backends / Generation Stage
   - V (almost complete) Generates V code from the AST, useful for testing the parser
   - x64 (not started)
   - C (not started)
