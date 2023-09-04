// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

import os
import time
import tinyv.ast
import tinyv.errors
import tinyv.pref
import tinyv.scanner
import tinyv.token

pub struct Parser {
	pref &pref.Preferences
mut:
	file    &token.File = &token.File{}
	scanner &scanner.Scanner
	// track state
	exp_lcbr bool // expecting `{` parsing `x` in `for|if|match x {` etc
	exp_pt   bool // expecting (p)ossible (t)ype from `p.expr()`
	// start token info
	line      int
	lit       string
	pos       token.Pos
	tok       token.Token = .unknown
	tok_next_ token.Token = .unknown // DO NOT access directly, use `p.peek()`
	// end token info
}

pub fn Parser.new(prefs &pref.Preferences) &Parser {
	return &Parser{
		pref: unsafe { prefs }
		scanner: scanner.new_scanner(prefs, .normal)
		// scanner: scanner.new_scanner(prefs, .skip_interpolation)
	}
}

fn (mut p Parser) init(filename string, src string, mut file_set token.FileSet) {
	// reset since parser instance may be reused
	p.line = 0
	p.lit = ''
	p.pos = 0
	p.tok = .unknown
	p.tok_next_ = .unknown
	// init
	// TODO: consider another way to pass in file set?
	p.file = file_set.add_file(filename, -1, src.len)
	p.scanner.init(p.file, src)
}

pub fn (mut p Parser) parse_files(files []string, mut file_set token.FileSet) []ast.File {
	mut ast_files := []ast.File{}
	for file in files {
		ast_files << p.parse_file(file, mut file_set)
	}
	return ast_files
}

pub fn (mut p Parser) parse_file(filename string, mut file_set token.FileSet) ast.File {
	if !p.pref.verbose {
		unsafe {
			goto start_no_time
		}
	}
	mut sw := time.new_stopwatch()
	start_no_time:
	src := os.read_file(filename) or { p.error('error reading ${filename}') }
	p.init(filename, src, mut file_set)
	// start
	p.next()
	mut top_stmts := []ast.Stmt{}
	// mut decls := []ast.Decl{}
	mut imports := []ast.ImportStmt{}
	mut mod := 'main'
	// file level attributes
	// or we are missing a stmt which supports attributes in this match
	mut attributes := []ast.Attribute{}
	if p.tok in [.attribute, .lsbr] {
		attribute_stmt := p.attribute_stmt()
		top_stmts << attribute_stmt
		if attribute_stmt is []ast.Attribute {
			attributes = attribute_stmt.clone()
			for attribute in attributes {
				if attribute.value is ast.Ident {
					if attribute.value.name !in ['has_globals', 'generated', 'manualfree'] {
						p.warn('invalid file level attribute `${attribute.name}` (or should `${p.tok}` support attributes)')
					}
				}
			}
		}
	}
	// TODO: script mode support?
	// I really hope it gets dropped.
	if p.tok == .key_module {
		p.next()
		module_stmt := ast.ModuleStmt{
			name: p.expect_name()
		}
		top_stmts << module_stmt
		mod = module_stmt.name
	} else {
		// TODO: set is_test somewhre, probably work it out in builder
		// and pass it to parser, or in prefs. (check current v)
		// if !p.file.name.contains('_test.') {
		// 	p.error('expectng module')
		// }
		// NOTE: allowing no moule for now
		// need to verify rules
	}
	for p.tok == .key_import {
		import_stmt := p.import_stmt()
		imports << import_stmt
		top_stmts << import_stmt
	}
	for p.tok != .eof {
		top_stmt := p.top_stmt()
		// if top_stmt is ast.Decl {
		// 	decls << top_stmt
		// }
		top_stmts << top_stmt
	}
	if p.pref.verbose {
		parse_time := sw.elapsed()
		println('scan & parse ${filename} (${p.file.line_count()} LOC): ${parse_time.milliseconds()}ms (${parse_time.microseconds()}us)')
	}
	return ast.File{
		attributes: attributes
		mod: mod
		name: filename
		imports: imports
		// decls: decls
		stmts: top_stmts
	}
}

fn (mut p Parser) top_stmt() ast.Stmt {
	match p.tok {
		.dollar {
			return p.comptime_stmt()
		}
		.hash {
			return p.directive()
		}
		.key_const {
			return p.const_decl(false)
		}
		.key_enum {
			return p.enum_decl(false, [])
		}
		.key_fn {
			return p.fn_decl(false, [])
		}
		.key_global {
			return p.global_decl([])
		}
		// NOTE: handling moved to parse_file
		// .key_import {
		// 	return p.import_stmt()
		// }
		.key_interface {
			return p.interface_decl(false, [])
		}
		// NOTE: handling moved to parse_file
		// .key_module {
		// 	p.next()
		// 	return ast.ModuleStmt{
		// 		name: p.expect_name()
		// 	}
		// }
		.key_pub {
			p.next()
			match p.tok {
				.key_const { return p.const_decl(true) }
				.key_enum { return p.enum_decl(true, []) }
				.key_fn { return p.fn_decl(true, []) }
				.key_interface { return p.interface_decl(true, []) }
				.key_struct, .key_union { return p.struct_decl(true, []) }
				.key_type { return p.type_decl(true) }
				else { p.error('not implemented: pub ${p.tok}') }
			}
		}
		.key_struct, .key_union {
			return p.struct_decl(false, [])
		}
		.key_type {
			return p.type_decl(false)
		}
		.attribute, .lsbr {
			return p.attribute_stmt()
		}
		else {
			p.error('unknown top stmt: ${p.tok} - ${p.file.name}:${p.line}')
		}
	}
}

fn (mut p Parser) stmt() ast.Stmt {
	// p.log('STMT: $p.tok - $p.file.name:$p.line')
	match p.tok {
		.dollar {
			return p.comptime_stmt()
		}
		.hash {
			return p.directive()
		}
		.key_assert {
			p.next()
			expr := p.expr(.lowest)
			return ast.AssertStmt{
				expr: expr
				extra: if p.tok == .comma {
					p.next()
					p.expr(.lowest)
				} else {
					ast.empty_expr
				}
			}
		}
		.key_break, .key_continue, .key_goto {
			line := p.line
			op := p.tok()
			if p.line == line && p.tok == .name {
				return ast.FlowControlStmt{
					op: op
					label: p.lit()
				}
			} else {
				return ast.FlowControlStmt{
					op: op
				}
			}
		}
		.key_defer {
			p.next()
			return ast.DeferStmt{
				stmts: p.block()
			}
		}
		.key_for {
			return p.for_stmt()
		}
		.key_return {
			// p.log('ast.ReturnStmt')
			p.next()
			if p.tok == .rcbr {
				return ast.ReturnStmt{}
			}
			return ast.ReturnStmt{
				exprs: p.expr_list()
			}
		}
		.lcbr {
			// anonymous / scoped block `{ a := 1 }`
			return ast.BlockStmt{
				stmts: p.block()
			}
		}
		else {
			expr := p.expr(.lowest)
			// label `start:`
			if p.tok == .colon {
				name := match expr {
					ast.Ident { expr.name }
					else { p.error('expecting identifier') }
				}
				p.next()
				return ast.LabelStmt{
					name: name
					stmt: if p.tok == .key_for { p.for_stmt() } else { ast.empty_stmt }
				}
			}
			return p.complete_simple_stmt(expr)
		}
	}
	p.error('unknown stmt: ${p.tok}')
}

fn (mut p Parser) attribute_stmt() ast.Stmt {
	// NOTE: could also return AttributeStmt{attributes: attributes, stmt: stmt}
	attributes := p.attributes()
	mut is_pub := false
	if p.tok == .key_pub {
		p.next()
		is_pub = true
	}
	match p.tok {
		.key_enum {
			return p.enum_decl(is_pub, attributes)
		}
		.key_fn {
			return p.fn_decl(is_pub, attributes)
		}
		.key_global {
			return p.global_decl(attributes)
		}
		.key_interface {
			return p.interface_decl(is_pub, attributes)
		}
		.key_struct, .key_union {
			return p.struct_decl(is_pub, attributes)
		}
		else {
			return attributes
		}
	}
}

[inline]
fn (mut p Parser) simple_stmt() ast.Stmt {
	return p.complete_simple_stmt(p.expr(.lowest))
}

fn (mut p Parser) complete_simple_stmt(expr ast.Expr) ast.Stmt {
	// stand alone expression in a statement list
	// eg: `if x == 1 {`, `x++`, `mut x := 1`, `a,`b := 1,2`
	// multi assign from match/if `a, b := if x == 1 { 1,2 } else { 3,4 }
	if p.tok == .comma {
		p.next()
		// a little extra code, but also a little more efficient
		mut exprs := [expr]
		exprs << p.expr(.lowest)
		for p.tok == .comma {
			p.next()
			exprs << p.expr(.lowest)
		}
		if p.tok.is_assignment() {
			return p.assign_stmt(exprs)
		}
		// multi return values (last statement, no return keyword)
		return ast.ExprStmt{ast.Tuple{
			exprs: exprs
		}}
	} else if p.tok.is_assignment() {
		return p.assign_stmt([expr])
	}
	// TODO: add check for all ExprStmt eg.
	// if expr is ast.ArrayInitExpr {
	// 	p.error('UNUSED')
	// }
	return ast.ExprStmt{
		expr: expr
	}
}

fn (mut p Parser) expr(min_bp token.BindingPower) ast.Expr {
	// p.log('EXPR: $p.tok - $p.line')
	mut line := p.line
	mut lhs := ast.empty_expr
	match p.tok {
		.char, .key_false, .key_true, .number {
			lhs = ast.BasicLiteral{
				kind: p.tok
				value: p.lit()
			}
		}
		.string {
			lhs = p.string_literal(.v)
		}
		.key_fn {
			p.next()
			// TODO: closure variable capture syntax is the same as generic arg/param syntax. This should change.
			// for clarity and also generic closures cannot exist, even though there is probably no use for them.
			mut captured_vars := []ast.Expr{}
			if p.tok == .lsbr {
				p.next()
				for p.tok != .rsbr {
					captured_vars << p.expr(.lowest)
					if p.tok == .comma {
						p.next()
					}
				}
				p.next()
			}
			if p.tok == .lsbr {
				p.error('generic closure')
			}
			typ := p.fn_type()
			if p.exp_pt && (p.tok != .lcbr || p.exp_lcbr) {
				return ast.Type(typ)
			}
			lhs = ast.FnLiteral{
				typ: typ
				stmts: p.block()
				captured_vars: captured_vars
			}
			// support chaining (eg. direct call `fn () int { return 1 }()`)
			line = p.line
		}
		.key_if {
			lhs = p.if_expr(false)
			// chaining eg. `a := if cond { 1 } else { 2 } * 10`
			line = p.line
		}
		// NOTE: I would much rather dump, likely, and unlikely were
		// some type of comptime fn/macro's which come as part of the
		// v stdlib, as apposed to being language keywords.
		// TODO: should these be replaced with something
		// like `CallExpr{lhs: KeywordOperator}` ?
		.key_isreftype, .key_sizeof, .key_typeof {
			op := p.tok()
			// p.expect(.lpar)
			if p.tok == .lpar {
				p.next()
				lhs = ast.KeywordOperator{
					op: op
					exprs: [p.expr_or_type(.lowest)]
				}
				p.expect(.rpar)
			} else {
				// TODO: is this the best way to handle this? (prob not :D)
				// this allows `typeof[type]()` to work
				lhs = ast.Ident{
					name: op.str()
				}
			}
		}
		.key_dump, .key_likely, .key_unlikely {
			op := p.tok()
			p.expect(.lpar)
			lhs = ast.KeywordOperator{
				op: op
				exprs: [p.expr(.lowest)]
			}
			p.expect(.rpar)
		}
		.key_offsetof {
			op := p.tok()
			p.expect(.lpar)
			expr := p.expr(.lowest)
			p.expect(.comma)
			lhs = ast.KeywordOperator{
				op: op
				exprs: [expr, p.expr(.lowest)]
			}
			p.expect(.rpar)
		}
		.key_go, .key_spawn {
			op := p.tok()
			lhs = ast.KeywordOperator{
				op: op
				exprs: [p.expr(.lowest)]
			}
		}
		.key_nil {
			p.next()
			return ast.Type(ast.NilType{})
		}
		.key_none {
			p.next()
			return ast.Type(ast.NoneType{})
		}
		.key_lock, .key_rlock {
			kind := p.tok()
			exp_lcbr := p.exp_lcbr
			p.exp_lcbr = true
			exprs := p.expr_list()
			p.exp_lcbr = exp_lcbr
			return ast.LockExpr{
				kind: kind
				exprs: exprs
				stmts: p.block()
			}
		}
		.key_select {
			p.next()
			p.expect(.lcbr)
			se := p.select_expr()
			p.expect(.rcbr)
			return se
		}
		.dollar {
			p.next()
			return p.comptime_expr()
		}
		// enum value `.green`
		// TODO: use ast.EnumValue{} or stick with SelectorExpr?
		// .dot {}
		.lpar {
			p.next()
			exp_lcbr := p.exp_lcbr
			p.exp_lcbr = false
			// p.log('ast.ParenExpr:')
			lhs = ast.ParenExpr{
				expr: p.expr(.lowest)
			}
			p.exp_lcbr = exp_lcbr
			p.expect(.rpar)
		}
		.lcbr {
			// if p.exp_lcbr {
			// 	p.error('unexpected `{`')
			// }
			// shorthand map / struct init
			// NOTE: config syntax handled in `p.fn_arguments()`
			// which afaik is the only place it's supported
			// lhs = p.struct_init()
			p.next()
			if p.tok == .ellipsis {
				p.error('this assoc syntax is no longer supported `{...`. You must explicitly specify a type `MyType{...`')
			}
			// empty map init `{}`
			if p.tok == .rcbr {
				p.next()
				return ast.MapInitExpr{
					pos: p.pos
				}
			}
			// map init
			pos := p.pos
			mut keys := []ast.Expr{}
			mut vals := []ast.Expr{}
			for p.tok != .rcbr {
				key := p.expr(.lowest)
				if key is ast.InfixExpr {
					if key.op == .pipe {
						p.error('this assoc syntax is no longer supported `{MyType|`. Use `MyType{...` instead')
					}
				}
				keys << key
				p.expect(.colon)
				val := p.expr(.lowest)
				vals << val
				if p.tok == .comma {
					p.next()
				}
			}
			p.next()
			lhs = ast.MapInitExpr{
				keys: keys
				vals: vals
				pos: pos
			}
		}
		.lsbr {
			// ArrayInitExpr: `[1,2,3,4]` | `[]type{}` | `[]type{len: 4}` | `[2]type{init: 0}` etc...
			// ArrayInitExpr->IndexExpr: `[1,2,3,4][0]` handled here for reasons listed in comment below
			// ArrayType in CastExpr: `[]type` in `[]type(x)` set lhs to type, cast handled later
			pos := p.pos
			p.next()
			// exprs in first `[]` eg. (`1,2,3,4` in `[1,2,3,4]) | (`2` in `[2]int{}`)
			mut exprs := []ast.Expr{}
			for p.tok != .rsbr {
				exprs << p.expr(.lowest)
				if p.tok == .comma {
					p.next()
				}
			}
			p.next()
			// (`[2]type{}` | `[2][2]type{}` | `[2][]type{}`) | `[1,2,3,4][0]` | `[2]type`
			// NOTE: it's tricky to differentiate between a fixed array of fixed array(s)
			// and an index directly after initialization. for example, the following:
			// a) fixed array of fixed array(s): `[2][2]type{}` | `[2][2][2]type{}`
			// b) index directly after init: `[1][0]` | `[x][2][2]` <- vs (a) above
			// only in this case collect exprs in following `[x][x]` then decide what to do
			if exprs.len > 0 && p.tok == .lsbr {
				// collect exprs in all the following `[x][x]`
				mut exprs_arr := [exprs]
				// NOTE: checking line here for this case:
				// `pub const const_a = ['a', 'b', 'c', 'd']`
				// '[attribute_a; attribute_b]''
				for p.tok == .lsbr && p.line == line {
					p.next()
					mut exprs2 := []ast.Expr{}
					for p.tok != .rsbr {
						exprs2 << p.range_expr(p.expr(.lowest))
						if p.tok == .comma {
							p.next()
						}
					}
					p.next()
					exprs_arr << exprs2
				}
				// (`[2]type{}` | `[2][]type{}` | `[2]&type{init: Foo{}}`) | `[2]type`
				if p.tok in [.amp, .name] && p.line == line {
					mut typ := p.expect_type()
					for i := exprs_arr.len - 1; i >= 0; i-- {
						exprs2 := exprs_arr[i]
						if exprs2.len == 0 {
							lhs = ast.Type(ast.ArrayType{
								elem_type: typ
							})
						} else if exprs2.len == 1 {
							lhs = ast.Type(ast.ArrayFixedType{
								elem_type: typ
								len: exprs2[0]
							})
						} else {
							// TODO: use same error message as typ() `expect(.rsbr)`
							p.error('expecting single expr for fixed array length')
						}
					}
					// `[2]type{}`
					if p.tok == .lcbr && !p.exp_lcbr {
						p.next()
						mut init := ast.empty_expr
						if p.tok != .rcbr {
							key := p.expect_name()
							p.expect(.colon)
							match key {
								'init' { init = p.expr(.lowest) }
								else { p.error('expecting `init`, got `${key}`') }
							}
						}
						p.next()
						lhs = ast.ArrayInitExpr{
							typ: typ
							init: init
							pos: pos
						}
					}
					// `[2]type`
					else {
						if !p.exp_pt && p.tok != .lpar {
							p.error('unexpected type')
						}
						// NOTE: no need to chain here afaik
						return typ
					}
				}
				// `[1][0]` | `[1,2,3,4][0]` | `[[1,2,3,4]][0][1]` <-- index directly after init
				else {
					lhs = ast.ArrayInitExpr{
						exprs: exprs
						pos: pos
					}
					for i := 1; i < exprs_arr.len; i++ {
						exprs2 := exprs_arr[i]
						if exprs2.len != 1 {
							// TODO: use same error message as IndexExpr in expr loop `expect(.rsbr)`
							p.error('invalid index expr')
						}
						lhs = ast.IndexExpr{
							lhs: lhs
							expr: exprs2[0]
						}
					}
				}
			}
			// (`[]type{}` | `[][]type{}` | `[]&type{len: 2}`) | `[]type`
			else if p.tok in [.amp, .lsbr, .name] && p.line == line {
				typ := ast.Type(ast.ArrayType{
					elem_type: p.expect_type()
				})
				// `[]type{}`
				if p.tok == .lcbr && !p.exp_lcbr {
					p.next()
					mut cap, mut init, mut len := ast.empty_expr, ast.empty_expr, ast.empty_expr
					for p.tok != .rcbr {
						key := p.expect_name()
						p.expect(.colon)
						match key {
							'cap' { cap = p.expr(.lowest) }
							'init' { init = p.expr(.lowest) }
							'len' { len = p.expr(.lowest) }
							else { p.error('expecting one of `cap, init, len`, got `${key}`') }
						}
						if p.tok == .comma {
							p.next()
						}
					}
					p.next()
					lhs = ast.ArrayInitExpr{
						typ: typ
						init: init
						cap: cap
						len: len
						pos: pos
					}
				}
				// `[]type`
				else {
					if !p.exp_pt && p.tok != .lpar {
						p.error('unexpected type')
					}
					// NOTE: no need to chain here afaik
					return typ
				}
			}
			// `[1,2,3,4]!`
			else if p.tok == .not {
				if exprs.len == 0 {
					p.error('expecting at least one initialization expr: `[expr, expr2]!`')
				}
				p.next()
				lhs = ast.ArrayInitExpr{
					exprs: exprs
					// NOTE: indicates fixed `!`
					len: ast.PostfixExpr{
						op: .not
						expr: ast.empty_expr
					}
					pos: pos
				}
				// `[]` | `[1,2,3,4]`
			} else {
				lhs = ast.ArrayInitExpr{
					exprs: exprs
					pos: pos
				}
			}
		}
		.key_match {
			match_pos := p.pos
			p.next()
			mut exp_lcbr := p.exp_lcbr
			p.exp_lcbr = true
			expr := p.expr(.lowest)
			p.exp_lcbr = exp_lcbr
			p.expect(.lcbr)
			mut branches := []ast.MatchBranch{}
			for p.tok != .rcbr {
				exp_lcbr = p.exp_lcbr
				branch_pos := p.pos
				p.exp_lcbr = true
				mut cond := [p.range_expr(p.expr_or_type(.lowest))]
				for p.tok == .comma {
					p.next()
					cond << p.range_expr(p.expr_or_type(.lowest))
				}
				p.exp_lcbr = exp_lcbr
				branches << ast.MatchBranch{
					cond: cond
					stmts: p.block()
					pos: branch_pos
				}
				if p.tok == .key_else {
					p.next()
					branches << ast.MatchBranch{
						stmts: p.block()
						pos: branch_pos
					}
				}
			}
			// support chaining
			line = p.line
			// rcbr
			p.next()
			lhs = ast.MatchExpr{
				expr: expr
				branches: branches
				pos: match_pos
			}
		}
		.key_mut, .key_shared, .key_static, .key_volatile {
			// also /* .key_atomic. */
			lhs = ast.Modifier{
				kind: p.tok()
				expr: p.expr(.highest)
			}
		}
		.key_unsafe {
			// p.log('ast.UnsafeExpr')
			p.next()
			// exp_lcbr := p.exp_lcbr
			// p.exp_lcbr = false
			lhs = ast.UnsafeExpr{
				stmts: p.block()
			}
			// p.exp_lcbr = exp_lcbr
		}
		.name {
			lit := p.lit
			lhs = p.ident_or_named_type()
			// raw/c/js string: `r'hello'`
			if p.line == line && p.tok == .string {
				lhs = p.string_literal(ast.StringLiteralKind.from_string_tinyv(lit) or {
					p.error(err.msg())
				})
			}
			// `ident{}`
			else if p.tok == .lcbr && !p.exp_lcbr {
				// TODO: move inits to expr loop? currently just handled where needed
				// since this is not very many places. consider if it should be moved
				// TODO: consider the following (tricky to parse)
				// `if err == IError(Eof{}) {`
				// `if Foo{} == Foo{} {`
				lhs = p.assoc_or_init_expr(lhs)
				// TODO: think about the best way to handle this
				// struct init was chaining with selector expr
				// {
				// 	.enum_val_a: StructInit{
				// 		...
				// 	}
				// 	.enum_val_b: ...
				// }
				if p.line != line {
					return lhs
				}
			}
		}
		// native optionals `x := ?mod_a.StructA{}`
		// could also simply be handled by `Token.is_prefix()` below
		.question {
			lhs = p.expect_type()
			// only handle where actually needed instead of expr loop
			// I may change my mind, however for now this seems best
			if p.tok == .lcbr && !p.exp_lcbr {
				lhs = p.assoc_or_init_expr(lhs)
			} else if !p.exp_pt && p.tok != .lpar {
				p.error('unexpected type')
			}
		}
		// selector handled in expr chaining loop below
		// range handled in `p.range_expr()`
		.dot, .dotdot, .ellipsis {}
		else {
			if p.tok.is_prefix() {
				// NOTE: just use .highest for now, later we might need to define for each op
				lhs = ast.PrefixExpr{
					pos: p.pos
					op: p.tok()
					expr: p.expr(.highest)
				}
			} else {
				p.error('expr: unexpected token `${p.tok}`')
			}
		}
	}

	// expr chaining
	// TOOD: make sure there are no cases where we get stuck stuck in this loop
	// for p.tok != .eof {
	for {
		// as cast
		// this could be handled with infix instead
		// if we choose not to support or chaning
		if p.tok == .key_as {
			p.next()
			// not returning since we support chaning or
			// we can return instead if that is removed
			lhs = ast.AsCastExpr{
				expr: lhs
				typ: p.expect_type()
			}
		}
		// call | cast
		else if p.tok == .lpar {
			pos := p.pos
			// NOTE: deref assign in parenthesis
			// (*ptr_a) = *ptr_a - 1
			// ((*ptr_a)) = *ptr_a - 1
			// TODO: find all cases & better way?
			if p.line != line && lhs !in [ast.Ident, ast.SelectorExpr] {
				return lhs
			}
			// p.log('ast.CastExpr or CallExpr: ${typeof(lhs)}')
			exp_lcbr := p.exp_lcbr
			p.exp_lcbr = false
			args := p.fn_arguments()
			p.exp_lcbr = exp_lcbr
			// definitely a call since we have `!` | `?`
			// fncall()! (Propagate Result) | fncall()? (Propagate Option)
			if p.tok in [.not, .question] {
				lhs = ast.CallExpr{
					lhs: lhs
					args: args
					pos: pos
				}
				// lhs = ast.PostfixExpr{
				// 	expr: lhs
				// 	op: p.tok()
				// }
			}
			// could be a call or a cast (1 arg)
			else if args.len == 1 {
				// definitely a cast
				if lhs is ast.Type {
					lhs = ast.CastExpr{
						typ: lhs
						expr: args[0]
						pos: pos
					}
				}
				// work this out after type checking
				else {
					lhs = ast.CallOrCastExpr{
						lhs: lhs
						expr: args[0]
						pos: pos
					}
				}
			}
			// definitely a call (0 args, or more than 1 arg)
			else {
				lhs = ast.CallExpr{
					lhs: lhs
					args: args
					pos: pos
				}
			}
		}
		// NOTE: if we want we can handle init like this
		// this is only needed for ident or selector, so there is really
		// no point handling it here, since it wont be used for chaining
		// else if p.tok == .lcbr && !p.exp_lcbr && p.line == line {
		// 	lhs = p.assoc_or_init_expr(lhs)
		// }
		// index or generic call (args part, call handled above): `expr[i]` | `expr#[i]` | `expr[exprs]()`
		else if p.tok in [.hash, .lsbr] && p.line == line {
			// struct init field w/ default literal value & attributes
			// do not incorrectly parse as index expr `'foo'[index]`
			// `field_d string = 'foo' [attribute_a]`
			// `field_d int = 111 [attribute_a]`
			if mut lhs is ast.BasicLiteral {
				// NOTE: if we end up with many situations like this it may be worth
				// using pratt bp loop for chaining, for now I don't see the value
				// if int(min_bp) > int(p.tok.left_binding_power()) {
				if min_bp == .highest {
					return lhs
				}
				// TODO: move to later stage for supporting vars / exprs
				// eg. `if lhs.type is number { error(... }`
				if lhs.kind == .number {
					p.error('cannot index number')
				}
			}
			// `array#[idx]`
			if p.tok == .hash {
				p.next()
				p.expect(.lsbr)
				// gated, even if followed by `(` we know it's `arr#[fn_idx]()` and not `fn[int]()`
				// println('HERE')
				lhs = ast.IndexExpr{
					lhs: lhs
					expr: p.range_expr(p.expr(.lowest))
					is_gated: true
				}
				p.expect(.rsbr)
			}
			// `array[idx]` | `array[fn_idx]()` | fn[int]()` | `GenericStruct[int]{}`
			else {
				p.next() // .lsbr
				// NOTE: `ast.GenericArgsOrIndexExpr` is only used for cases
				// which absolutely cannot be determined until a later stage
				// so try and determine every case we possibly can below
				expr := p.range_expr(p.expr_or_type(.lowest))
				mut exprs := [expr]
				for p.tok == .comma {
					p.next()
					exprs << p.expr_or_type(.lowest)
				}
				p.expect(.rsbr)
				// `GenericStruct[int]{}`
				if p.line == line && p.tok == .lcbr && !p.exp_lcbr {
					lhs = p.assoc_or_init_expr(ast.GenericArgs{ lhs: lhs, args: exprs })
					// lhs = ast.GenericArgs{ lhs: lhs, args: exprs }
				}
				// `array[0]()` | `fn[int]()`
				else if p.tok == .lpar {
					// multiple exprs | `fn[GenericStruct[int]]()` nested generic args
					if exprs.len > 1 || expr is ast.GenericArgs {
						lhs = ast.GenericArgs{
							lhs: lhs
							args: exprs
						}
					}
					// `ident[ident]()` this will be determined at a later stage by checking lhs
					else if expr in [ast.Ident, ast.SelectorExpr] {
						lhs = ast.GenericArgOrIndexExpr{
							lhs: lhs
							expr: expr
						}
					}
					// `array[0]()` we know its an index
					else {
						lhs = ast.IndexExpr{
							lhs: lhs
							expr: expr
						}
					}
				}
				// `array[idx]` | `fn[GenericStructA[int], GenericStructB[int]]`
				else {
					// `fn[GenericStructA[int]]` | `GenericStructA[GenericStructB[int]]]` nested generic args
					// TODO: make sure this does not cause false positives, may need extra check (.comma, .rsbr)
					// if p.exp_pt && expr in [ast.GenericArgs, ast.Ident, ast.SelectorExpr] && p.tok in [.comma, .rsbr] {
					if p.exp_pt && expr in [ast.GenericArgs, ast.Ident, ast.SelectorExpr] {
						lhs = ast.GenericArgs{
							lhs: lhs
							args: exprs
						}
					} else {
						lhs = ast.IndexExpr{
							lhs: lhs
							expr: expr
						}
					}
				}
			}
		}
		// SelectorExpr
		else if p.tok == .dot {
			p.next()
			// p.log('ast.SelectorExpr')
			lhs = ast.SelectorExpr{
				lhs: lhs
				// rhs: p.expr(.lowest)
				rhs: p.ident()
				pos: p.pos
			}
		}
		// doing this here since it can be
		// used between chaining selectors
		// eg. `struct.field?.field`
		else if p.tok in [.not, .question] {
			lhs = ast.PostfixExpr{
				op: p.tok()
				expr: lhs
			}
		} else if p.tok == .key_or {
			// p.log('ast.OrExpr')
			pos := p.pos
			p.next()
			lhs = ast.OrExpr{
				expr: lhs
				stmts: p.block()
				pos: pos
			}
		} else {
			break
		}
	}
	// pratt
	for int(min_bp) <= int(p.tok.left_binding_power()) {
		if p.tok.is_infix() {
			// TODO: handle by checking expr?
			// deref assign: `*a = b`
			if p.tok == .mul && p.line != line {
				return lhs
			}
			pos := p.pos
			op := p.tok()
			lhs = ast.InfixExpr{
				op: op
				lhs: lhs
				// `x in y` allow range for this case, eg. `x in 1..10`
				rhs: if op == .key_in {
					p.range_expr(p.expr(op.right_binding_power()))
				}
				// `x is Type`
				else if op == .key_is {
					p.expect_type()
				} else {
					p.expr(op.right_binding_power())
				}
				pos: pos
			}
		} else if p.tok.is_postfix() {
			lhs = ast.PostfixExpr{
				op: p.tok()
				expr: lhs
			}
		} else {
			break
		}
	}
	// p.log('returning: $p.tok')
	return lhs
}

// parse and return `ast.RangeExpr` if found, otherwise return `lhs_expr`
[inline]
fn (mut p Parser) range_expr(lhs_expr ast.Expr) ast.Expr {
	if p.tok in [.dotdot, .ellipsis] {
		return ast.RangeExpr{
			op: p.tok()
			start: lhs_expr
			end: if p.tok == .rsbr { ast.empty_expr } else { p.expr(.lowest) }
		}
	}
	return lhs_expr
}

// parse type or expr, eg. `typeof(expr|type)` | `array_or_generic_call[expr|type]()`
[inline]
fn (mut p Parser) expr_or_type(min_bp token.BindingPower) ast.Expr {
	// TODO: is there a better way to do this? see uses of `p.exp_pt`
	exp_pt := p.exp_pt
	p.exp_pt = true
	expr := p.expr(min_bp)
	p.exp_pt = exp_pt
	return expr
}

// use peek() over always keeping next_tok one token ahead.
// I have done it this way to keep scanner & parser in sync.
// this simplifies getting any extra information from scanner
// as I can retrieve it directly, no need to store somewhere.
// this also help enforce the hard 1 token look ahead limit.
[inline]
fn (mut p Parser) peek() token.Token {
	if p.tok_next_ == .unknown {
		p.tok_next_ = p.scanner.scan()
	}
	return p.tok_next_
}

[inline]
fn (mut p Parser) next() {
	if p.tok_next_ != .unknown {
		p.tok = p.tok_next_
		p.tok_next_ = .unknown
	} else {
		p.tok = p.scanner.scan()
	}
	p.line = p.file.line_count()
	p.lit = p.scanner.lit
	p.pos = p.file.pos(p.scanner.pos)
}

// expect `tok` & go to next token
[inline]
fn (mut p Parser) expect(tok token.Token) {
	if p.tok != tok {
		p.error_expected(tok, p.tok)
	}
	p.next()
}

// expect `.name` & return `p.lit` & go to next token
[inline]
fn (mut p Parser) expect_name() string {
	if p.tok != .name {
		p.error_expected(.name, p.tok)
	}
	name := p.lit
	p.next()
	return name
}

// return `p.lit` & go to next token
[inline]
fn (mut p Parser) lit() string {
	// TODO: check if there is a better way to handle this?
	// we should never use lit() in cases where p.lit is empty anyway
	// lit := if p.lit.len == 0 { p.tok.str() } else { p.lit }
	lit := p.lit
	p.next()
	return lit
}

// return `p.tok` & go to next token
[inline]
fn (mut p Parser) tok() token.Token {
	tok := p.tok
	p.next()
	return tok
}

[inline]
fn (mut p Parser) block() []ast.Stmt {
	mut stmts := []ast.Stmt{}
	p.expect(.lcbr)
	for p.tok != .rcbr {
		stmts << p.stmt()
	}
	// rcbr
	p.next()
	// TODO: correct way to error on `if x == Type{} {`
	// if p.tok == .lcbr {
	// 	p.error('TODO: booom')
	// }
	return stmts
}

[inline]
fn (mut p Parser) expr_list() []ast.Expr {
	mut exprs := []ast.Expr{}
	for {
		exprs << p.expr(.lowest)
		// TODO: was this just for previous generics impl or was there another need?
		// expr := p.expr(.lowest)
		// // TODO: is this the best place/way to handle this?
		// if expr is ast.EmptyExpr {
		// 	p.error('expecting expr, got `$p.tok`')
		// }
		// exprs << expr
		if p.tok != .comma {
			break
		}
		p.next()
	}
	return exprs
}

// @[attribute] | [attribute]
fn (mut p Parser) attributes() []ast.Attribute {
	p.next()
	mut attributes := []ast.Attribute{}
	for {
		// TODO: perhaps attrs with `.name` token before `:` we can set name
		// as apposed to value of `Ident{name}`
		mut name := ''
		mut value := ast.empty_expr
		mut comptime_cond := ast.empty_expr
		// since unsafe is a keyword
		if p.tok == .key_unsafe {
			p.next()
			// name = 'unsafe'
			value = ast.Ident{
				name: 'unsafe'
				pos: p.pos
			}
		}
		// TODO: properly
		// consider using normal if expr
		else if p.tok == .key_if {
			p.next()
			comptime_cond = p.expr(.lowest)
			// if p.tok == .question {
			// 	p.next()
			// 	comptime_cond = ast.PostfixExpr{
			// 		op: .question
			// 		expr: comptime_cond
			// 	}
			// }
		} else {
			// name = p.expect_name()
			value = p.expr(.lowest)
			if p.tok == .colon {
				if mut value is ast.Ident {
					name = value.name
				} else {
					p.error('expecting identifier')
				}
				p.next() // ;
				// NOTE: use tok instead of defining AttributeKind
				// kind := p.tok
				// TODO: do we need the match below or should we use:
				// if p.tok in [.semicolon, .rsbr] { p.error('...') }
				value = p.expr(.lowest)
				// value = match p.tok {
				// 	.name, .number, .string { p.lit() }
				// 	else { p.error('unexpected ${p.tok}, an argument is expected after `:`') }
				// }
			}
		}
		attributes << ast.Attribute{
			name: name
			value: value
			comptime_cond: comptime_cond
		}
		if p.tok == .semicolon {
			p.next()
			continue
		}
		p.expect(.rsbr)
		// @[attribute_a]
		// [attribute_b]
		if p.tok in [.attribute, .lsbr] {
			p.next()
			continue
		}
		break
	}
	// p.log('ast.Attribute: $name')
	return attributes
}

[inline]
fn (mut p Parser) assign_stmt(lhs []ast.Expr) ast.AssignStmt {
	return ast.AssignStmt{
		pos: p.pos
		op: p.tok()
		lhs: lhs
		rhs: p.expr_list()
	}
}

[inline]
fn (mut p Parser) comptime_expr() ast.Expr {
	pos := p.pos
	match p.tok {
		.key_if {
			return ast.ComptimeExpr{
				expr: p.if_expr(true)
				pos: pos
			}
		}
		else {
			return ast.ComptimeExpr{
				expr: p.expr(.lowest)
				pos: p.pos
			}
		}
	}
}

[inline]
fn (mut p Parser) comptime_stmt() ast.Stmt {
	p.next()
	match p.tok {
		.key_for {
			return ast.ComptimeStmt{
				stmt: p.for_stmt()
			}
		}
		else {
			return ast.ExprStmt{
				expr: p.comptime_expr()
			}
		}
	}
}

fn (mut p Parser) for_stmt() ast.ForStmt {
	p.next()
	exp_lcbr := p.exp_lcbr
	p.exp_lcbr = true
	mut init, mut cond, mut post := ast.empty_stmt, ast.empty_expr, ast.empty_stmt
	// `for x < y {` | `for x:=1; x<=10; x++ {`
	if p.tok != .lcbr {
		mut expr := if p.tok != .semicolon { p.expr(.lowest) } else { ast.empty_expr }
		// `x, y` in (`for mut x, y in z {` | `for x, y := 1, 2; ; {`)
		expr2 := if p.tok == .comma {
			p.next()
			p.expr(.highest)
		} else {
			ast.empty_expr
		}
		// `for x in {`
		if p.tok == .key_in {
			// p.expect(.key_in)
			p.next()
			init = ast.ForInStmt{
				key: expr
				value: expr2
				expr: p.expr(.lowest)
			}
		} else if p.tok == .lcbr {
			// `for x in y {`
			// TODO: maybe handle this differently
			if mut expr is ast.InfixExpr && expr.op == .key_in {
				init = ast.ForInStmt{
					value: expr.lhs
					expr: expr.rhs
				}
			}
			// `for x < y {`
			else {
				cond = expr
			}
		}
		// `for x:=1; x<=10; x++ {`
		else {
			if p.tok != .semicolon {
				// init = p.complete_simple_stmt(expr)
				init = if p.tok.is_assignment() {
					mut exprs := [expr]
					if expr2 !is ast.EmptyExpr {
						exprs << expr2
					}
					p.assign_stmt(exprs)
				} else {
					p.complete_simple_stmt(expr)
				}
			}
			p.expect(.semicolon)
			if p.tok != .semicolon {
				cond = p.expr(.lowest)
			}
			p.expect(.semicolon)
			if p.tok != .lcbr {
				post = p.simple_stmt()
			}
		}
	}
	p.exp_lcbr = exp_lcbr
	return ast.ForStmt{
		init: init
		cond: cond
		post: post
		stmts: p.block()
	}
}

fn (mut p Parser) if_expr(is_comptime bool) ast.IfExpr {
	// p.log('ast.IfExpr')
	p.next()
	// else if
	// NOTE: it's a bit weird to parse because of the way comptime has
	// `$` on every branch. Removing this would simplify things
	if p.tok == .key_if || (p.tok == .dollar && p.peek() == .key_if) {
		if is_comptime {
			p.expect(.dollar)
		}
		// p.expect(.key_if)
		p.next()
	}
	exp_lcbr := p.exp_lcbr
	p.exp_lcbr = true
	// mut cond := p.expr(.lowest)
	// NOTE: the line above works, but avoid calling p.expr()
	mut cond := if p.tok == .lcbr { ast.empty_expr } else { p.expr(.lowest) }
	mut else_expr := ast.empty_expr
	// if p.tok == .question {
	// 	// TODO: handle individual cases like this or globally
	// 	// use postfix for this and add to token.is_postfix()?
	// 	cond = ast.PostfixExpr{
	// 		expr: cond
	// 		op: p.tok
	// 	}
	// 	p.next()
	// }
	// if guard
	// TODO: is `if a, b := multi_return_opt() {` allowed?
	if p.tok == .decl_assign {
		cond = ast.IfGuardExpr{
			stmt: p.assign_stmt([cond])
		}
	}
	p.exp_lcbr = exp_lcbr
	stmts := p.block()
	// else
	if p.tok == .key_else || (p.tok == .dollar && p.peek() == .key_else) {
		// we are using expect instead of next to ensure we error when `is_comptime`
		// and not all branches have `$`, or `!is_comptime` and any branches have `$`.
		// the same applies for the `else if` condition directly below.
		if is_comptime {
			p.expect(.dollar)
		}
		// p.expect(.key_else)
		// p.next()
		else_expr = p.if_expr(is_comptime)
	}
	return ast.IfExpr{
		cond: cond
		else_expr: else_expr
		stmts: stmts
	}
}

fn (mut p Parser) import_stmt() ast.ImportStmt {
	p.next()
	// NOTE: we can also use SelectorExpr if we like
	// mod := p.expr(.lowest)
	mut name := p.expect_name()
	mut alias := name
	for p.tok == .dot {
		p.next()
		alias = p.expect_name()
		name += '.' + alias
	}
	is_aliased := p.tok == .key_as
	if is_aliased {
		p.next()
		alias = p.expect_name()
	}
	mut symbols := []ast.Expr{}
	// `import mod { sym1, sym2 }`
	if p.tok == .lcbr {
		p.next()
		// symbols << p.expr_or_type(.lowest)
		symbols << p.ident_or_type()
		for p.tok == .comma {
			p.next()
			// symbols << p.expr_or_type(.lowest)
			symbols << p.ident_or_type()
		}
		p.expect(.rcbr)
	}
	// p.log('ast.ImportStmt: $name as $alias')
	return ast.ImportStmt{
		name: name
		alias: alias
		is_aliased: is_aliased
		symbols: symbols
	}
}

fn (mut p Parser) directive() ast.Directive {
	// value := p.lit() // if we scan whole line see scanner
	p.next()
	line := p.line
	name := p.expect_name()
	// TODO: handle properly
	mut value := ''
	// mut value := p.lit()
	for p.line == line {
		if p.tok == .name {
			value += p.lit()
		} else {
			value += p.tok.str()
			p.next()
		}
	}
	return ast.Directive{
		name: name
		value: value
	}
}

fn (mut p Parser) const_decl(is_public bool) ast.ConstDecl {
	p.next()
	is_grouped := p.tok == .lpar
	if is_grouped {
		p.next()
	}
	mut fields := []ast.FieldInit{}
	for {
		name := p.expect_name()
		p.expect(.assign)
		value := p.expr(.lowest)
		fields << ast.FieldInit{
			name: name
			value: value
		}
		if !is_grouped {
			break
		} else if p.tok == .rpar {
			p.next()
			break
		}
	}
	return ast.ConstDecl{
		is_public: is_public
		fields: fields
	}
}

fn (mut p Parser) fn_decl(is_public bool, attributes []ast.Attribute) ast.FnDecl {
	pos := p.pos
	p.next()
	line := p.line
	// method
	mut is_method := false
	mut receiver := ast.Parameter{}
	if p.tok == .lpar {
		is_method = true
		p.next()
		// TODO: use parse_ident & type
		// receiver := p.ident() ?
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
		}
		// // TODO: clean up, will this be done here or in checker
		// receiver_name := p.expect_name()
		// mut receiver_type := p.expect_type()
		// if is_mut {
		// 	if mut receiver_type is ast.PrefixExpr {
		// 		if receiver_type.op == .amp {
		// 			p.error('use `mut Type` not `mut &Type`. TODO: proper error message')
		// 		}
		// 	}
		// 	receiver_type = ast.PrefixExpr{op: .amp, expr: receiver_type}
		// }
		receiver_pos := p.pos
		receiver = ast.Parameter{
			name: p.expect_name()
			typ: p.expect_type()
			// name: receiver_name
			// typ: receiver_type
			is_mut: is_mut
			pos: receiver_pos
		}
		p.expect(.rpar)
		// operator overload
		// TODO: what a mess finish / clean up & separate if possible
		if p.tok.is_overloadable() {
			// println('look like overload!')
			op := p.tok()
			_ = op
			p.expect(.lpar)
			is_mut2 := p.tok == .key_mut
			_ = is_mut2
			if is_mut {
				p.next()
			}
			receiver2 := ast.Parameter{
				name: p.expect_name()
				typ: p.expect_type()
				is_mut: is_mut
			}
			_ = receiver2
			p.expect(.rpar)
			mut return_type := ast.empty_expr
			_ = return_type
			if p.tok != .lcbr && p.line == line {
				return_type = p.expect_type()
			}
			p.block()
			// TODO
			return ast.FnDecl{
				pos: p.pos
			}
		}
	}
	language := p.decl_language()
	name_ident := p.ident()
	mut name := name_ident.name
	mut is_static := false
	if p.tok == .dot {
		p.next()
		// static method `Type.name`
		if language == .v {
			name = p.expect_name()
			is_method = true
			is_static = true
			receiver = ast.Parameter{
				typ: name_ident
			}
		}
		// eg. `Promise.resolve` in `JS.Promise.resolve`
		else {
			name += '.' + p.expect_name()
			for p.tok == .dot {
				p.next()
				name += '.' + p.expect_name()
			}
		}
	}
	typ := p.fn_type()
	// p.log('ast.FnDecl: $name $p.lit - $p.tok ($p.lit) - $p.tok_next_')
	// also check line for better error detection
	// stmts := if p.tok == .lcbr || p.line == line {
	stmts := if p.tok == .lcbr {
		p.block()
	} else {
		[]ast.Stmt{}
	}
	return ast.FnDecl{
		attributes: attributes
		is_public: is_public
		is_method: is_method
		is_static: is_static
		receiver: receiver
		name: name
		language: language
		typ: typ
		stmts: stmts
		pos: pos
	}
}

fn (mut p Parser) fn_parameters() []ast.Parameter {
	p.expect(.lpar)
	mut params := []ast.Parameter{}
	for p.tok != .rpar {
		// TODO: parse all modifiers (shared)
		pos := p.pos
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
		}
		// NOTE: case documented in `p.try_type()` todo
		mut typ := p.expect_type()
		mut name := ''
		if mut typ is ast.Ident && p.tok !in [.comma, .rpar] {
			name = typ.name
			typ = p.expect_type()
		}
		params << ast.Parameter{
			name: name
			typ: typ
			is_mut: is_mut
			pos: pos
		}
		if p.tok == .comma {
			p.next()
		}
	}
	p.next()
	return params
}

fn (mut p Parser) fn_arguments() []ast.Expr {
	p.expect(.lpar)
	// args := if p.tok == .rpar { []ast.Expr{} } else { p.expr_list() }
	// NOTE: not using p.expr_list() as I need to support config syntax
	// TODO: config syntax is getting deprecated, will become maps
	// eventually use named default params instead (once implemented)
	mut args := []ast.Expr{}
	for p.tok != .rpar {
		// TODO: is this how we will handle `...varg`
		expr := if p.tok == .ellipsis { ast.Expr(ast.PrefixExpr{
				op: p.tok()
				expr: p.expr(.lowest)
			}) } else { p.expr(.lowest) }
		// short struct config syntax
		// TODO: if also supported anywhere else it can be moved to `p.expr()`
		if p.tok == .colon {
			p.next()
			// println('looks like config syntax')
			if expr !is ast.Ident {
				p.error('expecting ident for struct config syntax?')
			}
			args << ast.FieldInit{
				name: (expr as ast.Ident).name
				value: p.expr(.lowest)
			}
		} else {
			args << expr
		}
		// args << expr
		if p.tok == .comma {
			p.next()
		}
	}
	p.next()
	return args
}

fn (mut p Parser) enum_decl(is_public bool, attributes []ast.Attribute) ast.EnumDecl {
	p.next()
	name := p.expect_name()
	as_type := if p.tok == .key_as {
		p.next()
		p.expect_type()
	} else {
		ast.empty_expr
	}
	// p.log('ast.EnumDecl: $name')
	p.expect(.lcbr)
	mut fields := []ast.FieldDecl{}
	for p.tok != .rcbr {
		field_name := p.expect_name()
		mut value := ast.empty_expr
		if p.tok == .assign {
			p.next()
			value = p.expr(.lowest)
		}
		field_attributes := if p.tok in [.attribute, .lsbr] {
			p.attributes()
		} else {
			[]ast.Attribute{}
		}
		fields << ast.FieldDecl{
			name: field_name
			value: value
			attributes: field_attributes
		}
	}
	p.next()
	return ast.EnumDecl{
		attributes: attributes
		is_public: is_public
		name: name
		as_type: as_type
		fields: fields
	}
}

fn (mut p Parser) global_decl(attributes []ast.Attribute) ast.GlobalDecl {
	p.next()
	// NOTE: this got changed at some stage (or perhaps was never forced)
	// if p.tok != .lpar {
	//     p.error('globals must be grouped, e.g. `__global ( a = int(1) )`')
	// }
	// p.next()
	is_grouped := p.tok == .lpar
	if is_grouped {
		p.next()
	}
	mut fields := []ast.FieldDecl{}
	for {
		name := p.expect_name()
		if p.tok == .assign {
			p.next()
			fields << ast.FieldDecl{
				name: name
				value: p.expr(.lowest)
			}
		} else {
			fields << ast.FieldDecl{
				name: name
				typ: p.expect_type()
			}
		}
		if !is_grouped {
			break
		} else if p.tok == .rpar {
			p.next()
			break
		}
	}
	return ast.GlobalDecl{
		attributes: attributes
		fields: fields
	}
}

fn (mut p Parser) interface_decl(is_public bool, attributes []ast.Attribute) ast.InterfaceDecl {
	p.next()
	mut name := p.expect_name()
	for p.tok == .dot {
		p.next()
		name += p.expect_name()
	}
	generic_params := if p.tok == .lsbr { p.generic_list() } else { []ast.Expr{} }
	p.expect(.lcbr)
	mut fields := []ast.FieldDecl{}
	mut embedded := []ast.Expr{}
	for p.tok != .rcbr {
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
			p.expect(.colon)
		}
		line := p.line
		mut field_name := ''
		mut field_type := p.expect_type()
		// `field type`
		if p.line == line {
			if mut field_type is ast.Ident {
				field_name = field_type.name
			} else {
				p.error('expecting field name')
			}
			fields << ast.FieldDecl{
				name: field_name
				typ: if p.tok == .lpar { ast.Type(p.fn_type()) } else { p.expect_type() }
			}
		}
		// embedded interface
		else {
			embedded << field_type
		}
	}
	// rcbr
	p.next()
	return ast.InterfaceDecl{
		is_public: is_public
		attributes: attributes
		name: name
		generic_params: generic_params
		embedded: embedded
		fields: fields
	}
}

fn (mut p Parser) struct_decl(is_public bool, attributes []ast.Attribute) ast.StructDecl {
	// TODO: union
	// is_union := p.tok == .key_union
	pos := p.pos
	p.next()
	language := p.decl_language()
	name := p.expect_name()
	generic_params := if p.tok == .lsbr { p.generic_list() } else { []ast.Expr{} }
	// p.log('ast.StructDecl: $name')
	// probably C struct decl with no body or {}
	if p.tok != .lcbr {
		return ast.StructDecl{
			is_public: is_public
			language: language
			name: name
		}
	}
	p.next()
	// fields
	mut fields := []ast.FieldDecl{}
	mut embedded := []ast.Expr{}
	for p.tok != .rcbr {
		is_pub := p.tok == .key_pub
		if is_pub {
			p.next()
		}
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
		}
		if is_pub || is_mut {
			p.expect(.colon)
		}
		line := p.line
		// NOTE: case documented in `p.try_type()` todo
		embed_or_name := p.expect_type()
		// embedded struct
		if p.line != line {
			if language != .v {
				p.error('${language} structs do not support embedding')
			}
			embedded << embed_or_name
			continue
		}
		// field
		field_name := match embed_or_name {
			ast.Ident { embed_or_name.name }
			else { p.error('invalid field name') }
		}
		field_type := p.expect_type()
		// field - default value
		field_value := if p.tok == .assign {
			p.next()
			p.expr(.lowest)
		} else {
			ast.empty_expr
		}
		field_attributes := if p.tok in [.attribute, .lsbr] {
			p.attributes()
		} else {
			[]ast.Attribute{}
		}
		fields << ast.FieldDecl{
			name: field_name
			typ: field_type
			value: field_value
			attributes: field_attributes
		}
	}
	p.next()
	return ast.StructDecl{
		attributes: attributes
		is_public: is_public
		embedded: embedded
		language: language
		name: name
		generic_params: generic_params
		fields: fields
		pos: pos
	}
}

fn (mut p Parser) select_expr() ast.Expr {
	exp_lcbr := p.exp_lcbr
	p.exp_lcbr = true
	stmt := p.simple_stmt()
	p.exp_lcbr = exp_lcbr
	stmts := if p.tok == .lcbr { p.block() } else { []ast.Stmt{} }
	select_expr := ast.SelectExpr{
		pos: p.pos
		stmt: stmt
		stmts: stmts
		next: if p.tok != .rcbr { p.select_expr() } else { ast.empty_expr }
	}
	return select_expr
}

fn (mut p Parser) assoc_or_init_expr(typ ast.Expr) ast.Expr {
	p.next() // .lcbr
	// assoc
	if p.tok == .ellipsis {
		p.next()
		lx := p.expr(.lowest)
		mut fields := []ast.FieldInit{}
		for p.tok != .rcbr {
			if p.tok == .comma {
				p.next()
			}
			field_name := p.expect_name()
			p.expect(.colon)
			fields << ast.FieldInit{
				name: field_name
				value: p.expr(.lowest)
			}
		}
		p.next()
		return ast.AssocExpr{
			typ: typ
			expr: lx
			fields: fields
		}
	}
	// struct init
	mut fields := []ast.FieldInit{}
	mut prev_has_name := false
	for p.tok != .rcbr {
		// could be name or init without field name
		mut field_name := ''
		mut value := p.expr(.lowest)
		// name / value
		if p.tok == .colon {
			match mut value {
				// ast.BasicLiteral { field_name = value.value }
				// ast.StringLiteral { field_name = value.value }
				ast.Ident { field_name = value.name }
				else { p.error('expected field name, got ${value.type_name()}') }
			}
			p.next()
			value = p.expr(.lowest)
		}
		has_name := field_name.len > 0
		if fields.len > 0 && has_name != prev_has_name {
			p.error('cant mix & match name & no name')
		}
		prev_has_name = has_name
		if p.tok == .comma {
			p.next()
		}
		fields << ast.FieldInit{
			name: field_name
			value: value
		}
	}
	p.next()
	return ast.InitExpr{
		typ: typ
		fields: fields
	}
}

fn (mut p Parser) string_literal(kind ast.StringLiteralKind) ast.Expr {
	value0 := p.lit()
	if p.tok != .str_dollar {
		return ast.StringLiteral{
			kind: kind
			value: value0
		}
	}
	mut values := []string{}
	mut inters := []ast.StringInter{}
	values << value0
	p.next()
	p.expect(.lcbr)
	inters << p.string_inter()
	p.expect(.rcbr)
	for p.tok == .string {
		value := p.lit()
		values << value
		if p.tok == .str_dollar {
			p.next()
			p.expect(.lcbr)
			inters << p.string_inter()
			p.expect(.rcbr)
		}
	}
	return ast.StringInterLiteral{
		kind: kind
		values: values
		inters: inters
	}
}

// TODO: finish
fn (mut p Parser) string_inter() ast.StringInter {
	expr := p.expr(.lowest)
	mut format := ast.StringInterFormat.unformatted
	mut format_expr := ast.empty_expr
	// TODO: proper
	if p.tok == .colon {
		p.next()
		// temp
		if p.tok in [.number, .minus, .plus] {
			format_expr = p.expr(.lowest)
		}
		// TODO
		// if p.tok == .minus {
		// 	p.next()
		// }
		// else if p.tok == .plus {
		// 	p.next()
		// }
		// if p.tok == .number {
		// 	_ = p.lit()
		// }
		if p.tok == .name {
			format = ast.StringInterFormat.from_u8(p.lit[0]) or { p.error(err.msg()) }
			p.next()
		}
	}
	return ast.StringInter{
		format: format
		format_expr: format_expr
		expr: expr
	}
}

[inline]
fn (mut p Parser) generic_list() []ast.Expr {
	p.next()
	mut generic_list := [p.expect_type()]
	for p.tok == .comma {
		p.next()
		generic_list << p.expect_type()
	}
	p.expect(.rsbr)
	return generic_list
}

[direct_array_access]
fn (mut p Parser) decl_language() ast.Language {
	mut language := ast.Language.v
	if p.lit.len == 1 && p.lit[0] == `C` {
		language = .c
	} else if p.lit.len == 2 && p.lit[0] == `J` && p.lit[1] == `S` {
		language = .js
	} else {
		return language
	}
	p.next()
	p.expect(.dot)
	return language
}

fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.expect_name()
	generic_params := if p.tok == .lsbr { p.generic_list() } else { []ast.Expr{} }

	// p.log('ast.TypeDecl: $name')
	p.expect(.assign)
	typ := p.expect_type()

	// alias `type MyType = int`
	if p.tok != .pipe {
		return ast.TypeDecl{
			is_public: is_public
			name: name
			generic_params: generic_params
			parent_type: typ
		}
	}
	// sum type `type MyType = int | string`
	p.next()
	mut variants := [typ, p.expect_type()]
	for p.tok == .pipe {
		p.next()
		variants << p.expect_type()
	}
	// TODO: consider separate node for alias / sum type ?
	return ast.TypeDecl{
		is_public: is_public
		name: name
		generic_params: generic_params
		variants: variants
	}
}

[inline]
fn (mut p Parser) ident() ast.Ident {
	return ast.Ident{
		pos: p.pos
		name: p.expect_name()
	}
}

[inline]
fn (mut p Parser) ident_or_selector_expr() ast.Expr {
	ident := p.ident()
	if p.tok == .dot {
		p.next()
		if p.tok == .dollar {
			p.next()
			p.expr(.lowest)
			return ast.SelectorExpr{
				lhs: ident
				rhs: ast.Ident{
					name: 'TODO: comptime selector'
				}
				pos: p.pos
			}
		}
		return ast.SelectorExpr{
			lhs: ident
			rhs: p.ident()
			pos: p.pos
		}
	}
	return ident
}

fn (mut p Parser) log(msg string) {
	if p.pref.verbose {
		println(msg)
	}
}

// TODO/NOTE: this can be completely replaced with token.File.position()
// I was only using this since it skips the binary search and is slightly
// faster, howevrer if only used in error conditions this is irrelevant.
fn (mut p Parser) current_position() token.Position {
	pos := p.pos - p.file.base
	return token.Position{
		filename: p.file.name
		line: p.line
		offset: pos
		column: pos - p.file.line_start(p.line) + 1
	}
}

fn (mut p Parser) error_expected(exp token.Token, got token.Token) {
	p.error('unexpected token. expecting `${exp}`, got `${got}`')
}

// so we can customize the error message used by warn & error
fn (mut p Parser) error_message(msg string, kind errors.Kind, pos token.Position) {
	errors.error(msg, errors.details(p.file, pos, 2), kind, pos)
}

fn (mut p Parser) warn(msg string) {
	p.error_message(msg, .warning, p.current_position())
}

[noreturn]
fn (mut p Parser) error(msg string) {
	p.error_with_position(msg, p.current_position())
	// p.error_with_position(msg, p.file.position(p.pos))
}

[noreturn]
fn (mut p Parser) error_with_pos(msg string, pos token.Pos) {
	p.error_with_position(msg, p.file.position(pos))
}

[noreturn]
fn (mut p Parser) error_with_position(msg string, pos token.Position) {
	p.error_message(msg, .error, pos)
	exit(1)
}
