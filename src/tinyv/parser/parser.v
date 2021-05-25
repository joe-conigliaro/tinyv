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
	file_path   string
	scanner     &scanner.Scanner
	in_init     bool // for/if/match eg. `for x in vals {`
	// start token info
	// the following are for tok, for next_tok get directly from scanner
	line_nr     int
	lit         string
	pos         int
	tok         token.Token // last token
	next_tok    token.Token // next token (scanner stays 1 tok ahead)
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
	pt0 := time.ticks()
	start_no_time:
	p.file_path = file_path
	text := os.read_file(file_path) or {
		panic('error reading $file_path')
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
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('scan & parse time for $file_path: ${parse_time}ms')
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
			return ast.ExprStmt{expr: p.@if(true)}
		}
		.hash {
			return p.directive()
		}
		.key_const {
			return p.const_decl(false)
		}
		.key_enum {
			return p.enum_decl(false)
		}
		.key_fn {
			return p.fn_decl(false, [])
		}
		.key_global {
			return p.global_decl()
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
				.key_const {
					return p.const_decl(true)
				}
				.key_enum {
					return p.enum_decl(true)
				}
				.key_fn {
					return p.fn_decl(true, [])
				}
				.key_interface {
					return p.interface_decl(true)
				}
				.key_struct, .key_union {
					return p.struct_decl(true, [])
				}
				.key_type {
					return p.type_decl(true)
				}
				else {}
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
				.key_fn { return p.fn_decl(is_pub, attributes) }
				.key_struct { return p.struct_decl(is_pub, attributes) }
				else { p.error('needs impl (pass attrs): $p.tok') }
			}
		}
		else {
			panic('X: $p.tok - $p.next_tok - $p.file_path:$p.line_nr')
		}
	}
	p.error('unknown top stmt')
	panic('')
}

pub fn (mut p Parser) stmt() ast.Stmt {
	// p.log('STMT: $p.tok - $p.file_path:$p.line_nr')
	match p.tok {
		.dollar {
			p.next()
			return ast.ExprStmt{expr: p.@if(true)}
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
			mut init := ast.new_empty_stmt()
			// for x in vals {
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
			// all other for with init
			else if p.tok != .semicolon && p.tok != .lcbr {
				init = p.stmt()
			}
			// init := p.stmt()
			// TODO: clean up
			mut cond := ast.new_empty_expr()
			mut post := ast.new_empty_stmt()
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
			// TODO: see if this interferes with anything as
			// I had to add a special check in For
			return ast.Block {
				stmts: p.block()
			}
		}
		else {
			// stand alone exression in a statement list
			// eg: `if x == 1 {`, `x++`, `break/continue`
			// also: `mut x := 1`, `a,`b := 1,2`
			expr := p.expr(.lowest)
			if p.tok == .colon {
				if expr !is ast.Ident {
					p.error('expecting identifier')
				}
				p.next()
				return ast.Label{
					name: (expr as ast.Ident).name
				}
			}
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
			return ast.ExprStmt{
				expr: expr
			}
		}
	}
	p.error('unknown stmt: $p.tok')
	panic('')
}

pub fn (mut p Parser) expr(min_bp token.BindingPower) ast.Expr {
	// p.log('EXPR: $p.tok - $p.line_nr')
	line_nr := p.line_nr
	mut lhs := ast.new_empty_expr()
	match p.tok {
		.char, .key_true, .key_false, .number, .string {
			lhs = ast.Literal{
				kind: p.tok
				value: p.lit()
			}
		}
		.key_fn {
			p.next()
			args := p.fn_args()
			mut return_type := ast.new_empty_expr()
			if p.tok != .lcbr {
				return_type = p.typ()
			}
			lhs = ast.Fn{
				args: args
				stmts: p.block()
				return_type: return_type
			}
		}
		.key_if {
			lhs = p.@if(false)
			return lhs
		}
		.key_none {
			p.next()
			return ast.None{}
		}
		.key_sizeof {
			p.next()
			p.expect(.lpar)
			expr := p.expr(.lowest)
			p.expect(.rpar)
			lhs = ast.SizeOf{expr: expr}
		}
		.key_typeof {
			p.next()
			p.expect(.lpar)
			expr := p.expr(.lowest)
			p.expect(.rpar)
			lhs = ast.TypeOf{expr: expr}
		}
		.lpar {
			// Paren
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
				// TODO: check if this is still supported (without starting `TypeName{...`)
				if p.tok == .ellipsis {
					// p.error('# assoc missing type (old/mid syntax): $p.file_path: $p.line_nr')
					return p.assoc(ast.new_empty_expr())
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
			// [1,2,3,4]
			// line_nr := p.line_nr
			mut exprs := []ast.Expr{}
			for p.tok != .rsbr {
				exprs << p.expr(.lowest)
				if p.tok == .comma {
					p.next()
				}
			}
			p.expect(.rsbr)
			if p.tok == .not {
				// TODO:
				// is_fixed =  true
				p.next()
			}
			mut typ := ast.new_empty_expr()
			// []int{}
			mut cap, mut init, mut len := ast.new_empty_expr(), ast.new_empty_expr(), ast.new_empty_expr()
			// TODO: restructure in parts (type->init) ?? no
			// NOTE: for [][]string, the first `[]` is parsed here, and the rest in p.typ()
			if p.tok in [.lsbr, .name] && p.line_nr == line_nr {
				typ = p.typ()
				// init
				if p.tok == .lcbr && !p.in_init {
					p.next()
					for p.tok != .rcbr {
						key := p.name()
						p.expect(.colon)
						if key == 'cap' {
							cap = p.expr(.lowest)
						}
						else if key == 'init' {
							init = p.expr(.lowest)
						}
						else if key == 'len' {
							init = p.expr(.lowest)
						}
						else {
							p.error('expecting one of `cap, init, len`')
						}
						if p.tok == .comma {
							p.next()
						}
					}
					p.next()
				}
			}
			lhs = ast.ArrayInit{
				typ: typ
				exprs: exprs
				init: init
				cap: cap
				len: len
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
			p.next()
			return ast.Match{
				expr: expr
				branches: branches
			}
		}
		.key_mut, .key_shared {
			lhs = ast.Modifier {
				kind: p.tok()
				expr: p.expr(.lowest)
			}
		}
		.name {
		// .name, .key_mut {
			// is_mut := p.tok == .key_mut
			// if is_mut {
			// 	p.next()
			// }
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
		.key_unsafe {
			// p.log('ast.Unsafe')
			p.next()
			lhs = ast.Unsafe{
				stmts: p.block()
			}
		}
		else {
			if p.tok.is_prefix() {
				op := p.tok()
				return ast.Prefix{
					op: op
					expr: p.expr(op.right_binding_power())
				}
			}
			// TODO: perhaps re-arrange the expression chaning support
			// below in a way which makes error conditions more stable
			else if p.tok !in [.lpar, .lsbr, .dot, .dotdot, .ellipsis] {
				p.error('expr: unexpected token `$p.tok`')
			}
		}
	}

	for {
		if p.tok == .lpar {
			// (*ptr_a) = *ptr_a - 1
			if line_nr != p.line_nr {
				return lhs
			}
			// p.log('ast.Cast or Call: ${typeof(lhs)}')
			args := p.call_args()
			// lhs = ast.Cast{
			lhs = ast.Call{
				lhs: lhs
				args: args
			}
			// TODO: should make this part of call? see which way is more helpful for gen
			if p.tok == .key_or {
				// p.log('ast.Or')
				p.next()
				lhs = ast.Or{
					expr: lhs
					stmts: p.block()
				}
				// no need to continue
				return lhs
			}
			// fncall()?
			else if p.tok == .question {
				p.next()
				// TODO
			}
		}
		// everything below is excluded from binding power check

		// index: `expr[i]`
		// checking linr_nr so that this wont het parsed as index:
		// `__global my_global = expr`
		// `[someattr]`
		// we could also check pos, making sure it's directly after
		if p.tok == .lsbr && p.line_nr == line_nr {
			p.next()
			// p.log('ast.Index: $p.scanner.lit')
			lhs = ast.Index{
				lhs: lhs
				expr: p.expr(.lowest)
			}
			p.expect(.rsbr)
			if p.tok == .key_or {
				p.next()
				lhs = ast.Or{
					expr: lhs
					stmts: p.block()
				}
				return lhs
			}
			// continue to allows `Index[1]Selector` with no regard to binding power 
			continue
		}
		// Selector
		else if p.tok == .dot {
			p.next()
			// p.log('ast.Selector')
			lhs = ast.Selector{
				lhs: lhs
				rhs: p.expr(.lowest)
			}
			// continue to allow `Selector[1]` with no regard to binding power 
			continue
		}
		// range
		// else if p.tok == .dotdot {
		// seriously wtf? why ... for range we alrady have 0..2 range. fooken
		else if p.tok in [.dotdot, .ellipsis] {
			op := p.tok
			p.next()
			// p.log('ast.Range')
			if p.tok == .rsbr {
				lhs = ast.Range{
					op: op
					start: lhs
				}
			}
			else {
				lhs = ast.Range{
					op: op
					start: lhs
					end: p.expr(.lowest)
				}
			}
		}

		// pratt - from here on we will break on binding power
		lbp := p.tok.left_binding_power()
		if int(lbp) < int(min_bp) {
			// p.log('breaking precedence: $p.tok ($lbp < $min_bp)')
			break
		}
		// p.expr(lbp)
		// TODO: use bp loop for infix & postifx instead		
		// lbp2 := p.tok.infix_bp()
		// if lbp2 < min_bp {
		// 	break
		// }
		// p.next()
		if p.tok.is_infix() {
			// deref assign: `*a = b`
			if p.tok == .mul && p.line_nr != line_nr {
				// check that starts at start of line
				// TODO: fix
				// if p.tok == .mul && p.scanner.line_offsets[p.line_nr-1]+1 == p.pos {
					return lhs
				// }
			}
			lhs = ast.Infix{
				op: p.tok()
				lhs: lhs
				rhs: p.expr(p.tok.left_binding_power())
			}
		}
		else if p.tok.is_postfix() {
			lhs = ast.Postfix{
				op: p.tok()
				expr: lhs
			}
		}
		else {
			// return lhs
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

// pub fn (mut p Parser) peek(pos int) scanner.Token {}

pub fn (mut p Parser) block() []ast.Stmt {
	mut stmts := []ast.Stmt{}
	p.expect(.lcbr)
	for p.tok != .rcbr {
		// p.log('BLOCK STMT START')
		stmts << p.stmt()
		// p.log('BLOCK STMT END')
	}
	p.next()
	// p.log('END BLOCK')
	return stmts
}

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
		// since unsafe is a keyword
		if p.tok == .key_unsafe {
			p.next()
			name = 'unsafe'
		}
		// TODO: properly
		else if p.tok == .key_if {
			p.next()
			name = 'if ' + p.name() 
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

pub fn (mut p Parser) assign(lhs []ast.Expr) ast.Assign {
	return ast.Assign{op: p.tok(), lhs: lhs, rhs: p.expr_list()}
}

pub fn (mut p Parser) @if(is_comptime bool) ast.If {
	// p.log('START IF')
	// TODO: clean up comptime stuff
	p.next()
	mut branches := []ast.Branch{}
	for {
		in_init := p.in_init
		p.in_init = true
		// mut cond := p.expr(.lowest)
		// NOTE: the line above works, but avoid calling p.expr()
		mut cond := if p.tok == .lcbr { ast.new_empty_expr() }  else { p.expr(.lowest) }
		if is_comptime && p.tok == .question {
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
		// if is_comptime {
		// 	p.expect(.dollar)
		// }
		if p.tok == .dollar && p.next_tok == .key_else {
			p.next()
		}
		if p.tok != .key_else {
			break
		}
		p.next()
		// if is_comptime {
		// 	p.expect(.dollar)
		// }
		if p.tok == .dollar && p.next_tok == .key_if {
			p.next()
		}
		if p.tok == .key_if {
			p.next()
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
		// p.log('const: $name')
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
			mut return_type := ast.new_empty_expr()
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
	mut return_type := ast.new_empty_expr()
	if p.tok != .lcbr && p.line_nr == line_nr {
		return_type = p.typ() // return type
	}
	// p.log('ast.FnDecl: $name $p.lit - $p.tok ($p.lit) - $p.next_tok')
	stmts := if p.tok == .lcbr {
		p.block()
	}
	else {
		[]ast.Stmt{}
	}
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
		name := if p.tok == .name && p.next_tok != .dot { p.name() } else { 'arg_$args.len' }
		typ := if p.tok !in [.comma, .rpar] { p.typ() } else { ast.new_empty_expr() }
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
				p.error('expecting ident for structy config syntax??')
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
	// p.expect(.rpar)
	p.next()
	return args
}

pub fn (mut p Parser) enum_decl(is_public bool) ast.EnumDecl {
	p.next()
	name := p.name()
	// p.log('ast.EnumDecl: $name')
	p.expect(.lcbr)
	mut fields := []ast.FieldDecl{}
	for p.tok != .rcbr {
		field_name := p.name()
		mut value := ast.new_empty_expr()
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
		is_public: is_public
		name: name
		fields: fields
	}
}

pub fn (mut p Parser) global_decl() ast.GlobalDecl {
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
	// empty interface ?
	if p.tok != .lcbr {
		return ast.InterfaceDecl{
			is_public: is_public
			name: name
		}
	}
	p.next()
	// TODO: finish
	// mut methods := []
	for p.tok != .rcbr {
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
	for p.tok != .rcbr {
		is_pub := p.tok == .key_pub
		if is_pub { p.next() }
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		if is_pub || is_mut { p.expect(.colon) }
		field_name := p.name()
		typ := p.typ()
		// default field value
		mut value := ast.new_empty_expr()
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
		name: name
		fields: fields
	}
}

// TODO: consider parsing type in here (same for assoc)
pub fn (mut p Parser) struct_init(typ ast.Expr) ast.StructInit {
	p.next()
	mut fields := []ast.FieldInit{}
	mut prev_field_name_len := 0
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
			// field_name = (value as ast.Ident).name
			p.next()
			value = p.expr(.lowest)
		}
		// better way to do this?
		if fields.len > 0 && ((prev_field_name_len == 0 && field_name.len > 0) || (prev_field_name_len > 0 && field_name.len == 0)) {
			p.error('struct_init: cant mix & match name & no name')
		}
		prev_field_name_len = field_name.len
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
	mut parent_type := ast.new_empty_expr()
	// sum type (otherwise alias)
	mut variants := []ast.Expr{}
	if p.tok == .assign {
		p.next()
		for {
			variant := p.typ()
			variants << variant
			if p.tok != .pipe {
				break
			}
			p.next()
		}
	}
	else {
		parent_type = p.typ()
	}
	// p.log('ast.TypeDecl: $name')
	return ast.TypeDecl{
		is_public: is_public
		name: name
		parent_type: parent_type
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

pub fn (mut p Parser) error(msg string) {
	println('error: $msg')
	// line_nr, col := p.scanner.position(p.pos)
	col := p.pos-p.scanner.line_offsets[p.line_nr-1]+1
	println('$p.file_path:$p.line_nr:$col')
	exit(1)
}
