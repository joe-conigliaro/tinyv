module v

import ast

struct Gen {
	file ast.File
}

pub fn gen(file ast.File) {
	g := Gen{file: file}
	g.gen()
}

fn (g &Gen) gen() {
	g.stmts(g.file.stmts)
}

fn (g &Gen) stmts(stmts []ast.Stmt) {
	for stmt in stmts {
		g.stmt(stmt)
	}
}

fn (g &Gen) stmt(stmt ast.Stmt) {
	match stmt {
		ast.Assign {}
		ast.Attribute {
			g.writeln('[$stmt.name]')
		}
		ast.Block {}
		ast.ComptimeIf {}
		ast.ConstDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.writeln('const (')
			for field in stmt.fields {
				g.write('\t$field.name type')
				g.write(' = ')
				g.expr(field.value)
				g.writeln('')
			}
			g.writeln(')')
		}
		ast.EnumDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.writeln('enum $stmt.name {')
			for field in stmt.fields {
				g.writeln('\t$field.name type')
				// if field.value != none {
				// 	g.write(' = ')
				// 	g.expr(field.value)
				// }
			}
			g.writeln('}')
		}
		ast.ExprStmt {
			// g.expr(stmt.expr)
			// g.writeln('')
		}
		ast.FlowControl {
			g.writeln(stmt.op.str())
		}
		ast.FnDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.write('fn ')
			// if stmt.is_method {
			g.write('${stmt.name}(')
			for i,arg in stmt.args {
				g.write('$arg.name type')
				if i < stmt.args.len-1 { g.write(',') }
			}
			g.write(')')
			// if stmt.return_type
			g.writeln(' {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
		ast.For {
			g.write('for ')
			g.stmt(stmt.init)
			g.write('; ')
			g.expr(stmt.cond)
			g.write('; ')
			g.stmt(stmt.post)
			g.writeln(' {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
		ast.GlobalDecl {
			g.write('global $stmt.name')
			// if g.expr != none {
			// 	g.write(' = ')
			// 	g.expr(g.expr)
			// }
		}
		ast.Import {
			g.write('import $stmt.name')
			if stmt.alias.len > 0 {
				g.write(' as $stmt.alias')
			}
			g.writeln('')
		}
		ast.Module {
			g.writeln('module $stmt.name')
		}
		ast.Return {
			g.write('return ')
			g.expr(stmt.expr)
			g.writeln('')
		}
		ast.StructDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.writeln('struct $stmt.name {')
			for field in stmt.fields {
				g.writeln('\t$field.name type')
				// if field.value != none {
				// 	g.write(' = ')
				// 	g.expr(field.value)
				// }
			}
			g.writeln('}')
		}
		ast.TypeDecl {}
		ast.Unsafe {
			g.writeln('unsafe {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
	}
	// g.writeln('')
}

fn (g &Gen) expr(expr ast.Expr) {
	match expr {
		ast.ArrayInit {}
		ast.BoolLiteral {
			if expr.value {
				g.write('true')
			}
			else {
				g.write('false')
			}
		}
		ast.Cast {}
		ast.Call {
			g.expr(expr.lhs)
			g.write('(')
			for i, arg in expr.args {
				if arg.is_mut {
					g.write('mut ')
				}
				g.expr(arg.expr)
				if i < expr.args.len-1 { g.write(', ') }
			}
			g.write(')')
		}
		ast.CharLiteral {
			g.write('`$expr.value`')
		}
		ast.Ident {
			if expr.is_mut {
				g.write('mut ')
			}
			g.write(expr.name)
		}
		ast.If {
			// for branch in stmt.branches {
			// 	g.write('if ')
			// 	g.expr(expr.cond)
			// 	g.writeln(' {')
			// 	g.stmts(expr.stmts)
			// 	g.writeln('}')
			// }
		}
		ast.IfGuard {}
		ast.Index {
			g.expr(expr.lhs)
			g.write('[')
			g.expr(expr.expr)
			g.write(']')
		}
		ast.Infix {
			g.expr(expr.lhs)
			g.write(' $expr.op ')
			g.expr(expr.rhs)
		}
		ast.List {
			for i, x in expr.exprs {
				g.expr(x)
				if i < expr.exprs.len-1 { g.write(', ') }
			}
		}
		ast.Match {}
		ast.None {
			g.write('none')
		}
		ast.NumberLiteral {
			g.write(expr.value)
		}
		ast.Paren {}
		ast.Postfix {
			g.expr(expr.expr)
			g.write(expr.op.str())
		}
		ast.Prefix {
			g.write(expr.op.str())
			g.expr(expr.expr)
		}
		ast.Range {
			g.expr(expr.start)
			g.write('..')
			g.expr(expr.end)
		}
		ast.Selector {
			g.expr(expr.lhs)
			g.write('.')
			g.expr(expr.rhs)
		}
		ast.StringLiteral {
			g.write("'$expr.value'")
		}
		ast.StructInit {}
	}
}

fn (g &Gen) write(str string) {
	// print(str)
}

fn (g &Gen) writeln(str string) {
	// println(str)
}