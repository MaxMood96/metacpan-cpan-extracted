use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Spec;

use Linux::Event::Stream;

for my $package (qw(
    Linux::Event::Framer::Delimiter
    Linux::Event::Framer::Fixed
    Linux::Event::Framer::LengthPrefix
    Linux::Event::Framer::U32BE
    Linux::Event::Framer::Netstring
    Linux::Event::Framer::Varint
    Linux::Event::Framer::DecimalLength
)) {
    (my $file = "$package.pm") =~ s{::}{/}g;
    require $file;
    ok(!$package->can('new'), "$package has no per-connection object constructor");
}

eval q{
    package T::DeclarationWithoutParent;
    use Linux::Event::Framer 'Fixed', size => 4;
    1;
};
like($@, qr/must inherit from Linux::Event::Stream/,
    'framer declaration requires explicit Stream inheritance first');

eval q{
    package T::LowercaseDeclaration;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'delimiter', "\n";
    sub on_message { }
    1;
};
like($@, qr/cannot declare framer 'delimiter'/,
    'framer name is the exact final package component');

eval q{
    package T::InvalidDeclarationName;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer '../Delimiter', "\n";
    sub on_message { }
    1;
};
like($@, qr/invalid framer name/,
    'unsafe package fragments are rejected before loading');

eval q{
    package T::DuplicateDeclaration;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Fixed', size => 4;
    use Linux::Event::Framer 'Fixed', size => 4;
    sub on_message { }
    1;
};
like($@, qr/already declares a framer/, 'a Stream type declares exactly one framer');

eval q{
    package T::BadFixedDeclaration;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Fixed', size => 0;
    sub on_message { }
    1;
};
like($@, qr/size must be a positive integer/,
    'built-in declaration arguments are validated at class definition time');

my $buffer_module = File::Spec->catfile(
    $Bin, '..', qw(lib Linux Event Stream Framer Buffer.pm),
);
ok(!-e $buffer_module,
    'obsolete custom-framer Buffer module is absent from the distribution');

done_testing;
