package App::perlmv::scriptlet::add_suffix_imgsize;

use 5.010001;
use strict;
use warnings;

use App::imgsize;
use Filename::Type::Image;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-10-31'; # DATE
our $DIST = 'App-perlmv-scriptlet-add_suffix_imgsize'; # DIST
our $VERSION = '0.001'; # VERSION

our $SCRIPTLET = {
    summary => 'Add suffix (before file extension) of image size (WxH) to filenames',
    args => {
        replace => {
            summary => 'Replace existing image size suffix',
            schema => 'bool*',
        },
    },
    code => sub {
        package
            App::perlmv::code;

        use vars qw($ARGS);

        my $replace = $ARGS && $ARGS->{replace};

        my $file = $_;
        my ($name, $ext);
        if ($file =~ /\A(.+)((?:\.\w+)+)\z/) {
            ($name, $ext) = ($1, $2);
            #say "ext=<$ext>";
        } else {
            warn "File does not have extension, won't guess if it's image, skipped: $file\n";
            return $file;
        }

        #my $existing_suffix;
        if ($name =~ s/(\.\d+x\d+)\z//) {
            unless ($replace) {
                warn "File already has image size suffix, not replacing, skipped: $file\n";
                return $file;
            }
            #$existing_suffix = $1;
        }

        my $res = Filename::Type::Image::check_image_filename(filename => $file);
        unless ($res) {
            warn "Filenames does not look like an image file, skipped: $file\n";
            return $file;
        }

        $res = App::imgsize::imgsize(filenames => [$file]);
        unless ($res->[0] == 200) {
            warn "Can't extract image size from file $file: $res->[0] - $res->[1], skipped\n";
            return $file;
        }
        my $suffix = $res->[2];

        "$name.$suffix$ext";
    },
};

1;

# ABSTRACT: Add suffix (before file extension) of image size (WxH) to filenames

__END__

=pod

=encoding UTF-8

=head1 NAME

App::perlmv::scriptlet::add_suffix_imgsize - Add suffix (before file extension) of image size (WxH) to filenames

=head1 VERSION

This document describes version 0.001 of App::perlmv::scriptlet::add_suffix_imgsize (from Perl distribution App-perlmv-scriptlet-add_suffix_imgsize), released on 2025-10-31.

=head1 SYNOPSIS

With files:

 foo.txt
 bar-new.txt
 baz.txt-new

This command:

 % perlmv add-suffix -a suffix=-new *

will rename the files as follow:

 foo.txt -> foo.txt-new
 bar-new.txt -> bar-new.txt-new
 baz.txt-new baz.txt-new-new

This command:

 % perlmv add-suffix -a suffix=-new- -a before_ext=1 *

will rename the files as follow:

 foo.txt -> foo-new.txt
 bar-new.txt -> bar-new-new.txt
 baz.txt-new baz-new.txt-new

This command:

 % perlmv add-suffix -a suffix=-new- -before_ext=1 -a avoid_duplicate_suffix=1 *

will rename the files as follow:

 foo.txt -> foo-new.txt
 baz.txt-new baz-new.txt-new

=head1 SCRIPTLET ARGUMENTS

Arguments can be passed using the C<-a> (C<--arg>) L<perlmv> option, e.g. C<< -a name=val >>.

=head2 replace

Replace existing image size suffix. 

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-perlmv-scriptlet-add_suffix_imgsize>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-perlmv-scriptlet-add_suffix_imgsize>.

=head1 SEE ALSO

L<App::perlmv::scriptlet::add_prefix>

The C<remove-common-suffix> scriptlet

L<perlmv> (from L<App::perlmv>)

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-perlmv-scriptlet-add_suffix_imgsize>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
