// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ssa

struct Builder{

}

fn (b Builder) expr(func &Function, expr ast.Expr) Value {
	
}

fn (b Builder) stmt(func &Function, stmt ast.Stmt) {
	match stmt {
		ast.For{

		}
		else {}
	}
}

// TODO: pass Function or BasicBlocks?
fn (b Builder) @for(func &Function, stmt ast.For/*, label*/) {
	mut body_bb := func.add_basic_block()
	mut done_bb := func.add_basic_block()

	mut loop_bb := body_bb
	if stmt.cond !is ast.EmptyStmt {
		loop_bb = func.add_basic_block()
	}
	mut cont_bb := loop_bb
	if stmt.post !is ast.EmptyExpr {
		cont_bb = func.add_basic_block()
	}

	body_bb.set_terminator(bb, BranchTerminator{jmp: header_bb});

	if stmt.cond !is ast.EmptyStmt {
		// cond := b.cond(func, stmt.cond, body_bb, done_bb)
		cond := b.expr(func, stmt.cond)
		body_bb.set_terminator(IfTerminator{val: cond, jmp_true: body_bb, jmp_false: done_bb});
	}

	body_bb.set_terminator(BranchTerminator{jmp: body_bb})

	if s.post !is ast.EmptyExpr {
		b.stmt(func, s.post)
		body_bb.set_terminator(BranchTerminator{jmp: loop_bb})
	}
}

