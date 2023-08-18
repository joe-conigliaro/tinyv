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
		p.error('expecting type, got `${p.tok}`')
	}
	return typ
}

// TODO: use result or stick with empty expr?
// pub fn (mut p Parser) try_type() !ast.Expr {
fn (mut p Parser) try_type() ast.Expr {
	match p.tok {
		// pointer: `&type`
		.amp {
			p.next()
			return ast.PrefixExpr{
				op: .amp
				expr: p.expect_type()
			}
		}
		// variadic: `...type`
		.ellipsis {
			p.next()
			// TODO: what will we use here?
			return ast.PrefixExpr{
				op: .ellipsis
				expr: p.expect_type()
			}
		}
		// atomic | shared
		// eg. typespec in struct field with modifier. other cases handled in expr()
		.key_atomic, .key_shared {
			kind := p.tok
			p.next()
			return ast.Modifier{
				kind: kind
				expr: p.expect_type()
			}
		}
		// function: `fn(type) type`
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
		// tuple (multi return): `(type, type)`
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
			return ast.Type(ast.TupleType{
				types: types
			})
		}
		// array: `[]type` | `[len]type`
		.lsbr {
			p.next()
			// dynamic array
			if p.tok == .rsbr {
				p.next()
				return ast.Type(ast.ArrayType{
					elem_type: p.expect_type()
				})
			}
			// fixed array
			len_expr := p.expr(.lowest)
			p.expect(.rsbr)
			return ast.Type(ast.ArrayFixedType{
				len: len_expr
				elem_type: p.expect_type()
			})
		}
		// name | chan | map
		.name {
			pos := p.pos
			type_name := p.ident_or_named_type()
			if p.tok == .lsbr {
				// TODO: is there a better solution than this. it should be the
				// concern of p.fn_parameters() rather than this. find solution.
				// TODO: using ast.GenericArgs here may not be correct,
				// perhaps we should rename it to ast.GenericTypes
				next_pos := if type_name is ast.Ident { pos + type_name.name.len } else { -1 }
				if p.pos == next_pos {
					generic_types := p.generic_list()
					return ast.GenericArgs{
						lhs: type_name
						args: generic_types
					}
				}
			}
			return type_name
		}
		// result: `!` | `!type`
		.not {
			line := p.line
			p.next()
			return ast.Type(ast.ResultType{
				base_type: if p.line == line { p.try_type() } else { ast.empty_expr }
				// base_type: if p.line == line { p.try_type() or { ast.empty_expr } } else { ast.empty_expr }
			})
		}
		// option: `?` | `?type`
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

// function type / signature
fn (mut p Parser) fn_type() ast.FnType {
	generic_params := if p.tok == .lsbr { p.generic_list() } else { []ast.Expr{} }
	line := p.line
	params := p.fn_parameters()
	return ast.FnType{
		generic_params: generic_params
		params: params
		return_type: if p.line == line { p.try_type() } else { ast.empty_expr }
	}
}

[direct_array_access]
fn (mut p Parser) ident_or_named_type() ast.Expr {
	pos := p.pos
	// `chan` | `chan type`
	if p.lit.len == 4 && p.lit[0] == `c` && p.lit[1] == `h` && p.lit[2] == `a` && p.lit[3] == `n` {
		line := p.line
		p.next()
		elem_type := if p.line == line { p.try_type() } else { ast.empty_expr }
		if elem_type !is ast.EmptyExpr {
			return ast.Type(ast.ChannelType{
				elem_type: elem_type
			})
		}
		// struct called `chan` in builtin
		return ast.Ident{
			name: 'chan'
			pos: pos
		}
	}
	// `map[type]type`
	else if p.lit.len == 3 && p.lit[0] == `m` && p.lit[1] == `a` && p.lit[2] == `p` {
		p.next()
		if p.tok == .lsbr {
			p.next()
			key_type := p.expect_type()
			p.expect(.rsbr)
			return ast.Type(ast.MapType{
				key_type: key_type
				value_type: p.expect_type()
			})
		}
		// struct called `map` in builtin
		return ast.Ident{
			name: 'map'
			pos: pos
		}
	}
	// `thread` | `thread type`
	else if p.lit.len == 6 && p.lit[0] == `t` && p.lit[1] == `h` && p.lit[2] == `r`
		&& p.lit[3] == `e` && p.lit[4] == `a` && p.lit[5] == `d` {
		line := p.line
		p.next()
		return ast.Type(ast.ThreadType{
			elem_type: if p.line == line { p.try_type() } else { ast.empty_expr }
		})
	}
	// ident := p.ident()
	// return ident
	return p.ident_or_selector_expr()
}

fn (mut p Parser) ident_or_selector_expr() ast.Expr {
	lhs := p.ident()
	// lhs := p.expr(.lowest)
	if p.tok == .dot {
		p.next()
		return ast.SelectorExpr{
			lhs: lhs
			// rhs: p.ident_or_selector_expr()
			rhs: p.ident()
			pos: p.pos
		}
	}
	return lhs
}
