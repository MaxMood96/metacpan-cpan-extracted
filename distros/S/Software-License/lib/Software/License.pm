use strict;
use warnings;
package Software::License 0.104007;
# ABSTRACT: packages that provide templated software licenses

use Data::Section -setup => { header_re => qr/\A__([^_]+)__\Z/ };
use Text::Template ();

#pod =head1 SYNOPSIS
#pod
#pod   my $license = Software::License::Discordian->new({
#pod     holder => 'Ricardo Signes',
#pod   });
#pod
#pod   print $output_fh $license->fulltext;
#pod
#pod =method new
#pod
#pod   my $license = $subclass->new(\%arg);
#pod
#pod This method returns a new license object for the given license class.  Valid
#pod arguments are:
#pod
#pod =for :list
#pod = holder
#pod the holder of the copyright; required
#pod = year
#pod the year of copyright; defaults to current year
#pod = program
#pod the name of software for use in the middle of a sentence
#pod = Program
#pod the name of software for use in the beginning of a sentence
#pod
#pod C<program> and C<Program> arguments may be specified both, either one or none.
#pod Each argument, if not specified, is defaulted to another one, or to properly
#pod capitalized "this program", if both arguments are omitted.
#pod
#pod =cut

sub new {
  my ($class, $arg) = @_;

  Carp::croak "no copyright holder specified" unless $arg->{holder};

  bless $arg => $class;
}

#pod =method year
#pod
#pod =method holder
#pod
#pod These methods are attribute readers.
#pod
#pod =cut

sub year   { $_[0]->{year} // (localtime)[5]+1900 }
sub holder { $_[0]->{holder}     }

sub _dotless_holder {
  my $holder = $_[0]->holder;
  $holder =~ s/\.$//;
  return $holder;
}

#pod =method program
#pod
#pod Name of software for using in the middle of a sentence.
#pod
#pod The method returns value of C<program> constructor argument (if it evaluates as true, i. e.
#pod defined, non-empty, non-zero), or value of C<Program> constructor argument (if it is true), or
#pod "this program" as the last resort.
#pod
#pod =cut

sub program { $_[0]->{program} || $_[0]->{Program} || 'this program' }

#pod =method Program
#pod
#pod Name of software for using in the middle of a sentence.
#pod
#pod The method returns value of C<Program> constructor argument (if it is true), or value of C<program>
#pod constructor argument (if it is true), or "This program" as the last resort.
#pod
#pod =cut

sub Program { $_[0]->{Program} || $_[0]->{program} || 'This program' }

#pod =method name
#pod
#pod This method returns the name of the license, suitable for shoving in the middle
#pod of a sentence, generally with a leading capitalized "The."
#pod
#pod =method url
#pod
#pod This method returns the URL at which a canonical text of the license can be
#pod found, if one is available.  If possible, this will point at plain text, but it
#pod may point to an HTML resource.
#pod
#pod =method notice
#pod
#pod This method returns a snippet of text, usually a few lines, indicating the
#pod copyright holder and year of copyright, as well as an indication of the license
#pod under which the software is distributed.
#pod
#pod =cut

sub notice { shift->_fill_in('NOTICE') }

#pod =method license
#pod
#pod This method returns the full text of the license.
#pod
#pod =cut

sub license { shift->_fill_in('LICENSE') }

#pod =method fulltext
#pod
#pod This method returns the complete text of the license, preceded by the copyright
#pod notice.
#pod
#pod =cut

sub fulltext {
  my ($self) = @_;
  return join "\n", $self->notice, $self->license;
}

#pod =method version
#pod
#pod This method returns the version of the license.  If the license is not
#pod versioned, this method will return false.
#pod
#pod =cut

sub version  {
  my ($self) = @_;
  my $pkg = ref $self ? ref $self : $self;
  $pkg =~ s/.+:://;
  my (undef, @vparts) = split /_/, $pkg;

  return unless @vparts;
  return join '.', @vparts;
}

#pod =method meta_name
#pod
#pod This method returns the string that should be used for this license in the CPAN
#pod META.yml file, according to the CPAN Meta spec v1, or undef if there is no
#pod known string to use.
#pod
#pod This method may also be invoked as C<meta_yml_name> for legacy reasons.
#pod
#pod =method meta2_name
#pod
#pod This method returns the string that should be used for this license in the CPAN
#pod META.json or META.yml file, according to the CPAN Meta spec v2, or undef if
#pod there is no known string to use.  If this method does not exist, and
#pod C<meta_name> returns open_source, restricted, unrestricted, or unknown, that
#pod value will be used.
#pod
#pod =cut

# sub meta1_name    { return undef; } # sort this out later, should be easy
sub meta_name     { return undef; }
sub meta_yml_name { $_[0]->meta_name }

sub meta2_name {
  my ($self) = @_;
  my $meta1 = $self->meta_name;

  return undef unless defined $meta1;

  return $meta1
    if $meta1 =~ /\A(?:open_source|restricted|unrestricted|unknown)\z/;

  return undef;
}

#pod =method spdx_expression
#pod
#pod This method should return the string with the spdx identifier as indicated by
#pod L<https://spdx.org/licenses/>
#pod
#pod =cut

sub spdx_expression { return undef; }

sub _fill_in {
  my ($self, $which) = @_;

  Carp::confess "couldn't build $which section" unless
    my $template = $self->section_data($which);

  return Text::Template->fill_this_in(
    $$template,
    HASH => { self => \$self },
    DELIMITERS => [ qw({{ }}) ],
  );
}

#pod =head1 LOOKING UP LICENSE CLASSES
#pod
#pod If you have an entry in a F<META.yml> or F<META.json> file, or similar
#pod metadata, and want to look up the Software::License class to use, there are
#pod useful tools in L<Software::LicenseUtils>.
#pod
#pod =head1 TODO
#pod
#pod =for :list
#pod * register licenses with aliases to allow $registry->get('gpl', 2);
#pod
#pod =head1 SEE ALSO
#pod
#pod The specific license:
#pod
#pod =for :list
#pod * L<Software::License::AGPL_3>
#pod * L<Software::License::Apache_1_1>
#pod * L<Software::License::Apache_2_0>
#pod * L<Software::License::Artistic_1_0>
#pod * L<Software::License::Artistic_1_0_Perl>
#pod * L<Software::License::Artistic_2_0>
#pod * L<Software::License::BSD>
#pod * L<Software::License::CC0_1_0>
#pod * L<Software::License::Custom>
#pod * L<Software::License::EUPL_1_1>
#pod * L<Software::License::EUPL_1_2>
#pod * L<Software::License::FreeBSD>
#pod * L<Software::License::GFDL_1_2>
#pod * L<Software::License::GFDL_1_3>
#pod * L<Software::License::GPL_1>
#pod * L<Software::License::GPL_2>
#pod * L<Software::License::GPL_3>
#pod * L<Software::License::LGPL_2_1>
#pod * L<Software::License::LGPL_3_0>
#pod * L<Software::License::MIT>
#pod * L<Software::License::Mozilla_1_0>
#pod * L<Software::License::Mozilla_1_1>
#pod * L<Software::License::Mozilla_2_0>
#pod * L<Software::License::None>
#pod * L<Software::License::OpenSSL>
#pod * L<Software::License::Perl_5>
#pod * L<Software::License::PostgreSQL>
#pod * L<Software::License::QPL_1_0>
#pod * L<Software::License::SSLeay>
#pod * L<Software::License::Sun>
#pod * L<Software::License::Zlib>
#pod
#pod Extra licenses are maintained on CPAN in separate modules.
#pod
#pod The L<App::Software::License> module comes with a script
#pod L<software-license|https://metacpan.org/pod/distribution/App-Software-License/script/software-license>,
#pod which provides a command-line interface
#pod to Software::License.
#pod
#pod =cut

1;

=pod

=encoding UTF-8

=head1 NAME

Software::License - packages that provide templated software licenses

=head1 VERSION

version 0.104007

=head1 SYNOPSIS

  my $license = Software::License::Discordian->new({
    holder => 'Ricardo Signes',
  });

  print $output_fh $license->fulltext;

=head1 PERL VERSION

This module is part of CPAN toolchain, or is treated as such.  As such, it
follows the agreement of the Perl Toolchain Gang to require no newer version
of perl than one released in the last ten years.  This version may change by
agreement of the Toolchain Gang, but for now is governed by the L<Lancaster
Consensus|https://github.com/Perl-Toolchain-Gang/toolchain-site/blob/master/lancaster-consensus.md>
of 2013 and the Lyon Amendment of 2023 (described at the linked-to document).

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to
lower the minimum required perl.

=head1 METHODS

=head2 new

  my $license = $subclass->new(\%arg);

This method returns a new license object for the given license class.  Valid
arguments are:

=over 4

=item holder

the holder of the copyright; required

=item year

the year of copyright; defaults to current year

=item program

the name of software for use in the middle of a sentence

=item Program

the name of software for use in the beginning of a sentence

=back

C<program> and C<Program> arguments may be specified both, either one or none.
Each argument, if not specified, is defaulted to another one, or to properly
capitalized "this program", if both arguments are omitted.

=head2 year

=head2 holder

These methods are attribute readers.

=head2 program

Name of software for using in the middle of a sentence.

The method returns value of C<program> constructor argument (if it evaluates as true, i. e.
defined, non-empty, non-zero), or value of C<Program> constructor argument (if it is true), or
"this program" as the last resort.

=head2 Program

Name of software for using in the middle of a sentence.

The method returns value of C<Program> constructor argument (if it is true), or value of C<program>
constructor argument (if it is true), or "This program" as the last resort.

=head2 name

This method returns the name of the license, suitable for shoving in the middle
of a sentence, generally with a leading capitalized "The."

=head2 url

This method returns the URL at which a canonical text of the license can be
found, if one is available.  If possible, this will point at plain text, but it
may point to an HTML resource.

=head2 notice

This method returns a snippet of text, usually a few lines, indicating the
copyright holder and year of copyright, as well as an indication of the license
under which the software is distributed.

=head2 license

This method returns the full text of the license.

=head2 fulltext

This method returns the complete text of the license, preceded by the copyright
notice.

=head2 version

This method returns the version of the license.  If the license is not
versioned, this method will return false.

=head2 meta_name

This method returns the string that should be used for this license in the CPAN
META.yml file, according to the CPAN Meta spec v1, or undef if there is no
known string to use.

This method may also be invoked as C<meta_yml_name> for legacy reasons.

=head2 meta2_name

This method returns the string that should be used for this license in the CPAN
META.json or META.yml file, according to the CPAN Meta spec v2, or undef if
there is no known string to use.  If this method does not exist, and
C<meta_name> returns open_source, restricted, unrestricted, or unknown, that
value will be used.

=head2 spdx_expression

This method should return the string with the spdx identifier as indicated by
L<https://spdx.org/licenses/>

=head1 LOOKING UP LICENSE CLASSES

If you have an entry in a F<META.yml> or F<META.json> file, or similar
metadata, and want to look up the Software::License class to use, there are
useful tools in L<Software::LicenseUtils>.

=head1 TODO

=over 4

=item *

register licenses with aliases to allow $registry->get('gpl', 2);

=back

=head1 SEE ALSO

The specific license:

=over 4

=item *

L<Software::License::AGPL_3>

=item *

L<Software::License::Apache_1_1>

=item *

L<Software::License::Apache_2_0>

=item *

L<Software::License::Artistic_1_0>

=item *

L<Software::License::Artistic_1_0_Perl>

=item *

L<Software::License::Artistic_2_0>

=item *

L<Software::License::BSD>

=item *

L<Software::License::CC0_1_0>

=item *

L<Software::License::Custom>

=item *

L<Software::License::EUPL_1_1>

=item *

L<Software::License::EUPL_1_2>

=item *

L<Software::License::FreeBSD>

=item *

L<Software::License::GFDL_1_2>

=item *

L<Software::License::GFDL_1_3>

=item *

L<Software::License::GPL_1>

=item *

L<Software::License::GPL_2>

=item *

L<Software::License::GPL_3>

=item *

L<Software::License::LGPL_2_1>

=item *

L<Software::License::LGPL_3_0>

=item *

L<Software::License::MIT>

=item *

L<Software::License::Mozilla_1_0>

=item *

L<Software::License::Mozilla_1_1>

=item *

L<Software::License::Mozilla_2_0>

=item *

L<Software::License::None>

=item *

L<Software::License::OpenSSL>

=item *

L<Software::License::Perl_5>

=item *

L<Software::License::PostgreSQL>

=item *

L<Software::License::QPL_1_0>

=item *

L<Software::License::SSLeay>

=item *

L<Software::License::Sun>

=item *

L<Software::License::Zlib>

=back

Extra licenses are maintained on CPAN in separate modules.

The L<App::Software::License> module comes with a script
L<software-license|https://metacpan.org/pod/distribution/App-Software-License/script/software-license>,
which provides a command-line interface
to Software::License.

=head1 AUTHOR

Ricardo Signes <cpan@semiotic.systems>

=head1 CONTRIBUTORS

=for stopwords Alex Kapranoff Andrew Grangaard Axel Beckert Bernardo Rechea Bernhard Amann bowtie Brian Cassidy Phillips Craig Scrivner Curtis Brandt Dave Rolsky David E. Wheeler Golden Dominique Dumont Dylan William Hardison Flavio Poletti Florian Ragwitz Graham Knop Justin Baker jvolkening Kang-min Liu Karen Etheridge Kenichi Ishigaki Kivanc Yazan Leon Timmermans magnolia Marcel Telka mikegrb Neil Bowers Nicolas Rochelemagne Olivier Mengué Pablo Rodríguez González Petr Písař Ricardo Signes Shlomi Fish srchulo Syohei YOSHIDA Tomasz Konojacki Van de Bugger Wesley Schwengle

=over 4

=item *

Alex Kapranoff <kappa@yandex.ru>

=item *

Andrew Grangaard <granny-github@ofb.net>

=item *

Axel Beckert <abe@deuxchevaux.org>

=item *

Bernardo Rechea <brbpub@gmail.com>

=item *

Bernhard Amann <bernhard@icsi.berkeley.edu>

=item *

bowtie <bowtie@cpan.org>

=item *

Brian Cassidy <bricas@cpan.org>

=item *

Brian Phillips <bphillips@digitalriver.com>

=item *

Craig Scrivner <scrivner@geology.cwu.edu>

=item *

Curtis Brandt <curtis@cpan.org>

=item *

Dave Rolsky <autarch@urth.org>

=item *

David E. Wheeler <david@justatheory.com>

=item *

David Golden <dagolden@cpan.org>

=item *

Dominique Dumont <dod@debian.org>

=item *

Dylan William Hardison <dylan@hardison.net>

=item *

Flavio Poletti <flavio@polettix.it>

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Graham Knop <haarg@haarg.org>

=item *

Justin Baker <me@jbaker.dev>

=item *

jvolkening <jdv@base2bio.com>

=item *

Kang-min Liu <gugod@gugod.org>

=item *

Karen Etheridge <ether@cpan.org>

=item *

Kenichi Ishigaki <ishigaki@cpan.org>

=item *

Kivanc Yazan <kivancyazan@gmail.com>

=item *

Leon Timmermans <fawaka@gmail.com>

=item *

magnolia <magnolia.k@me.com>

=item *

Marcel Telka <marcel@telka.sk>

=item *

mikegrb <mgreb@linode.com>

=item *

Neil Bowers <neil@bowers.com>

=item *

Nicolas Rochelemagne <rochelemagne@cpanel.net>

=item *

Olivier Mengué <dolmen@cpan.org>

=item *

Pablo Rodríguez González <pablo.rodriguez.gonzalez@gmail.com>

=item *

Petr Písař <ppisar@redhat.com>

=item *

Ricardo Signes <rjbs@semiotic.systems>

=item *

Shlomi Fish <shlomif@iglu.org.il>

=item *

srchulo <violapiratejunky@gmail.com>

=item *

Syohei YOSHIDA <syohex@gmail.com>

=item *

Tomasz Konojacki <me@xenu.pl>

=item *

Van de Bugger <van.de.bugger@gmail.com>

=item *

Wesley Schwengle <wesley@schwengle.net>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__
__NOTICE__
This software is Copyright (c) {{$self->year}} by {{$self->_dotless_holder}}.

This is free software, licensed under:

  {{ $self->name }}
