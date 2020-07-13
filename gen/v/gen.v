module v

import ast
import pref
import strings

const(
	tabs = build_tabs()
)

struct Gen {
	prefs      &pref.Preferences
mut:
	file       ast.File
	out		   strings.Builder 
	indent     int
	on_newline bool
	in_init    bool
}

fn build_tabs() []string {
	mut tabs := []string{len: 10, cap: 10}
	mut indent := ''
	for i in 1..10 {
		indent += '\t'
		tabs[i] = indent
	}
	return tabs
}

pub fn new_gen(prefs &pref.Preferences) &Gen {
	gen := &Gen{
		prefs: prefs
		out: strings.new_builder(1000)
		indent: -1
	}
	return gen
}

pub fn (mut g Gen) reset() {
	g.out.go_back_to(0)
	g.indent = -1
	g.on_newline = false
}

pub fn (g &Gen) gen(file ast.File) {
	// clear incase we are reusing gen instance
	if g.out.len > 1 {
		g.reset()
	}
	g.file = file
	g.stmts(g.file.stmts)
}

fn (g &Gen) stmts(stmts []ast.Stmt) {
	for stmt in stmts {
		g.stmt(stmt)
	}
}

fn (g &Gen) stmt(stmt ast.Stmt) {
	g.indent++
	match stmt {
		ast.Assign {
			for i, l in stmt.lhs {
				g.expr(l)
				if i < stmt.lhs.len-1 { g.write(', ') }
			}
			g.write(' $stmt.op ')
			for i, r in stmt.rhs {
				g.expr(r)
				if i < stmt.lhs.len-1 { g.write(', ') }
			}
			if !g.in_init { g.writeln('') }
		}
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
			g.indent++
			for field in stmt.fields {
				g.write(field.name)
				g.write(' = ')
				g.expr(field.value)
				g.writeln('')
			}
			g.indent--
			g.writeln(')')
		}
		ast.EnumDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.writeln('enum $stmt.name {')
			g.indent++
			for field in stmt.fields {
				g.write('$field.name #type#')
				// if field.value != none {
					g.write(' = ')
					g.expr(field.value)
				// }
				g.writeln('')
			}
			g.indent--
			g.writeln('}')
		}
		ast.ExprStmt {
			g.expr(stmt.expr)
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
			in_init := g.in_init
			g.in_init = true
			g.stmt(stmt.init)
			g.write('; ')
			g.expr(stmt.cond)
			g.write('; ')
			g.stmt(stmt.post)
			g.in_init = in_init
			g.writeln(' {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
		ast.GlobalDecl {
			g.write('global $stmt.name')
			// if stmt.value != none {
				g.write(' = ')
				g.expr(stmt.value)
			// }
		}
		ast.Import {
			g.write('import $stmt.name')
			if stmt.is_aliased {
				g.write(' as $stmt.alias')
			}
			g.writeln('')
		}
		ast.Module {
			g.writeln('module $stmt.name')
		}
		ast.Return {
			g.write('return ')
			for i, x in stmt.exprs {
				g.expr(x)
				if i < stmt.exprs.len-1 { g.write(', ') }
			}
			g.writeln('')
		}
		ast.StructDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.writeln('struct $stmt.name {')
			g.indent++
			for field in stmt.fields {
				g.write('$field.name #type#')
				// if field.value != none {
				// 	g.write(' = ')
				// 	g.expr(field.value)
				// }
				g.writeln('')
			}
			g.indent--
			g.writeln('}')
		}
		ast.TypeDecl {
			g.write('type $stmt.name')
			if stmt.variants.len > 0 {
				g.write(' =')
				for i, vairant in stmt.variants {
					g.write(' #type#')
					if i < stmt.variants.len-1 {
						g.write(' |')
					}
				}
			}
			else {
				g.write(' #type#')
			}
			g.writeln('')
		}
		ast.Unsafe {
			g.writeln('unsafe {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
	}
	g.indent--
	// g.writeln('')
}

fn (g &Gen) expr(expr ast.Expr) {
	match expr {
		ast.ArrayInit {
			if expr.exprs.len > 0 {
				g.write('[')
				for i, x in expr.exprs {
					g.expr(x)
					if i < expr.exprs.len-1 { g.write(', ') }
				}
				g.write(']')
			}
			else {
				g.write('[]#type#{')
				// if expr.init != none {
					g.write('init: ')
					g.expr(expr.init)
					g.write(', ')
				// }
				// if expr.len != none {
					g.write('len: ')
					g.expr(expr.len)
					g.write(', ')
				// }
				// if expr.cap != none {
					g.write('cap: ')
					g.expr(expr.cap)
				// }
				g.write('}')
			}
		}
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
			for i, branch in expr.branches {
				if i == 0 {
					g.write('if ')
				}
				else {
					g.write('else ')
					// TODO: if no cond is else
					// if branch.cond != none {
						g.write('if ')
					// }
				}
				in_init := g.in_init
				g.in_init = true
				g.expr(branch.cond)
				g.in_init = in_init
				g.writeln(' {')
				g.stmts(branch.stmts)
				g.writeln('}')
			}
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
		ast.Paren {
			g.write('(')
			g.expr(expr.expr)
			g.write(')')
		}
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
		ast.StructInit {
			if expr.fields.len == 0 {
				g.write('#type#{')
			}
			else {
				g.writeln('#type#{')
			}
			for i, field in expr.fields {
				g.write('\t$field.name: ')
				g.expr(field.value)
				if i < expr.fields.len-1 { g.writeln(',') } else { g.writeln('') }
			}
			g.write('}')
		}
	}
}

fn (g &Gen) write(str string) {
	if g.on_newline {
		g.out.write(tabs[g.indent])
	}
	g.out.write(str)
	g.on_newline = false
}

fn (g &Gen) writeln(str string) {
	if g.on_newline {
		g.out.write(tabs[g.indent])
	}
	g.out.writeln(str)
	g.on_newline = true
}

pub fn (g &Gen) print_output() {
	println(g.out)
}
