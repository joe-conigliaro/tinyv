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
	is_public bool
	fields    []FieldInit
}

pub struct EnumDecl {
	is_public bool
	name      string
	fields    []FieldDecl
}

pub struct ExprStmt {
	
}

pub struct FieldDecl {
	name  string
	typ   types.Type
	value Expr
}

pub struct FieldInit {
	name  string
	value Expr
}

pub struct File {
	path  string
	stmts []Stmt
}

pub struct FnDecl {
	is_public bool
	name      string
	stmts     []Stmt
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
	name  string
	typ   types.Type
	value Expr
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
	function
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
	is_public bool
	name      string
	fields    []FieldDecl
}

pub struct StructInit {
	fields []FieldInit
}

pub struct TypeDecl {
	is_public bool
	name      string
	typ       types.Type
}

pub struct Unsafe {
	stmts []Stmt
}

