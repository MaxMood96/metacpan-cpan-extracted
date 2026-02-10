package IO::Divert;

use v5.14;
use warnings;
use utf8;
use Encode ();
use Carp;

our $VERSION = "0.99";

sub new {
    my $class = shift;
    my %opt = (
	BUFFER    => '',
	encoding  => 'utf-8',
	autoprint => 1,
	@_
    );
    my $encoding = $opt{encoding};
    open $opt{FH}, ">:encoding($encoding)", \$opt{BUFFER}
	or croak "open: $!";
    $opt{STDOUT} = select $opt{FH}
	or croak "select: $!";
    bless \%opt, $class;
}

sub fh {
    my $obj = shift;
    $obj->{FH};
}

sub buffer {
    my $obj = shift;
    \$obj->{BUFFER};
}

sub content {
    my $obj = shift;
    $obj->flush;
    $obj->{BUFFER};
}

sub flush {
    my $obj = shift;
    $obj->fh->flush;
    $obj;
}

sub clear {
    my $obj = shift;
    $obj->flush;
    seek $obj->fh, 0, 0;
    $obj->fh->truncate(0);
    $obj->{BUFFER} = '';
    $obj;
}

sub cancel {
    my $obj = shift;
    $obj->{autoprint} = 0;
    delete $obj->{FINAL};
    $obj;
}

sub DESTROY {
    my $obj = shift;
    select $obj->{STDOUT};
    $obj->fh->close;
    if (my $final = $obj->{FINAL}) {
	local $_ = $obj->{BUFFER};
	$final->();
	$obj->{BUFFER} = $_;
    }
    if ($obj->{autoprint}) {
	print Encode::decode($obj->{encoding}, $obj->{BUFFER});
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

IO::Divert - Divert STDOUT to capture and process output

=head1 SYNOPSIS

    use IO::Divert;

    {
        my $divert = IO::Divert->new(
            FINAL => sub { s/^/# /mg }
        );

        complex_output_function();
        # All output is commented, without modifying the function
    }

=head1 VERSION

Version 0.99

=head1 DESCRIPTION

IO::Divert temporarily redirects STDOUT to an internal buffer using
Perl's C<select()> function.  When the object goes out of scope, the
captured output is optionally processed through a callback and printed
to the original STDOUT.

The key benefit is B<transparent output transformation>: you can modify
all output from a block of code without changing any individual C<print>
statements within it.

This is particularly useful when:

=over 4

=item * You need to post-process output from code you don't want to modify

=item * Adding consistent formatting (prefixes, indentation) to complex output

=item * Conditionally suppressing or transforming output based on results

=back

=head1 CONSTRUCTOR

=head2 new

    my $divert = IO::Divert->new(%options);

Creates a new IO::Divert object and begins capturing STDOUT.

Options:

=over 4

=item B<FINAL> => \&coderef

A subroutine to process the captured output before printing.
The captured text is available in C<$_> and should be modified
in place.

    FINAL => sub { s/foo/bar/g }

=item B<encoding> => $encoding

Character encoding for the buffer.  Default is C<utf-8>.

=item B<autoprint> => $bool

If true (default), automatically print the captured output when
the object is destroyed.  Set to false to capture without printing.

=back

=head1 METHODS

=head2 fh

    my $fh = $divert->fh;

Returns the filehandle used for capturing.

=head2 buffer

    my $bufref = $divert->buffer;

Returns a reference to the internal buffer string.

=head2 content

    my $text = $divert->content;

Returns the current captured content as a string.
This method flushes the buffer before returning.

=head2 flush

    $divert->flush;

Flushes the output buffer.  Returns the object for chaining.

=head2 clear

    $divert->clear;

Clears the captured content.  Returns the object for chaining.

=head2 cancel

    $divert->cancel;

Cancels the C<FINAL> callback and autoprint on object destruction.
The captured content remains accessible via C<content>.
Returns the object for chaining.

=head1 EXAMPLES

=head2 Transform output from existing code

    {
        my $divert = IO::Divert->new(
            FINAL => sub { s/^/    /mg }  # indent all lines
        );

        legacy_report_generator();  # prints many lines
        # All output is indented without touching the original code
    }

=head2 Capture without printing

    my $output;
    {
        my $divert = IO::Divert->new(autoprint => 0);
        generate_output();
        $output = $divert->content;
    }
    # Process $output as needed

=head1 PRACTICAL USAGE IN sdif/cdif

This module was originally extracted from L<App::sdif>.

In B<sdif> and B<cdif>, C<git log --graph> output has graph prefix
characters (C<| >, C<* >, etc.) on each line.  To process the diff
content, the prefix is stripped from input lines.  IO::Divert is then
used to recover the prefix by prepending it to every output line.
Since the diff processing code has many scattered C<print> statements,
modifying each one to handle the prefix would be impractical.
IO::Divert recovers the prefix in one place, so the processing code
remains completely unaware of it, and works the same whether graph
output is present or not.

    my $divert;
    if ($prefix) {
        $divert = IO::Divert->new(
            FINAL => sub { s/^/$prefix/mg }
        );
    }

    # diff processing code -- unaware of graph prefix
    process_diff();

    # $divert goes out of scope:
    # prefix is recovered in the output by FINAL callback

=head1 SEE ALSO

L<App::sdif>

L<Capture::Tiny>, L<IO::Capture::Stdout>

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 2026 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
