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
		ast.Attribute {}
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
		ast.ExprStmt {}
		ast.FlowControl {}
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
		ast.For {}
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
		ast.Return {}
		ast.StructDecl {}
		ast.TypeDecl {}
		ast.Unsafe {}
	}
}

fn (g &Gen) expr(expr ast.Expr) {}

fn (g &Gen) write(str string) {
	print(str)
}

fn (g &Gen) writeln(str string) {
	println(str)
}