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

pub type Expr = ArrayInitExpr
	| AssocExpr
	| BasicLiteral
	| CallExpr
	| CallOrCastExpr
	| CastExpr
	| ChannelInitExpr
	| ComptimeExpr
	| EmptyExpr
	| FieldInit
	| FnLiteral
	| GenericArgOrIndexExpr
	| GenericArgs
	| Ident
	| IfExpr
	| IfGuardExpr
	| IndexExpr
	| InfixExpr
	| KeywordOperator
	| LockExpr
	| MapInitExpr
	| MatchExpr
	| Modifier
	| OrExpr
	| ParenExpr
	| PostfixExpr
	| PrefixExpr
	| RangeExpr
	| SelectorExpr
	| StringInterLiteral
	| StringLiteral
	| StructInitExpr
	| Tuple
	| Type
	| UnsafeExpr

// TODO: decide if this going to be done like this (FieldInit)

pub type Stmt = AssertStmt
	| AssignStmt
	| BlockStmt
	| ComptimeStmt
	| ConstDecl
	| DeferStmt
	| Directive
	| EmptyStmt
	| EnumDecl
	| ExprStmt
	| FlowControlStmt
	| FnDecl
	| ForInStmt
	| ForStmt
	| GlobalDecl
	| ImportStmt
	| InterfaceDecl
	| LabelStmt
	| ModuleStmt
	| ReturnStmt
	| StructDecl
	| TypeDecl

// pub type Decl = ConstDecl | EnumDecl | FnDecl | GlobalDecl
// 	| InterfaceDecl | StructDecl | TypeDecl

// TOOD: (re)implement nested sumtype like TS (was removed from v)
// currently need to cast to type in parser.type. Should I leave like
// this or add these directly to Expr until nesting is implemented?
pub type Type = ArrayFixedType
	| ArrayType
	| ChannelType
	| FnType
	| MapType
	| NilType
	| NoneType
	| OptionType
	| ResultType
	| TupleType

// File (AST container)
pub struct File {
pub:
	mod  string
	name string
	// attributes []Attribute
	stmts   []Stmt
	imports []ImportStmt
}

pub enum Language {
	v
	c
	js
}

pub fn (lang Language) str() string {
	return match lang {
		.v { 'V' }
		.c { 'C' }
		.js { 'JS' }
	}
}

// Expressions
pub struct ArrayInitExpr {
pub:
	typ   Expr = ast.empty_expr
	exprs []Expr
	init  Expr = ast.empty_expr
	cap   Expr = ast.empty_expr
	len   Expr = ast.empty_expr
	pos   token.Pos
}

pub struct AssocExpr {
pub:
	typ    Expr
	expr   Expr
	fields []FieldInit
}

pub struct BasicLiteral {
pub:
	kind  token.Token
	value string
}

pub struct CallExpr {
pub:
	lhs  Expr
	args []Expr
	pos  token.Pos
}

pub struct CallOrCastExpr {
pub:
	lhs  Expr
	expr Expr
	pos  token.Pos
}

pub struct CastExpr {
pub:
	typ  Expr
	expr Expr
	pos  token.Pos
}

pub struct ChannelInitExpr {
pub:
	typ Expr
	cap Expr = ast.empty_expr
}

pub struct ComptimeExpr {
pub:
	expr Expr
	pos  token.Pos
}

pub struct FieldDecl {
pub:
	name       string
	typ        Expr = ast.empty_expr // can be empty as used for const (unless we use something else)
	value      Expr = ast.empty_expr
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

pub struct GenericArgOrIndexExpr {
pub:
	lhs  Expr
	expr Expr
}

pub struct Ident {
pub:
	pos  token.Pos
	name string
}

pub struct IfExpr {
pub:
	cond      Expr = ast.empty_expr
	else_expr Expr = ast.empty_expr
	stmts     []Stmt
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
	pos token.Pos
}

pub struct IndexExpr {
pub:
	lhs      Expr
	expr     Expr
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

pub struct LockExpr {
pub:
	kind  token.Token
	exprs []Expr
	stmts []Stmt
}

pub struct MapInitExpr {
pub:
	typ  Expr = ast.empty_expr
	keys []Expr
	vals []Expr
	pos  token.Pos
}

pub struct MatchBranch {
pub:
	cond  []Expr
	stmts []Stmt
	pos   token.Pos
}

pub struct MatchExpr {
pub:
	expr     Expr
	branches []MatchBranch
	pos      token.Pos
}

pub struct Modifier {
pub:
	kind token.Token
	expr Expr
}

// pub fn (expr Modifier) unwrap() Expr {
// 	return expr.expr
// }

pub struct OrExpr {
pub:
	expr  Expr
	stmts []Stmt
	pos   token.Pos
}

pub struct Parameter {
pub:
	name   string
	typ    Expr
	is_mut bool
	pos    token.Pos
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
	pos  token.Pos
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
	rhs Ident
	pos token.Pos
}

// pub fn (expr Expr) str() string {
// 	return 'Expr.str() - $expr.type_name()'
// }

pub fn (se SelectorExpr) name() string {
	return se.lhs.name() + '.' + se.rhs.name
}

pub fn (expr Expr) name() string {
	return match expr {
		SelectorExpr {
			expr.name()
		}
		Ident {
			expr.name
		}
		else {
			expr.str()
		}
	}
}

pub enum StringLiteralKind {
	c
	js
	raw
	v
}

pub fn (s StringLiteralKind) str() string {
	return match s {
		.c { 'c' }
		.js { 'js' }
		.raw { 'r' }
		.v { 'v' }
	}
}

[direct_array_access]
pub fn StringLiteralKind.from_string(s string) !StringLiteralKind {
	match s[0] {
		`c` {
			return .c
		}
		`j` {
			if s[1] == `s` {
				return .js
			}
		}
		`r` {
			return .raw
		}
		else {}
	}
	return error('invalid string prefix `${s}`')
}

// NOTE: I'm using two nodes StringLiteral & StringInterLiteral
// to avoid the extra array allocations when not needed.
pub struct StringLiteral {
pub:
	kind  StringLiteralKind
	value string
}

pub struct StringInterLiteral {
pub:
	kind   StringLiteralKind
	values []string
	inters []StringInter
}

pub struct StringInter {
pub:
	format    StringInterFormat
	width     int
	precision int
	expr      Expr
	// TEMP: prob removed once individual
	// fields are set, precision etc
	format_expr Expr = ast.empty_expr
}

pub enum StringInterFormat {
	unformatted
	binary
	character
	decimal
	exponent
	exponent_short
	float
	hex
	octal
	string
}

pub fn StringInterFormat.from_u8(c u8) !StringInterFormat {
	return match c {
		`b` { .binary }
		`c` { .character }
		`d` { .decimal }
		`e`, `E` { .exponent }
		`g`, `G` { .exponent_short }
		`f`, `F` { .float }
		`x`, `X` { .hex }
		`o` { .octal }
		`s` { .string }
		else { error('unknown formatter `${c.ascii_str()}`') }
	}
}

pub fn (sif StringInterFormat) str() string {
	return match sif {
		.unformatted { '' }
		.binary { 'b' }
		.character { 'c' }
		.decimal { 'd' }
		.exponent { 'e' }
		.exponent_short { 'g' }
		.float { 'f' }
		.hex { 'x' }
		.octal { 'o' }
		.string { 's' }
	}
}

pub struct StructInitExpr {
pub:
	typ    Expr
	fields []FieldInit
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
	pos token.Pos
}

pub fn (attributes []Attribute) has(name string) bool {
	for attribute in attributes {
		if attribute.name == name {
			return true
		}
	}
	return false
}

pub struct Attribute {
pub:
	name          string
	value         Expr
	comptime_cond Expr
}

pub struct BlockStmt {
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

// enum FnArributes {
// 	method
// 	static
// }

pub struct FnDecl {
pub:
	attributes []Attribute
	is_public  bool
	is_method  bool
	is_static  bool
	receiver   Parameter
	language   Language = .v
	name       string
	typ        FnType
	stmts      []Stmt
	pos        token.Pos
}

pub struct ForStmt {
pub:
	init  Stmt = ast.empty_stmt // initialization
	cond  Expr = ast.empty_expr // condition
	post  Stmt = ast.empty_stmt // post iteration (afterthought)
	stmts []Stmt
}

// NOTE: used as the initializer for ForStmt
pub struct ForInStmt {
pub:
	// key   		 string
	// value 		 string
	// value_is_mut bool
	// expr	     Expr
	// TODO:
	key   Expr = ast.empty_expr
	value Expr
	expr  Expr
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
	stmt Stmt = ast.empty_stmt
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
	attributes     []Attribute
	is_public      bool
	embedded       []Expr
	language       Language = .v
	name           string
	generic_params []Expr
	fields         []FieldDecl
	pos            token.Pos
}

pub struct TypeDecl {
pub:
	is_public      bool
	name           string
	generic_params []Expr
	parent_type    Expr = ast.empty_expr
	variants       []Expr
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

pub struct ChannelType {
pub:
	cap       Expr
	elem_type Expr
}

pub struct FnType {
pub:
	generic_params []Expr
	params         []Parameter
	return_type    Expr = ast.empty_expr
}

pub fn (ft &FnType) str() string {
	mut s := 'fn('
	for param in ft.params {
		s += param.name + param.typ.str()
	}
	s += ') ' + ft.return_type.str()
	return s
}

pub fn (ident &Ident) str() string {
	return ident.name.clone()
}

// pub fn (expr Expr) str() string {
// 	return match expr {
// 		Ident {
// 			expr.name
// 		}
// 		SelectorExpr {
// 			expr.lhs.str() + '.' + expr.rhs.name
// 		}
// 		else {
// 			'missing Expr.str() for ${expr.type_name()}'
// 			// expr.str()
// 		}
// 	}
// }

pub struct MapType {
pub:
	key_type   Expr
	value_type Expr
}

pub struct NilType {}

pub struct NoneType {}

pub struct OptionType {
pub:
	base_type Expr = ast.empty_expr
}

pub struct ResultType {
pub:
	base_type Expr = ast.empty_expr
}

pub struct TupleType {
pub:
	types []Expr
}
