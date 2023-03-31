// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builder

import tinyv.ast
import tinyv.parser

fn (mut b Builder) parse_files(files []string) []ast.File {
	mut parser_reused := parser.new_parser(b.pref)
	mut ast_files := []ast.File{}
	// parse builtin
	if !b.pref.skip_builtin {
		ast_files << parser_reused.parse_files(get_v_files_from_dir(b.pref.get_vlib_module_path('builtin')))
	}
	// parse user files
	ast_files << parser_reused.parse_files(files)
	if b.pref.skip_imports {
		return ast_files
	}
	// parse imports
	mut parsed_imports := []string{}
	for afi := 0; afi < ast_files.len ; afi++ {
		ast_file := ast_files[afi]
		for mod in ast_file.imports {
			if mod.name in parsed_imports {
				continue
			}
			mod_path := b.pref.get_module_path(mod.name, ast_file.path)
			ast_files << parser_reused.parse_files(get_v_files_from_dir(mod_path))
			parsed_imports << mod.name
		}
	}
	return ast_files
}