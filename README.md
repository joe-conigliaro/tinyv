# tinyv
V compiler... but tinier

A simplistic compiler for the V language: https://github.com/vlang/v

*Please ***no PR's for code***, thanks. This is an experiment & may change drastically at any moment.*

## Foreword
Although this aims to be a functioning V compiler, it is not intended to be an alternative to the main V compiler, it may or may not support all the features the main compiler does.

It was started as a research project to discover ways to simplify & improve the main V compiler.

## Motivation
The thing I love about V is the simplicity of the language & compiler. As more features have been added, the complexity of the compiler has increased significantly. As a byproduct the chance of edge cases also increases.

The fundamental principles of tinyv are simplicity & stability. Rather than supporting all the features of the main compiler, I may choose to exclude more complicated features, and instead focus on making the supported subset as stable as possible. Then again I may choose to support them all, or even add new features.

I'm very passionate about the V project & it's community. Making the V compiler the best it can be has always been my highest priority. Due to the increasing complexity of the V compiler, it is difficult test new ideas (especially regarding core principles). This project allows me to easily test new ideas & simplifications without any existing constraints.

## New features / Possible Differences
1. Compile time Features:
   - Any V function will be able to be run at compile time, by using the compile time call syntax `x := $fn_call()`, the function will go through the normal stages AST -> IR -> Bytecode and will then be run through the interpreter, the result will be statically compiled into the program.
2. Metadata:
   - Make object introspection first class. All objects will provide metadata which will be available to the user (through some type of interface), this will be useful at compile time. As an example, objects of type `Struct` will have metadata about the fields, methods and their types etc. This will extend to all objects, it can be decided which data is made available to the user. Since there will be an interface for all objects to provide this data by default no special implementations will be needed.
3. Syntax Changes:
   - This is tricky as I don't want to break backwards compatibility, however there are various small changes which I feel would help unify the syntax.
   - Compile time fields etc: use a unified syntax for metadata/introspection. No special or hard to remember syntax eg: `object.metadata.fields`, `object.metadata.return_type`
   - use `[]` instead of `<>` for generics. this has many benefits for parsing. Possibly change the closure variable capture syntax.
   - explicit mutable references: `mut &x`
   - named parameters & default parameters
   - consider the possibility of uninitialized objects: this would be need to be unsafe, and it would probably hardly ever be used. But there are certain areas, for example game development where this could be useful or even mandatory. For example when dealing with huge arrays of data structures like game assets.

## Design Details / Status
1. Compilation Stages
   - Scanner / Lexer (working)
   - Parser (working)
   - AST Generation (working)
   - AST -> SSA (planned)
   - Optimization passes (planned): operating on SSA form
   - SSA -> Bytecode (planned): going from AST directly to Byte Code is an option I may explore
2. Interpreter - Bytecode VM (planned)
   - The advantage to operating as a Bytecode VM is that once the interpreter handles every Bytecode operation, it doesn't matter what kind of syntactic sugar or higher level abstractions we start off with in code / AST, once lowered to Bytecode the interpreter should be able to handle it with no modifications. 
3. Backends / Code Generation
   - V (working): AST -> V Generates V code from the AST, useful for testing the parser
   - x64 (planned): Bytecode -> x64 machine code
   - C (under consideration): Bytecode - > C (not started)