// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module v

import tinyv.ast
import tinyv.pref
import strings
import time

const(
	tabs = build_tabs(16)
	// tabs = build_tabs(24)
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

pub fn new_gen(prefs &pref.Preferences) &Gen {
	unsafe { return &Gen{
		pref: prefs
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
	mut sw := time.new_stopwatch()
	start_no_time:
	g.file = file
	g.stmts(g.file.stmts)
	if g.pref.verbose {
		gen_time := sw.elapsed()
		println('gen (v) $file.path: ${gen_time.milliseconds()}ms (${gen_time.microseconds()}us)')
	}
}

fn (mut g Gen) stmts(stmts []ast.Stmt) {
	for stmt in stmts {
		g.indent++
		g.stmt(stmt)
		g.indent--
	}
}

fn (mut g Gen) stmt(stmt ast.Stmt) {
	match stmt {
		ast.AssertStmt {
			g.write('assert ')
			g.expr(stmt.expr)
			g.writeln('')
		}
		ast.AssignStmt {
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
		ast.DeferStmt {
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
		ast.FlowControlStmt {
			if stmt.label.len > 0 {
				g.write(stmt.op.str())
				g.write(' ')
				g.writeln(stmt.label)
			} else {
				g.writeln(stmt.op.str())
			}
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
			if stmt.language != .v {
				g.write(stmt.language.str())
				g.write('.')
			}
			g.write(stmt.name)
			if stmt.signature.generic_params.len > 0 {
				g.generic_list(stmt.signature.generic_params)
			}
			g.write('(')
			for i,arg in stmt.signature.params {
				if arg.name.len > 0 {
					g.write(arg.name)
					g.write(' ')
				}
				g.expr(arg.typ)
				if i < stmt.signature.params.len-1 { g.write(', ') }
			}
			g.write(') ')
			if stmt.signature.return_type !is ast.EmptyExpr {
				g.expr(stmt.signature.return_type)
			}
			// C fn definition |
			// v fns with compiler implementations eg. `pub fn (a array) filter(predicate fn (voidptr) bool) array`
			// NOTE: can we use generics for these fns, also make sure we parser error for normal fns without a body
			// TODO: is it the correct way to handle those cases (the fn definitions, not this code)?
			if /*stmt.language == .c &&*/ stmt.stmts.len == 0 {
				g.writeln('')
			}
			// normal v function
			else {
				g.writeln(' {')
				g.stmts(stmt.stmts)
				g.writeln('}')
			}
		}
		ast.ForStmt {
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
		ast.ImportStmt {
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
		ast.LabelStmt {
			g.write(stmt.name)
			g.writeln(':')
			if stmt.stmt != ast.empty_stmt {
				g.stmt(stmt.stmt)
			}
		}
		ast.ModuleStmt {
			g.write('module ')
			g.writeln(stmt.name)
		}
		ast.ReturnStmt {
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
			if stmt.language != .v {
				g.write(stmt.language.str())
				g.write('.')
			}
			g.write(stmt.name)
			if stmt.generic_params.len > 0 {
				g.generic_list(stmt.generic_params)
			}
			if stmt.fields.len > 0 { g.writeln(' {') } else { g.write(' {') }
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
	// g.writeln('')
}

fn (mut g Gen) expr(expr ast.Expr) {
	match expr {
		ast.ArrayInitExpr {
			if expr.exprs.len > 0 {
				g.write('[')
				for i, x in expr.exprs {
					g.expr(x)
					if i < expr.exprs.len-1 { g.write(', ') }
				}
				g.write(']')
				// TODO: better way to handle this
				if expr.len !is ast.EmptyExpr {
					g.write('!')
				}
			}
			else {
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
		ast.AssocExpr {
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
				g.writeln('')
			}
			g.indent--
			g.write('}')
		}
		ast.CallExpr {
			g.expr(expr.lhs)
			g.write('(')
			for i, arg in expr.args {
				g.expr(arg)
				if i < expr.args.len-1 { g.write(', ') }
			}
			g.write(')')
		}
		ast.CallOrCastExpr {
			g.expr(expr.lhs)
			g.write('(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.CastExpr {
			g.expr(expr.typ)
			g.write('(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.ComptimeExpr {
			g.write('$')
			g.expr(expr.expr)
		}
		ast.EmptyExpr {}
		// TODO: should this be handled like this
		ast.FieldInit {
			g.write(expr.name)
			g.write(': ')
			g.expr(expr.value)
		}
		ast.FnLiteral {
			g.write('fn')
			if expr.signature.generic_params.len > 0 {
				g.generic_list(expr.signature.generic_params)
			}
			g.write('(')
			for i, arg in expr.signature.params {
				g.write(arg.name)
				g.write(' ')
				g.expr(arg.typ)
				if i < expr.signature.params.len-1 { g.write(', ') }
			}
			g.write(') ')
			if expr.signature.return_type !is ast.EmptyExpr {
				g.expr(expr.signature.return_type)
				g.writeln(' {')
			} else {
				g.writeln('{')
			}
			g.stmts(expr.stmts)
			g.write('}')
		}
		ast.GenericArgs {
			g.write('/* ast.GenericArgs */')
			g.expr(expr.lhs)
			g.generic_list(expr.args)
		}
		ast.GenericArgsOrIndexExpr {
			g.write('/* ast.GenericArgsOrIndexExpr */')
			g.expr(expr.lhs)
			g.generic_list(expr.exprs)
		}
		ast.GoExpr {
			g.write('go ')
			g.expr(expr.expr)
		}
		ast.Ident {
			g.write(expr.name)
		}
		ast.IfExpr {
			for i, branch in expr.branches {
				in_init := g.in_init
				g.in_init = true
				if i == 0 {
					g.write('if ')
				} else {
					if expr.is_comptime { g.write(' \$else') } else { g.write(' else') }
					if branch.cond[0] !is ast.EmptyExpr {
						if expr.is_comptime { g.write(' \$if ') } else { g.write('if ') }
					}
				}
				g.expr(branch.cond[0])
				g.in_init = in_init
				g.writeln(' {')
				g.stmts(branch.stmts)
				g.write('}')
			}
		}
		ast.IfGuardExpr {
			g.write('/* IfGuardExpr */ ')
			g.stmt(expr.stmt)
		}
		ast.IndexExpr {
			g.write('/* ast.IndexExpr */')
			g.expr(expr.lhs)
			g.write('[')
			g.expr(expr.expr)
			g.write(']')
		}
		ast.InfixExpr {
			g.expr(expr.lhs)
			g.write(' ')
			g.write(expr.op.str())
			g.write(' ')
			g.expr(expr.rhs)
		}
		ast.KeywordOperator {
			g.write(expr.op.str())
			g.write('(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.Tuple {
			g.write('/*tuple:start*/')
			for i, x in expr.exprs {
				g.expr(x)
				if i < expr.exprs.len-1 { g.write(', ') }
			}
			g.write('/*tuple:end*/')
		}
		ast.BasicLiteral {
			if expr.kind == .char {
				g.write('`')
				g.write(expr.value)
				g.write('`')
			}
			else if expr.kind == .string {
				// TODO: proper store extra info from scanner in BasicLiteral (also raw etc)
				quote := if expr.value.contains("'") { '"' } else { "'" }
				g.write(quote)
				g.write(expr.value)
				g.write(quote)
			}
			else {
				g.write(expr.value)
			}
		}
		ast.LockExpr {
			g.write('$expr.kind ')
			for i, x in expr.exprs {
				g.expr(x)
				if i < expr.exprs.len-1 { g.write(', ') }
			}
			g.writeln(' {')
			g.stmts(expr.stmts)
			g.writeln('}')
		}
		ast.MapInitExpr {
			// long syntax
			if expr.typ !is ast.EmptyExpr {
				g.expr(expr.typ)
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
		ast.MatchExpr {
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
		ast.OrExpr {
			g.expr(expr.expr)
			g.writeln(' or {')
			g.stmts(expr.stmts)
			g.write('}')
		}
		ast.ParenExpr {
			g.write('(')
			g.expr(expr.expr)
			g.write(')')
		}
		ast.PostfixExpr {
			g.expr(expr.expr)
			g.write(expr.op.str())
		}
		ast.PrefixExpr {
			g.write(expr.op.str())
			g.expr(expr.expr)
		}
		ast.RangeExpr {
			g.expr(expr.start)
			// g.write('..')
			g.write(expr.op.str())
			g.expr(expr.end)
		}
		ast.SelectorExpr {
			g.expr(expr.lhs)
			g.write('.')
			g.expr(expr.rhs)
		}
		ast.StructInitExpr {
			g.expr(expr.typ)
			// with field names
			if expr.fields.len > 0 && expr.fields[0].name.len > 0 {
				g.writeln('{')
				in_init := g.in_init
				g.in_init = true
				g.indent++
				for i, field in expr.fields {
					g.write(field.name)
					g.write(': ')
					g.expr(field.value)
					if i < expr.fields.len-1 { g.writeln(',') } else { g.writeln('') }
				}
				g.indent--
				g.in_init = in_init
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
		ast.UnsafeExpr {
			// NOTE: use in_init or stmts.len? check vfmt
			if g.in_init {
				g.write('unsafe { ')
			} else {
				g.writeln('unsafe {')
			}
			g.stmts(expr.stmts)
			if g.in_init {
				g.write(' }')
			} else {
				g.write('}')
			}
		}
		// Type Nodes
		// TODO: I really would like to allow matching the nested sumtypes like TS
		ast.Type {
			match expr {
				ast.ArrayType {
					g.write('[]')
					g.expr(expr.elem_type)
				}
				ast.ArrayFixedType {
					g.write('[')
					if expr.len !is ast.EmptyExpr {
						g.expr(expr.len)
					}
					g.write(']')
					g.expr(expr.elem_type)
				}
				ast.FnType {
					g.write('fn')
					if expr.generic_params.len > 0 {
						g.generic_list(expr.generic_params)
					}
					g.write('(')
					for i, arg in expr.params {
						g.expr(arg.typ)
						if i < expr.params.len-1 { g.write(', ') }
					}
					g.write(')')
					if expr.return_type !is ast.EmptyExpr {
						g.write(' ')
						g.expr(expr.return_type)
					}
				}
				ast.MapType {
					g.write('map[')
					g.expr(expr.key_type)
					g.write(']')
					g.expr(expr.value_type)
				}
				ast.NilType {
					g.write('nil')
				}
				ast.NoneType {
					g.write('none')
				}
				ast.OptionType {
					g.write('?')
					if expr.base_type !is ast.EmptyExpr {
						g.expr(expr.base_type)
					}
				}
				ast.ResultType {
					g.write('!')
					if expr.base_type !is ast.EmptyExpr {
						g.expr(expr.base_type)
					}
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
		if attribute.comptime_cond !is ast.EmptyExpr {
			g.write('if ')
			g.expr(attribute.comptime_cond)
		} else {
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
	}
	g.write(']')
}

[inline]
fn (mut g Gen) generic_list(exprs []ast.Expr) {
	g.write('[')
	for i, expr in exprs {
		g.expr(expr)
		if i < exprs.len-1 { g.write(',') }
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
