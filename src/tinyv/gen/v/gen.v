module v

import tinyv.ast
import tinyv.pref
import strings
import time

const(
	tabs = build_tabs(14)
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

fn build_tabs(tabs_len int) []string {
	mut tabs_arr := []string{len: tabs_len, cap: tabs_len}
	mut indent := ''
	for i in 1..tabs_len {
		indent += '\t'
		tabs_arr[i] = indent
	}
	return tabs_arr
}

pub fn new_gen(pref &pref.Preferences) &Gen {
	unsafe { return &Gen{
		pref: pref
		out: strings.new_builder(1000)
		indent: -1
	} }
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
		unsafe { goto start_no_time }
	}
	gt0 := time.ticks()
	start_no_time:
	g.file = file
	g.stmts(g.file.stmts)
	if g.pref.verbose {
		gt1 := time.ticks()
		gen_time := gt1-gt0
		println('gen (v) $file.path: ${gen_time}ms')
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
		ast.Block {
			g.writeln('{')
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
		ast.EmptyStmt {}
		ast.EnumDecl {
			if stmt.attributes.len > 0 {
				g.attributes(stmt.attributes)
				g.writeln('')
			}
			if stmt.is_public {
				g.write('pub ')
			}
			g.write('enum ')
			g.write(stmt.name)
			g.writeln(' {')
			g.indent++
			for field in stmt.fields {
				g.write('$field.name')
				g.expr(field.typ)
				// if field.value != none {
				if field.value !is ast.EmptyExpr {
					g.write(' = ')
					g.expr(field.value)
				}
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
			if stmt.attributes.len > 0 {
				g.attributes(stmt.attributes)
				g.writeln('')
			}
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
			if stmt.return_type !is ast.EmptyExpr {
				g.expr(stmt.return_type)
			}
			// C fn definition
			if stmt.language == .c && stmt.stmts.len == 0 {
				g.writeln('')
			}
			// normal v function
			else {
				g.writeln(' {')
				g.stmts(stmt.stmts)
				g.writeln('}')
			}
		}
		ast.For {
			g.write('for ')
			in_init := g.in_init
			g.in_init = true
			mut infinate := true
			if stmt.init !is ast.EmptyStmt {
				infinate = false
				g.stmt(stmt.init)
			}
			if stmt.cond !is ast.EmptyExpr {
				infinate = false
				g.write('; ')
				g.expr(stmt.cond)
			}
			if stmt.post !is ast.EmptyStmt {
				infinate = false
				g.write('; ')
				g.stmt(stmt.post)
			}
			g.in_init = in_init
			g.writeln(if infinate { '{' } else { ' {'} )
			g.stmts(stmt.stmts)
			g.writeln('}')
		}
		ast.ForIn {
			if stmt.key.len > 0 {
				g.write(stmt.key)
				g.write(', ')
			}
			if stmt.value_is_mut {
				g.write('mut ')
			}
			g.write(stmt.value)
			g.write(' in ')
			g.expr(stmt.expr)
		}
		ast.GlobalDecl {
			g.writeln('__global (')
			g.indent++
			for field in stmt.fields {
				// TODO
				g.write(field.name)
				// if field.value != none {
				if field.value !is ast.EmptyExpr {
					g.write(' = ')
					g.expr(field.value)
				}
				else {
					g.write(' ')
					g.expr(field.typ)
				}
				g.writeln('')
			}
			g.indent--
			g.writeln(')')
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
			if stmt.attributes.len > 0 {
				g.attributes(stmt.attributes)
				g.writeln('')
			}
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
				if field.value !is ast.EmptyExpr {
					g.write(' = ')
					g.expr(field.value)
				}
				if field.attributes.len > 0 {
					g.write(' ')
					g.attributes(field.attributes)
				}
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
				g.write('[]')
				g.expr(expr.typ)
				g.write('{')
				// if expr.init != none {
				if expr.init !is ast.EmptyExpr {
					g.write('init: ')
					g.expr(expr.init)
					g.write(', ')
				}
				// if expr.len != none {
				if expr.len !is ast.EmptyExpr {
					g.write('len: ')
					g.expr(expr.len)
					g.write(', ')
				}
				// if expr.cap != none {
				if expr.cap !is ast.EmptyExpr {
					g.write('cap: ')
					g.expr(expr.cap)
				}
				g.write('}')
			}
		}
		ast.Assoc {
			g.expr(expr.typ)
			g.writeln('{')
			g.indent++
			g.write('...')
			g.expr(expr.expr)
			g.writeln('')
			for field in expr.fields {
				g.write(field.name)
				g.write(': ')
				g.expr(field.value)
			}
			g.writeln('')
			g.indent--
			g.write('}')
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
		ast.EmptyExpr {}
		// TODO: should this be handled like this
		ast.FieldInit {
			g.write(expr.name)
			g.write(': ')
			g.expr(expr.value)
		}
		ast.Fn {
			g.write('fn(')
			for i, arg in expr.args {
				g.write(arg.name)
				g.write(' ')
				g.expr(arg.typ)
				if i < expr.args.len-1 { g.write(', ') }
			}
			g.write(') ')
			// TODO: if expr.return_type
			g.expr(expr.return_type)
			g.writeln(' {')
			g.stmts(expr.stmts)
			g.write('}')
		}
		ast.Ident {
			// if expr.is_mut {
			// 	g.write('mut ')
			// }
			g.write(expr.name)
		}
		ast.If {
			for i, branch in expr.branches {
				if i == 0 {
					if expr.is_comptime { g.write('$') }
					g.write('if ')
				}
				else {
					g.writeln('')
					if expr.is_comptime { g.write('$') }
					g.write('else')
					if branch.cond[0] !is ast.EmptyExpr {
						g.write(' ')
						if expr.is_comptime { g.write('$') }
						g.write('if ')
					}
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
			//g.writeln('// mapinit: $expr.keys.len')
			// long syntax
			if expr.key_type !is ast.EmptyExpr {
				g.write('map[')
				g.expr(expr.key_type)
				g.write(']')
				g.expr(expr.value_type)
				g.write('{}')
			}
			// shorthand syntax
			else if expr.keys.len > 0 {
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
			// empty {}
			else {
				g.write('{}')
			}
		}
		ast.Match {
			g.write('match ')
			g.expr(expr.expr)
			g.writeln(' {')
			g.indent++
			for branch in expr.branches {
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
				g.writeln('}')
			}
			g.indent--
			g.write('}')
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
			// g.write('..')
			g.write(expr.op.str())
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
			// with field names
			if expr.fields.len > 0 && expr.fields[0].name.len > 0 {
				g.writeln('{')
				for i, field in expr.fields {
					g.write('\t')
					g.write(field.name)
					g.write(': ')
					g.expr(field.value)
					if i < expr.fields.len-1 { g.writeln(',') } else { g.writeln('') }
				}
			}
			// without field names, or empty init `Struct{}`
			else {
				g.write('{')
				for i, field in expr.fields {
					g.expr(field.value)
					if i < expr.fields.len-1 { g.write(', ') }
				}
			}
			g.write('}')
		}
		ast.TypeOf {
			g.write('typeof(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.Unsafe {
			// some sort of fuckery
			// if expr.stmts.len == 1 && expr.stmts[0] is ast.ExprStmt {
			// 	g.write('unsafe(')
			// 	g.expr(expr.stmts[0])
			// 	g.write(')')
			// }
			g.writeln('unsafe {')
			g.stmts(expr.stmts)
			g.write('}')
		}
		// Type Nodes
		// TODO: I really would like to allow matching the nested sumtypes like TS
		ast.Type {
			match expr {
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
				//ast.Type {}
			}
		}
	}
}

fn (mut g Gen) attributes(attributes []ast.Attribute) {
	g.write('[')
	for i, attribute in attributes {
		g.write(attribute.name)
		if attribute.value.len > 0 {
			g.write(": '")
			g.write(attribute.value)
			g.write("'")
		}
		if i < attributes.len-1 {
			g.write('; ')
		}
	}
	g.write(']')
}

[inline]
fn (mut g Gen) write(str string) {
	if g.on_newline {
		g.out.write_string(tabs[g.indent])
	}
	g.out.write_string(str)
	g.on_newline = false
}

[inline]
fn (mut g Gen) writeln(str string) {
	if g.on_newline {
		g.out.write_string(tabs[g.indent])
	}
	g.out.writeln(str)
	g.on_newline = true
}

pub fn (g &Gen) print_output() {
	println(g.out)
}
