module util

import tinyv.token
import term

pub enum ErrorKind{
	warning
	notice
	error
}

pub struct ErrorInfo {
	message  string
	details  string
	position token.Position
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

pub fn error(err ErrorInfo, kind ErrorKind) {
	eprintln(term.bold(kind.color(kind.str())) + ': ' + err.message)
	eprintln(' -> ' + err.position.str())
	if err.details.len > 0 {
		eprintln(err.details)
	}
}
