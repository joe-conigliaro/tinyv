module ast

import token

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | BoolLiteral | Cast | CharLiteral | Ident | If | Index
	| Infix | List | Match | NumberLiteral | ParExpr | Prefix | Range | Selector
	| StringLiteral | StructInit
pub type Stmt =  Assign | Block | ConstDecl | EnumDecl | ExprStmt | FlowControl | FnDecl
	| For | Import | Module | Return | StructDecl | TypeDecl

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

pub struct CharLiteral {
pub:
	value string
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
	
}

pub struct Ident {
pub:
	name   string
	is_mut bool
}

pub struct If {

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

