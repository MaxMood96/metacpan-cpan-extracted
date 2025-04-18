package Template::Preprocessor::TTML::Base;
$Template::Preprocessor::TTML::Base::VERSION = '0.0105';
use strict;
use warnings;


use base 'Class::Accessor';

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->initialize(@_);
    return $self;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Template::Preprocessor::TTML::Base - Base class for Template::Preprocessor::TTML classes

=head2 Template::Preprocessor::TTML::Base->new(@args)

What this does is create an object that inherits from Class::Accessor, and
also has a default constructor that is initialized using the initialize()
function.

=head1 VERSION

version 0.0105

=head1 VERSION

version 0.0105

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/> .

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Shlomi Fish, all rights reserved.

This program is released under the following license: MIT X11

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/Template-Preprocessor-TTML>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Template-Preprocessor-TTML>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/Template-Preprocessor-TTML>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/T/Template-Preprocessor-TTML>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Template-Preprocessor-TTML>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Template::Preprocessor::TTML>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-template-preprocessor-ttml at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=Template-Preprocessor-TTML>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/thewml/latemp>

  git clone http://bitbucket.org/shlomif/latemp

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Template-Preprocessor-TTML> or
by email to
L<bug-template-preprocessor-ttml@rt.cpan.org|mailto:bug-template-preprocessor-ttml@rt.cpan.org>.

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/Template-Preprocessor-TTML>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Template-Preprocessor-TTML>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/Template-Preprocessor-TTML>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/T/Template-Preprocessor-TTML>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Template-Preprocessor-TTML>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Template::Preprocessor::TTML>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-template-preprocessor-ttml at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=Template-Preprocessor-TTML>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/thewml/latemp>

  git clone http://bitbucket.org/shlomif/latemp

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Template-Preprocessor-TTML> or
by email to
L<bug-template-preprocessor-ttml@rt.cpan.org|mailto:bug-template-preprocessor-ttml@rt.cpan.org>.

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
