// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ast

import token

// NOTE: this is just a very naive example of how it could possibly work.
// actual implementation may work on IR instead of AST (or not). it will also
// need type information which we don't have here. as I said, just an example.
pub fn(m &MatchExpr) desugar() Expr {
	mut branches := []Branch{}
	for branch in m.branches {
		mut branch_cond := empty_expr
		for cond in branch.cond {
			op := if cond in [ast.Ident, ast.SelectorExpr] { token.Token.key_is } else { token.Token.eq }
			c := ast.InfixExpr{lhs: m.expr, op: op, rhs: cond}
			if branch_cond !is EmptyExpr {
				branch_cond = InfixExpr{lhs: branch_cond, op: .logical_or, rhs: c}
			} else {
				branch_cond = c
			}
		}
		branches << Branch{
			cond: [branch_cond]
			stmts: branch.stmts
		}
	}
	return IfExpr{
		branches: branches
	}
}