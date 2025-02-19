package Graphics::ColorNamesCMYK::ToutesLesCouleursCom::Gray;

use strict;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-05-06'; # DATE
our $DIST = 'Graphics-ColorNamesCMYK-ToutesLesCouleursCom'; # DIST
our $VERSION = '0.001'; # VERSION

our $NAMES_CMYK_TABLE = {
  'grey' => 0x0000003e, # 0,0,0,62
  'slate' => 0x100c003a, # 16,12,0,58
  'silver' => 0x00000013, # 0,0,0,19
  'clay' => 0x00000006, # 0,0,0,6
  'bi' => 0x00060f36, # 0,6,15,54
  'bistre' => 0x001e314c, # 0,30,49,76
  'bistre' => 0x00122a30, # 0,18,42,48
  'bitumen' => 0x00163145, # 0,22,49,69
  'celadon' => 0x15000923, # 21,0,9,35
  'chestnut' => 0x000f1e32, # 0,15,30,50
  'oxidized tin' => 0x0000001b, # 0,0,0,27
  'pure tin' => 0x00000007, # 0,0,0,7
  'fumes' => 0x1107000c, # 17,7,0,12
  'grege' => 0x0007131b, # 0,7,19,27
  'steel grey' => 0x0000001f, # 0,0,0,31
  'charcoal grey' => 0x48413d3d, # 72,65,61,61
  'payne grey' => 0x0f070035, # 15,7,0,53
  'gray iron' => 0x00000030, # 0,0,0,48
  'gray iron' => 0x00000032, # 0,0,0,50
  'pearl grey' => 0x00000013, # 0,0,0,19
  'pearl grey' => 0x04000250, # 4,0,2,80
  'gray' => 0x00000026, # 0,0,0,38
  'dove gray' => 0x0008081b, # 0,8,8,27
  'putty' => 0x0001131e, # 0,1,19,30
  'pinchard' => 0x00000014, # 0,0,0,20
  'lead' => 0x06010031, # 6,1,0,49
  'mountbatten pink' => 0x01180028, # 0,280,0,40
  'taupe' => 0x000a1d49, # 0,10,29,73
  'tourdille' => 0x00010818, # 0,1,8,24
};


1;
# ABSTRACT: CMYK colors from http://toutes-les-couleurs.com/ (gray)

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::ColorNamesCMYK::ToutesLesCouleursCom::Gray - CMYK colors from http://toutes-les-couleurs.com/ (gray)

=head1 VERSION

This document describes version 0.001 of Graphics::ColorNamesCMYK::ToutesLesCouleursCom::Gray (from Perl distribution Graphics-ColorNamesCMYK-ToutesLesCouleursCom), released on 2024-05-06.

=head1 DESCRIPTION

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Graphics-ColorNamesCMYK-ToutesLesCouleursCom>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Graphics-ColorNamesCMYK-ToutesLesCouleursCom>.

=head1 SEE ALSO

Other C<Graphics::ColorNamesCMYK::ToutesLesCoulersCom::*> modules.

Other C<Graphics::ColorNamesCMYK::*> modules.

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

This software is copyright (c) 2024 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Graphics-ColorNamesCMYK-ToutesLesCouleursCom>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
