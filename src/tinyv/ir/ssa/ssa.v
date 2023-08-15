// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
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
type Instruction = Call | Prefix | Terminator
type Variable = u32

// type Value = A | B // TODO
struct Value {
	// kind   ValueKind
	parent &Function
	// name   string
	users []&Instruction
	typ   types.Type
}

struct Phi {
	bb &BasicBlock
}

struct Function {
	bb []&BasicBlock
}

// Terminators
struct BranchTerminator {
	bb &BasicBlock
}

struct IfTerminator {
	val      Value
	bb_true  &BasicBlock
	bb_false &BasicBlock
}

struct MatchTerminator {}

struct ReturnTerminator {}

// Instructions

struct Call {}

struct Prefix {}

pub struct BasicBlock {
mut:
	parent_fn    &Function
	index        int
	name         string
	variables    []Value
	predecessors []&BasicBlock
	// immediate_dominator &BasicBlock
	// successors   		[]&BasicBlock
	// phi_nodes
	instructions []Instruction
	terminator   Terminator
	is_sealed    bool
}

fn add_edge(from &BasicBlock, to &BasicBlock) {
	// from.successors << to
	// from.successor = to
	to.predecessors << from
}

fn (f &Function) add_basic_block(name string) &BasicBlock {
	b := &BasicBlock{
		parent_fn: f
		index: f.basic_blocks.len
		name: name
	}
	f.basic_blocks << b
	return b
}

fn (bb &BasicBlock) new_variable() Variable {
	return Variable(bb.variables.len)
}

// fn (bb BasicBlock) write_variable(var Variable, val Value) {}

// add a new variable and save it to it. returns the new var
fn (bb &BasicBlock) write_variable_new(val Value) Variable {
	var := bb.new_variable()
	bb.variables << val
	return var
}

fn (bb &BasicBlock) read_variable(var Variable) Value {
	return bb.variables[var] or { bb.read_variable_recursive(var) }
}

// readVariableRecursive(variable, block):
// if block not in sealedBlocks:
// 	# Incomplete CFG
// 	val ← new Phi(block)
// 	incompletePhis[block][variable] ← val
// else if |block.preds| = 1:
// 	# Optimize the common case of one predecessor: No phi needed
// 	val ← readVariable(variable, block.preds[0])
// else:
// 	# Break potential cycles with operandless phi
// 	val ← new Phi(block)
// 	writeVariable(variable, block, val)
// 	val ← addPhiOperands(variable, val)
// 	writeVariable(variable, block, val)
// return val

fn (bb &BasicBlock) read_variable_recursive(var Variable) Value {
	val := if !bb.is_sealed {
		val := Phi{
			basic_block: bb
		}
		//
	} else if bb.predecessors.len == 1 {
		bb.predecessors[0].read_variable(var)
	} else {
	}
}

fn (bb &BasicBlock) add_instruction(inst Instruction) Value {
	inst.set_block(bb)
	bb.instructions << inst
	return inst.value()
}

fn (bb &BasicBlock) set_terminator(inst Terminator) Value {
	bb.terminator = inst
	return bb.add_instruction(inst)
}
