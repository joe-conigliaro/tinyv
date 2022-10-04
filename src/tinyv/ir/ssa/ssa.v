// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ssa


// Instruction
type Instruction = Call | Prefix

struct Call{}
struct Prefix{}

pub struct BasicBlock {
	Predecessors []&BasicBlock
	Successors   []&BasicBlock
	// TODO:
	Instructions []Instructions
}
