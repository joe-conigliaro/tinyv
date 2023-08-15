module util

import tinyv.token
import term

pub enum ErrorKind {
	warning
	notice
	error
}

pub fn (e ErrorKind) str() string {
	return match e {
		.warning { 'warning' }
		.notice { 'notice' }
		.error { 'error' }
	}
}

pub fn (e ErrorKind) color(s string) string {
	return match e {
		.warning { term.yellow(s) }
		.notice { term.blue(s) }
		.error { term.red(s) }
	}
}

pub fn error(msg string, details string, kind ErrorKind, pos token.Position) {
	eprintln(pos.str() + ' -> ' + term.bold(kind.color(kind.str())) + ': ' + msg)
	if details.len > 0 {
		eprintln(details)
	}
}
