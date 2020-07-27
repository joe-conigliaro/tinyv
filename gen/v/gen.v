module v

import ast
import pref
import strings
import time

const(
	tabs = build_tabs()
)

struct Gen {
	pref       &pref.Preferences
mut:
	file       ast.File
	out        strings.Builder 
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

pub fn new_gen(pref &pref.Preferences) &Gen {
	return &Gen{
		pref: pref
		out: strings.new_builder(1000)
		indent: -1
	}
}

pub fn (mut g Gen) reset() {
	g.out.go_back_to(0)
	g.indent = -1
	g.on_newline = false
}

pub fn (mut g Gen) gen(file ast.File) {
	// clear incase we are reusing gen instance
	if g.out.len > 1 {
		g.reset()
	}
	if !g.pref.verbose {
		goto start_no_time
	}
	gt0 := time.ticks()
	start_no_time:
	g.file = file
	g.stmts(g.file.stmts)
	if g.pref.verbose {
		gt1 := time.ticks()
		gen_time := gt1-gt0
		println('gen (v) for $file.path: ${gen_time}ms')
	}
}

fn (mut g Gen) stmts(stmts []ast.Stmt) {
	for stmt in stmts {
		g.stmt(stmt)
	}
}

fn (mut g Gen) stmt(stmt ast.Stmt) {
	g.indent++
	match stmt {
		ast.Assert {
			g.write('assert ')
			g.expr(stmt.expr)
		}
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
			g.write('[')
			g.write(stmt.name)
			g.writeln(']')
		}
		ast.ComptimeIf {
			g.write('\$if ')
			g.expr(stmt.cond)
			g.writeln(' {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
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
		ast.Defer {
			g.write('defer {')
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
		ast.Directive {
			g.write('#')
			g.write(stmt.name)
			g.write(' ')
			g.writeln(stmt.value)
		}
		ast.EnumDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.write('enum ')
			g.write(stmt.name)
			g.writeln(' {')
			g.indent++
			for field in stmt.fields {
				g.write('$field.name ')
				g.expr(field.typ)
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
			if !g.in_init { g.writeln('') }
		}
		ast.FlowControl {
			g.writeln(stmt.op.str())
		}
		ast.FnDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.write('fn ')
			if stmt.is_method {
				g.write('(')
				g.write(stmt.receiver.name)
				g.write(' ')
				g.expr(stmt.receiver.typ)
				g.write(') ')
			}
			g.write(stmt.name)
			g.write('(')
			for i,arg in stmt.args {
				g.write(arg.name)
				g.write(' ')
				g.expr(arg.typ)
				if i < stmt.args.len-1 { g.write(', ') }
			}
			g.write(') ')
			// TODO: if stmt.return_type
			g.expr(stmt.return_type)
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
		ast.ForIn {
			if stmt.key.len > 0 {
				g.write(stmt.key)
				g.write(', ')
			}
			g.write(stmt.value)
			g.write(' in ')
			g.expr(stmt.expr)
		}
		ast.GlobalDecl {
			g.write('global ')
			g.write(stmt.name)
			// if stmt.value != none {
				g.write(' = ')
				g.expr(stmt.value)
			// }
			g.writeln('')
		}
		ast.Import {
			g.write('import ')
			g.write(stmt.name)
			if stmt.is_aliased {
				g.write(' as ')
				g.write(stmt.alias)
			}
			g.writeln('')
		}
		ast.InterfaceDecl {
			if stmt.is_public {
				g.write('pub ')
			}
			g.write('interface ')
			g.write(stmt.name)
			// g.writeln(' {')
			// TODO: methods
			g.writeln(' { /* TODO */ }')
		}
		ast.Label {
			g.write(stmt.name)
			g.writeln(':')
		}
		ast.Module {
			g.write('module ')
			g.writeln(stmt.name)
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
			g.write('struct ')
			g.write(stmt.name)
			g.writeln(' {')
			g.indent++
			for field in stmt.fields {
				g.write(field.name)
				g.write(' ')
				g.expr(field.typ)
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
			g.write('type ')
			g.write(stmt.name)
			if stmt.variants.len > 0 {
				g.write(' = ')
				//for i, vairant in stmt.variants {
				for i, variant in stmt.variants {
					g.expr(variant)
					if i < stmt.variants.len-1 {
						g.write(' | ')
					}
				}
			}
			else {
				g.write(' ')
				g.expr(stmt.parent_type)
			}
			g.writeln('')
		}
	}
	g.indent--
	// g.writeln('')
}

fn (mut g Gen) expr(expr ast.Expr) {
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
		ast.Cast {}
		ast.Call {
			g.expr(expr.lhs)
			g.write('(')
			for i, arg in expr.args {
				// if arg.is_mut {
				// 	g.write('mut ')
				// }
				g.expr(arg)
				if i < expr.args.len-1 { g.write(', ') }
			}
			g.write(')')
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
					g.writeln('')
					g.write('else ')
					// TODO: if no cond is else
					// if branch.cond != none {
						g.write('if ')
					// }
				}
				g.expr(branch.cond[0])
				g.writeln(' {')
				g.stmts(branch.stmts)
				g.write('}')
			}
		}
		ast.IfGuard {
			g.write('/* IfGuard */ ')
			g.stmt(expr.stmt)
		}
		ast.Index {
			g.expr(expr.lhs)
			g.write('[')
			g.expr(expr.expr)
			g.write(']')
		}
		ast.Infix {
			g.expr(expr.lhs)
			g.write(' ')
			g.write(expr.op.str())
			g.write(' ')
			g.expr(expr.rhs)
		}
		ast.List {
			for i, x in expr.exprs {
				g.expr(x)
				if i < expr.exprs.len-1 { g.write(', ') }
			}
		}
		ast.Literal {
			if expr.kind == .char {
				g.write('`')
				g.write(expr.value)
				g.write('`')
			}
			else if expr.kind == .string {
				g.write("'")
				g.write(expr.value)
				g.write("'")
			}
			else {
				g.write(expr.value)
			}
		}
		ast.MapInit {
			g.write('{')
			for i, key in expr.keys {
				val := expr.vals[i]
				g.expr(key)
				g.write(': ')
				g.expr(val)
				if i < expr.keys.len-1 { g.write(', ') }
			}
			g.write('}')
		}
		ast.Match {
			g.write('match ')
			g.expr(expr.expr)
			g.write(' {')
			g.indent++
			for branch in expr.branches {
				g.writeln('')
				if branch.cond.len > 0 {
					for j, cond in branch.cond {
						g.expr(cond)
						if j < branch.cond.len-1 { g.write(', ') }
					}
				}
				else {
					g.write('else')
				}
				g.writeln(' {')
				g.stmts(branch.stmts)
				g.write('}')
			}
			g.indent--
		}
		ast.Modifier {
			g.write(expr.kind.str())
			g.write(' ')
			g.expr(expr.expr)
		}
		ast.None {
			g.write('none')
		}
		ast.Or {
			g.expr(expr.expr)
			g.writeln(' or {')
			g.stmts(expr.stmts)
			g.write('}')
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
		ast.SizeOf {
			g.write('sizeof(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.StructInit {
			g.expr(expr.typ)
			if expr.fields.len == 0 {
				g.write('{')
			}
			else {
				g.writeln('{')
			}
			for i, field in expr.fields {
				g.write('\t')
				g.write(field.name)
				g.write(': ')
				g.expr(field.value)
				if i < expr.fields.len-1 { g.writeln(',') } else { g.writeln('') }
			}
			g.write('}')
		}
		ast.TypeOf {
			g.write('typeof(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.Unsafe {
			g.writeln('unsafe {')
			g.stmts(expr.stmts)
			g.write('}')
		}
		// Type Nodes
		ast.ArrayType {
			g.write('[]')
			g.expr(expr.elem_type)
		}
		ast.FnType {
			g.write('fn(')
			for i, arg in expr.args {
				g.expr(arg.typ)
				if i < expr.args.len-1 { g.write(', ') }
			}
			g.write(')')
			g.expr(expr.return_type)
		}
		ast.MapType {
			g.write('map[')
			g.expr(expr.key_type)
			g.write(']')
			g.expr(expr.value_type)
		}
		ast.TupleType {
			g.write('(')
			for i, x in expr.types {
				g.expr(x)
				if i < expr.types.len-1 { g.write(', ') } 
			}
			g.write(')')
		}
		// TODO: v bug since all variants are accounted for
		// this should not be required?
		ast.Type {}
	}
}

[inline]
fn (mut g Gen) write(str string) {
	if g.on_newline {
		g.out.write(tabs[g.indent])
	}
	g.out.write(str)
	g.on_newline = false
}

[inline]
fn (mut g Gen) writeln(str string) {
	if g.on_newline {
		g.out.write(tabs[g.indent])
	}
	g.out.writeln(str)
	g.on_newline = true
}

pub fn (g &Gen) print_output() {
	println(g.out)
}
