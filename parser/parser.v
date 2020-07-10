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

pub fn (mut p Parser) parse() ast.File {
	p.next()
	mut top_stmts := []ast.Stmt{}
	for p.tok != .eof {
		top_stmts << p.top_stmt()
	}
	return ast.File{
		path: p.file_path
		stmts: top_stmts
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
			p.log('ast.Import: $name as $alias')
			return ast.Import{
				name: name
				alias: alias
				is_aliased: is_aliased
			}
		}
		.key_module {
			p.next()
			name := p.name()
			p.log('ast.Module: $name')
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
			post := p.stmt()
			p.in_init = in_init
			return ast.For{
				init: init
				cond: cond
				post: post
				stmts: p.block()
			}
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
				expr: expr
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
			expr := p.expr(.lowest)
			if p.tok in [.assign, .decl_assign] {
				panic('What the? $p.tok')
			}
			// if p.tok in [.assign, .decl_assign] {
			// 	p.next()
			// 	return ast.Assign{}
			// }
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
			value := if p.tok == .key_true { true } else { false }
			p.next()
			return ast.BoolLiteral{
				value: value
			}
		}
		.lpar {
			// Paren
			p.next()
			p.log('ast.Paren:')
			lhs = ast.Paren{
				expr: p.expr(.lowest)
			}
			p.expect(.rpar)
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
				// typ := p.typ()
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
			p.log('NAME: $name - $p.tok ($p.scanner.lit)')
			// struct init
			// NOTE: can use lit0 capital check, OR registered type check, OR inside stmt init check (eg. `for cond {` OR `if cond {`)
			// currently using in_init for if/for/map initialization
			if p.tok == .lcbr && !p.in_init {
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
				lhs = ast.StructInit{fields: fields}
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
			p.log('ast.NumberLiteral: $value')
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
				op := p.tok
				p.next()
				return ast.Prefix{
					op: op
					expr: p.expr(.lowest)
				}
			}
		}
	}

	for {
		if p.tok == .lpar {
			p.log('ast.Cast or Call: ${typeof(lhs)}')
			args := p.call_args()
			// lhs = ast.Cast{
			lhs = ast.Call{
				lhs: lhs
				args: args
			}
			// TODO: later decide if its a cast
			if p.tok == .key_or {
				p.log('ast.IfGuard')
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
			p.log('ast.Index: $p.scanner.lit')
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
			mut exprs := [lhs]
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
			op := p.tok
			p.next()
			lhs = ast.Infix{
				op: op
				lhs: lhs
				rhs: p.expr(p.tok.left_binding_power())
			}
		}
		else if p.tok.is_postfix() {
			op := p.tok
			p.next()
			lhs = ast.Postfix{
				op: op
				expr: lhs
			}
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

// NOTE: currently we can get a comma separated exprs directly with p.expr()
// TODO: decide if i keep this or explicitly parse expr list everywhere needed
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
	mut fields := []ast.FieldInit{}
	for {
		name := p.name()
		p.log('const: $name')
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
	// method
	if p.tok == .lpar {
		p.next()
		// TODO: use parse_ident & type
		// receiver := p.ident() ?
		if p.tok == .key_mut {
			p.next()
		}
		receiver := p.name()
		receiver_type := p.typ()
		p.expect(.rpar)
	}
	name := p.name()
	p.fn_args()
	if p.tok != .lcbr {
		p.typ() // return type
	}
	p.log('ast.FnDecl: $name')
	return ast.FnDecl{
		is_public: is_public
		name: name
		stmts: p.block()
	}
}

pub fn (mut p Parser) fn_args() []ast.Arg {
	p.expect(.lpar)
	mut args := []ast.Arg{}
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		name := p.name()
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
	return ast.Call{
		
	}
}


pub fn (mut p Parser) call_args() []ast.Arg {
	p.expect(.lpar)
	mut args := []ast.Arg{}
	for p.tok != .rpar {
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		args << ast.Arg{
			expr: p.expr(.lowest)
			is_mut: is_mut
		}
		if p.tok == .comma {
			p.next()
		}
	}
	// NOTE: we could just use expr list and mut is hadled with ident,
	// but currently mut is requred even for exprs initialized in the arg
	// args := p.expr_list()
	p.expect(.rpar)
	return args
}

pub fn (mut p Parser) enum_decl(is_public bool) ast.EnumDecl {
	p.next()
	name := p.name()
	p.log('ast.EnumDecl: $name')
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
	p.next()
	name := p.name()
	p.log('ast.StructDecl: $name')
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

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.name()
	// sum type (otherwise alias)
	if p.tok == .eq {
		p.next()
	}
	typ := p.typ()
	p.log('ast.TypeDecl: $name')
	return ast.TypeDecl{
		is_public: is_public
		name: name
		typ: typ
	}
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

