module types

// TODO: this MIGHT be moved to anohter module, here for now

pub type Object = Module | Type

pub struct Scope{
	parent  &Scope
mut:
	objects map[string]Object
	start   int
	end     int
}

pub fn new_scope(parent &Scope) &Scope {
	return &Scope{
		parent: parent
	}
}

pub fn (mut s Scope) register(name string, obj Object) {
	s.objects[name] = obj
}
