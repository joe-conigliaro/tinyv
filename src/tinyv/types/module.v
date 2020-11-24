module types

pub struct Module {
	name  string
	path  string
	scope &Scope
}

pub fn new_module(name string, path string, parent &Scope) Module {
	return Module{
		name: name
		path: path
		scope: new_scope(parent)
	}
}
