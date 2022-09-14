# tinyv
V compiler... but tinier

A simplistic compiler for the V language: https://github.com/vlang/v

*Please ***no PR's for code***, thanks. This is an experiment & may change drastically at any moment.*

## Foreword
Although this aims to be a functioning V compiler, it is not intended to be an alternative to the main V compiler, it may or may not support all the features the main compiler does.

It was started as a research project to discover ways to simplify & improve the main V compiler.

The fundamental principles of tinyv are simplicity & stability, and it must remain simple.

## Motivation
My goal is to make V the best it can be. I'm very passionate about the V project & it's community.

I love the simplicity of V, although as more features have been added, the complexity of the compiler has increased significantly. Due to this, it is difficult test new ideas (especially regarding core principles). This project allows me to easily test new ideas & simplifications without any existing constraints.


## New features / Possible Differences
1. Compile time Features:
   - Any V function will be able to be run at compile time, by using the compile time call syntax `x := $fn_call()`, the function will go through the normal stages AST -> IR -> Bytecode and will then be run through the interpreter, the result will be statically compiled into the program.
2. Metadata / Compile Time Introspection:
   - All objects can potentially expose metadata to the user. As an example, objects of type `Struct` will have metadata about the fields, methods and their types etc. Since there will be a method for all objects to provide this data by default no special implementations will be needed.
   - Possible example interface: `global.metadata.os`, `struct.metadata.fields`, `function.metadata.return_type`
3. Syntax Changes:
   - I don't want to break backwards compatibility, however there are various small changes which I feel would help unify the syntax (TODO: Add).
   - Use `[]` instead of `<>` for generics. this has many benefits for parsing. Possibly change the closure variable capture syntax.
   - Explicit mutable references: `mut &x`
   - Named parameters & default parameters
   - Consider the possibility of uninitialized objects: This would need to be `unsafe`, and would probably be rarely used. But there are certain areas, for example game development where lack of this feature could be a non starter. For example when dealing with huge arrays of data structures like game assets or entities.

## Design Details / Status
1. Frontend
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
   - C (under consideration): Bytecode - > C