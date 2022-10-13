// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ssa

// To construct the SSA, we will be using the algorithm's described in:
// 1. Simple and Efficient Construction of Static Single Assignment Form
// 	  https://pp.info.uni-karlsruhe.de/uploads/publikationen/braun13cc.pdf
// SSA will be constructed directly from AST without needing an existing CFG
// We will try to employ on the fly optimization's while constructing it:
//   * Remove trivial φ functions
//   * Arithmetic simplification
//   * Common subexpression elimination
//   * Constant folding
//   * Copy propagation

type Terminator = BranchTerminator | IfTerminator | MatchTerminator | ReturnTerminator
type Instruction = Call | Prefix
// type Value/Variable = int // TODO


struct Function{
	basic_blocks []&BasicBlock
}

// Terminators
struct BranchTerminator{
	jmp &BasicBlock
}

struct IfTerminator {
	val       Value
	jmp_true  &BasicBlock
	jmp_false &BasicBlock
}

struct MatchTerminator {}

struct ReturnTerminator {}

// Instructions

struct Call{}
struct Prefix{}


pub struct BasicBlock {
mut:
	index		 		int
    // immediate_dominator &BasicBlock
   	predecessors 		[]&BasicBlock
	// successors   		[]&BasicBlock
    terminator			Terminator;
    // phi_nodes;
    instructions        []Instruction;
}


fn add_edge(from &BasicBlock, to &BasicBlock) {
	// from.successors << to
	// from.successor = to
	to.predecessors << from
}

fn (f Function) add_basic_block(/* dominator &BasicBlock*/) &BasicBlock {
	b := &BasicBlock{
		index:   f.basic_blocks.len,
		parent:  f,
		// immediate_dominator: dominator;
	}
	f.basic_blocks << b
	return b
}