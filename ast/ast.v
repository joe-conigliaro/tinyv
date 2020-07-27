module ast

import token

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | Cast | Call | Ident | If | IfGuard | Index
	| Infix | List | Literal | MapInit | Match | Modifier | None | Or
	| Paren | Postfix | Prefix | Range | Selector | SizeOf | StructInit
	| Type | TypeOf | Unsafe
pub type Stmt = Assert | Assign | Attribute | ComptimeIf | ConstDecl
	| Defer | Directive | EnumDecl | ExprStmt | FlowControl | FnDecl | For
	| ForIn | GlobalDecl | Import | InterfaceDecl | Label | Module | Return
	| StructDecl | TypeDecl
pub type Type = ArrayType | MapType | FnType | TupleType

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
	typ    Expr
	is_mut bool
}

pub struct ArrayInit {
pub:
	typ   Expr
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
	typ   Expr
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
	typ    Expr
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
	is_public   bool
	is_method   bool
	receiver    Arg
	name        string
	args        []Arg
	stmts       []Stmt
	return_type Expr
}

pub struct For {
pub:
	init  Stmt // initialization
	cond  Expr // condition
	post  Stmt // post iteration (afterthought)
	stmts []Stmt
}

// TODO: this will just be used at the initializer for For
// possibly split into its own loop stmt later, work out whats best
pub struct ForIn {
pub:
	key   string
	value string
	expr  Expr
}

pub struct GlobalDecl {
pub:
	name  string
	typ   Expr
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
	parent_type Expr
	variants    []Expr
}

// Type Nodes
pub struct ArrayType {
pub:
	elem_type Expr
}

pub struct FnType {
pub:
	args        []Arg
	return_type Expr
}

pub struct MapType {
pub:
	key_type   Expr
	value_type Expr
}

pub struct TupleType {
pub:
	types []Expr
}


// Other

// pub struct Var {
// pub:
// 	name string
// }
