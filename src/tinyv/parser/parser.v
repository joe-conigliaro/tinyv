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
	return &Parser{
		pref: pref
		scanner: scanner.new_scanner(pref, false)
	}
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
		goto start_no_time
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
			return p.comptime_if()
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
					return p.fn_decl(true)
				}
				.key_interface {
					return p.interface_decl(true)
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
			return p.comptime_if()
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
			mut init := ast.Stmt{}
			if p.next_tok in [.comma, .key_in] {
				mut key, mut value := '', p.name()
				if p.tok == .comma {
					p.next()
					key = value
					value = p.name()
				}
				p.expect(.key_in)
				init = ast.ForIn{
					key: key
					value: value
					expr: p.expr(.lowest)
				}
			}
			else if p.tok != .semicolon {
				init = p.stmt()
			}
			// init := p.stmt()
			// TODO: clean up
			mut cond := ast.Expr{}
			mut post := ast.Stmt{}
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
	// TODO: fix match so it last expr can be used `x := match {...`
	// p.log('EXPR: $p.tok - $p.line_nr')
	line_nr := p.line_nr
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
			p.next()
			mut branches := []ast.Branch{}
			for {
				in_init := p.in_init
				p.in_init = true
				mut cond := p.expr(.lowest)
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
				if p.tok != .key_else {
					break
				}
				p.next()
				if p.tok == .key_if {
					p.next()
				}
			}
			lhs = ast.If{
				branches: branches
			}
			// no need to continue
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
			if !p.in_init {
				// TODO: options struct
				// lhs = p.struct_init()
				p.next()
				if p.tok == .rcbr {
					p.next()
					return ast.StructInit{}
				}
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
			mut typ := ast.Expr{}
			// []int{}
			mut cap, mut init, mut len := ast.Expr{}, ast.Expr{}, ast.Expr{}
			// TODO: restructure in parts (type->init) ?? no
			if p.tok == .name && p.line_nr == line_nr {
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
			else if p.tok !in [.lpar, .lsbr, .dot, .dotdot] {
				p.error('expr: unexpected token `$p.tok`')
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
			if p.tok == .rsbr {
				lhs = ast.Range{
					start: lhs
				}
			}
			else {
				lhs = ast.Range{
					start: lhs
					end: p.expr(.lowest)
				}
			}
		}

		// pratt - from here on we will break on binding power
		lbp := p.tok.left_binding_power()
		if lbp < min_bp {
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

pub fn (mut p Parser) assign(lhs []ast.Expr) ast.Assign {
	return ast.Assign{op: p.tok(), lhs: lhs, rhs: p.expr_list()}
}

pub fn (mut p Parser) comptime_if() ast.ComptimeIf {
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
	// if p.tok == .dollar {
	// 	p.next()
	// 	if p.tok == .key_else {
	// 		p.next()
	// 		else_stmts = p.block()
	// 	}
	// }
	if p.tok == .dollar && p.next_tok == .key_else {
		p.next()
		p.next()
		else_stmts = p.block()
	}
	return ast.ComptimeIf{
		cond: cond
		stmts: stmts
		else_stmts: stmts
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
	}
	mut name := p.name()
	// TODO: think if we use string or selector/ident
	// is_c := p.tok == .dot && name == 'C'
	// if is_c {
	// 	p.next()
	// 	name = 
	// }
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
	mut return_type := ast.Expr{}
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
		is_public: is_public
		is_method: is_method
		receiver: receiver
		name: name
		args: args
		stmts: stmts
		return_type: return_type
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
		typ := if p.tok !in [.comma, .rpar] {
			p.typ()
		}
		else {
			ast.Expr{}
		}
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
	args := if p.tok == .rpar { []ast.Expr{} } else { p.expr_list() }
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
	p.next()
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
	// mut methods := []
	for p.tok != .rcbr {
		line_nr := p.line_nr
		p.name() // method name
		p.fn_args()
		if p.line_nr == line_nr {
			p.typ() // method return type
		}
		// TODO: methods <<
	}
	p.next()
	return ast.InterfaceDecl{
		is_public: is_public
		name: name
		// methods: methods
	}
}

pub fn (mut p Parser) struct_decl(is_public bool) ast.StructDecl {
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
	p.next()
	return ast.StructInit{fields: fields}
}

pub fn (mut p Parser) type_decl(is_public bool) ast.TypeDecl {
	p.next()
	name := p.name()
	mut parent_type := ast.Expr{}
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
