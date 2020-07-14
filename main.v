module main

import os
import time
import scanner
import ast
import pref
import builder
// import v.scanner as vscanner

const(
	v_path = '/home/kastro/dev/src/v'
	// v_path = '/mnt/storage/homes/kastro/dev/v'
	files = [
		// '$v_path/vlib/builtin/int.v',
		// '$v_path/vlib/builtin/string.v',
		// '$v_path/vlib/regex/regex.v',
		// '$v_path/vlib/crypto/aes/block_generic.v'
		// 'tests/syntax.v'
		'$v_path/cmd/v/v.v'
	]
	pref = &pref.Preferences{
		debug: false
		// debug: true
		verbose: false
		// verbose: true
	}
)

fn main() {
	b := builder.new_builder(pref)
	b.build(files)
}

