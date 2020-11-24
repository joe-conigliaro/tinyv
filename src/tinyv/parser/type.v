module parser

import tinyv.ast

// TODO:
pub fn (mut p Parser) typ() ast.Expr {
	// optional
	// TODO: handle
	is_optional := p.tok == .question
	if is_optional {
		p.next()
	}
	// pointer
	// mut ptr_count := 0
	// for p.tok == .amp {
	// 	ptr_count++
	// 	p.next()
	// }
	if p.tok == .amp {
		return ast.Prefix{op: p.tok(), expr: p.typ()}
	}
	// name OR map
	else if p.tok == .name {
		// map
		if p.lit == 'map' {
			p.next()
			// map[string]string
			if p.tok == .lsbr {
				p.expect(.lsbr)
				key_type := p.typ()
				p.expect(.rsbr)
				return ast.MapType{key_type: key_type, value_type: p.typ()}
			}
			// there is just struct called map in builtin
			return ast.Ident{name: 'map'}
		}
		// name
		ident := p.ident()
		if p.tok == .dot {
			p.next()
			// p.name()
			return ast.Selector{lhs: ident, rhs: p.ident()}
		}
		return ident
	}
	// array
	else if p.tok == .lsbr {
		p.next()
		if p.tok == .number {
			p.next()
		}
		p.expect(.rsbr)
		return ast.ArrayType{elem_type: p.typ()}
	}
	// Tuple (multi return)
	else if p.tok == .lpar {
		p.next()
		mut types := []ast.Expr{}
		for p.tok != .rpar {
			types << p.typ()
			if p.tok == .comma {
				p.next()
			}
		}
		p.expect(.rpar)
		return ast.TupleType{types: types}
	}
	// variadic
	// TODO:
	else if p.tok == .ellipsis {
		p.next()
		return p.typ()
	}
	else if p.tok == .key_fn {
		p.next()
		mut args := []ast.Arg{}
		if p.tok == .lpar {
			args = p.fn_args()
		}
		mut return_type := ast.Expr{}
		if p.tok in [.amp, .lsbr, .name, .question] {
			// return type
			return_type = p.typ()
		}
		return ast.FnType{args: args, return_type: return_type}
	}
	// TODO: :D quick hack to handle just ?
	if is_optional {
		return ast.Ident{name: '?'}
	}
	p.error('typ: unknown type (tok: `$p.tok`)')
	exit(1)
}
