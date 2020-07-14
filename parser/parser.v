module parser

import os
import ast
import scanner
import token
import types
import pref

struct Parser {
	pref      &pref.Preferences
mut:
	file_path string
	scanner   &scanner.Scanner
	tok       token.Token
	in_init   bool // for/if/match eg. `for x in vals {`
}

pub fn new_parser(pref &pref.Preferences) &Parser {
	return &Parser{
		pref: pref
		scanner: scanner.new_scanner(pref)
	}
}

pub fn (mut p Parser) reset() {
	p.scanner.reset()
	p.tok = .unknown
}

pub fn (mut p Parser) parse(file_path string) ast.File {
	// reset if we are reusing parser instance
	if p.scanner.pos > 0 {
		p.reset()
	}
	p.file_path = file_path
	text := os.read_file(file_path) or {
		panic('error reading $file_path')
	}
	p.scanner.set_text(text)
	// start
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
	return ast.File{
		path: p.file_path
		imports: imports
		stmts: top_stmts
	}
}

pub fn (mut p Parser) top_stmt() ast.Stmt {
	match p.tok {
		.hash {
			p.next()
			line_nr := p.scanner.line_nr
			name := p.name()
			// TODO: handle properly
			mut value := p.lit()
			for p.scanner.line_nr == line_nr {
				value += p.lit()
			}
			return ast.Directive{
				name: name
				value: value
			}
		}
		.key_const {
			return p.const_decl(false)
		}
		.key_enum {
			return p.enum_decl(false)
		}
		.key_fn {
			return p.fn_decl(false)
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
					return p.fn_decl(true)
				}
				.key_struct, .key_union {
					return p.struct_decl(true)
				}
				.key_type {
					return p.type_decl(true)
				}
				else {}
			}
		}
		.key_struct, .key_union {
			return p.struct_decl(false)
		}
		.key_type {
			return p.type_decl(false)
		}
		.lsbr {
			// [attribute]
			p.next()
			name := p.name()
			// p.log('ast.Attribute: $name')
			p.expect(.rsbr)
			return ast.Attribute{name: name}
		}
		else {
			panic('X: $p.tok')
		}
	}
	p.error('unknown top stmt')
	panic('')
}

pub fn (mut p Parser) stmt() ast.Stmt {
	// p.log('STMT: $p.tok - $p.scanner.line_nr')
	match p.tok {
		.dollar {
			p.next()
			p.expect(.key_if)
			// p.log('ast.ComptimeIf')
			// we are setting in_init here to maake sure
			// `$if foo {` is not mistaken for struct init
			in_init := p.in_init
			p.in_init = true
			cond := p.expr(.lowest)
			p.in_init = in_init
			if p.tok == .question {
				p.next()
			}
			stmts := p.block()
			mut else_stmts := []ast.Stmt{}
			// TODO:
			if p.tok == .dollar {
				p.next()
				if p.tok == .key_else {
					p.next()
					else_stmts = p.block()
				}
			}
			return ast.ComptimeIf{
				cond: cond
				stmts: stmts
				else_stmts: stmts
			}
		}
		.key_assert {
			p.next()
			return ast.Assert{expr: p.expr(.lowest)}
		}
		.key_break, .key_continue {
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
			init := p.stmt()
			if p.tok == .semicolon {
				p.next()
			}
			cond := p.expr(.lowest)
			if p.tok == .semicolon {
				p.next()
			}
			post := p.stmt()
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
		.key_unsafe {
			// p.log('ast.Unsafe')
			p.next()
			return ast.Unsafe{
				stmts: p.block()
			}
		}
		else {
			// stand alone exression in a statement list
			// eg: `if x == 1 {`, `x++`, `break/continue`
			// also: `mut x := 1`, `a,`b := 1,2`
			expr := p.expr(.lowest)
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

pub fn (mut p Parser) expr(min_lbp token.BindingPower) ast.Expr {
	// TODO: fix match so it last expr can be used `x := match {...`
	// p.log('EXPR: $p.tok - $p.scanner.line_nr')
	mut lhs := ast.Expr{}
	match p.tok {
		.char, .key_true, .key_false, .number, .string {
			lhs = ast.Literal{
				kind: p.tok
				value: p.lit()
			}
		}
		.key_if {
			// p.log('START IF')
			mut branches := []ast.Branch{}
			for p.tok in [.key_if, .key_else] {
				p.next()
				if p.tok == .key_if {
					p.next()
				}
				in_init := p.in_init
				p.in_init = true
				cond := p.expr(.lowest)
				p.in_init = in_init
				if p.tok == .key_or {
					panic('GOT OR')
				}
				branches << ast.Branch{
					cond: cond
					stmts: p.block()
				}
			}
			if p.tok == .key_or {
				panic('GOT OR')
			}
			lhs = ast.If{
				branches: branches
			}
			// p.log('END IF')
		}
		.key_none {
			p.next()
			return ast.None{}
		}
		.key_sizeof {
			p.next()
			p.expect(.lpar)
			p.expr(.lowest)
			p.expect(.rpar)
			// TODO
			//lhs = ast.SizeOf {}
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
			if !p.in_init {
				lhs = p.struct_init()
			}
		}
		.lsbr {
			p.next()
			// [1,2,3,4]
			line_nr := p.scanner.line_nr
			mut exprs := []ast.Expr{}
			for p.tok != .rsbr {
				// p.log('ARRAY INIT EXPR:')
				exprs << p.expr(.lowest)
				if p.tok == .comma {
					p.next()
				}
				// p.expect(.comma)
			}
			p.expect(.rsbr)
			// []int{}
			mut cap, mut init, mut len := ast.Expr{}, ast.Expr{}, ast.Expr{}
			// TODO: restructure in parts (type->init) ?? no
			if p.tok == .name && p.scanner.line_nr == line_nr {
				// typ := p.typ()
				p.next()
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
					p.expect(.rcbr)
				}
			}
			lhs = ast.ArrayInit{
				exprs: exprs
				init: init
				cap: cap
				len: len
			}
		}
		.key_match {
			p.next()
			in_init := p.in_init
			p.in_init = true
			p.expr(.lowest)
			p.in_init = in_init
			p.expect(.lcbr)
			for p.tok != .rcbr {
				in_init2 := p.in_init
				p.in_init = true
				for {
					p.expr(.lowest)
					if p.tok != .comma {
						break
					}
					p.next()
				}
				p.in_init = in_init2
				p.block()
				if p.tok == .key_else {
					p.next()
					p.block()
				}
			}
			p.expect(.rcbr)

			return ast.Match{}
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
			name := p.name()
			// p.log('NAME: $name - $p.tok ($p.scanner.lit)')
			// struct init
			// NOTE: can use lit0 capital check, OR registered type check, OR inside stmt init check (eg. `for cond {` OR `if cond {`)
			// currently using in_init for if/for/map initialization
			if p.tok == .lcbr && !p.in_init {
				// TODO: add type or name (prob type)
				lhs = p.struct_init()
			}
			// ident
			else {
				lhs = ast.Ident{
					name: name
					// is_mut: is_mut
				}
			}
		}
		.plus_assign{
			p.error('BOO')
		}
		else {
			if p.tok.is_prefix() {
				return ast.Prefix{
					op: p.tok()
					expr: p.expr(.lowest)
				}
			}
		}
	}

	for {
		if p.tok == .lpar {
			// p.log('ast.Cast or Call: ${typeof(lhs)}')
			args := p.call_args()
			// lhs = ast.Cast{
			lhs = ast.Call{
				lhs: lhs
				args: args
			}
			// TODO: later decide if its a cast
			// TODO: this is not going to work, what was I trying to do?
			// need to be part of If? or or as part of call?
			if p.tok == .key_or {
				// p.log('ast.IfGuard')
				p.next()
				lhs = ast.IfGuard{
					cond: lhs
					or_stmts: p.block()
				}
			}
		}
		// excluded from binding power check they run either way
		// index
		if p.tok == .lsbr {
			p.next()
			// p.log('ast.Index: $p.scanner.lit')
			lhs = ast.Index{
				lhs: lhs
				expr: p.expr(.lowest)
			}
			p.expect(.rsbr)
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
		else if p.tok == .dotdot {
			p.next()
			// p.log('ast.Range')
			lhs = ast.Range{
				start: lhs
				end: p.expr(.lowest)
			}
		}

		// pratt - from here on we will break on binding power
		lbp := p.tok.left_binding_power()
		if lbp < min_lbp {
			// p.log('breaking precedence: $p.tok ($lbp < $min_lbp)')
			break
		}
		// p.expr(lbp)
		// TODO: use bp loop for infix & postifx instead		
		// lbp2 := p.tok.infix_bp()
		// if lbp2 < min_lbp {
		// 	break
		// }
		// p.next()
		if p.tok.is_infix() {
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
	if p.tok == .key_return && p.scanner.line_nr == 1174  {
		exit(1)
	}
	return lhs
}

pub fn (mut p Parser) next() {
	for {
		p.tok = p.scanner.scan()
		if p.tok != .comment {
			break
		}
	}
}

pub fn (mut p Parser) expect(tok token.Token) {
	if tok != p.tok {
		p.error('unexpected token. expecting `$tok`, got `$p.tok`')
	}
	p.next()
}

// expect name & return lit & go to next token
[inline]
pub fn (mut p Parser) name() string {
	name := p.scanner.lit
	p.expect(.name)
	return name
}

// return lit & go to next token
[inline]
pub fn (mut p Parser) lit() string {
	lit := p.scanner.lit
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

pub fn (p &Parser) block() []ast.Stmt {
	mut stmts := []ast.Stmt{}
	p.expect(.lcbr)
	for p.tok != .rcbr {
		// p.log('BLOCK STMT START')
		stmts << p.stmt()
		// p.log('BLOCK STMT END')
	}
	p.expect(.rcbr)
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

pub fn (mut p Parser) assign(lhs []ast.Expr) ast.Assign {
	return ast.Assign{op: p.tok(), lhs: lhs, rhs: p.expr_list()}
}

pub fn (mut p Parser) const_decl(is_public bool) ast.ConstDecl {
	p.next()
	p.expect(.lpar)
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
		if p.tok == .rpar {
			break
		}
	}
	p.expect(.rpar)
	return ast.ConstDecl{
		is_public: is_public
		fields: fields
	}
}

pub fn (mut p Parser) fn_decl(is_public bool) ast.FnDecl {
	p.next()
	line_nr := p.scanner.line_nr
	mut args := []ast.Arg{}
	// method
	mut is_method := false
	if p.tok == .lpar {
		is_method = true
		p.next()
		// TODO: use parse_ident & type
		// receiver := p.ident() ?
		is_mut := p.tok == .key_mut
		if is_mut {
			p.next()
		}
		// add receiver as arg0
		args << ast.Arg{
			name: p.name()
			typ: p.typ()
			is_mut: is_mut
		}
		p.expect(.rpar)
	}
	mut name := p.name()
	for p.tok == .dot {
		p.next()
		name += '.$p.name()'
	}
	args << p.fn_args()
	// TODO:
	// mut return_type := types.void
	if p.tok != .lcbr && p.scanner.line_nr == line_nr {
		p.typ() // return type
	}
	// p.log('ast.FnDecl: $name')
	mut stmts := if p.tok == .lcbr {
		p.block()
	}
	else {
		[]ast.Stmt{}
	}
	return ast.FnDecl{
		is_public: is_public
		is_method: is_method
		name: name
		stmts: stmts
	}
}

pub fn (mut p Parser) fn_args() []ast.Arg {
	p.expect(.lpar)
	mut args := []ast.Arg{}
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		mut name := 'arg_$args.len'
		if p.tok == .name {
			name = p.name()
		}
		if p.tok !in [.comma, .rpar] {
			p.typ()
		}
		if p.tok == .comma {
			p.next()
		}
		args << ast.Arg{
			name: name
			// typ: 
			is_mut: is_mut
		}
	}
	p.expect(.rpar)
	return args
}


pub fn (mut p Parser) call() ast.Call {
	return ast.Call{}
}


pub fn (mut p Parser) call_args() []ast.Expr {
	p.expect(.lpar)
	// mut args := []ast.Arg{}
	// for p.tok != .rpar {
	// 	is_mut := p.tok == .key_mut
	// 	if is_mut { p.next() }
	// 	args << ast.Arg{
	// 		expr: p.expr(.lowest)
	// 		is_mut: is_mut
	// 	}
	// 	if p.tok == .comma {
	// 		p.next()
	// 	}
	// }
	args := p.expr_list()
	// NOTE: we could just use expr list and mut is hadled with ident,
	// but currently mut is requred even for exprs initialized in the arg
	// args := p.expr_list()
	p.expect(.rpar)
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
		mut value := ast.Expr{}
		if p.tok == .assign {
			p.next()
			value = p.expr(.lowest)
		}
		fields << ast.FieldDecl{
			name: field_name
			value: value
		}
	}
	p.expect(.rcbr)
	return ast.EnumDecl{
		is_public: is_public
		name: name
		fields: fields
	}
}

pub fn (mut p Parser) global_decl() ast.GlobalDecl {
	p.next()
	name := p.name()
	typ := p.typ()
	mut value := ast.Expr{}
	if p.tok == .assign {
		p.next()
		value = p.expr(.lowest)
	}
	return ast.GlobalDecl{
		name: name
		typ: typ
		value: value
	}
}

pub fn (mut p Parser) struct_decl(is_public bool) ast.StructDecl {
	is_union := p.tok == .key_union
	p.next()
	mut name := p.name()
	for p.tok == .dot {
		p.next()
		name += p.name()
	}
	// p.log('ast.StructDecl: $name')
	p.expect(.lcbr)
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
		mut value := ast.Expr{}
		if p.tok == .assign {
			p.next()
			value = p.expr(.lowest)
		}
		fields << ast.FieldDecl{
			name: field_name
			typ: typ
			value: value
		}
	}
	p.next()
	return ast.StructDecl{
		is_public: is_public
		name: name
		fields: fields
	}
}

pub fn (mut p Parser) struct_init() ast.StructInit {
	p.next()
	mut fields := []ast.FieldInit{}
	for p.tok != .rcbr {
		// could be name or init without field name
		mut field_name := ''
		mut value := p.expr(.lowest)
		// name / value
		if p.tok == .colon {
			field_name = (value as ast.Ident).name
			p.next()
			value = p.expr(.lowest)
		}
		if p.tok == .comma {
			p.next()
		}
		fields << ast.FieldInit{
			name: field_name
			value: value
		}
	}
	p.expect(.rcbr)
	return ast.StructInit{fields: fields}
}

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.name()
	// sum type (otherwise alias)
	mut variants := []types.Type{}
	if p.tok == .eq {
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
	parent_type := p.typ()
	// p.log('ast.TypeDecl: $name')
	return ast.TypeDecl{
		is_public: is_public
		name: name
		parent_type: parent_type
		variants: variants
	}
}

pub fn (mut p Parser) log(msg string) {
	if p.pref.verbose {
		println(msg)
	}
}

pub fn (mut p Parser) error(msg string) {
	println('error: $msg')
	col := p.scanner.pos-p.scanner.last_nl_pos-p.scanner.lit.len
	println('$p.file_path:$p.scanner.line_nr:$col')
	exit(1)
}

