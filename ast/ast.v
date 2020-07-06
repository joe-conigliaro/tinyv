module ast

import token

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | BoolLiteral | Cast | Call | CharLiteral | Ident
	| If | IfGuard | Index | Infix | List | Match | None | NumberLiteral
	| ParExpr | Prefix | Range | Selector | StringLiteral | StructInit
pub type Stmt =  Assign | Block | ComptimeIf | ConstDecl | EnumDecl | ExprStmt
	| FlowControl | FnDecl | For | Import | Module | Return | StructDecl
	| TypeDecl

pub struct ArrayInit {
pub:
	exprs []Expr
}

pub struct Assign {
pub:
	op  token.Token
	lhs []Expr
	rhs []Expr
}

pub struct Block {
	stmts []Stmt
}

pub struct BoolLiteral {
	val bool
}

pub struct Cast {
	expr Expr
}

pub struct Call {
	lhs Expr
}

pub struct CharLiteral {
pub:
	value string
}

pub struct ComptimeIf {

}

pub struct ConstDecl {
	
}

pub struct EnumDecl {
	
}

pub struct ExprStmt {
	
}

pub struct FnDecl {
	
}

pub struct FlowControl {
	op token.Token
}

pub struct For {
	init Stmt
	cond Expr
	inc  Stmt
}

pub struct Ident {
pub:
	name   string
	is_mut bool
}

pub struct If {

}

pub struct IfGuard {
	cond     Expr
	or_block []Stmt
}

pub struct Infix {

}

pub struct List {
pub:
	exprs []Expr
}

pub struct Import {

}

pub struct Index {
	lhs Expr
}

pub struct Match {
}

pub struct Module {
pub:
	name string
}

pub struct None {

}

pub struct NumberLiteral {
pub:
	value string
}

pub struct ParExpr {

}

pub struct Prefix {

}

pub struct Range {
	start Expr
	end   Expr
}

pub struct Return {

}

pub struct Selector {
	lhs Expr
	rhs Expr
}

pub struct StringLiteral {
	value string
}

pub struct StructDecl {
	
}

pub struct StructInit {
	
}

pub struct TypeDecl {
	
}

