module ast

import token
import types

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | BoolLiteral | Cast | Call | CharLiteral | Ident
	| If | IfGuard | Index | Infix | List | Match | None | NumberLiteral
	| ParExpr | Prefix | Range | Selector | StringLiteral | StructInit
pub type Stmt =  Assign | Attribute | Block | ComptimeIf | ConstDecl | EnumDecl
	| ExprStmt | FlowControl | FnDecl | For | GlobalDecl | Import | Module
	| Return | StructDecl | TypeDecl | Unsafe

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

pub struct Attribute {
pub:
	name string
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

pub struct FieldDecl {
	name    string
	typ     types.Type
	default Expr
}
pub struct FieldInit {
	name  string
	value Expr
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

pub struct GlobalDecl {
	
}

pub struct Ident {
pub:
	name   string
	kind   IdentKind
	is_mut bool
}

pub enum IdentKind {
	unresolved
	constant
	functiom
	global
	mod
	variable
}


pub struct If {

}

pub struct IfGuard {
	cond     Expr
	or_stmts []Stmt
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
	fields []FieldDecl
}

pub struct StructInit {
	fields []FieldInit
}

pub struct TypeDecl {
	
}

pub struct Unsafe {
	stmts []Stmt
}

