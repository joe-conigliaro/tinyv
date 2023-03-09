# tinyv
V compiler... but tinier

A simplistic compiler for the V language: https://github.com/vlang/v

*This is an experiment & may change drastically at any moment.*

## Foreword
tinyv was started as a research project to discover ways to simplify & improve the main V compiler.

The fundamental principles of tinyv are simplicity & stability, and it must remain simple.

## Motivation
I'm very passionate about the V project & it's community. My goal is to make V the best it can be.

I love the simplicity of V, although over time the complexity of the compiler has increased significantly. It can be challenging to test new ideas (especially regarding core features). This project allows me to easily try out new ideas and simplifications without existing constraints.

## New features / Possible Differences
1. Compile time Code Execution:
   - Any V function will be able to be run at compile time, by using the compile time call syntax `x := $fn_call()` (actual syntax may differ), the function will go through the normal stages AST -> IR -> Bytecode and will then be run through the interpreter, the result will be statically compiled into the program.
2. Metadata / Compile Time Introspection:
   - Make introspection first class. Have a core interface to allow any object to expose metadata to the user. As an example, objects of type `Struct` will provide metadata for fields, methods, and their types. Objects will be able to expose this data by satisfying the interface, no special implementations needed.
   - Potential metadata access syntax:
      - Global:`$global.metadata.os`
      - Struct Instance: `struct_inst.$metadata.fields`
      - Function: `function.$metadata.return_type`
3. Language / Syntax Changes:
   - I don't want to break backwards compatibility, however there are various small changes which I feel would help unify the language (TODO: Add).
   - Explicit mutable references: `mut &x`
   - Ability to take the underlying Sum Type pointer address. Extremely useful for:
      - Comparison
      - Map Keys
      - Referencing Nodes
      - Preventing Recursion
   - Named parameters & default parameters
   - Uninitialized objects: Consider the possibility of uninitialized objects. This would need to be `unsafe`, and would probably rarely be used. However there are certain areas, for example game development where the lack of this feature could be a non starter. For example when dealing with huge arrays of data structures like game assets or entities.

## Design Details / Status
1. Frontend
   - Scanner (working)
   - Parser (working)
   - AST Generation (working)
   - AST -> SSA (in progress)
   - Optimization passes (planned), operating on SSA form
   - SSA -> Bytecode (planned)
2. Interpreter - Bytecode VM (planned). Some notable advantages to operating as a Bytecode VM:
   - No matter what kind of syntactic sugar or higher level abstractions we start off with in code / AST, once lowered to Bytecode the interpreter will handle it with no modifications.
   - Compile time code execution
   - Close to machine code / registers
3. Backends / Code Generation
   - V (working): AST -> V Generates V code from the AST, useful for testing the parser
   - x64 (planned): Bytecode -> x64 machine code
   - C (under consideration): Bytecode - > C