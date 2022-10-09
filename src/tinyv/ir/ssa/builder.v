module ssa

struct Builder{

}

// TODO: pass Function or BasicBlocks?
fn (b Builder) @for(func Function, stmt ast.For/*, label*/) {
	mut body_bb := func.add_basic_block()

	mut loop_bb := body_bb
	if stmt.cond !is ast.EmptyStmt {
		loop_bb = func.add_basic_block()
	}
}

