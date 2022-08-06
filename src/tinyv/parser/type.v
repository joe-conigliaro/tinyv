// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

import tinyv.ast

// TODO:
pub fn (mut p Parser) typ() ast.Expr {
	// optional
	if p.tok == .question {
		line_nr := p.line_nr
		p.next()
		if p.tok == .lcbr || line_nr != p.line_nr { return ast.Type(ast.OptionType{}) }
		return ast.Type(ast.OptionType{ base_type: p.typ() })
	}
	// result
	else if p.tok == .not {
		p.next()
		return ast.Type(ast.ResultType{ base_type: p.typ() })
	}
	// pointer
	else if p.tok == .amp {
		// TODO: bug
		// return ast.Prefix{op: p.tok(), expr: p.typ()?}
		return ast.Prefix{op: p.tok(), expr: p.typ()}
	}
	// atomic | shared
	// TODO: proper
	else if p.tok in [.key_atomic, .key_shared] {
		kind := p.tok
		p.next()
		return ast.Modifier{kind: kind, expr: p.typ()}
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
				return ast.Type(ast.MapType{key_type: key_type, value_type: p.typ()})
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
	else if p.tok == .key_nil {
		p.next()
		return ast.Type(ast.NilType{})
	}
	else if p.tok == .key_none {
		p.next()
		return ast.Type(ast.NoneType{})
	}
	// array
	else if p.tok == .lsbr {
		p.next()
		// if p.tok == .number {
		// 	p.next()
		// }
		// fixed array length
		if p.tok != .rsbr {
			len_expr := p.expr(.lowest)
			p.expect(.rsbr)
			return ast.Type(ast.ArrayFixedType{len: len_expr, elem_type: p.typ()})
		}
		p.expect(.rsbr)
		return ast.Type(ast.ArrayType{elem_type: p.typ()})
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
		return ast.Type(ast.TupleType{types: types})
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
		return_type := if p.tok in [.amp, .lsbr, .name, .question] { p.typ() } else { ast.empty_expr }
		return ast.Type(ast.FnType{args: args, return_type: return_type})
	}
	p.error('typ: expected type, got `$p.tok`')
}
