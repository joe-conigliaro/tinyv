// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ssa

struct Builder {
	current_fn &Function
	current_bb &BasicBlock
}

fn (b Builder) add_basic_block(name string) BasicBlock {
	return b.current_fn.add_basic_block('${b.current_bb.name}.${name}')
}

fn (b Builder) expr(expr ast.Expr) Value {
	match expr {
		ast.CallExpr {}
		else {}
	}
}

fn (b Builder) stmt(stmt ast.Stmt) {
	match stmt {
		ast.ForStmt {}
		else {}
	}
}

fn (b Builder) if_expr(if_expr ast.IfExpr) {
	if_bb := b.add_basic_block('if')
	else_bb := b.add_basic_block('if.else')
	endif_bb := b.add_basic_block('if.endif')
}

fn (b Builder) for_stmt(stmt ast.ForStmt) {
	mut bb_body := b.add_basic_block('for.body')
	mut bb_done := b.add_basic_block('for.done')

	mut bb_loop := bb_body
	if stmt.cond !is ast.EmptyStmt {
		bb_loop = b.add_basic_block('for.loop')
	}
	mut bb_cont := bb_loop
	if stmt.post !is ast.EmptyExpr {
		bb_cont = b.add_basic_block('for.post')
	}

	// bb_body.set_terminator(bb, BranchTerminator{bb: bb_header})
	bb_body.set_terminator(bb, BranchTerminator{ bb: bb_loop })

	if stmt.cond !is ast.EmptyStmt {
		// cond := b.cond(stmt.cond, body_bb, done_bb)
		cond := b.expr(stmt.cond)
		bb_body.set_terminator(IfTerminator{ val: cond, bb_true: bb_body, bb_false: bb_done })
	}

	body_bb.set_terminator(BranchTerminator{ bb: bb_body })

	if s.post !is ast.EmptyExpr {
		b.stmt(func, s.post)
		body_bb.set_terminator(BranchTerminator{ bb: bb_loop })
	}
}
