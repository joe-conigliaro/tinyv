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

struct Parser {
	pref      &pref.Preferences
mut:
	file_path string
	scanner   &scanner.Scanner
	in_init   bool // for/if/match eg. `for x in vals {`
	// start token info
	// the following are for tok, for next_tok get directly from scanner
	line_nr   int
	lit       string
	pos       int
	tok       token.Token // last token
	next_tok  token.Token // next token (scanner stays 1 tok ahead)
	// end token info
}

pub fn new_parser(pref &pref.Preferences) &Parser {
	unsafe { return &Parser{
		pref: pref
		scanner: scanner.new_scanner(pref, false)
	} }
}

pub fn (mut p Parser) reset() {
	p.scanner.reset()
	p.line_nr = 0
	p.lit = ''
	p.pos = 0
	p.tok = .unknown
	p.next_tok = .unknown
}

pub fn (mut p Parser) parse_files(files []string) []ast.File {
	mut ast_files := []ast.File{}
	for file in files {
		ast_files << p.parse_file(file)
	}
	return ast_files
}

pub fn (mut p Parser) parse_file(file_path string) ast.File {
	// reset if we are reusing parser instance
	if p.scanner.pos > 0 {
		p.reset()
	}
	if !p.pref.verbose {
		unsafe { goto start_no_time }
	}
	mut sw := time.new_stopwatch()
	start_no_time:
	p.file_path = file_path
	text := os.read_file(file_path) or {
		p.error('error reading $file_path')
	}
	p.scanner.set_text(text)
	// start
	p.next_tok = p.scanner.scan()
	p.next()
	mut top_stmts := []ast.Stmt{}
	mut imports := []ast.Import{}
	for p.tok != .eof {
		stmt := p.top_stmt()
		if stmt is ast.Import {
			imports << stmt
		}
		top_stmts << stmt
	}
	if p.pref.verbose {
		parse_time := sw.elapsed()
		println('scan & parse $file_path: ${parse_time.milliseconds()}ms (${parse_time.microseconds()}us)')
	}
	return ast.File{
		path: file_path
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
				.key_if { return ast.ExprStmt{expr: ast.Comptime{expr: p.@if(true)}} }
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
			mut name := p.name()
			mut alias := name
			for p.tok == .dot {
				p.next()
				alias = p.name()
				name += '.$alias'
			}
			is_aliased := p.tok == .key_as
			if is_aliased {
				p.next()
				alias = p.name()
			}
			// p.log('ast.Import: $name as $alias')
			return ast.Import{
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
			name := p.name()
			// p.log('ast.Module: $name')
			return ast.Module{
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
					// I didnt want attributes as a statemment, but attached to things like fn/struct
					// will have to rethink this now, it can be set on p.has_globals = true
					// if not needed in later stages. otherwise add a stmt for it. come back to this
					// TODO: attach these attributes to the file node itself?
					if attributes[0].name == 'has_globals' {
						// TODO
						// p.has_globals = true
						return ast.empty_stmt
					}
					p.error('needs impl (pass attrs): $p.tok')
				}
			}
		}
		else {
			p.error('unknown top stmt: $p.tok - $p.next_tok - $p.file_path:$p.line_nr')
		}
	}
	
}

pub fn (mut p Parser) stmt() ast.Stmt {
	// p.log('STMT: $p.tok - $p.file_path:$p.line_nr')
	match p.tok {
		.dollar {
			p.next()
			// NOTE: we could remove this branch completely in which case it would be
			// handled in the else branch below by expr() and returned as ExprStmt.
			// expr() could also handle this if we blindly return an ExprStmt here.
			// however it is being done this way for better error detection.
			match p.tok {
				.key_if { return ast.ExprStmt{expr: ast.Comptime{expr: p.@if(true)}} }
				else { p.error('unexpected comptime: $p.tok') }
			}
		}
		.hash {
			return p.directive()
		}
		.key_assert {
			p.next()
			return ast.Assert{expr: p.expr(.lowest)}
		}
		.key_break, .key_continue, .key_goto {
			return ast.FlowControl{op: p.tok()}
		}
		.key_defer {
			p.next()
			return ast.Defer{stmts: p.block()}
		}
		.key_for {
			p.next()
			in_init := p.in_init
			p.in_init = true
			mut init, mut cond, mut post := ast.empty_stmt, ast.empty_expr, ast.empty_stmt
			// for in `for x in vals {`
			if p.next_tok in [.comma, .key_in] {
				mut key, mut value := '', p.name()
				mut value_is_mut := false
				if p.tok == .comma {
					p.next()
					key = value
					if p.tok == .key_mut {
						value_is_mut = true
						p.next()
					}
					value = p.name()
				}
				p.expect(.key_in)
				init = ast.ForIn{
					key: key
					value: value
					value_is_mut: value_is_mut
					expr: p.expr(.lowest)
				}
			}
			// infinate `for {` and C style `for x:=1; x<=10; x++`
			else {
				if p.tok !in [.lcbr, .semicolon] {
					init = p.stmt()
				}
				if p.tok == .semicolon {
					p.next()
				}
				if p.tok != .semicolon {
					cond = p.expr(.lowest)
				}
				if p.tok == .semicolon {
					p.next()
				}
				if p.tok != .lcbr {
					post = p.stmt()
				}
			}
			p.in_init = in_init
			return ast.For{
				init: init
				cond: cond
				post: post
				stmts: p.block()
			}
		}
		.key_return {
			// p.log('ast.Return')
			p.next()
			// small optimization, save call/array init
			if p.tok == .rcbr {
				return ast.Return{}
			}
			return ast.Return{
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
				if expr !is ast.Ident {
					p.error('expecting identifier')
				}
				p.next()
				// TODO: labelled for
				// if p.tok == .key_for {
				// 	return p.@for()
				// }
				return ast.Label{
					name: (expr as ast.Ident).name
				}
			}
			// stand alone exression in a statement list
			// eg: `if x == 1 {`, `x++`, `break/continue`
			// also: `mut x := 1`, `a,`b := 1,2`
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
					ast.List{exprs: exprs}
				}
			}
			if p.tok.is_assignment() {
				return p.assign([expr])
			}
			// TODO: add check for all ExprStmt eg.
			// if expr is ast.ArrayInit {
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
	// p.log('EXPR: $p.tok - $p.line_nr')
	mut line_nr := p.line_nr
	mut lhs := ast.empty_expr
	match p.tok {
		.char, .key_true, .key_false, .number, .string {
			lhs = ast.Literal{
				kind: p.tok
				value: p.lit()
			}
		}
		.key_fn {
			p.next()
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
			args := p.fn_args()
			mut return_type := ast.empty_expr
			if p.tok != .lcbr {
				return_type = p.typ()
			}
			lhs = ast.Fn{
				args: args
				stmts: p.block()
				return_type: return_type
			}
		}
		.key_go {
			p.next()
			return ast.Go{expr: p.expr(.lowest)}
		}
		.key_if {
			return p.@if(false)
		}
		// NOTE: handle all these using KeywordOperator for now, if or
		// as needed later we can split them off into their own types.
		// NOTE: I would much rather dump, likely, and unlikely were
		// some type of comptime fn/macro's which come as part of the
		// v stdlib, as apposed to being language keywords.
		.key_dump, .key_likely, .key_unlikely, .key_isreftype, .key_sizeof, .key_typeof {
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
			// TODO: handle with in_init, or different solution? check .lcbr in expr()
			in_init := p.in_init
			p.in_init = true
			exprs := p.expr_list()
			p.in_init = in_init
			return ast.Lock{
				kind: kind
				exprs: exprs
				stmts: p.block()
			}
		}
		.dollar {
			p.next()
			match p.tok {
				.key_if { return ast.Comptime{expr: p.@if(true)} }
				else { return ast.Comptime{expr: p.expr(.lowest)} }
			}
		}
		.lpar {
			p.next()
			// p.log('ast.Paren:')
			lhs = ast.Paren{
				expr: p.expr(.lowest)
			}
			p.expect(.rpar)
		}
		.lcbr {
			// shorthand map / struct init
			if !p.in_init {
				// TODO: options struct
				// lhs = p.struct_init()
				p.next()
				// assoc
				if p.tok == .ellipsis {
					if lhs is ast.EmptyExpr {
						p.error('this assoc syntax is no longer supported `{...`. You must explicitly specify a type `MyType{...`')
					}
					return p.assoc(ast.empty_expr)
				}
				// empty map init `{}`
				if p.tok == .rcbr {
					p.next()
					return ast.MapInit{}
				}
				// TODO: dfferentiate short map / struct init (if possible at this stage)
				// map init
				mut keys := []ast.Expr{}
				mut vals := []ast.Expr{}
				for p.tok != .rcbr {
					key := p.expr(.lowest)
					if key is ast.Infix {
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
				lhs = ast.MapInit{
					keys: keys
					vals: vals
				}
			}
		}
		.lsbr {
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
			// `[1,2,3,4]!
			if p.tok == .not {
				if exprs.len == 0 {
					p.error('expecting at lest one initialisation expr: `[expr, expr2]!`')
				}
				p.next()
				lhs = ast.ArrayInit{
					exprs: exprs
					// TODO: don't need this, we do need some way to indicate `!` though
					len: ast.Literal{kind: .number, value: exprs.len.str()}
				}
			}
			// `[2][]int{}` | `[1,2,3,4][0]` <-- index directly after init
			// NOTE: this is tricky to do without looking far ahead because of the following:
			// fixed size array: `[2]int`, array of fixed size arrays: `[][2][2]int`
			// index directly after array init: [1,2,3,4][0]
			// its vary hard to tell the difference between a multi dimenensional array including
			// fixed array(s) and array index directly after initialisation
			// only in this case we collect the exprs in following `[x][x]` then decide what to do
			else if exprs.len > 0 && p.tok == .lsbr {
				// collect exprs in all the following `[x][x]`
				mut exprs_arr := [exprs]
				for p.tok == .lsbr {
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
				// `[2][]int{}`
				if p.tok in [.amp, .name] && p.line_nr == line_nr {
					mut typ := p.typ()
					for i:=exprs_arr.len-1; i>=0; i-- {
						exprs2 := exprs_arr[i]
						if exprs2.len == 0  {
							typ = ast.Type(ast.ArrayType{elem_type: typ})
						}
						else if exprs2.len == 1 {
							typ = ast.Type(ast.ArrayFixedType{elem_type: typ, len: exprs2[0]})
						}
						else {
							p.error('we should never end up here')
						}
					}
					// cast `[2]u8(x)` we know this is a cast
					// set lhs as the type, cast handled later in expr loop
					if p.tok == .lpar {
						lhs = typ
					}
					// `[2]int{}` | `[2][]string{}` | `[2]&Foo{}`
					else {
						p.expect(.lcbr)
						mut init := ast.empty_expr
						if p.tok != .rcbr {
							key := p.name()
							p.expect(.colon)
							match key {
								'init'  { init = p.expr(.lowest) }
								else   { p.error('expecting `init`, got `$key`') }
							}
						}
						p.next()
						lhs = ast.ArrayInit{
							typ: typ
							init: init
						}
					}
				}
				// `[1,2,3,4][0]` | `[[1,2,3,4]][0][1]` <-- index directly after init
				else {
					lhs = ast.ArrayInit{
						exprs: exprs
					}
					for i:= 1; i<exprs_arr.len; i++ {
						exprs2 := exprs_arr[i]
						if exprs2.len != 1 {
							p.error('we should never end up here')
						}
						lhs = ast.Index{
							lhs: lhs
							expr: exprs2[0]
						}
					}
				}
			}
			// `[]int{}` | `[][]string{}` | `[]&Foo{}` | `[]u8(x)`
			// TODO: make sure we never end up here in for anything besides ArrayInit
			else if p.tok in [.amp, .lsbr, .name] && p.line_nr == line_nr {
				typ := ast.Type(ast.ArrayType{elem_type: p.typ()})
				// cast `[]u8(x)` we know this is a cast
				// set lhs as the type, cast handled later in expr loop
				if p.tok == .lpar {
					lhs = typ
				}
				// `[]int{}` | `[][]string{}` | `[]&Foo{}`
				else {
					p.expect(.lcbr)
					mut cap, mut init, mut len := ast.empty_expr, ast.empty_expr, ast.empty_expr
					for p.tok != .rcbr {
						key := p.name()
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
					lhs = ast.ArrayInit{
						typ: typ
						init: init
						cap: cap
						len: len
					}
				}
			}
			// `[1,2,3,4]`
			else {
				lhs = ast.ArrayInit{
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
			line_nr = p.line_nr
			// rcbr
			p.next()
			lhs = ast.Match{
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
			// p.log('ast.Unsafe')
			p.next()
			lhs = ast.Unsafe{
				stmts: p.block()
			}
		}
		.name {
			// TODO: proper
			if p.next_tok == .lcbr && !p.in_init {
				typ := p.typ()
				if p.next_tok == .ellipsis {
					p.next()
					return p.assoc(typ)
				}
				// NOTE: we can allow this if wanted also for assoc
				// lhs = p.struct_init(typ)
				return p.struct_init(typ)
			}
			name := p.name()
			// long map init: map[string]string{}
			if name == 'map' && p.tok == .lsbr {
				// p.expect(.lsbr)
				p.next()
				key_type := p.typ()
				p.expect(.rsbr)
				value_type := p.typ()
				p.expect(.lcbr)
				// TODO: init stuffs (check support)
				p.expect(.rcbr)
				return ast.MapInit{
					lhs: lhs
					key_type: key_type
					value_type: value_type
				}
			}
			lhs = ast.Ident{
				name: name
				// is_mut: is_mut
			}
		}
		// selector (enum value), range. handled in loop below
		.dot, .dotdot, .ellipsis {}
		else {
			if p.tok.is_prefix() {
				// NOTE: just use .highest for now, later we might need to define for each op
				lhs = ast.Prefix{
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
		// call || generic call (TODO: proper, fix this fugly :-D)
		if p.tok == .lpar || (p.tok == .lt && p.next_tok == .name && p.scanner.lit[0].is_capital()) {
			// (*ptr_a) = *ptr_a - 1
			if p.line_nr != line_nr {
				return lhs
			}
			// TODO: call or cast
			// this will currently only be type from ArrayInit `[]u8(x)`
			// if lhs is ast.Type {
			// 	lhs = ast.Cast{
			// 		typ: lhs
			// 		expr: p.expr(.lowest)
			// 	}
			// 	continue
			// }
			// p.log('ast.Cast or Call: ${typeof(lhs)}')
			// generic call
			if p.tok == .lt {
				p.next()
				p.typ()
				p.expect(.gt)
			}
			args := p.call_args()
			// lhs = ast.Cast{
			lhs = ast.Call{
				lhs: lhs
				args: args
			}
			// fncall()! (Propagate Result) | fncall()? (Propagate Option)
			if p.tok in [.not, .question] {
				p.next()
				// TODO
			}
		}
		// index: `expr[i]`
		// checking linr_nr so that this wont get parsed as index:
		// `__global my_global = expr`
		// `[someattr]`
		// we could also check pos, making sure it's directly after
		else if p.tok in [.hash, .lsbr] && p.line_nr == line_nr {
			is_gated := p.tok == .hash
			if is_gated {
				p.next()
				if p.tok != .lsbr {
					p.error('how did we end up here?')
				}
			}
			p.next()
			// p.log('ast.Index: $p.scanner.lit')
			lhs = ast.Index{
				lhs: lhs
				expr: p.expr(.lowest)
				is_gated: is_gated
			}
			p.expect(.rsbr)
		}
		// Selector
		else if p.tok == .dot {
			p.next()
			// p.log('ast.Selector')
			lhs = ast.Selector{
				lhs: lhs
				rhs: p.expr(.lowest)
			}
		}
		else if p.tok == .key_or {
			// p.log('ast.Or')
			p.next()
			lhs = ast.Or{
				expr: lhs
				stmts: p.block()
			}
		}
		// range
		else if p.tok in [.dotdot, .ellipsis] {
			// p.log('ast.Range')
			// no need to continue
			return ast.Range{
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
			// deref assign: `*a = b`
			if p.tok == .mul && p.line_nr != line_nr {
				// check that starts at start of line
				// TODO: fix (what was this about?)
				// if p.tok == .mul && p.scanner.line_offsets[p.line_nr-1]+1 == p.pos {
					return lhs
				// }
			}
			op := p.tok()
			lhs = ast.Infix{
				op: op
				lhs: lhs
				rhs: p.expr(op.right_binding_power())
			}
		}
		else if p.tok.is_postfix() {
			lhs = ast.Postfix{
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

[inline]
pub fn (mut p Parser) next() {
	p.line_nr = p.scanner.line_offsets.len
	p.lit = p.scanner.lit
	p.pos = p.scanner.pos
	p.tok = p.next_tok
	p.next_tok = p.scanner.scan()
}

[inline]
pub fn (mut p Parser) expect(tok token.Token) {
	if tok != p.tok {
		p.error('unexpected token. expecting `$tok`, got `$p.tok`')
	}
	p.next()
}

// expect name & return lit & go to next token
[inline]
pub fn (mut p Parser) name() string {
	name := p.lit
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
		// p.log('BLOCK STMT START')
		stmts << p.stmt()
		// p.log('BLOCK STMT END')
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
		mut comptime_cond_opt := false
		// TODO: implement is_comptime
		// mut is_comptime := false
		// since unsafe is a keyword
		if p.tok == .key_unsafe {
			p.next()
			name = 'unsafe'
		}
		// TODO: properly
		// consider using normal if expr
		else if p.tok == .key_if {
			p.next()
			// name = 'if ' + p.name()
			comptime_cond = p.expr(.lowest)
			comptime_cond_opt = p.tok == .question
			if comptime_cond_opt {
				p.next()
			}
		}
		else {
			name = p.name()
		}
		if p.tok == .colon {
			p.next()
			if p.tok == .name {
				// kind = .plain
				value = p.name()
			} else if p.tok == .number {
				// kind = .number
				value = p.lit()
			} else if p.tok == .string { // `name: 'arg'`
				// kind = .string
				value = p.lit()
			} else {
				p.error('unexpected $p.tok, an argument is expected after `:`')
			}
		}
		attributes << ast.Attribute{
			name: name
			value: value
			comptime_cond: comptime_cond
			comptime_cond_opt: comptime_cond_opt
		}
		if p.tok == .semicolon {
			p.next()
			continue
		}
		else if p.next_tok == .lsbr {
			p.expect(.rsbr)
			p.next()
			continue
		}
		break
	}
	// name := p.name()
	// p.log('ast.Attribute: $name')
	p.expect(.rsbr)
	return attributes
}

[inline]
pub fn (mut p Parser) assign(lhs []ast.Expr) ast.Assign {
	return ast.Assign{op: p.tok(), lhs: lhs, rhs: p.expr_list()}
}

pub fn (mut p Parser) @if(is_comptime bool) ast.If {
	// p.log('ast.If')
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
			cond = ast.Postfix{expr: cond, op: p.tok}
			p.next()
		}
		// if guard
		// if p.tok in [.assign. .decl_assign] {
		if p.tok == .decl_assign {
			cond = ast.IfGuard{
				stmt: p.assign([cond])
			}
		}
		p.in_init = in_init
		branches << ast.Branch{
			cond: [cond]
			stmts: p.block()
		}
		// else
		if p.tok == .key_else || (p.tok == .dollar && p.next_tok == .key_else) {
			// we are using expect instead of next to ensure we error when `is_comptime`
			// and not all branches have `$`, or `!is_comptime` and any branches have `$`.
			// the same applies for the `else if` condition directly below.
			if is_comptime { p.expect(.dollar) }
			p.expect(.key_else)
			// else if
			if p.tok == .key_if || (p.tok == .dollar && p.next_tok == .key_if) {
				if is_comptime { p.expect(.dollar) }
				p.expect(.key_if)
			}
		} else {
			break
		}
	}
	return ast.If{
		branches: branches
		is_comptime: is_comptime
	}
}

pub fn (mut p Parser) directive() ast.Directive {
	// value := p.lit() // if we scan whole line see scanner
	p.next()
	line_nr := p.line_nr
	name := p.name()
	// TODO: handle properly
	mut value := p.lit()
	for p.line_nr == line_nr {
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
		name := p.name()
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
	line_nr := p.line_nr
	// method
	mut is_method := false
	mut receiver := ast.Arg{}
	if p.tok == .lpar {
		is_method = true
		p.next()
		// TODO: use parse_ident & type
		// receiver := p.ident() ?
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
		}
		receiver = ast.Arg{
			name: p.name()
			typ: p.typ()
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
			receiver2 := ast.Arg{
				name: p.name()
				typ: p.typ()
				is_mut: is_mut
			}
			_ = receiver2
			p.expect(.rpar)
			mut return_type := ast.empty_expr
			_ = return_type
			if p.tok != .lcbr && p.line_nr == line_nr {
				return_type = p.typ()
			}
			p.block()
			// TODO
			return ast.FnDecl{}
		}
	}
	mut name := p.name()
	// TODO: think if we use string or selector/ident
	// is_c := p.tok == .dot && name == 'C'
	// if is_c {
	// 	p.next()
	// 	name = 
	// }
	mut language := ast.Language.v
	// TODO: use module namespaces
	if p.tok == .dot {
		if name.len == 1 && name[0] == `C` {
			language = .c
		}
		else if name.len == 2 && name == 'JS' {
			language = .js
		}
	}
	// do we do this or always idents
	for p.tok == .dot {
		p.next()
		name += '.$p.name()'
	}
	// TODO: generics
	if p.tok == .lt {
		p.next()
		for {
			p.typ()
			if p.tok != .comma {
				break
			}
			p.next()
		}
		p.expect(.gt)
	}
	args := p.fn_args()
	// TODO:
	// mut return_type := types.void
	mut return_type := ast.empty_expr
	if p.tok != .lcbr && p.line_nr == line_nr {
		return_type = p.typ() // return type
	}
	// p.log('ast.FnDecl: $name $p.lit - $p.tok ($p.lit) - $p.next_tok')
	stmts := if p.tok == .lcbr { p.block() } else { []ast.Stmt{} }
	return ast.FnDecl{
		attributes: attributes
		is_public: is_public
		is_method: is_method
		receiver: receiver
		name: name
		args: args
		stmts: stmts
		return_type: return_type
		language: language
	}
}

pub fn (mut p Parser) fn_args() []ast.Arg {
	p.expect(.lpar)
	mut args := []ast.Arg{}
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		// TODO: proper
		mut typ := p.typ()
		mut name := ''
		if p.tok == .name {
			name = (typ as ast.Ident).name
			typ = p.typ()
		}
		// name := if p.tok == .name && p.next_tok != .dot { p.name() } else { 'arg_$args.len' }
		// typ := if p.tok !in [.comma, .rpar] { p.typ() } else { ast.empty_expr }
		if p.tok == .comma {
			p.next()
		}
		args << ast.Arg{
			name: name
			typ: typ
			is_mut: is_mut
		}
	}
	p.next()
	return args
}

pub fn (mut p Parser) call_args() []ast.Expr {
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
			expr = ast.FieldInit{
				name: (expr as ast.Ident).name
				value: p.expr(.lowest)
			}
		}
		args << expr
		if p.tok == .comma {
			p.next()
		}
	}
	p.next()
	return args
}

pub fn (mut p Parser) enum_decl(is_public bool, attributes []ast.Attribute) ast.EnumDecl {
	p.next()
	name := p.name()
	// p.log('ast.EnumDecl: $name')
	p.expect(.lcbr)
	mut fields := []ast.FieldDecl{}
	for p.tok != .rcbr {
		field_name := p.name()
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
		name := p.name()
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
				typ: p.typ()
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
	mut name := p.name()
	for p.tok == .dot {
		p.next()
		name += p.name()
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
		line_nr := p.line_nr
		p.name() // method/field name
		if p.tok == .lpar {
			p.fn_args()
			if p.line_nr == line_nr {
				p.typ() // method return type
			}
			// methods <<
		} else {
			// fields <<
			p.typ()
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

pub fn (mut p Parser) assoc(typ ast.Expr) ast.Assoc {
	p.next()
	lx := p.expr(.lowest)
	mut fields := []ast.FieldInit{}
	for p.tok != .rcbr {
		field_name := p.name()
		p.expect(.colon)
		fields << ast.FieldInit{
			name: field_name
			value: p.expr(.lowest)
		}
	}
	p.next()
	return ast.Assoc{
		typ: typ
		expr: lx
		fields: fields
	}
}

pub fn (mut p Parser) struct_decl(is_public bool, attributes []ast.Attribute) ast.StructDecl {
	// TODO: union
	// is_union := p.tok == .key_union
	p.next()
	mut name := p.name()
	language := if name == 'C' && p.tok == .dot { ast.Language.c } else { ast.Language.v }
	for p.tok == .dot {
		p.next()
		name += p.name()
	}
	// p.log('ast.StructDecl: $name')
	// probably C struct decl with no body or {}
	if p.tok != .lcbr {
		return ast.StructDecl{
			is_public: is_public
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
		if language == .v && (p.next_tok == .dot || p.lit[0].is_capital()) {
			embedded << p.typ()
			continue
		}
		field_name := p.name()
		typ := p.typ()
		// default field value
		mut value := ast.empty_expr
		if p.tok == .assign {
			p.next()
			value = p.expr(.lowest)
		}
		field_attributes := if p.tok == .lsbr { p.attributes() } else { []ast.Attribute{} }
		fields << ast.FieldDecl{
			name: field_name
			typ: typ
			value: value
			attributes: field_attributes
		}
	}
	p.next()
	return ast.StructDecl{
		attributes: attributes
		is_public: is_public
		embedded: embedded
		name: name
		fields: fields
	}
}

// TODO: consider parsing type in here (same for assoc)
pub fn (mut p Parser) struct_init(typ ast.Expr) ast.StructInit {
	p.next()
	mut fields := []ast.FieldInit{}
	mut prev_has_name := false
	for p.tok != .rcbr {
		// could be name or init without field name
		mut field_name := ''
		mut value := p.expr(.lowest)
		// name / value
		if p.tok == .colon {
			match mut value {
				ast.Literal { field_name = value.value }
				ast.Ident { field_name = value.name }
				else { p.error('struct_init: expected field name, got $value.type_name()') }
			}
			p.next()
			value = p.expr(.lowest)
		}
		has_name := field_name.len > 0
		if fields.len > 0 && (has_name != prev_has_name) {
			p.error('struct_init: cant mix & match name & no name')
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
	return ast.StructInit{typ: typ, fields: fields}
}

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.name()
	// p.log('ast.TypeDecl: $name')
	p.expect(.assign)
	typ := p.typ()
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
	mut variants := [typ, p.typ()]
	for p.tok == .pipe {
		p.next()
		variants << p.typ()
	}
	// TODO: consider seperate node for alias / sum type ?
	return ast.TypeDecl{
		is_public: is_public
		name: name
		variants: variants
	}
}

[inline]
pub fn (mut p Parser) ident() ast.Ident {
	return ast.Ident{name: p.name()}
}

pub fn (mut p Parser) log(msg string) {
	if p.pref.verbose {
		println(msg)
	}
}

[noreturn]
pub fn (mut p Parser) error(msg string) {
	// NOTE: use scanner.position()) when all we know is pos (later stages)
	// since we already know line_nr here we use it instead
	// line_nr, col := p.scanner.position(p.pos)
	col := p.pos-p.scanner.line_offsets[p.line_nr-1]+1
	println('========================================')
	println(' error: $msg')
	println(' file: $p.file_path:$p.line_nr:$col')
	println('========================================')
	exit(1)
}
