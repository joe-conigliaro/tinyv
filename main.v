module main

import os
import time
import scanner
import ast
import pref
import builder
// import v.scanner as vscanner

const(
	v_dir = '/home/kastro/dev/src/v'
	// v_dir = '/mnt/storage/homes/kastro/dev/v'
	files = [
		'$v_dir/vlib/builtin/int.v',
		'$v_dir/vlib/builtin/string.v',
		'$v_dir/vlib/regex/regex.v',
		'$v_dir/vlib/crypto/aes/block_generic.v'
		'tests/syntax.v'
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

