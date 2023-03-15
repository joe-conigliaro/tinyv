// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builder

import tinyv.ast
import tinyv.parser
import runtime

// TODO: remove workaround once fixed in compiler
struct SharedIntWorkaround { mut: value int }
struct ParsingSharedState {
mut:
	parsed_modules shared []string
	files_queued   shared SharedIntWorkaround
}

fn (mut pstate ParsingSharedState) mark_module_as_parsed( name string ) {
   lock pstate.parsed_modules {
	   pstate.parsed_modules << name
   }
}

fn (mut pstate ParsingSharedState) already_parsed_module(name string) bool {
   rlock pstate.parsed_modules {
	   if name in pstate.parsed_modules {
		   return true
	   }
   }
   return false
}

fn (mut pstate ParsingSharedState) add_files(ch_in chan string, files []string) {
	for file in files {
		// eprintln('>>>> ${@METHOD} file: $file')
		ch_in <- file
		lock pstate.files_queued {
			pstate.files_queued.value++
		}
	}
}

fn (mut pstate ParsingSharedState) worker(mut b Builder, ch_in chan string, ch_out chan ast.File, skip_imports bool) {
	// eprintln('>> ${@METHOD}')
	mut p := parser.new_parser(b.pref)
	for {
		filename := <- ch_in or { break }
		ast_file := p.parse_file(filename)		
		if !skip_imports {
			for mod in ast_file.imports {
				if pstate.already_parsed_module( mod.name ) {
					continue
				}
				pstate.mark_module_as_parsed(mod.name)
				mod_path := b.get_module_path(mod.name, ast_file.path)
				pstate.add_files(ch_in, get_v_files_from_dir(mod_path))
			}
		}
		// eprintln('>> ${@METHOD} fully parsed file: $filename')
		lock pstate.files_queued {
			pstate.files_queued.value--
		}
		ch_out <- ast_file
	}
}

fn (mut b Builder) parse_files_parallel(files []string) []ast.File {
	mut ch_in := chan string{cap: 1000}
	mut ch_out := chan ast.File{cap: 1000}
	mut pstate := &ParsingSharedState{}
	mut ast_files := []ast.File{}
	mut threads := []thread{}
	
	// spawn workers
	for _ in 0..runtime.nr_jobs() {
		// dump(thread_idx)
		threads << spawn pstate.worker(mut b, ch_in, ch_out, b.pref.skip_imports)
	}
	// parse builtin
	if !b.pref.skip_builtin {
		pstate.add_files(ch_in, get_v_files_from_dir(b.get_vlib_module_path('builtin')))
	}
	// parse user files
	pstate.add_files(ch_in, files)

	// mut output_idx := 0
	for {
		// output_idx++
		rlock pstate.files_queued {
			if pstate.files_queued.value == 0 {
				// eprintln('output reading idx: $output_idx')
				// dump(pstate)
				break
			}
		}
		ast_file := <- ch_out
		ast_files << ast_file
	}
	
	ch_in.close()
	ch_out.close()
	threads.wait()       

	return ast_files
}