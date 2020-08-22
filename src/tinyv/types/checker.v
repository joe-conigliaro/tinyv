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
