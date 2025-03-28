package Test::Data::Split::Backend::ValidateHash;
$Test::Data::Split::Backend::ValidateHash::VERSION = '0.2.2';
use strict;
use warnings;

use Carp qw/confess/;

use parent 'Test::Data::Split::Backend::Hash';

sub populate
{
    my ( $self, $array_ref ) = @_;

    my @l = @$array_ref;

    my $tests = $self->get_hash;

    if ( @l & 0x1 )
    {
        confess("Input length is not even.");
    }
    while (@l)
    {
        my $key = shift @l;
        my $val = shift @l;
        if ( exists( $tests->{$key} ) )
        {
            confess("Duplicate key '$key'!");
        }
        $tests->{$key} =
            $self->validate_and_transform( { id => $key, data => $val, } );
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Data::Split::Backend::ValidateHash - hash backend with input validation
and transformation.

=head1 VERSION

version 0.2.2

=head1 SYNOPSIS

See the tests.

=head1 DESCRIPTION

This inherits from L<Test::Data::Split::Backend::Hash> .

=head1 METHODS

=head2 $pkg->populate([$id1,$data1,$id2,$data2,$id3,$data3...]);

Populate the hash with the IDs and data passed as an even lengthed
array reference. The IDs must be unique and the
L<validate_and_transform> method must be implemented.

The accepts an C<< {id => $id, data => $data} >> hash reference and either
throws an exception or returns the transformed/mutated data (which can be the
same as the original.

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/Test-Data-Split>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Test-Data-Split>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/Test-Data-Split>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/T/Test-Data-Split>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Test-Data-Split>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Test::Data::Split>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-test-data-split at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=Test-Data-Split>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/perl-Test-Data-Split>

  git clone git://github.com/shlomif/perl-Test-Data-Split.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/perl-Test-Data-Split/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
