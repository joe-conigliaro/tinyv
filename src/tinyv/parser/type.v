// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

import tinyv.ast

[inline]
fn (mut p Parser) expect_type() ast.Expr {
	// return p.try_type() or {
	// 	p.error(err.msg())
	// }
	typ := p.try_type()
	if typ is ast.EmptyExpr {
		p.error('expecting type, got `$p.tok`')
	}
	return typ
}

// TODO: use optional or stick with empty expr?
// pub fn (mut p Parser) try_type() ?ast.Expr {
fn (mut p Parser) try_type() ast.Expr {
	match p.tok {
		// pointer
		.amp {
			return ast.PrefixExpr{op: p.tok(), expr: p.expect_type()}
		}
		// TODO: variadic
		.ellipsis {
			p.next()
			return p.expect_type()
		}
		// atomic | shared
		// eg. typespec in struct field with modifier. other cases handled in expr()
		.key_atomic, .key_shared {
			kind := p.tok
			p.next()
			return ast.Modifier{kind: kind, expr: p.expect_type()}
		}
		// function `fn(int) int`
		.key_fn {
			p.next()
			return ast.Type(p.fn_type())
		}
		// nil
		.key_nil {
			p.next()
			return ast.Type(ast.NilType{})
		}
		// none
		.key_none {
			p.next()
			return ast.Type(ast.NoneType{})
		}
		// Tuple (multi return)
		.lpar {
			p.next()
			// expect at least two (so we otherwise error)
			mut types := [p.expect_type()]
			p.expect(.comma)
			types << p.expect_type()
			// more than two
			for p.tok == .comma {
				p.next()
				types << p.expect_type()
			}
			p.expect(.rpar)
			return ast.Type(ast.TupleType{types: types})
		}
		// array
		.lsbr {
			p.next()
			// dynamic array
			if p.tok == .rsbr {
				p.next()
				return ast.Type(ast.ArrayType{elem_type: p.expect_type()})
			}
			// fixed array
			len_expr := p.expr(.lowest)
			p.expect(.rsbr)
			return ast.Type(ast.ArrayFixedType{len: len_expr, elem_type: p.expect_type()})
		}
		// name | chan | map
		.name {
			match p.lit {	
				'map' {
					p.next()
					// map[string]string
					if p.tok == .lsbr {
						p.next()
						key_type := p.expect_type()
						p.expect(.rsbr)
						return ast.Type(ast.MapType{key_type: key_type, value_type: p.expect_type()})
					}
					// struct called `map` in builtin
					return ast.Ident{name: 'map'}
				}
				'chan' {
					line := p.line
					p.next()
					elem_type := if p.line == line { p.try_type() } else { ast.empty_expr }
					if elem_type !is ast.EmptyExpr {
						return ast.Type(ast.ChannelType{elem_type: elem_type})
					}
					// struct called `chan` in builtin
					return ast.Ident{name: 'chan'}
				}
				else {
					// name
					ident := p.ident()
					if p.tok == .dot {
						p.next()
						return ast.SelectorExpr{lhs: ident, rhs: p.ident()}
					}
					return ident
				}
			}
		}
		// result
		.not {
			line := p.line
			p.next()
			return ast.Type(ast.ResultType{
				base_type: if p.line == line { p.try_type() } else { ast.empty_expr }
				// base_type: if p.line == line { p.try_type() or { ast.empty_expr } } else { ast.empty_expr }
			})
		}
		// optional
		.question {
			line := p.line
			p.next()
			return ast.Type(ast.OptionType{
				base_type: if p.line == line { p.try_type() } else { ast.empty_expr }
				// base_type: if p.line == line { p.try_type() or { ast.empty_expr } } else { ast.empty_expr }
			})
		}
		else {
			// return error('expecting type, got `$p.tok`')
			return ast.empty_expr
		}
	}
}

fn (mut p Parser) fn_type() ast.FnType {
	mut generic_params := []ast.Expr{}
	if p.tok == .lsbr {
		p.next()
		generic_params << p.expect_type()
		for p.tok == .comma {
			p.next()
			generic_params << p.expect_type()
		}
		p.expect(.rsbr)
	}
	line := p.line
	params := p.fn_parameters()
	return ast.FnType{
		generic_params: generic_params,
		params: params,
		return_type: if p.line == line { p.try_type() } else { ast.empty_expr }
	}
}
