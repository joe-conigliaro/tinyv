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
		return ast.Prefix{op: p.tok(), expr: p.typ()}
	}
	// atomic | shared
	// eg. typespec in struct field with modifier. other cases handled in expr()
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
				p.next()
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
		// dynamic array
		if p.tok == .rsbr {
			p.next()
			return ast.Type(ast.ArrayType{elem_type: p.typ()})
		}
		// fixed array
		len_expr := p.expr(.lowest)
		p.expect(.rsbr)
		return ast.Type(ast.ArrayFixedType{len: len_expr, elem_type: p.typ()})
	}
	// Tuple (multi return)
	else if p.tok == .lpar {
		p.next()
		// expect at least two (so we otherwise error)
		mut types := [p.typ()]
		p.expect(.comma)
		types << p.typ()
		// more than two
		for p.tok == .comma {
			p.next()
			types << p.typ()
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
		params := p.fn_parameters()
		return_type := if p.tok in [.amp, .lsbr, .name, .question] { p.typ() } else { ast.empty_expr }
		return ast.Type(ast.FnType{params: params, return_type: return_type})
	}
	p.error('typ: expected type, got `$p.tok`')
}
