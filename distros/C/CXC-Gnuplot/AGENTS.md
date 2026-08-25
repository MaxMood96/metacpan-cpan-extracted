# Overview

* This is a Perl project
* It is under Mercurial version control
* It use the perlclass object framework
* It is managed via Dist::Zilla
* All commands must be invoked with the plx command
* tests are run with prove
* Tests are written using the Test2::V0 suite
* Tests may emit a spurious `cannot handle ref type 16...` message; ignore it unless there is another concrete failure
* run tidyall on any changed Perl files.  it must be run from the project root.
* use the specific predicate from `Ref::Util` in conditionals when checking the type of reference rather than using Perl's `ref()` directly; 
* In class methods, use `__PACKAGE__` instead of `__CLASS__`. This avoids the segv issue.
* V1 constructor input normalization is implemented with Object::Pad `BUILDARGS`; `CXC::Gnuplot::V1::Base` handles hashrefs and ordinary key/value lists, specialized classes handle shorthand forms, and `pvalidate` passes values directly to `new`
* document V1 constructor shorthand under `=constructor new`, with examples returning an object from `new`; `BUILDARGS` is an implementation detail and should not appear in the public POD
* V1 classes that override `BUILDARGS` should handle their specialized input first, then fall through to `$class->SUPER::BUILDARGS( @args )` when the specialization does not apply
* every V1 `=for Pod::Coverage` stanza should include `BUILDARGS` and `clone`
