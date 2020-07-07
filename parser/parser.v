module parser

import os
import ast
import scanner
import token

struct Parser {
	file_path string
mut:
	scanner   &scanner.Scanner
	tok       token.Token
	in_init   bool // for/if/match eg. `for x in vals {`
}

pub fn new_parser(file string) Parser {
	text := os.read_file(file) or {
		panic('error reading $file')
	}
	return Parser{
		file_path: file,
		scanner: scanner.new_scanner(text)
	}
}

pub fn (mut p Parser) parse() {
	p.next()
	for p.tok != .eof {
		p.top_stmt()
	}
}

pub fn (mut p Parser) top_stmt() ast.Stmt {
	match p.tok {
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
			return p.global_decl(false)
		}
		.key_import {
			p.next()
			// TODO: do we parse as string with loop to handle dots
			// or as selector expr ? 
			// mod := p.expr(.lowest)
			mut mod := p.name()
			for p.tok == .dot {
				p.next()
				mod += '.' + p.name()
			}
			p.log('ast.Import: $mod')
			return ast.Import{

			}
		}
		.key_module {
			p.next()
			mod := p.name()
			p.log('ast.Module: $mod')
			return ast.Module{

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
				.key_global {
					return p.global_decl(true)
				}
				.key_struct {
					return p.struct_decl(true)
				}
				.key_type {
					return p.type_decl(true)
				}
				else {}
			}
		}
		.key_struct {
			return p.struct_decl(false)
		}
		.key_type {
			return p.type_decl(false)
		}
		.lsbr {
			// [attribute]
			p.next()
			name := p.name()
			p.log('ast.Attribute: $name')
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
	p.log('STMT: $p.tok - $p.scanner.line_nr')
	match p.tok {
		.dollar {
			p.next()
			p.expect(.key_if)
			p.log('ast.ComptimeIf')
			cond := p.expr(.lowest)
			if p.tok == .question {
				p.next()
			}
			block := p.block()
			return ast.ComptimeIf{}
		}
		.key_break, .key_continue {
			op := p.tok
			p.next()
			return ast.FlowControl{op: op}
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
			inc := p.stmt()
			p.in_init = in_init
			p.block()
			return ast.For{}
		}
		.name, .key_mut {
			lhs := p.expr_list()
			if p.tok.is_assignment() {
				return p.assign(lhs)
			}
			//panic('WHY ARE WE HERE: $p.tok - $p.scanner.line_nr')
			return ast.ExprStmt{}
		}
		.key_return {
			p.log('ast.Return')
			p.next()
			expr := p.expr(.lowest)
			if expr is ast.List {
				p.log('## RETURN IS LIST')
			}
			return ast.Return{

			}
		}
		.key_unsafe {
			p.log('ast.Unsafe')
			p.next()
			return ast.Unsafe{
				stmts: p.block()
			}
		}
		else {
			p.log('HRMMM: $p.tok')
			expr := p.expr(.lowest)
			if p.tok in [.assign, .decl_assign] {
				p.next()
				return ast.Assign{}
			}
			return ast.ExprStmt{}
		}
	}

	// TODO
	p.error('unknown stmt: $p.tok')
	panic('')
}

pub fn (mut p Parser) expr(min_lbp token.BindingPower) ast.Expr {
	// TODO: fix match so it last expr can be used `x := match {...`
	p.log('EXPR: $p.tok - $p.scanner.line_nr')
	mut lhs := ast.Expr{}
	match p.tok {
		.chartoken {
			value := p.lit()
			lhs = ast.CharLiteral{
				value: value
			}
		}
		.key_if {
			p.log('START IF')
			for p.tok in [.key_if, .key_else] {
				p.next()
				if p.tok == .key_if {
					p.next()
				}
				in_init := p.in_init
				p.in_init = true
				p.expr(.lowest)
				p.in_init = in_init
				if p.tok == .key_or {
					panic('GOT OR')
				}
				p.block()
			}
			if p.tok == .key_or {
				panic('GOT OR')
			}
			lhs = ast.If{}
			p.log('END IF')
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
		.key_true, .key_false {
			val := if p.tok == .key_true { true } else { false }
			p.next()
			return ast.BoolLiteral{
				val: val
			}
		}
		.lpar {
			// ParExpr
			p.next()
			p.log('PAREXPR:')
			p.expr(.lowest)
			// TODO
			p.expect(.rpar)
			lhs = ast.ParExpr{

			}
		}
		.lsbr {
			p.next()
			// [1,2,3,4]
			line_nr := p.scanner.line_nr
			mut exprs := []ast.Expr{}
			for p.tok != .rsbr {
				p.log('ARRAY INIT EXPR:')
				exprs << p.expr(.lowest)
				if p.tok == .comma {
					p.next()
				}
				// p.expect(.comma)
			}
			p.expect(.rsbr)
			// []int{}
			// TODO: restructure in parts (type->init) ?? no
			if p.tok == .name && p.scanner.line_nr == line_nr {
				// typ := p.parse_type()
				p.next()
				// init
				mut init_exprs := map[string]ast.Expr{}
				if p.tok == .lcbr {
					p.next()
					allowed_init_keys := ['cap', 'init', 'len']
					for p.tok != .rcbr {
						key := p.name()
						if key !in allowed_init_keys {
							p.error('expecting one of ' + allowed_init_keys.join(', '))
						}
						p.expect(.colon)
						init_exprs[key] = p.expr(.lowest)
					}
					p.expect(.rcbr)
				}
			}
			lhs = ast.ArrayInit{
				exprs: exprs
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
				p.expr(.lowest)
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
		.key_mut, .name {
			is_mut := p.tok == .key_mut
			if is_mut {
				p.next()
			}
			name := p.name()
			// TODO: parse type for cast
			p.log('NAME: $name - $p.tok ($p.scanner.lit)')
			// TODO: call as well as cast (currently all parsed as cast :D)
			// cast
			if p.tok == .lpar {
				p.log('ast.Cast')
				//p.next()
				//expr := p.expr(.lowest)
				p.fn_call_args()
				//p.expect(.rpar)
				lhs = ast.Cast{
					//expr: expr
					// typ: // TODO
				}
				if p.tok == .key_or {
					p.log('ast.IfGuard')
					p.next()
					lhs = ast.IfGuard{
						cond: lhs
						or_stmts: p.block()
					}
				}
			}
			// struct init
			// NOTE: can use lit0 capital check, OR registered type check, OR inside stmt init check (eg. `for cond {` OR `if cond {`)
			// currently using in_init for if/for/map initialization
			else if p.tok == .lcbr && !p.in_init {
				p.next()
				for p.tok != .rcbr {
					//field_name := p.name()
					// could be name or init without field name
					p.expr(.lowest)
					// has value
					if p.tok == .colon {
						p.next()
						val := p.expr(.lowest)
					}
					if p.tok == .comma {
						p.next()
					}
				}
				p.expect(.rcbr)
				lhs = ast.StructInit{}
			}
			// ident
			else {
				lhs = ast.Ident{
					name: name
					is_mut: is_mut
				}
			}
		}
		.number {
			value := p.lit()
			p.log('NUMBER: $value')
			lhs = ast.NumberLiteral{
				value: value
			}
		}
		.string {
			value := p.lit()
			lhs = ast.StringLiteral{
				value: value
			}
		}
		.plus_assign{
			p.error('BOO')
		}
		else {
			if p.tok.is_prefix() {
				p.next()
				p.expr(.lowest)
				return ast.Prefix{}
			}
		}
	}

	for {
		// excluded from binding power check they run either way
		// index
		if p.tok == .lsbr {
			p.next()
			p.log('ast.Index: $p.scanner.lit')
			p.expr(.lowest)
			lhs = ast.Index{
				lhs: lhs
			}
			p.expect(.rsbr)
			// continue to allows `Index[1]Selector` with no regard to binding power 
			continue
		}
		// Selector
		else if p.tok == .dot {
			p.next()
			p.log('ast.Selector')
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
			p.log('ast.Range')
			lhs = ast.Range{
				start: lhs
				end: p.expr(.lowest)
			}
		}
		// Expr list  / Tuple ( muti assign / return )
		// TODO: consider if this is the method I want to use
		// or just use list() where needed eg. assign
		else if p.tok == .comma {
			p.next()
			mut exprs := []ast.Expr{}
			exprs << lhs
			for {
				exprs << p.expr(.lowest)
				if p.tok != .comma {
					break
				}
				p.next()
			}
			lhs = ast.List{
				exprs: exprs
			}
			p.log('ast.ExprList: $exprs.len - $p.scanner.line_nr')
		}

		// pratt - from here on we will break on binding power
		lbp := p.tok.left_binding_power()
		if lbp < min_lbp {
			p.log('breaking precedence: $p.tok ($lbp < $min_lbp)')
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
			p.next()
			lhs = p.expr(p.tok.left_binding_power())
		}
		else if p.tok.is_postfix() {
			p.next()
			lhs = p.expr(p.tok.left_binding_power())
		}
		else {
			// return lhs
			break
		}
	}
	p.log('returning: $p.tok')
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

pub fn (mut p Parser) name() string {
	name := p.scanner.lit
	p.expect(.name)
	return name
}

pub fn (mut p Parser) lit() string {
	lit := p.scanner.lit
	p.next()
	return lit
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
	p.log('END BLOCK')
	return stmts
}

pub fn (mut p Parser) expr_list() []ast.Expr {
	expr := p.expr(.lowest)
	match expr {
		ast.List { return it.exprs }
		else { return [expr] }
	}
}

pub fn (mut p Parser) assign(lhs []ast.Expr) ast.Assign {
	op := p.tok
	p.next()
	return ast.Assign{op: op, lhs: lhs, rhs: p.expr_list()}
}

pub fn (mut p Parser) const_decl(is_public bool) ast.ConstDecl {
	p.next()
	p.expect(.lpar)
	for {
		name := p.name()
		p.log('const: $name')
		p.expect(.assign)
		p.expr(.lowest)
		if p.tok == .rpar {
			break
		}
	}
	p.expect(.rpar)

	return ast.ConstDecl{
		
	}
}

pub fn (mut p Parser) fn_decl(is_public bool) ast.FnDecl {
	p.next()
	// method
	if p.tok == .lpar {
		p.next()
		// TODO: use parse_ident & type
		// receiver := p.ident() ?
		if p.tok == .key_mut {
			p.next()
		}
		receiver := p.name()
		receiver_type := p.parse_type()
		p.expect(.rpar)
	}
	name := p.name()
	p.log('FN: $name')

	p.fn_args()

	if p.tok != .lcbr {
		p.parse_type() // return type
	}

	stmts := p.block()

	return ast.FnDecl{

	}
}

pub fn (mut p Parser) fn_args() /* []ast.Arg */ {
	p.expect(.lpar)
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		p.expect(.name) // arg
		if p.tok !in [.comma, .rpar] {
			p.parse_type()
		}
		if p.tok == .comma {
			p.next()
		}
	}
	p.expect(.rpar)
}


pub fn (mut p Parser) fn_call() ast.Call {
	return ast.Call{}
}


pub fn (mut p Parser) fn_call_args() /* []ast.Arg */ {
	p.expect(.lpar)
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		p.expr(.lowest)
		if p.tok == .comma {
			p.next()
		}
	}
	p.expect(.rpar)
}

pub fn (mut p Parser) enum_decl(is_public bool) ast.EnumDecl {
	p.next()
	name := p.name()
	p.log('enum: $name')
	p.expect(.lcbr)
	// fields
	for p.tok != .rcbr {
		field_name := p.name()
		p.log('field: $field_name')
		if p.tok == .assign {
			p.next()
			default_val := p.expr(.lowest)
		}
	}
	p.expect(.rcbr)
	return ast.EnumDecl{
	}
}

pub fn (mut p Parser) global_decl(is_public bool) ast.GlobalDecl {
	p.next()
	name := p.name()
	typ := p.parse_type()
	return ast.GlobalDecl{}
}

pub fn (mut p Parser) struct_decl(is_public bool) ast.StructDecl {
	p.next()
	name := p.name()
	p.log('struct: $name')
	p.expect(.lcbr)
	// fields
	for p.tok != .rcbr {
		is_pub := p.tok == .key_pub
		if is_pub { p.next() }
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		if is_pub || is_mut { p.expect(.colon) }
		field_name := p.name()
		p.log('field: $field_name')
		typ := p.parse_type()
		// default field value
		if p.tok == .assign {
			p.next()
			default_val := p.expr(.lowest)
		}
	}
	p.next()
	return ast.StructDecl{

	}
}

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.name()
	// sum type (otherwise alias)
	if p.tok == .eq {
		p.next()
	}
	p.parse_type()

	p.log('ast.TypeDecl: $name')
	return ast.TypeDecl{}
}

pub fn (mut p Parser) log(msg string) {
	// println(msg)
}

pub fn (mut p Parser) error(msg string) {
	println('error: $msg')
	col := p.scanner.pos-p.scanner.last_nl_pos-p.scanner.lit.len
	println('$p.file_path:$p.scanner.line_nr:$col')
	exit(1)
}

