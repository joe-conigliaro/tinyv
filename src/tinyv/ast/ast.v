// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
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
pub type Expr = ArrayInitExpr | AssocExpr | BasicLiteral | CallExpr
	| CallOrCastExpr | CastExpr | ComptimeExpr | EmptyExpr | FnLiteral
	| GenericArgs | GenericArgsOrIndexExpr | GoExpr | Ident | IfExpr
	| IfGuardExpr | IndexExpr | InfixExpr | KeywordOperator | LockExpr
	| MapInitExpr | MatchExpr | Modifier | OrExpr | ParenExpr | PostfixExpr
	| PrefixExpr | RangeExpr | SelectorExpr | StructInitExpr | Tuple | Type
	| UnsafeExpr
	// TODO: decide if this going to be done like this
	| FieldInit
pub type Stmt = AssertStmt | AssignStmt | Block | ConstDecl | DeferStmt
	| Directive | EmptyStmt | EnumDecl | ExprStmt | FlowControlStmt
	| FnDecl | ForStmt | ForIn | GlobalDecl | ImportStmt | InterfaceDecl
	| LabelStmt | ModuleStmt | ReturnStmt | StructDecl | TypeDecl
// TOOD: (re)implement nested sumtype like TS (was removed from v)
// currently need to cast to type in parser.type. Should I leave like
// this or add these directly to Expr until nesting is implemented?
pub type Type = ArrayType | ArrayFixedType | FnType | MapType
	| NilType | NoneType | OptionType | ResultType | TupleType

// File (AST container)
pub struct File {
pub:
	path       string
	// attributes []Attribute
	stmts      []Stmt
	imports    []ImportStmt
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

pub struct ArrayInitExpr {
pub:
	typ   Expr = empty_expr
	exprs []Expr
	init  Expr = empty_expr
	cap   Expr = empty_expr
	len   Expr = empty_expr
}

pub struct AssocExpr {
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

pub struct CallExpr {
pub:
	lhs  Expr
	args []Expr
}

pub struct CallOrCastExpr {
pub:
	lhs  Expr
	expr Expr
}

pub struct CastExpr {
pub:
	typ  Expr
	expr Expr
}

pub struct ComptimeExpr {
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

// anon fn / closure
pub struct FnLiteral {
pub:
	typ           FnType
	captured_vars []Expr
	stmts         []Stmt
}

pub struct GenericArgs {
pub:
	lhs  Expr
	args []Expr // concrete types
}

pub struct GenericArgsOrIndexExpr {
pub:
	lhs   Expr
	exprs []Expr
}

pub struct GoExpr {
pub:
	expr Expr
}

pub struct Ident {
pub:
	name   string
}

pub struct IfExpr {
pub:
	branches    []Branch
	is_comptime bool
}

pub struct IfGuardExpr {
pub:
	stmt Stmt
}

pub struct InfixExpr {
pub:
	op  token.Token
	lhs Expr
	rhs Expr
}

pub struct IndexExpr {
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

pub struct BasicLiteral {
pub:
	kind  token.Token
	value string
}

pub struct LockExpr {
pub:
	kind  token.Token
	exprs []Expr
	stmts []Stmt
}

pub struct MapInitExpr {
pub:
	typ  Expr = empty_expr
	keys []Expr
	vals []Expr
}

pub struct MatchExpr {
pub:
	expr     Expr
	branches []Branch
}

pub struct Modifier {
pub:
	kind token.Token
	expr Expr
}

pub struct OrExpr {
pub:
	expr  Expr
	stmts []Stmt
}

pub struct ParenExpr {
pub:
	expr Expr
}

pub struct PostfixExpr {
pub:
	op   token.Token
	expr Expr
}

pub struct PrefixExpr {
pub:
	op   token.Token
	expr Expr
}

pub struct RangeExpr {
pub:
	op    token.Token // `..` exclusive | `...` inclusive
	start Expr
	end   Expr
}

pub struct SelectorExpr {
pub:
	lhs Expr
	rhs Expr
}

pub struct StructInitExpr {
pub:
	typ    		   Expr
	fields        []FieldInit
}

pub struct UnsafeExpr {
pub:
	stmts []Stmt
}

// Statements
pub struct AssertStmt {
pub:
	expr Expr
}

pub struct AssignStmt {
pub:
	op  token.Token
	lhs []Expr
	rhs []Expr
}

// TODO: look at part 1 & 2 in parser
// consider removing this completely
// NOTE: don't use this instead attach global attrs to File
// pub struct AttributeDecl {
// pub:
// 	attributes []Attribute
// }

pub struct Attribute {
pub:
	name          string
	value         string
	comptime_cond Expr
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

pub struct DeferStmt {
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

pub struct FlowControlStmt {
pub:
	op    token.Token
	label string
}

pub struct FnDecl {
pub:
	attributes []Attribute
	is_public  bool
	is_method  bool
	receiver   Parameter
	language   Language = .v
	name       string
	typ        FnType
	stmts      []Stmt
}

pub struct ForStmt {
pub:
	init  Stmt = empty_stmt // initialization
	cond  Expr = empty_expr // condition
	post  Stmt = empty_stmt // post iteration (afterthought)
	stmts []Stmt
}

// NOTE: used as the initializer for ForStmt
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

pub struct ImportStmt {
pub:
	name       string
	alias      string
	is_aliased bool
}

pub struct InterfaceDecl {
pub:
	is_public bool
	name      string
	fields    []FieldDecl
}

pub struct LabelStmt {
pub:
	name string
	stmt Stmt = empty_stmt
}

pub struct ModuleStmt {
pub:
	name string
}

pub struct ReturnStmt {
pub:
	exprs []Expr
}

pub struct StructDecl {
pub:
	attributes 	   []Attribute
	is_public  	   bool
	embedded   	   []Expr
	language  	   Language = .v
	name       	   string
	generic_params []Expr
	fields         []FieldDecl
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
	generic_params []Expr
	params         []Parameter
	return_type    Expr = empty_expr
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
