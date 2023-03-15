// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module types

import tinyv.ast

struct Checker {

}

pub fn new_checker() &Checker {
	return &Checker{

	}
}

pub fn (c &Checker) check_files(files []ast.File) {
	for file in files {
		_ = file
	}
}

pub fn (c &Checker) ident(ident ast.Ident) {
	
}
