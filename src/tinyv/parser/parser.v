// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

import os
import time
import tinyv.ast
import tinyv.scanner
import tinyv.token
import tinyv.pref
import tinyv.util

pub struct Parser {
	pref      &pref.Preferences
mut:
	scanner   &scanner.Scanner
	filename  string
	// track state
	in_init   bool // for/if/match eg. `for x in vals {`
	exp_pt    bool // expecting (p)ossible (t)ype from `p.expr()`
	// start token info
	line      int
	lit       string
	pos       int
	tok       token.Token = .unknown
	tok_next_ token.Token = .unknown // DO NOT access directly, use `p.peek()`
	// end token info
}

pub fn new_parser(prefs &pref.Preferences) &Parser {
	unsafe { return &Parser{
		pref: prefs
		scanner: scanner.new_scanner(prefs, false)
	} }
}

pub fn (mut p Parser) reset() {
	p.scanner.reset()
	p.line = 0
	p.lit = ''
	p.pos = 0
	p.tok = .unknown
	p.tok_next_ = .unknown
}

pub fn (mut p Parser) parse_files(files []string) []ast.File {
	mut ast_files := []ast.File{}
	for file in files {
		ast_files << p.parse_file(file)
	}
	return ast_files
}

pub fn (mut p Parser) parse_file(filename string) ast.File {
	// reset if we are reusing parser instance
	if p.scanner.pos > 0 {
		p.reset()
	}
	if !p.pref.verbose {
		unsafe { goto start_no_time }
	}
	mut sw := time.new_stopwatch()
	start_no_time:
	p.filename = filename
	text := os.read_file(filename) or {
		p.error('error reading $filename')
	}
	p.scanner.set_text(text)
	// start
	p.next()
	mut top_stmts := []ast.Stmt{}
	mut imports := []ast.ImportStmt{}
	for p.tok != .eof {
		stmt := p.top_stmt()
		if stmt is ast.ImportStmt {
			imports << stmt
		}
		top_stmts << stmt
	}
	if p.pref.verbose {
		parse_time := sw.elapsed()
		println('scan & parse $filename ($p.scanner.line_offsets.len LOC): ${parse_time.milliseconds()}ms (${parse_time.microseconds()}us)')
	}
	return ast.File{
		path: filename
		imports: imports
		stmts: top_stmts
	}
}

pub fn (mut p Parser) top_stmt() ast.Stmt {
	match p.tok {
		.dollar {
			p.next()
			// NOTE: expr() could handle this if we blindly return an ExprStmt.
			// however it is being done this way for better error detection.
			match p.tok {
				.key_if { return ast.ExprStmt{expr: ast.ComptimeExpr{expr: p.if_expr(true)}} }
				else { p.error('unexpected comptime: $p.tok') }
			}
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
		.key_import {
			p.next()
			// NOTE: we can also use SelectorExpr if we like
			// mod := p.expr(.lowest)
			mut name := p.expect_name()
			mut alias := name
			for p.tok == .dot {
				p.next()
				alias = p.expect_name()
				name += '.$alias'
			}
			is_aliased := p.tok == .key_as
			if is_aliased {
				p.next()
				alias = p.expect_name()
			}
			// p.log('ast.ImportStmt: $name as $alias')
			return ast.ImportStmt{
				name: name
				alias: alias
				is_aliased: is_aliased
			}
		}
		.key_interface {
			return p.interface_decl(false)
		}
		.key_module {
			p.next()
			name := p.expect_name()
			// p.log('ast.ModuleStmt: $name')
			return ast.ModuleStmt{
				name: name
			}
		}
		.key_pub {
			p.next()
			match p.tok {
				.key_const { return p.const_decl(true) }
				.key_enum { return p.enum_decl(true, []) }
				.key_fn { return p.fn_decl(true, []) }
				.key_interface { return p.interface_decl(true) }
				.key_struct, .key_union { return p.struct_decl(true, []) }
				.key_type { return p.type_decl(true) }
				else { p.error('not implemented: pub $p.tok') }
			}
		}
		.key_struct, .key_union {
			return p.struct_decl(false, [])
		}
		.key_type {
			return p.type_decl(false)
		}
		.lsbr {
			attributes := p.attributes()
			mut is_pub := false
			if p.tok == .key_pub {
				p.next()
				is_pub = true
			}
			match p.tok {
				.key_enum { return p.enum_decl(is_pub, attributes) }
				.key_fn { return p.fn_decl(is_pub, attributes) }
				.key_global { return p.global_decl(attributes) }
				.key_struct { return p.struct_decl(is_pub, attributes) }
				else {
					// file level attributes
					// or we are missing a stmt which supports attributes in this match
					for attribute in attributes {
						match attribute.name {
							'has_globals' {}
							else {
								p.warn('invalid file level attribute `$attribute.name` (or should `$p.tok` support attributes)')
							}
						}
					}
					// if p.attributes.len > 0 {
					// 	p.error('file level attributes must be declared only once at the start of the file')
					// }
					// TODO: should we store these attributes then add them to ast.File?
					// p.attributes = attributes
					return ast.empty_stmt
				}
			}
		}
		else {
			p.error('unknown top stmt: $p.tok - $p.filename:$p.line')
		}
	}
	
}

pub fn (mut p Parser) stmt() ast.Stmt {
	// p.log('STMT: $p.tok - $p.filename:$p.line')
	match p.tok {
		.dollar {
			p.next()
			// NOTE: we could remove this branch completely in which case it would be
			// handled in the else branch below by expr() and returned as ExprStmt.
			// expr() could also handle this if we blindly return an ExprStmt here.
			// however it is being done this way for better error detection.
			match p.tok {
				.key_if { return ast.ExprStmt{expr: ast.ComptimeExpr{expr: p.if_expr(true)}} }
				else { p.error('unexpected comptime: $p.tok') }
			}
		}
		.hash {
			return p.directive()
		}
		.key_assert {
			p.next()
			return ast.AssertStmt{expr: p.expr(.lowest)}
		}
		.key_break, .key_continue, .key_goto {
			line := p.line
			op := p.tok()
			if p.line == line && p.tok == .name {
				return ast.FlowControlStmt{op: op, label: p.expect_name()}
			} else {
				return ast.FlowControlStmt{op: op}
			}
		}
		.key_defer {
			p.next()
			return ast.DeferStmt{stmts: p.block()}
		}
		.key_for {
			return p.for_stmt()
		}
		.key_return {
			// p.log('ast.ReturnStmt')
			p.next()
			// small optimization, save call/array init
			if p.tok == .rcbr {
				return ast.ReturnStmt{}
			}
			return ast.ReturnStmt{
				exprs: p.expr_list()
			}
		}
		.lcbr {
			// anonymous block `{ a := 1 }`
			return ast.Block {
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
					stmt: if p.tok == .key_for { p.stmt() } else { ast.empty_stmt }
				}
			}
			// stand alone expression in a statement list
			// eg: `if x == 1 {`, `x++`, `mut x := 1`, `a,`b := 1,2`
			// multi assign from match/if `a, b := if x == 1 { 1,2 } else { 3,4 }
			if p.tok == .comma {
				p.next()
				// it's a little extra code, but also a little more
				// efficient than using expr_list and creating 2 arrays
				mut exprs := [expr]
				for {
					exprs << p.expr(.lowest)
					if p.tok != .comma {
						break
					}
					p.next()
				}
				// doubling up assignment check also for efficiency
				// to avoid creating array from expr_list each time
				if p.tok.is_assignment() {
					return p.assign(exprs)
				}
				return ast.ExprStmt{
					ast.Tuple{exprs: exprs}
				}
			}
			if p.tok.is_assignment() {
				return p.assign([expr])
			}
			// TODO: add check for all ExprStmt eg.
			// if expr is ast.ArrayInitExpr {
			// 	p.error('UNUSED')
			// }
			return ast.ExprStmt{
				expr: expr
			}
		}
	}
	p.error('unknown stmt: $p.tok')
}

pub fn (mut p Parser) expr(min_bp token.BindingPower) ast.Expr {
	// p.log('EXPR: $p.tok - $p.line')
	mut line := p.line
	mut lhs := ast.empty_expr
	match p.tok {
		.char, .key_true, .key_false, .number, .string {
			lhs = ast.BasicLiteral{
				kind: p.tok
				value: p.lit()
			}
		}
		.key_fn {
			p.next()
			mut generic_params := []ast.Expr{}
			if p.tok == .lsbr {
				p.next()
				generic_params << p.expect_type()
				for p.tok == .comma {
					p.next()
					generic_params << p.expect_type()
				}
				p.expect(.rsbr)
			}
			// TODO: closure variable capture syntax is the same as generic arg/param syntax. This should change.
			// Because of this generic closures cannot exist, even though there is probably no use for them.
			// If I remember correctly, Go does not allow generic closures. Unless I'm thinking of another lang.
			// TODO: proper - closure vars
			if p.tok == .lsbr {
				p.next()
				for p.tok != .rsbr {
					p.expr(.lowest)
					if p.tok == .comma {
						p.next()
					}
				}
				p.next()
			}
			params := p.fn_parameters()
			// NOTE: we may need to check line due to the generic call case listed below
			// return_type := if line == p.line { p.try_type() } else { ast.empty_expr }
			// return_type := p.try_type() or { ast.empty_expr }
			return_type := p.try_type()
			// this only occurs if parsing generic fn in generic call `fn_generic_b<fn<int>(int),int>()`
			// since we need to use expr() instead of typ() because we don't yet know what we are parsing.
			// take a look at expr chaining loop branch `if p.tok == .lt`
			// TODO: are we using ast.GenericArgs in this case?
			if p.exp_pt && p.tok != .lcbr {
				return ast.Type(ast.FnType{generic_params: generic_params, params: params, return_type: return_type})
			}
			lhs = ast.FnLiteral{
				generic_params: generic_params
				params: params
				stmts: p.block()
				return_type: return_type
			}
		}
		.key_go {
			p.next()
			return ast.GoExpr{expr: p.expr(.lowest)}
		}
		.key_if {
			return p.if_expr(false)
		}
		// NOTE: handle all these using KeywordOperator for now, if or
		// as needed later we can split them off into their own types.
		// NOTE: I would much rather dump, likely, and unlikely were
		// some type of comptime fn/macro's which come as part of the
		// v stdlib, as apposed to being language keywords.
		.key_typeof {
			op := p.tok()
			p.expect(.lpar)
			expr := p.type_or_expr(.lowest)
			p.expect(.rpar)
			lhs = ast.KeywordOperator{op: op, expr: expr}
		}
		// .key_dump, .key_likely, .key_unlikely, .key_isreftype, .key_sizeof, .key_typeof {
		.key_dump, .key_likely, .key_unlikely, .key_isreftype, .key_sizeof {
			op := p.tok()
			p.expect(.lpar)
			expr := p.expr(.lowest)
			p.expect(.rpar)
			lhs = ast.KeywordOperator{op: op, expr: expr}
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
			in_init := p.in_init
			p.in_init = true
			exprs := p.expr_list()
			p.in_init = in_init
			return ast.LockExpr{
				kind: kind
				exprs: exprs
				stmts: p.block()
			}
		}
		.dollar {
			p.next()
			match p.tok {
				.key_if { return ast.ComptimeExpr{expr: p.if_expr(true)} }
				else { return ast.ComptimeExpr{expr: p.expr(.lowest)} }
			}
		}
		.lpar {
			p.next()
			// p.log('ast.ParenExpr:')
			lhs = ast.ParenExpr{
				expr: p.expr(.lowest)
			}
			p.expect(.rpar)
		}
		.lcbr {
			// shorthand map / struct init
			if !p.in_init {
				// TODO: options struct - what?
				// lhs = p.struct_init()
				p.next()
				if p.tok == .ellipsis {
					p.error('this assoc syntax is no longer supported `{...`. You must explicitly specify a type `MyType{...`')
				}
				// empty map init `{}`
				if p.tok == .rcbr {
					p.next()
					return ast.MapInitExpr{}
				}
				// map init
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
				// panic('GOT HERE. hrmm?')
				lhs = ast.MapInitExpr{
					keys: keys
					vals: vals
				}
			}
		}
		.lsbr {
			// ArrayInitExpr: `[1,2,3,4]` | `[]int{}` | `[]int{len: 4}` | `[2]int{init: 0}` etc...
			// ArrayInitExpr->IndexExpr: `[1,2,3,4][0]` handled here for reasons listed in comment below
			// ArrayType in CastExpr: `[]u8` in `[]u8(x)` set type as it's known, cast handled later
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
			// (`[2]int{}` | `[2][2]int{}` | `[2][]int{}`) | `[1,2,3,4][0]` | `[2]u8(x)`
			// NOTE: it's tricky to differentiate between a fixed array of fixed array(s)
			// and an index directly after initialization. for example, the following:
			// a) fixed array of fixed array(s): `[2][2]int{}` | `[2][2][2]int{}`
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
						exprs2 << p.expr(.lowest)
						if p.tok == .comma {
							p.next()
						}
					}
					p.next()
					exprs_arr << exprs2
				}
				// (`[2]int{}` | `[2][]string{}` | `[2]&Foo{init: Foo{}}`) | `[2]u8(x)`
				if p.tok in [.amp, .name/*, .question*/] && p.line == line {
					mut typ := p.expect_type()
					for i:=exprs_arr.len-1; i>=0; i-- {
						exprs2 := exprs_arr[i]
						if exprs2.len == 0  {
							typ = ast.Type(ast.ArrayType{elem_type: typ})
						}
						else if exprs2.len == 1 {
							typ = ast.Type(ast.ArrayFixedType{elem_type: typ, len: exprs2[0]})
						}
						else {
							// TODO: use same error message as typ() `expect(.rsbr)`
							p.error('expecting single expr for fixed array length')
						}
					}
					// cast `[2]u8(x)` we know this is a cast
					// set lhs as the type, cast handled later in expr loop
					if p.tok == .lpar {
						lhs = typ
					}
					// `[2]int{}` | `[2][]string{}` | `[2]&Foo{init: Foo{}}`
					else {
						if p.exp_pt && p.tok != .lcbr { return typ }
						p.expect(.lcbr)
						mut init := ast.empty_expr
						if p.tok != .rcbr {
							key := p.expect_name()
							p.expect(.colon)
							match key {
								'init'  { init = p.expr(.lowest) }
								else   { p.error('expecting `init`, got `$key`') }
							}
						}
						p.next()
						lhs = ast.ArrayInitExpr{
							typ: typ
							init: init
						}
					}
				}
				// `[1][0]` | `[1,2,3,4][0]` | `[[1,2,3,4]][0][1]` <-- index directly after init
				else {
					lhs = ast.ArrayInitExpr{
						exprs: exprs
					}
					for i:= 1; i<exprs_arr.len; i++ {
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
			// (`[]int{}` | `[][]string{}` | `[]&Foo{len: 2}`) | `[]u8(x)`
			else if p.tok in [.amp, .lsbr, .name/*, .question*/] && p.line == line {
				typ := ast.Type(ast.ArrayType{elem_type: p.expect_type()})
				// cast `[]u8(x)` we know this is a cast
				// set lhs as the type, cast handled later in expr loop
				if p.tok == .lpar {
					lhs = typ
				}
				// `[]int{}` | `[][]string{}` | `[]&Foo{len: 2}`
				else {
					if p.exp_pt && p.tok != .lcbr { return typ }
					p.expect(.lcbr)
					mut cap, mut init, mut len := ast.empty_expr, ast.empty_expr, ast.empty_expr
					for p.tok != .rcbr {
						key := p.expect_name()
						p.expect(.colon)
						match key {
							'cap'  { cap = p.expr(.lowest) }
							'init' { init = p.expr(.lowest) }
							'len'  { len = p.expr(.lowest) }
							else   { p.error('expecting one of `cap, init, len`, got `$key`') }
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
					}
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
					// TODO: don't need this, we do need some way to indicate `!` though
					len: ast.BasicLiteral{kind: .number, value: exprs.len.str()}
				}
			// `[]` | `[1,2,3,4]`
			} else {
				lhs = ast.ArrayInitExpr{
					exprs: exprs
				}
			}
		}
		.key_match {
			p.next()
			mut in_init := p.in_init
			p.in_init = true
			expr := p.expr(.lowest)
			p.in_init = in_init
			p.expect(.lcbr)
			mut branches := []ast.Branch{}
			for p.tok != .rcbr {
				in_init = p.in_init
				p.in_init = true
				cond := p.expr_list()
				p.in_init = in_init
				branches << ast.Branch {
					cond: cond
					stmts: p.block()
				}
				if p.tok == .key_else {
					p.next()
					branches << ast.Branch {
						stmts: p.block()
					}
				}
			}
			// update linr_nr to support chaining
			line = p.line
			// rcbr
			p.next()
			lhs = ast.MatchExpr{
				expr: expr
				branches: branches
			}
		}
		.key_mut, .key_shared, .key_static {
			return ast.Modifier {
				kind: p.tok()
				expr: p.expr(.lowest)
			}
		}
		.key_unsafe {
			// p.log('ast.UnsafeExpr')
			p.next()
			lhs = ast.UnsafeExpr{
				stmts: p.block()
			}
		}
		.name {
			// NOTE: we could also use expect_type() here since it also returns
			// ident & selector, but we are repeating some code for efficiency
			match p.lit {
				'map' {
					p.next()
					if p.tok == .lsbr {
						p.next()
						key_type := p.expect_type()
						p.expect(.rsbr)
						value_type := p.expect_type()
						map_type := ast.Type(ast.MapType{key_type: key_type, value_type: value_type})
						if p.exp_pt && p.tok != .lcbr { return map_type }
						p.expect(.lcbr)
						p.expect(.rcbr)
						return ast.MapInitExpr{typ: map_type}
					}
					lhs = ast.Ident{name: 'map'}
				}
				else { lhs = p.ident() }
			}
			// NOTE: since we're returning struct init here, we complete the selector
			// but if we move the init to expr loop then we can use if instead of for
			// if p.tok == .dot {
			for p.tok == .dot {
				p.next()
				lhs = ast.SelectorExpr{lhs:lhs, rhs: p.ident()}
			}
			// TODO: move inits to expr loop
			// NOTE: since we are not relying on capital for types
			// and therefore struct init, it's not so simple to parse
			// the following cases without trickery (TODO: consider).
			// `if err == IError(Eof{}) {`
			// `if Foo{} == Foo{} {`
			if p.tok == .lcbr && !p.in_init {
				return p.assoc_or_struct_init(lhs)
			}
		}
		// selector (enum value), range. handled in loop below
		.dot, .dotdot, .ellipsis {}
		else {
			if p.tok.is_prefix() {
				// NOTE: just use .highest for now, later we might need to define for each op
				lhs = ast.PrefixExpr{
					op: p.tok()
					expr: p.expr(.highest)
				}
			} else {
				p.error('expr: unexpected token `$p.tok`')
			}
		}
	}
	
	// expr chaining
	// for now I am doing this outside of the pratt loop 
	// the pratt loop is currently just being used for basic infix & postfix operators
	// I might decide to change this later.
	for {
		// call | cast
		if p.tok == .lpar {
			// TODO: handle by checking expr?
			// (*ptr_a) = *ptr_a - 1
			if p.line != line {
				return lhs
			}
			// p.log('ast.CastExpr or CallExpr: ${typeof(lhs)}')
			args := p.fn_arguments()
			// definitely a call since we have `!` | `?`
			// fncall()! (Propagate Result) | fncall()? (Propagate Option)
			if p.tok in [.not, .question] {
				lhs = ast.PostfixExpr{expr: lhs, op: p.tok()}
				lhs = ast.CallExpr{
					lhs: lhs
					args: args
				}
			}
			// could be a call or a cast (1 arg)
			else if args.len == 1 {
				// definitely a cast
				if lhs is ast.Type {
					lhs = ast.CastExpr{
						typ: lhs
						expr: args[0]
					}
				}
				// work this out after type checking
				else {
					lhs = ast.CallOrCastExpr{
						lhs: lhs
						expr: args[0]
					}
				}
			}
			// definitely a call (0 args, or more than 1 arg)
			else {
				lhs = ast.CallExpr{
					lhs: lhs
					args: args
				}
			}
		}
		// NOTE: if we want we can handle init like this
		// this is only needed for ident or selector, so there is really
		// no point handling it here, since it wont be used for chaining
		// else if p.tok == .lcbr && p.line == line && !p.in_init {
		// 	lhs = p.assoc_or_struct_init(lhs)
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
			is_gated := p.tok == .hash
			if is_gated {
				p.next()
				p.expect(.lsbr)
			} else {
				p.next() // .lsbr
			}
			// TODO: clean this up / simplify if possible
			mut exprs := []ast.Expr{}
			for {
				exprs << p.type_or_expr(.lowest)
				if p.tok != .comma {
					break
				}
				p.next()
			}
			p.expect(.rsbr)
			if p.tok == .lpar {
				lhs = ast.GenericArgs{lhs: lhs, args: exprs}
			}
			else if p.tok == .lcbr && p.line == line && !p.in_init {
				lhs = p.assoc_or_struct_init(ast.GenericArgs{lhs: lhs, args: exprs})
			}
			else {
				lhs = ast.IndexExpr{
					lhs: lhs
					expr: exprs[0]
					is_gated: is_gated
				}
			}
		}
		// SelectorExpr
		else if p.tok == .dot {
			p.next()
			// p.log('ast.SelectorExpr')
			lhs = ast.SelectorExpr{
				lhs: lhs
				rhs: p.expr(.lowest)
			}
		}
		else if p.tok == .key_or {
			// p.log('ast.OrExpr')
			p.next()
			lhs = ast.OrExpr{
				expr: lhs
				stmts: p.block()
			}
		}
		// range
		else if p.tok in [.dotdot, .ellipsis] {
			// p.log('ast.RangeExpr')
			// no need to continue
			return ast.RangeExpr{
				op: p.tok()
				start: lhs
				end: if p.tok == .rsbr { ast.empty_expr } else { p.expr(.lowest) }
			}
		}
		else {
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
			op := p.tok()
			lhs = ast.InfixExpr{
				op: op
				lhs: lhs
				rhs: p.expr(op.right_binding_power())
			}
		}
		else if p.tok.is_postfix() {
			lhs = ast.PostfixExpr{
				op: p.tok()
				expr: lhs
			}
		}
		else {
			break
		}
	}
	// p.log('returning: $p.tok')
	return lhs
}

// parse either a type or expr, eg. `typeof(type|expr)`
fn (mut p Parser) type_or_expr(min_bp token.BindingPower) ast.Expr {
	// NOTE: don't use `p.try_type()` for `.lpar` here
	// otherwise `ParExpr` will be parsed as `Tuple`
	// if p.tok in [.question, .key_fn] {
	if p.tok == .question {
		return p.try_type()
	}
	// TODO: is there a better way? see uses of `p.exp_pt` above.
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
pub fn (mut p Parser) peek() token.Token {
	if p.tok_next_ == .unknown {
		p.tok_next_ = p.scanner.scan()
	}
	return p.tok_next_
}

[inline]
pub fn (mut p Parser) next() {
	if p.tok_next_ != .unknown {
		p.line = p.scanner.line_offsets.len
		p.lit = p.scanner.lit
		p.pos = p.scanner.pos
		p.tok = p.tok_next_
		p.tok_next_ = .unknown
	} else {
		p.tok = p.scanner.scan()
		p.line = p.scanner.line_offsets.len
		p.lit = p.scanner.lit
		p.pos = p.scanner.pos
	}
}

[inline]
pub fn (mut p Parser) expect(tok token.Token) {
	if p.tok != tok {
		p.error('unexpected token. expecting `$tok`, got `$p.tok`')
	}
	p.next()
}

// expect name & return lit & go to next token
[inline]
pub fn (mut p Parser) expect_name() string {
	name := p.lit
	// NOTE: if we do the checking in here instead if using expect it will
	// give us a minuscule speed gain, but for convenience I'm using expect
	p.expect(.name)
	return name
}

// return lit & go to next token
[inline]
pub fn (mut p Parser) lit() string {
	// TODO: check if there is a better way to handle this?
	// we should never use lit() in cases where p.lit is empty anyway
	// lit := if p.lit.len == 0 { p.tok.str() } else { p.lit }
	lit := p.lit
	p.next()
	return lit
}

// return tok & go to next token
[inline]
pub fn (mut p Parser) tok() token.Token {
	tok := p.tok
	p.next()
	return tok
}

[inline]
pub fn (mut p Parser) block() []ast.Stmt {
	mut stmts := []ast.Stmt{}
	p.expect(.lcbr)
	for p.tok != .rcbr {
		stmts << p.stmt()
	}
	// rcbr
	p.next()
	return stmts
}

[inline]
pub fn (mut p Parser) expr_list() []ast.Expr {
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

// [attribute]
pub fn (mut p Parser) attributes() []ast.Attribute {
	p.next()
	mut attributes := []ast.Attribute{}
	for {
		mut name := ''
		mut value := ''
		mut comptime_cond := ast.empty_expr
		// since unsafe is a keyword
		if p.tok == .key_unsafe {
			p.next()
			name = 'unsafe'
		}
		// TODO: properly
		// consider using normal if expr
		else if p.tok == .key_if {
			p.next()
			comptime_cond = p.expr(.lowest)
			if p.tok == .question {
				p.next()
				comptime_cond = ast.PostfixExpr{
					op: .question
					expr: comptime_cond
				}
			}
		}
		else {
			name = p.expect_name()
			if p.tok == .colon {
				p.next()
				// NOTE: use tok instead of defining AttributeKind
				// kind := p.tok
				// TODO: do we need the match below or should we use:
				// if p.tok in [.semicolon, .rsbr] { p.error('...') }
				value = match p.tok {
					.name, .number, .string { p.lit() }
					else { p.error('unexpected $p.tok, an argument is expected after `:`') }
				}
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
		// [attribute_a]
		// [attribute_b]
		if p.tok == .lsbr {
			p.next()
			continue
		}
		break
	}
	// p.log('ast.Attribute: $name')
	return attributes
}

[inline]
pub fn (mut p Parser) assign(lhs []ast.Expr) ast.AssignStmt {
	return ast.AssignStmt{op: p.tok(), lhs: lhs, rhs: p.expr_list()}
}

// TODO: should we use string or LabelStmt/Ident
pub fn (mut p Parser) for_stmt() ast.ForStmt {
	p.next()
	in_init := p.in_init
	p.in_init = true
	mut init, mut cond, mut post := ast.empty_stmt, ast.empty_expr, ast.empty_stmt
	// for in `for x in vals {`
	// stmt := if p.tok in [.lcbr, semicolon] { ast.empty_stmt } else { p.stmt() }
	// if p.tok in [.comma, .key_in] {
	tok_next := p.peek()
	if tok_next in [.comma, .key_in] {
		mut key, mut value := '', p.expect_name()
		// mut key, mut value := '', ''
		// if stmt is ast.ExprStmt {
		// 	if stmt.expr is ast.Ident {
		// 		value = stmt.expr.name
		// 	} else {
		// 		p.error('expecting identifier')
		// 	}
		// } else {
		// 	p.error('expecting identifier')
		// }
		mut value_is_mut := false
		if p.tok == .comma {
			p.next()
			key = value
			if p.tok == .key_mut {
				value_is_mut = true
				p.next()
			}
			value = p.expect_name()
		}
		p.expect(.key_in)
		init = ast.ForIn{
			key: key
			value: value
			value_is_mut: value_is_mut
			expr: p.expr(.lowest)
		}
	}
	// infinite `for {` and C style `for x:=1; x<=10; x++`
	else {
		if p.tok !in [.lcbr, .semicolon] {
			// init = stmt
			init = p.stmt()
		}
		if p.tok == .semicolon {
			p.next()
			if p.tok != .semicolon {
				cond = p.expr(.lowest)
			}
			p.expect(.semicolon)
			if p.tok != .lcbr {
				post = p.stmt()
			}
		}
	}
	p.in_init = in_init
	return ast.ForStmt{
		init: init
		cond: cond
		post: post
		stmts: p.block()
	}
}

pub fn (mut p Parser) if_expr(is_comptime bool) ast.IfExpr {
	// p.log('ast.IfExpr')
	// .key_if
	p.next()
	mut branches := []ast.Branch{}
	for {
		in_init := p.in_init
		p.in_init = true
		// mut cond := p.expr(.lowest)
		// NOTE: the line above works, but avoid calling p.expr()
		mut cond := if p.tok == .lcbr { ast.empty_expr }  else { p.expr(.lowest) }
		if p.tok == .question {
			// TODO: use postfix for this? handle individual cases like this or globally add to token.is_postfix()?
			cond = ast.PostfixExpr{expr: cond, op: p.tok}
			p.next()
		}
		// if guard
		// if p.tok in [.assign. .decl_assign] {
		if p.tok == .decl_assign {
			cond = ast.IfGuardExpr{
				stmt: p.assign([cond])
			}
		}
		p.in_init = in_init
		branches << ast.Branch{
			cond: [cond]
			stmts: p.block()
		}
		// else
		mut tok_next := p.peek()
		if p.tok == .key_else || (p.tok == .dollar && tok_next == .key_else) {
			// we are using expect instead of next to ensure we error when `is_comptime`
			// and not all branches have `$`, or `!is_comptime` and any branches have `$`.
			// the same applies for the `else if` condition directly below.
			if is_comptime { p.expect(.dollar) }
			p.expect(.key_else)
			// else if
			tok_next = p.peek()
			if p.tok == .key_if || (p.tok == .dollar && tok_next == .key_if) {
				if is_comptime { p.expect(.dollar) }
				p.expect(.key_if)
			}
		} else {
			break
		}
	}
	return ast.IfExpr{
		branches: branches
		is_comptime: is_comptime
	}
}

pub fn (mut p Parser) directive() ast.Directive {
	// value := p.lit() // if we scan whole line see scanner
	p.next()
	line := p.line
	name := p.expect_name()
	// TODO: handle properly
	mut value := p.lit()
	for p.line == line {
		value += p.lit()
	}
	return ast.Directive{
		name: name
		value: value
	}
}

pub fn (mut p Parser) const_decl(is_public bool) ast.ConstDecl {
	p.next()
	// p.expect(.lpar)
	mut is_single := true
	if p.tok == .lpar {
		p.next()
		is_single = false
	}
	mut fields := []ast.FieldInit{}
	for {
		name := p.expect_name()
		p.expect(.assign)
		value := p.expr(.lowest)
		fields << ast.FieldInit{
			name:  name
			value: value
		}
		if is_single || p.tok == .rpar {
			break
		}
	}
	// p.expect(.rpar)
	if p.tok == .rpar {
		p.next()
	}
	return ast.ConstDecl{
		is_public: is_public
		fields: fields
	}
}

pub fn (mut p Parser) fn_decl(is_public bool, attributes []ast.Attribute) ast.FnDecl {
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
		receiver = ast.Parameter{
			name: p.expect_name()
			typ: p.expect_type()
			is_mut: is_mut
		}
		p.expect(.rpar)
		// operator overload
		// TODO: finish / what a mess clean this up
		// try uncouple, or at least separate nicely
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
			return ast.FnDecl{}
		}
	}
	language, name := p.decl_lang_and_name()
	mut generic_params := []ast.Expr{}
	if p.tok == .lsbr {
		p.next()
		for {
			generic_params << p.expect_type()
			if p.tok != .comma {
				break
			}
			p.next()
		}
		p.expect(.rsbr)
	}
	params := p.fn_parameters()
	return_type := if p.tok != .lcbr && p.line == line { p.expect_type() } else { ast.empty_expr }
	// p.log('ast.FnDecl: $name $p.lit - $p.tok ($p.lit) - $p.tok_next_')
	// also check line for better error detection
	stmts := if p.tok == .lcbr /*|| p.line == line*/ { p.block() } else { []ast.Stmt{} }
	return ast.FnDecl{
		attributes: attributes
		is_public: is_public
		is_method: is_method
		receiver: receiver
		name: name
		language: language
		generic_params: generic_params
		params: params
		stmts: stmts
		return_type: return_type
	}
}

pub fn (mut p Parser) fn_parameters() []ast.Parameter {
	p.expect(.lpar)
	mut params := []ast.Parameter{}
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		// TODO: proper
		mut typ := p.expect_type()
		mut name := ''
		if p.tok == .name {
			name = (typ as ast.Ident).name
			typ = p.expect_type()
		}
		// name := if p.tok == .name && p.tok_next_ != .dot { p.expect_name() } else { 'param_$params.len' }
		// typ := if p.tok !in [.comma, .rpar] { p.expect_type() } else { ast.empty_expr }
		if p.tok == .comma {
			p.next()
		}
		params << ast.Parameter{
			name: name
			typ: typ
			is_mut: is_mut
		}
	}
	p.next()
	return params
}

pub fn (mut p Parser) fn_arguments() []ast.Expr {
	p.expect(.lpar)
	// args := if p.tok == .rpar { []ast.Expr{} } else { p.expr_list() }
	// NOTE: I'm doing this manually now instead of using p.expr_list()
	// because I need to support the config syntax. I think this is only
	// allowed in call args, need to double check.
	// TODO: config syntax is getting deprecated, will become maps 
	// eventually use named default params instead (once implemented)
	mut args := []ast.Expr{}
	for p.tok != .rpar  {
		mut expr := p.expr(.lowest)
		// TODO: where does this belong? here or in expr?
		// was this just allowed in args? need to check, cant remember
		// short short struct config syntax
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

pub fn (mut p Parser) enum_decl(is_public bool, attributes []ast.Attribute) ast.EnumDecl {
	p.next()
	name := p.expect_name()
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
		fields << ast.FieldDecl{
			name: field_name
			value: value
		}
	}
	p.next()
	return ast.EnumDecl{
		attributes: attributes
		is_public: is_public
		name: name
		fields: fields
	}
}

pub fn (mut p Parser) global_decl(attributes []ast.Attribute) ast.GlobalDecl {
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
		}
		else {
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

pub fn (mut p Parser) interface_decl(is_public bool) ast.InterfaceDecl {
	p.next()
	mut name := p.expect_name()
	for p.tok == .dot {
		p.next()
		name += p.expect_name()
	}
	p.expect(.lcbr)
	// TODO: finish
	// mut methods := []
	for p.tok != .rcbr {
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
			p.expect(.colon)	
		}
		line := p.line
		p.expect_name() // method/field name
		if p.tok == .lpar {
			p.fn_parameters()
			if p.line == line {
				p.expect_type() // method return type
			}
			// methods <<
		} else {
			// fields <<
			p.expect_type()
		}
	}
	// rcbr
	p.next()
	return ast.InterfaceDecl{
		is_public: is_public
		name: name
		// methods: methods
		// fields: fields
	}
}

pub fn (mut p Parser) struct_decl(is_public bool, attributes []ast.Attribute) ast.StructDecl {
	// TODO: union
	// is_union := p.tok == .key_union
	p.next()
	language, name := p.decl_lang_and_name()
	mut generic_params := []ast.Expr{}
	if p.tok == .lsbr {
		p.next()
		generic_params << p.expect_type()
		for p.tok == .comma {
			p.next()
			generic_params << p.expect_type()
		}
		p.expect(.rsbr)
	}
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
		if is_pub { p.next() }
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		if is_pub || is_mut { p.expect(.colon) }
		line := p.line
		embed_or_name := p.expect_type()
		// embedded struct
		if p.line != line {
			if language != .v {
				p.error('$language structs do not support embedding')
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
		field_value := if p.tok == .assign { p.next() p.expr(.highest) } else { ast.empty_expr }
		field_attributes := if p.tok == .lsbr { p.attributes() } else { []ast.Attribute{} }
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
	}
}

pub fn (mut p Parser) assoc_or_struct_init(typ ast.Expr) ast.Expr {
	p.next() // .lcbr
	// assoc
	if p.tok == .ellipsis {
		p.next()
		lx := p.expr(.lowest)
		mut fields := []ast.FieldInit{}
		for p.tok != .rcbr {
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
				ast.BasicLiteral { field_name = value.value }
				ast.Ident { field_name = value.name }
				else { p.error('expected field name, got $value.type_name()') }
			}
			p.next()
			value = p.expr(.lowest)
		}
		has_name := field_name.len > 0
		if fields.len > 0 && (has_name != prev_has_name) {
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
	return ast.StructInitExpr{typ: typ, fields: fields}
}

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.expect_name()
	// p.log('ast.TypeDecl: $name')
	p.expect(.assign)
	typ := p.expect_type()
	// alias `type MyType = int`
	if p.tok != .pipe {
		return ast.TypeDecl{
			is_public: is_public
			name: name
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
		variants: variants
	}
}

[inline]
[direct_array_access]
pub fn (mut p Parser) decl_lang_and_name() (ast.Language, string) {
	name := p.expect_name()
	if p.tok == .dot {
		p.next()
		if name.len == 1 && name[0] == `C` {
			return ast.Language.c, p.expect_name()
		} else if name.len == 2 && name[0] == `J` && name[1] == `S` {
			return ast.Language.js, p.expect_name()
		} else {
			p.error('invalid language prefix `$name`')
		}
	}
	return ast.Language.v, name
}

[inline]
pub fn (mut p Parser) ident() ast.Ident {
	return ast.Ident{name: p.expect_name()}
}

pub fn (mut p Parser) log(msg string) {
	if p.pref.verbose {
		println(msg)
	}
}

// TEMP/TODO: remove this & use file / fileset position + helper fns
fn (mut p Parser) position() token.Position {
	// NOTE: use scanner.position() when all we know is pos (later stages)
	// since we already know line here we use it instead
	// line, col := p.scanner.position(p.pos)
	return token.Position{
		filename: p.filename
		line: p.line
		offset: p.pos
		column: p.pos-p.scanner.line_offsets[p.line-1]+1
	}
}

// so we can customize the error message used by warn & error
fn (mut p Parser) error_message(msg string, kind util.ErrorKind) {
	pos := p.position()
	util.error(pos, msg, p.scanner.error_details(pos, 2), kind)
}

pub fn (mut p Parser) warn(msg string) {
	p.error_message(msg, .warning)
}

[noreturn]
pub fn (mut p Parser) error(msg string) {
	p.error_message(msg, .error)
	exit(1)
}
