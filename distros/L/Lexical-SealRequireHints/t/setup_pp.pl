if("$]" < 5.007002 || ("$]" >= 5.009004 && "$]" < 5.010001)) {
	require Test::More;
	Test::More::plan(skip_all =>
		"pure Perl Lexical::SealRequireHints can't work on this perl");
}

require XSLoader;

my $orig_load = \&XSLoader::load;
# Suppress redefinition warning, without loading warnings.pm, for the
# benefit of before_warnings.t.
BEGIN { ${^WARNING_BITS} = ""; }
*XSLoader::load = sub {
	if(($_[0] || "") eq "Lexical::SealRequireHints") {
		# Load DynaLoader before dying in order to better
		# replicate the module loading status of a failed XS load,
		# in order to make the pure Perl tests more realistic.
		eval { local $SIG{__DIE__}; require DynaLoader; };
		die "XS loading disabled for Lexical::SealRequireHints";
	}
	goto &$orig_load;
};

1;
