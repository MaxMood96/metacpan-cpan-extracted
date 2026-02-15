package Progress::Any::SIGHandler;

use 5.010001;
use strict;
use warnings;

use Progress::Any '$progress';
use Progress::Any::Output ();

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-10-30'; # DATE
our $DIST = 'Progress-Any-SIGHandler'; # DIST
our $VERSION = '0.001'; # VERSION

our $Template  = 'Progress: %P/%T (%6.2p%%), %R';
our $Signal    = 'USR1';

sub import {
    my ($package, %args) = @_;

    #if (my $val = delete $args{indicator}) {
    #    $Indicator = $val;
    #}
    if (defined(my $val = delete $args{template})) {
        $Template = $val;
    }

    die "Unknown import argument(s): " . join(", ", sort keys %args)
        if keys %args;

    install_sig_handler();
}

sub install_sig_handler {
    my $filled_message = "";

    Progress::Any::Output->add(
        'Callback',
        callback => sub {
            my ($self, %args) = @_;
            $filled_message = $progress->fill_template($Template);
        },
    );

    $SIG{ $Signal } = sub {
        warn $filled_message, "\n";
    };
}

1;
# ABSTRACT: Output progress to terminal as simple message

__END__

=pod

=encoding UTF-8

=head1 NAME

Progress::Any::SIGHandler - Output progress to terminal as simple message

=head1 VERSION

This document describes version 0.001 of Progress::Any::SIGHandler (from Perl distribution Progress-Any-SIGHandler), released on 2025-10-30.

=head1 SYNOPSIS

Simplest way to use:

 use Progress::Any '$progress';
 use Progress::Any::SIGHandler;

 # do stuffs while updating progress
 $progress->target(10);
 for (1..10) {
     # do stuffs
     $progress->update;
 }
 $progress->finish;

Customize some aspects:

 use Progress::Any::SIGHandler (
     template  => '...',      # default template is: "Progress: %P/%T (%6.2p%%), %R"
     signal    => 'USR2',     # default is USR1
 );

=head1 DESCRIPTION

Importing this module will install a C<%SIG> handler (the default is C<USR1>).
When your process is sent the signal, the handler will print to STDERR the
progress report. You can customize some aspects (see Synopsis). More
customization will be added in the future.

=for Pod::Coverage ^()$

=head1 IMPORT ARGUMENTS

=head2 signal

See L</$Signal>.

=head2 template

See L</$Template>.

=head1 PACKAGE VARIABLES

=head2 $Signal

The Unix signal to use. Set it before call to C<install_sig_handler()>. A
convenient is to pass the `signal` argument during import, which will set this
variable.

=head2 $Template

Template to use (see C<fill_template> in L<Progress::Any> documentation).

=head1 FUNCTIONS

=head2 install_sig_handler

Called automatically by C<import()>, but if you do not import, you can invoke
this explicitly yourself.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Progress-Any-SIGHandler>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Progress-Any-SIGHandler>.

=head1 SEE ALSO

L<Progress::Any>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Progress-Any-SIGHandler>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
