package PERLANCAR::ShellQuote::Any;

our $DATE = '2016-09-27'; # DATE
our $VERSION = '0.002'; # VERSION

# Be lean.
#use 5.010001;
#use strict 'subs', 'vars';
#use warnings;

sub import {
    my $caller = caller;

    *{"$caller\::shell_quote"} = \&shell_quote;
}

sub shell_quote {
    if ($^O eq 'MSWin32') {
        require Win32::ShellQuote;
        Win32::ShellQuote::quote_system_string(@_);
    } else {
        require String::ShellQuote;
        String::ShellQuote::shell_quote(@_);
    }
}

1;
# ABSTRACT: Escape strings for the shell on Unix or MSWin32

__END__

=pod

=encoding UTF-8

=head1 NAME

PERLANCAR::ShellQuote::Any - Escape strings for the shell on Unix or MSWin32

=head1 VERSION

This document describes version 0.002 of PERLANCAR::ShellQuote::Any (from Perl distribution PERLANCAR-ShellQuote-Any), released on 2016-09-27.

=head1 SYNOPSIS

 use ShellQuote::Any; # exports shell_quote()

 shell_quote('curl', 'http://example.com/?foo=123&bar=baz');
 # curl 'http://example.com/?foo=123&bar=baz'

=head1 DESCRIPTION

B<This distribution is currently For testing only.>

=head1 FUNCTIONS

=head2 shell_quote(@cmd) => str

Quote command C<@cmd> according to OS. On Windows, will use
L<Win32::ShellQuote>'s C<quote_system_string()>. Otherwise, will use
L<String::ShellQuote>'s C<shell_quote()>. Exported by default.

If you want to simulate how quoting is done under another OS, you could do
something like:

 {
     local $^O = "Win32"; # simulate Windows
     say shell_quote("foo bar");
 }

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/PERLANCAR-ShellQuote-Any>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-PERLANCAR-ShellQuote-Any>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=PERLANCAR-ShellQuote-Any>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<Win32::ShellQuote>

L<String::ShellQuote>

L<ShellQuote::Any>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
