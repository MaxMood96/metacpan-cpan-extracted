# Generated from Makefile.PL using makefilepl2cpanfile

requires 'ExtUtils::MakeMaker', '6.64';   # Minimum version for TEST_REQUIRES
requires 'JSON::MaybeXS';   # Required for encoding data to JSON
requires 'Object::Configure', '0.24';
requires 'Params::Get';
requires 'Scalar::Util';

on 'test' => sub {
	requires 'IPC::System::Simple';
	requires 'Test::DescribeMe';
	requires 'Test::HTML::T5';
	requires 'Test::Most';
	requires 'Test::Needs';
	requires 'Test::Warnings';
};

on 'develop' => sub {
	requires 'Devel::Cover';
	requires 'Perl::Critic';
	requires 'Test::Pod';
	requires 'Test::Pod::Coverage';
};
