module ast

import token
import types

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | BoolLiteral | Cast | Call | CharLiteral | Ident
	| If | IfGuard | Index | Infix | List | Match | None | NumberLiteral
	| Paren | Postfix | Prefix | Range | Selector | StringLiteral | StructInit
pub type Stmt =  Assign | Attribute | Block | ComptimeIf | ConstDecl | EnumDecl
	| ExprStmt | FlowControl | FnDecl | For | GlobalDecl | Import | Module
	| Return | StructDecl | TypeDecl | Unsafe

// File (main Ast container)
pub struct File {
pub:
	path  string
	stmts []Stmt
}

// Expressions
pub struct Arg {
pub:
	name   string
	expr   Expr
	is_mut bool
}

pub struct ArrayInit {
pub:
	exprs []Expr
}

pub struct BoolLiteral {
pub:
	value bool
}

pub struct Branch {
pub:
	cond  Expr
	stmts []Stmt
}

pub struct Cast {
pub:
	expr Expr
}

pub struct Call {
pub:
	lhs  Expr
	args []Arg
	// args []Expr // NOTE: see call_args()
}

pub struct CharLiteral {
pub:
	value string
}

pub struct FieldDecl {
pub:
	name  string
	typ   types.Type
	value Expr
}

pub struct FieldInit {
pub:
	name  string
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
pub:
	branches []Branch
}

pub struct IfGuard {
pub:
	cond     Expr
	or_stmts []Stmt
}

pub struct Infix {
pub:
	op  token.Token
	lhs Expr
	rhs Expr
}

pub struct List {
pub:
	exprs []Expr
}

pub struct Index {
pub:
	lhs  Expr
	expr Expr
}

pub struct Match {
}


pub struct None {

}

pub struct NumberLiteral {
pub:
	value string
}

pub struct Paren {
pub:
	expr Expr
}

pub struct Postfix {
pub:
	op   token.Token
	expr Expr
}

pub struct Prefix {
pub:
	op   token.Token
	expr Expr
}

pub struct Range {
pub:
	start Expr
	end   Expr
}

pub struct Selector {
pub:
	lhs Expr
	rhs Expr
}

pub struct StringLiteral {
pub:
	value string
}

pub struct StructInit {
pub:
	fields []FieldInit
	typ    types.Type
}

// Statements
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
pub:
	stmts []Stmt
}

pub struct ComptimeIf {

}

pub struct ConstDecl {
pub:
	is_public bool
	fields    []FieldInit
}

pub struct EnumDecl {
pub:
	is_public bool
	name      string
	fields    []FieldDecl
}

pub struct ExprStmt {
pub:
	expr Expr
}

pub struct FlowControl {
pub:
	op token.Token
}

pub struct FnDecl {
pub:
	is_public bool
	name      string
	args      []Arg
	stmts     []Stmt
}

pub struct For {
pub:
	init  Stmt // initialization
	cond  Expr // condition
	post  Stmt // post iteration (afterthought)
	stmts []Stmt
}

pub struct GlobalDecl {
pub:
	name  string
	typ   types.Type
	value Expr
}

pub struct Import {
pub:
	name       string
	alias      string
	is_aliased bool
}

pub struct Module {
pub:
	name string
}

pub struct Return {
pub:
	// TODO: do we use []Expr or Expr and List
	expr Expr
}

pub struct StructDecl {
pub:
	is_public bool
	name      string
	fields    []FieldDecl
}

pub struct TypeDecl {
pub:
	is_public bool
	name      string
	typ       types.Type
}

pub struct Unsafe {
pub:
	stmts []Stmt
}

