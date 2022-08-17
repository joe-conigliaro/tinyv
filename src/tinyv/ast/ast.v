// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ast

import tinyv.token

pub const (
	empty_expr = Expr(EmptyExpr(0))
	empty_stmt = Stmt(EmptyStmt(0))
)

type EmptyExpr = u8
type EmptyStmt = u8

// pub type Decl = ConstDecl | EnumDecl | StructDecl
pub type Expr = ArrayInit | Assoc | Call | CallOrCast | Cast | Comptime
	| EmptyExpr | Fn | Go | Ident | If | IfGuard | Index | Infix | KeywordOperator
	| Literal | Lock | MapInit | Match | Modifier | Or | Paren | Postfix | Prefix
	| Range | Selector | StructInit | Tuple | Type | Unsafe
	// TODO: decide if this going to be done like this
	| FieldInit
pub type Stmt = Assert | Assign | Block | ConstDecl | Defer | Directive
	| EmptyStmt | EnumDecl | ExprStmt | FlowControl | FnDecl | For | ForIn
	| GlobalDecl | Import | InterfaceDecl | Label | Module | Return
	| StructDecl | TypeDecl
// TOOD: (re)implement nested sumtype like TS (was removed from v)
// currently need to cast to type in parser.type. Should I leave like
// this or add these directly to Expr until nesting is implemented?
pub type Type = ArrayType | ArrayFixedType | FnType | MapType
	| NilType | NoneType | OptionType | ResultType | TupleType

// File (main Ast container)
pub struct File {
pub:
	path    string
	stmts   []Stmt
	imports []Import
}

pub enum Language {
	v
	c
	js
}

pub fn(lang Language) str() string {
	return match lang {
		.v { 'V' }
		.c { 'C' }
		.js { 'JS' }
	}
}

// Expressions
pub struct Parameter {
pub:
	name   string
	typ    Expr
	is_mut bool
}

pub struct ArrayInit {
pub:
	typ   Expr = empty_expr
	exprs []Expr
	init  Expr = empty_expr
	cap   Expr = empty_expr
	len   Expr = empty_expr
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

pub struct Call {
pub:
	lhs  		  Expr
	generic_types []Expr
	args 		  []Expr
}

pub struct CallOrCast {
pub:
	lhs  Expr
	expr Expr
}

pub struct Cast {
pub:
	typ  Expr
	expr Expr
}

pub struct Comptime {
pub:
	expr Expr
}

pub struct FieldDecl {
pub:
	name  	   string
	typ   	   Expr
	value	   Expr = empty_expr
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
	generic_types []Expr
	params        []Parameter
	stmts         []Stmt
	return_type   Expr
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

pub struct KeywordOperator {
pub:
	op   token.Token
	expr Expr
}

pub struct Tuple {
pub:
	exprs []Expr
}

pub struct Literal {
pub:
	kind  token.Token
	value string
}

pub struct Lock {
pub:
	kind  token.Token
	exprs []Expr
	stmts []Stmt
}

pub struct MapInit {
pub:
	typ  Expr = empty_expr
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

pub struct StructInit {
pub:
	fields []FieldInit
	typ    Expr
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
	attributes    []Attribute
	is_public     bool
	is_method     bool
	receiver      Parameter
	language      Language = .v
	name          string
	generic_types []Expr
	params        []Parameter
	stmts         []Stmt
	return_type   Expr = empty_expr
}

pub struct For {
pub:
	label string
	init  Stmt = empty_stmt // initialization
	cond  Expr = empty_expr // condition
	post  Stmt = empty_stmt // post iteration (afterthought)
	stmts []Stmt
}

// NOTE: used as the initializer for For
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
	language   Language = .v
	name       string
	fields     []FieldDecl
}

pub struct TypeDecl {
pub:
	is_public   bool
	name        string
	parent_type Expr = empty_expr
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
	generic_types []Expr
	params        []Parameter
	return_type   Expr = empty_expr
}

pub struct MapType {
pub:
	key_type   Expr
	value_type Expr
}

pub struct NilType {}

pub struct NoneType {}

pub struct OptionType {
pub:
	base_type Expr = empty_expr
}

pub struct ResultType {
pub:
	base_type Expr = empty_expr
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
