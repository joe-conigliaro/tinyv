// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ssa


type Stmt = Call | Prefix

struct Function{}
struct Call{}
struct Prefix{}

pub struct BasicBlock {
mut:
	predecessors []&BasicBlock
	successors   []&BasicBlock
	// TODO:
	// statements []Stmt
	definitions     map[string]Value
	incomplete_phis map[string]Phi
	sealed bool
}

struct Operand {}

type None = u8
type Value = None | Variable | Phi

struct Variable {}

struct Phi {
mut:
	block    &BasicBlock
	users    []Value
	operands []Value
}

fn (f Function) add_base_block() {
	
}

// To construct the SSA, we will be using the algorithm's described in:
// [0] - Simple and Efficient Construction of Static Single Assignment Form
//     - https://pp.info.uni-karlsruhe.de/uploads/publikationen/braun13cc.pdf
// SSA will be constructed directly from AST without needing an existing CFG
// We will try to employ on the fly optimization's while constructing it:
//   * Remove trivial φ functions
//   * Arithmetic simplification
//   * Common subexpression elimination
//   * Constant folding
//   * Copy propagation


// Rough translation of pseudocode algorithms listed in [0]

// Algorithm 1: Implementation of local value numbering
fn (mut block BasicBlock) write_variable(name string, value Value) {
	// currentDef[variable][block] = value
	block.definitions[name] = value
}

fn (mut block BasicBlock) read_variable(variable string) Value {
	// if currentDef[variable] contains block {
		// local value numbering
		// return currentDef[variable][block]
	// }
	// global value numbering
	// return read_variable_recursive(variable, block)
	// =======================
	// local value numbering
	return block.definitions[variable] or {
		// global value numbering
		block.read_variable_recursive(variable)
	}
}

// Algorithm 2: Implementation of global value numbering
fn (mut block BasicBlock) read_variable_recursive(variable string) Value {
	// if block not in sealedBlocks {
	val := if !block.sealed {
		// Incomplete CFG
		// val = new Phi(block)
		// incomplete_phis[block][variable] = val
		val0 := Phi{block: unsafe { &block }}
		block.incomplete_phis[variable] = val0
		Value(val0)
	} else if block.predecessors.len == 1 {
		// Optimize the common case of one predecessor: No phi needed
		// val = read_variable(variable, block.predecessors[0])
		block.predecessors[0].read_variable(variable)
	} else {
		// Break potential cycles with operandless phi
		// val = new Phi(block)
		mut val0 := Phi{block: unsafe { &block }}
		block.write_variable(variable, val0)
		val0.add_operands(variable)
	}
	block.write_variable(variable, val)
	return val
}
fn (mut phi Phi) add_operands(variable string) Value {
	// Determine operands from predecessors
	for mut pred in phi.block.predecessors {
		// phi.appendOperand(read_variable(variable, pred))
		phi.operands << pred.read_variable(variable)
	}
	return try_remove_trivial_phi(phi)
}

// Algorithm 3: Detect and recursively remove a trivial φ function
fn try_remove_trivial_phi(phi Phi) Value {
	mut same := Value(None(0))
	for op in phi.operands {
		// if op == same || op == phi {
		// 	continue // Unique value or self−reference
		// }
		if op == same {
			continue // Unique value or self−reference
		}
		if op is Phi {
			if op == phi {
				continue
			}
		}
		if same !is None {
			return phi // The phi merges at least two values: not trivial
		}
		same = op
	}
	if same is None {
		// same = Undef() // The phi is unreachable or in the start block
		// TODO:
	}
	// users = phi.users.remove(phi) // Remember all users except the phi itself
	mut users := []Value{}
	for user in phi.users {
		match user {
			Phi {
				if user != phi {
					users << user
				}
			}
			else {
				users << user
			}
		}
	}
	// phi.replaceBy(same) // Reroute all uses of phi to same and remove phi
	// Try to recursively remove all phi users, which might have become trivial
	for use in users {
		if use is Phi {
			try_remove_trivial_phi(use)
		}
	}
	return same
}

// Algorithm 4: Handling incomplete CFGs
fn (mut block BasicBlock) seal() {
	// for variable in incomplete_phis[block] {
	for variable, _ in block.incomplete_phis {
		// add_phi_operands(variable, incomplete_phis[block][variable])
		block.incomplete_phis[variable].add_operands(variable)
	}
	// sealedBlocks.add(block)
	block.sealed = true
}

// Algorithm 5: Remove superfluous φ functions in case of irreducible data flow.
// fn removeRedundantPhis(phi_functions) {
// 	sccs = computePhiSCCs(inducedSubgraph(phi_functions))
// 	for scc in topologicalSort(sccs) {
// 		processSCC(scc)
// 	}
// }

// fn processSCC(scc) {
// 	if scc.len == 1 {
// 		 return // we already handled trivial φ functions
// 	}
// 	mut inner := set()
// 	mut outerOps := set()
// 	for phi in scc {
// 		isInner = true
// 		for operand in phi.getOperands() {
// 			if operand not in scc {
// 				isInner = False
// 			}
// 		if isInner {
// 			inner.add(phi)
// 		}
// 	}
// 	if outerOps.len == 1 {
// 		replaceSCCByValue(scc, outerOps.pop())
// 	} else if outerOps.len > 1 {
// 		removeRedundantPhis(inner)
// 	}
// }
