module ast

import token
import types

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | Cast | Call | Ident | If | IfGuard | Index
	| Infix | List | Literal | MapInit | Match | Modifier | None | Or
	| Paren | Postfix | Prefix | Range | Selector | SizeOf | StructInit
	| TypeOf | Unsafe
pub type Stmt = Assert | Assign | Attribute | ComptimeIf | ConstDecl
	| Defer | Directive | EnumDecl | ExprStmt | FlowControl | FnDecl | For
	| GlobalDecl | Import | InterfaceDecl | Label | Module | Return
	| StructDecl | TypeDecl

// File (main Ast container)
pub struct File {
pub:
	path    string
	stmts   []Stmt
	imports []Import
}

// Expressions
pub struct Arg {
pub:
	name   string
	// expr   Expr
	typ    types.Type
	is_mut bool
}

pub struct ArrayInit {
pub:
	exprs []Expr
	init  Expr
	cap   Expr
	len   Expr
}

pub struct Branch {
pub:
	cond  []Expr
	stmts []Stmt
}

pub struct Cast {
pub:
	expr Expr
}

pub struct Call {
pub:
	lhs  Expr
	// args []Arg
	args []Expr
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
	stmt Stmt
}

pub struct Infix {
pub:
	op  token.Token
	lhs Expr
	rhs Expr
}

pub struct Index {
pub:
	lhs  Expr
	expr Expr
}

pub struct List {
pub:
	exprs []Expr
}

pub struct Literal {
pub:
	kind  token.Token
	value string
}

pub struct MapInit {
pub:
	keys []Expr
	vals []Expr
}

pub struct Match {
pub:
	expr     Expr
	branches []Branch
}

pub struct Modifier {
pub:
	kind token.Token
	expr Expr
}

pub struct None {

}

pub struct Or {
pub:
	expr  Expr
	stmts []Stmt
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

pub struct SizeOf {
pub:
	expr Expr
}

pub struct StructInit {
pub:
	fields []FieldInit
	typ    types.Type
}

pub struct TypeOf {
pub:
	expr Expr
}

pub struct Unsafe {
pub:
	stmts []Stmt
}

// Statements
pub struct Assert {
pub:
	expr Expr
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

pub struct ComptimeIf {
pub:
	cond       Expr
	stmts      []Stmt
	else_stmts []Stmt
}

pub struct ConstDecl {
pub:
	is_public bool
	fields    []FieldInit
}

pub struct Defer {
pub:
	stmts []Stmt
}

// #flag / #include
pub struct Directive {
pub:
	name  string
	value string
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
	is_method bool
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

pub struct InterfaceDecl {
pub:
	is_public bool
	name      string
	// methods    []
}

pub struct Label {
pub:
	name string
}

pub struct Module {
pub:
	name string
}

pub struct Return {
pub:
	exprs []Expr
}

pub struct StructDecl {
pub:
	is_public bool
	name      string
	fields    []FieldDecl
}

pub struct TypeDecl {
pub:
	is_public   bool
	name        string
	parent_type types.Type
	variants    []types.Type
}


