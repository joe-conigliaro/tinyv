module util

import tinyv.token
import term

pub enum ErrorKind{
	warning
	notice
	error
}

pub fn (e ErrorKind) str() string {
	return match e {
		.warning { 'warning' }
		.notice  { 'notice' }
		.error   { 'error' }
	}
}

pub fn (e ErrorKind) color(s string) string {
	return match e {
		.warning { term.yellow(s) }
		.notice  { term.blue(s) }
		.error   { term.red(s) }
	}
}

pub fn error(pos token.Position, msg string, details string, kind ErrorKind) {
	eprintln(term.bold(kind.color(kind.str())) + ': ' + msg)
	eprintln(' -> ' + pos.str())
	if details.len > 0 {
		eprintln(details)
	}
}