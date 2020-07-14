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
	mut imports := []string
	mut parsed_imports := []string
	
	mut ast_files := []ast.File{}
	mut p := parser.new_parser(b.pref)
	for file in files {
		pt0 := time.ticks()
		ast_file := p.parse(file)
		for mod in ast_file.imports {
			if mod.name in imports {
				continue
			}
			imports << mod.name
		}
		ast_files << ast_file
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('scan & parse time for $file: ${parse_time}ms')
	}

	// parse imports
	for mod in imports {
		if mod in parsed_imports {
			continue
		}
		mod_path := get_module_path(mod)
		println('parsing import: $mod ($mod_path)')
		mod_files := os.ls(mod_path)  or {
			panic('error getting ls from $mod_path')
		}
		// println(mod_files)
		for file in mod_files {
			if !file.ends_with('.v') || file.ends_with('.js.v') || file.ends_with('_test.v') {
				continue
			}
			file_path := '$mod_path/${file}'
			println('parsing file $file_path for import $mod')
			ast_file := p.parse(file_path)
			for imp in ast_file.imports {
				if imp.name in imports {
					continue
				}
				imports << imp.name
			}
		}
		parsed_imports << mod
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

// fn qualify_module(mod string) string {
	
// }

fn get_module_path(mod string) string {
	return '/home/kastro/dev/src/v/vlib/' + mod.replace('.', '/')
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
