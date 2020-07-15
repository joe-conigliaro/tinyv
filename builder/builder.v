module builder

import os
import ast
import gen.v as gen_v
import parser
import pref
import time

struct Builder {
	pref &pref.Preferences
}

pub fn new_builder(pref &pref.Preferences) &Builder {
	return &Builder{
		pref: pref
	}
}

pub fn (mut b Builder) build(files []string) {
	total0 := time.ticks()
	ast_files := b.parse_files(files)
	b.gen_v_files(ast_files)
	total1 := time.ticks()
	total_time := total1 - total0
	println('total time: ${total_time}ms')
}

fn (mut b Builder) parse_files(files []string) []ast.File {
	mut ast_files := []ast.File{}
	mut p := parser.new_parser(b.pref)
	// parse builtin
	builtin_files := get_v_files_from_dir(get_module_path('builtin'))
	for file in builtin_files {
		pt0 := time.ticks()
		ast_files << p.parse(file)
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('scan & parse time for $file: ${parse_time}ms')
	}
	// parse user files
	for file in files {
		pt0 := time.ticks()
		ast_files << p.parse(file)
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('scan & parse time for $file: ${parse_time}ms')
	}
	// parse imports
	mut imports := []string
	mut parsed_imports := []string
	for afi := 0; afi < ast_files.len ; afi++ {
		ast_file := ast_files[afi]
		for mod in ast_file.imports {
			if mod.name in parsed_imports {
				continue
			}
			relative_dir := os.base_dir(ast_file.path) + os.path_separator + mod.name
			mod_path := if os.is_dir(relative_dir) {
				relative_dir
			}
			else {
				get_module_path(mod.name)
			}
			for file in get_v_files_from_dir(mod_path) {
				pt0 := time.ticks()
				ast_files << p.parse(file)
				pt1 := time.ticks()
				parse_time := pt1 - pt0
				println('scan & parse time for $file: ${parse_time}ms')
			}
			parsed_imports << mod.name
		}
	}

	return ast_files
}

fn (mut b Builder) gen_v_files(ast_files []ast.File) {
	mut gen := gen_v.new_gen(b.pref)
	for file in ast_files {
		gt0 := time.ticks()
		gen.gen(file)
		gt1 := time.ticks()
		gen_time := gt1-gt0
		println('gen (v) for $file.path: ${gen_time}ms')
		if b.pref.debug {
			gen.print_output()
		}
	}
}

fn get_module_path(mod string) string {
	// return '/mnt/storage/homes/kastro/dev/v/vlib/' + mod.replace('.', '/')
	return '/home/kastro/dev/src/v/vlib/' + mod.replace('.', '/')
}

fn get_v_files_from_dir(dir string) []string {
	mod_files := os.ls(dir)  or {
		panic('error getting ls from $dir')
	}
	mut v_files := []string
	for file in mod_files {
		if !file.ends_with('.v') || file.ends_with('.js.v') || file.ends_with('_test.v') {
			continue
		}
		v_files << '$dir/${file}'
	}
	return v_files
}

// fn scan_files() {
// 	for file in files {
// 		mut text := os.read_file('$file') or {
// 			panic('error reading $file')
// 		}
// 		s := scanner.new_scanner(pref)
// 		s.set_text(text)
// 		t0 := time.ticks()
// 		for {
// 			kind := s.scan()
// 			// kind, lit, pos := s.scan()
// 			// println('lit: $s.lit - $kind - ' + int(kind).str())
// 			if kind == .eof {
// 				break
// 			}
// 		}
// 		// s.scan_all()
// 		t1 := time.ticks()
// 		scan_time := t1 - t0
// 		println('scan time for $file: ${scan_time}ms')
// 	}
// }
