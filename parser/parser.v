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
	// p.next()
	for {
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
		.key_import {
			p.next()
			mod := p.name()
			println('import: $mod')
			return ast.Import{

			}
		}
		.key_module {
			p.next()
			mod := p.name()
			println('module: $mod')
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
			p.expect(.name)
			p.expect(.rsbr)
			continue
		}
		else {
			
			panic('X: $p.tok')
		}
	}
	}
	p.error('unknown top stmt')
	panic('')
}

pub fn (mut p Parser) stmt() ast.Stmt {
	println('STMT: $p.tok')
	match p.tok {
		// .assign, .decl_assign {
		// 	p.next()
		// 	return ast.Assign {}
		// }
		.key_break, .key_continue {
			op := p.tok
			p.next()
			return ast.FlowControl{op: op}
		}
		.key_for {
			p.next()
			p.expr(.lowest)
			p.block()
			return ast.For{}
		}
		// .key_if {}
		.name, .key_mut {
			lhs := p.expr_list()
			if p.tok in [.assign, .decl_assign, .plus_assign, .minus_assign] {
				op := p.tok
				p.next()
				return ast.Assign{op: op, lhs: lhs, rhs: p.expr_list()}
			}
			//panic('WHY ARE WE HERE: $p.tok - $p.scanner.line_nr')
			return ast.ExprStmt{}
		}
		// .key_match {}
		// .key_mut {
		// 	println('MUT')
		// 	p.next()
		//  // previously Same as .name, now .mut handled in expr
		//  // the ident is set to is_mut
		// }
		.key_return {
			println('ast.Return')
			p.next()
			expr := p.expr(.lowest)
			if expr is ast.List {
				println('## RETURN IS LIST')
			}
			return ast.Return{

			}
		}
		else {
			println('HRMMM: $p.tok')
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
	// TODO: dont return continue to pratt loop
	// TODO: fix match so it last expr can be used `x := match {...`
	println('EXPR: $p.tok - $p.scanner.line_nr')
	mut lhs := ast.Expr{}
	match p.tok {
		.chartoken {
			value := p.lit()
			lhs = ast.CharLiteral{
				value: value
			}
		}
		// .dot {
		// 	p.next()
		// 	rhs := p.expr(.lowest)
		// 	lhs = ast.Selector{
		// 		flhs: lhs
		// 		rhs: rhs
		// 	}
		// }
		.key_if {
			println('START IF')
			p.next()
			p.expr(.lowest)
			p.expect(.lcbr)
			for p.tok != .rcbr {
				p.stmt()
			}
			p.expect(.rcbr)
			lhs = ast.If{}
			println('END IF')
		}
		// .key_mut {
		// 	// TODO: maybe this shouldnt be done like this
		// 	// or we need to save somewhere or pass
		// 	p.next()
		// 	p.expr(.lowest)
		// }
		.key_true, .key_false {
			val := if p.tok == .key_true { true } else { false }
			p.next()
			return ast.BoolLiteral{
				val: val
			}
		}
		// .lcbr {
		// 	p.next()
		// 	p.expect(.rsbr)
		// }
		.lpar {
			// ParExpr
			p.next()
			println('PAREXPR:')
			p.expr(.lowest)
			// TODO
			p.expect(.rpar)
			lhs = ast.ParExpr{

			}
		}
		.lsbr {
			p.next()
			// index
			// if lhs is ast.Selector {
				// lhs = ast.Index{
				// 	lhs: lhs
				// }
			// }
			// array init
			// else {
				// [1,2,3,4]
				line_nr := p.scanner.line_nr
				mut exprs := []ast.Expr{}
				for p.tok != .rsbr {
					println('ARRAY INIT EXPR:')
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
				}
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
				lhs = ast.ArrayInit{
					exprs: exprs
				}
			// }
		}
		.key_match {
			p.next()
			p.expr(.lowest)
			p.expect(.lcbr)
			for p.tok != .rcbr {
				p.expr(.lowest)
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
			println('NAME: $name')
			// cast
			if p.tok == .lpar {
				p.next()
				expr := p.expr(.lowest)
				p.expect(.rpar)
				lhs = ast.Cast{
					expr: expr
					// typ: // TODO
				}
			}
			// struct init
			// TODO: replace capital check with type check OR with inside stmt init check (`for cond {` OR `if cond {`)
			else if p.tok == .lcbr && name[0].is_capital() {
				p.next()
				for p.tok != .rcbr {
					p.expr(.lowest)
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
			println('NUMBER: $value')
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
		// index
		if p.tok == .lsbr {
			// lhs = p.expr(.lowest)
			p.next()
			p.expr(.lowest)
			lhs = ast.Index{
				lhs: lhs
			}
			p.expect(.rsbr)
		}
		// Selector
		else if p.tok == .dot {
			p.next()
			println('ast.Selector')
			rhs := p.expr(.lowest)
			lhs = ast.Selector{
				lhs: lhs
				rhs: rhs
			}
		}
		// expr list muti assign / return
		else if p.tok == .comma {
			p.next()
			println('ast.ExprList')
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
			println('LIST: $exprs.len - $p.scanner.line_nr')
		}
		// TODO: pratt loop - finish
		// println('PRATT LOOP: $p.tok - $p.scanner.line_nr')
		lbp := p.tok.left_binding_power()
		if lbp < min_lbp {
			println('breaking precedence')
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
			lhs =p.expr(p.tok.left_binding_power())
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
	println('returning: $p.tok')
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
	// println('expect $tok - $p.tok')
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

// pub fn (mut p Parser) peek(pos int) scanner.Token {
// 	return scanner.
// }

pub fn (p &Parser) block() []ast.Stmt {
	mut stmts := []ast.Stmt{}
	p.expect(.lcbr)
	for p.tok != .rcbr {
		// println('BLOCK STMT START')
		stmts << p.stmt()
		// println('BLOCK STMT END')
	}
	p.expect(.rcbr)
	println('END BLOCK')
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
	// lhs := p.expr(.lowest)
	// p.expect
	return ast.Assign{}
}

pub fn (mut p Parser) const_decl(is_public bool) ast.ConstDecl {
	// is_public := p.tok == .key_pub
	// if is_public {
	// 	p.next()
	// }
	// p.expect(.key_const)
	p.next()
	p.expect(.lpar)
	for {
		name := p.name()
		println('const: $name')
		p.expect(.assign)
		// p.next()
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
		// TODO: use parse_ident & parse_type
		// receiver := p.ident() ?
		if p.tok == .key_mut {
			p.next()
		}
		receiver := p.name()
		// TODO:
		// receiver_type := p.parse_type()
		receiver_type := p.lit()
		p.expect(.rpar)
	}
	name := p.name()
	println('FN: $name')

	p.fn_args()

	// TODO: parse type (multi return)
	if p.tok == .lpar {
		p.next()
		for p.tok != .rpar {
			p.expect(.name) // type
			if p.tok == .comma {
				p.next()
			}
		}
		p.expect(.rpar)
	}

	if p.tok != .lcbr {
		p.expect(.name) // return type
	}

	stmts := p.block()

	return ast.FnDecl{

	}
}

pub fn (mut p Parser) fn_args() /* []ast.Arg */ {
	p.expect(.lpar)
	for p.tok != .rpar {
		p.expect(.name) // arg
		if p.tok == .name {
			p.expect(.name) // type
		}
		if p.tok == .comma {
			// p.expect(.comma)
			p.next()
		}
	}
	p.expect(.rpar)
}

pub fn (mut p Parser) enum_decl(is_public bool) ast.EnumDecl {
	p.next()
	name := p.name()
	println('enum: $name')
	p.expect(.lcbr)
	// fields
	for p.tok != .rcbr {
		field_name := p.name()
		println('field: $field_name')
	}
	p.expect(.rcbr)
	return ast.EnumDecl{
	}
}

pub fn (mut p Parser) struct_decl(is_public bool) ast.StructDecl {
	p.next()
	name := p.name()
	println('struct: $name')
	p.expect(.lcbr)
	// fields
	for p.tok != .rcbr {
		is_pub := p.tok == .key_pub
		if is_pub { p.next() }
		is_mut := p.tok == .key_mut
		if is_mut { p.next() }
		if is_pub || is_mut { p.expect(.colon) }
		field_name := p.name()
		println('field: $field_name')
		// typ := p.scanner.lit
		// p.expect(.name)
		typ := p.parse_type()
		// default field value
		if p.tok == .assign {
			p.next()
			default_val := p.expr(.lowest)
		}
	}
	// p.expect(.rcbr)
	p.next()
	return ast.StructDecl{

	}
}

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.name()
	// sum type
	if p.tok == .eq {
		p.next()
	}
	// fn type TODO: move to parse_type (become part of alias)
	else if p.tok == .key_fn {
		p.next()
		// p.fn_decl(false)
		p.fn_args()
	}
	// alias
	// else {
	// 	alias_type := p.parse_type()
	// }
	p.next() // return type

	println('TYPE: $name')
	return ast.TypeDecl{}
}

pub fn (mut p Parser) error(msg string) {
	println('error: $msg')
	col := p.scanner.pos-p.scanner.last_nl_pos-p.scanner.lit.len
	println('$p.file_path:$p.scanner.line_nr:$col')
	exit(1)
}

