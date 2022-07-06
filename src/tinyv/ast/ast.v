// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ast

import tinyv.token

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | Assoc | Cast | Call | EmptyExpr | Fn | Go | Ident
	| If | IfGuard | Index | Infix | List | Literal | MapInit | Match
	| Modifier | None | Or | Paren | Postfix | Prefix | Range | Selector
	| SizeOf | StructInit | Type | TypeOf | Unsafe
	| ComptimeExpr
	// TODO: decide if this going to be done like this
	| FieldInit
pub type Stmt = Assert | Assign | Block | ConstDecl | Defer | Directive
	| EmptyStmt | EnumDecl | ExprStmt | FlowControl | FnDecl | For | ForIn
	| GlobalDecl | Import | InterfaceDecl | Label | Module | Return
	| StructDecl | TypeDecl
	| ComptimeStmt
// TOOD: Fix nested sumtype like TS
// currently need to cast to type in parser.type. Should I leave like
// this or add these directly to Exor until nesting is implemented?
pub type Type = ArrayType | ArrayFixedType | MapType | FnType | OptionType | ResultType | TupleType

pub struct EmptyExpr {}
pub struct EmptyStmt {}

[inline]
pub fn new_empty_expr() Expr {
	return Expr(EmptyExpr{})
}
[inline]
pub fn new_empty_stmt() Stmt {
	return Stmt(EmptyStmt{})
}

// File (main Ast container)
pub struct File {
pub:
	path    string
	stmts   []Stmt
	imports []Import
}

pub enum Language {
	c
	v
	js
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
	// TODO: don't use EmptyExpr, inits struct each time
	// use bool, or ideally none or option when impl
	init  Expr = EmptyExpr{}
	cap   Expr = EmptyExpr{}
	len   Expr = EmptyExpr{}
}

pub struct Assoc {
pub:
	typ    Expr
	expr   Expr
	fields []FieldInit
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

pub struct ComptimeExpr {
pub:
	expr Expr
}

pub struct FieldDecl {
pub:
	name  	   string
	typ   	   Expr
	value	   Expr = EmptyExpr{}
	attributes []Attribute
}

pub struct FieldInit {
pub:
	name  string
	value Expr
}

// anon fn
pub struct Fn {
pub:
	args        []Arg
	stmts       []Stmt
	return_type Expr
}

pub struct Go {
pub:
	expr Expr
}

pub struct Ident {
pub:
	// kind   IdentKind
	name   string
	// is_mut bool
// pub mut:
// 	obj    Object
}

// pub enum IdentKind {
// 	unresolved
// 	constant
// 	function
// 	global
// 	mod
// 	variable
// }

pub struct If {
pub:
	branches    []Branch
	is_comptime bool
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
	lhs  	 Expr
	expr 	 Expr
	is_gated bool
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
	lhs        Expr
	key_type   Expr = EmptyExpr{}
	value_type Expr = EmptyExpr{}
	keys 	   []Expr
	vals 	   []Expr
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
	op    token.Token // `..` exclusive | `...` inclusive
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

// TODO: look at part 1 & 2 in parser
// consider removing this completely
pub struct AttributeDecl {
pub:
	attributes []Attribute
}

pub struct Attribute {
pub:
	name              string
	value             string
	comptime_cond     Expr
	comptime_cond_opt bool
}

pub struct Block {
pub:
	stmts []Stmt
}

pub struct ComptimeStmt {
pub:
	stmt Stmt
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
	attributes []Attribute
	is_public  bool
	name       string
	fields     []FieldDecl
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
	attributes  []Attribute
	is_public   bool
	is_method   bool
	receiver    Arg
	name        string
	args        []Arg
	stmts       []Stmt
	return_type Expr
	language    Language
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
	key   		 string
	value 		 string
	value_is_mut bool
	expr  		 Expr
}

pub struct GlobalDecl {
pub:
	attributes []Attribute
	fields     []FieldDecl
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
	attributes []Attribute
	is_public  bool
	embedded   []Expr
	name       string
	fields     []FieldDecl
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

pub struct ArrayFixedType {
pub:
	len       Expr
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

pub struct OptionType {
pub:
	base_type Expr = EmptyExpr{}
}

pub struct ResultType {
pub:
	base_type Expr = EmptyExpr{}
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
