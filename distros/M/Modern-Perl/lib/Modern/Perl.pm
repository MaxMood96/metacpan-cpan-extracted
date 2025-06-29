package Modern::Perl;
# ABSTRACT: enable all of the features of Modern Perl with one import
$Modern::Perl::VERSION = '1.20250607';
use 5.010_000;

use strict;
use warnings;

use mro     ();
use feature ();

# enable methods on filehandles; unnecessary when 5.14 autoloads them
use IO::File   ();
use IO::Handle ();

my $wanted_date;

sub VERSION {
    my ($self, $version) = @_;

    my $default = 2025;

    return $Modern::Perl::VERSION || $default unless defined $version;
    return $Modern::Perl::VERSION || $default if             $version < 2009;

    $wanted_date = $version if (caller(1))[3] =~ /::BEGIN/;
    return $default;
}

my $unimport_tag;
BEGIN {
    $unimport_tag = $] > 5.015 ? ':all' : ':5.10';
}

sub import {
    my ($class, $date) = @_;
    $date = $wanted_date unless defined $date;

    my $feature_tag    = validate_date( $date );
    undef $wanted_date;

    warnings->import;
    strict->import;
    feature->unimport( $unimport_tag );
    feature->import( $feature_tag );

    if ($feature_tag ge ':5.34') {
        feature->import( 'signatures' );
        warnings->unimport( 'experimental::signatures' );
    }

    if ($feature_tag ge ':5.38') {
        feature->import( 'module_true' );
    }

    mro::set_mro( scalar caller(), 'c3' );
}

sub unimport {
    warnings->unimport;
    strict->unimport;
    feature->unimport;
}

sub validate_date {
    my %dates = (
        2009 => ':5.10',
        2010 => ':5.10',
        2011 => ':5.12',
        2012 => ':5.14',
        2013 => ':5.16',
        2014 => ':5.18',
        2015 => ':5.20',
        2016 => ':5.24',
        2017 => ':5.24',
        2018 => ':5.26',
        2019 => ':5.28',
        2020 => ':5.30',
        2021 => ':5.32',
        2022 => ':5.34',
        2023 => ':5.36',
        2024 => ':5.38',
        2025 => ':5.40',
    );

    my $date = shift;

    # always enable unicode_strings when available
    unless ($date) {
        return ':5.12' if $] > 5.011003;
        return ':5.10';
    }

    my $year = substr $date, 0, 4;
    return $dates{$year} if exists $dates{$year};

    die "Unknown date '$date' requested\n";
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Modern::Perl - enable all of the features of Modern Perl with one import

=head1 VERSION

version 1.20250607

=head1 SYNOPSIS

Modern Perl programs use several modules to enable additional features of Perl
and of the CPAN.  Instead of copying and pasting all of these C<use> lines,
instead write only one:

    use Modern::Perl;

This enables the L<strict> and L<warnings> pragmas, as well as all of the
features available in Perl 5.10. It also enables C3 method resolution order as
documented in C<perldoc mro> and loads L<IO::File> and L<IO::Handle> so that
you may call methods on filehandles. In the future, it may include additional
core modules and pragmas (but is unlikely to include non-core features).

Because so much of this module's behavior uses lexically scoped pragmas, you
may disable these pragmas within an inner scope with:

    no Modern::Perl;

See L<http://www.modernperlbooks.com/mt/2009/01/toward-a-modernperl.html> for
more information, L<http://www.modernperlbooks.com/> for further discussion of
Modern Perl and its implications, and
L<http://onyxneon.com/books/modern_perl/index.html> for a freely-downloadable
Modern Perl tutorial.

=head2 CLI Usage

As of Modern::Perl 2019, you may also enable this pragma from the command line:

    $ perl -Modern::Perl -e 'say "Take that, awk!"'

You may also enable year-specific features:

    $ perl -Modern::Perl=2020 -e 'say "Looking forward to Perl 5.30!"'

=head2 Wrapping Modern::Perl

If you want to wrap Modern::Perl in your own C<import()> method, you can do so
to add additional pragmas or features, such as the use of L<Try::Tiny>. Please
note that, if you do so, you will I<not> automatically enable C3 method
resolution in the calling scope. This is due to how the L<mro> pragma works. In
your custom C<import()> method, you will need to write code such as:

    mro::set_mro( scalar caller(), 'c3' );

=head2 Forward Compatibility

For forward compatibility, I recommend you specify a string containing a
I<year> value as the single optional import tag. For example:

    use Modern::Perl '2009';
    use Modern::Perl '2010';

... both enable 5.10 features, while:

    use Modern::Perl '2011';

... enables 5.12 features:

    use Modern::Perl '2012';

... enables 5.14 features:

    use Modern::Perl '2013';

... enables 5.16 features, and:

    use Modern::Perl '2014';

... enables 5.18 features, and:

    use Modern::Perl '2015';

... enables 5.20 features, and:

    use Modern::Perl '2016';

... enables 5.24 features, and:

    use Modern::Perl '2017';

... enables 5.24 features, and:

    use Modern::Perl '2018';

... enables 5.26 features, and:

    use Modern::Perl '2019';

... enables 5.28 features, and:

    use Modern::Perl '2020';

... enables 5.30 features, and:

    use Modern::Perl '2021';

... enables 5.32 features, and:

    use Modern::Perl '2022';

... enables 5.34 features, and:

    use Modern::Perl '2023';

... enables 5.36 features, and:

    use Modern::Perl '2024';

... enables 5.38 features, and:

    use Modern::Perl '2025';

... enables 5.40 features.

Obviously you cannot use newer features on earlier versions. Perl will throw
the appropriate exception if you try.

As of Perl 5.38, you may prefer to write C<use v5.38>, which is almost entirely
equivalent to the use of this module. For the purpose of forward compatibility,
this module will continue to work as expected--and will continue regular
maintenance.

As of Perl 5.41.4, C<given> is no longer available, so any import tags for
older versions of Perl will not enable this feature, no matter how much you try.

=head1 AUTHOR

chromatic, C<< <chromatic at wgz.org> >>

=head1 BUGS

None known.

Please report any bugs or feature requests to C<bug-modern-perl at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Modern-Perl>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Modern::Perl

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Modern-Perl>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Modern-Perl>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Modern-Perl>

=item * Search CPAN

L<http://search.cpan.org/dist/Modern-Perl/>

=back

=head1 ACKNOWLEDGEMENTS

Damian Conway (inspiration from L<Toolkit>), Florian Ragwitz
(L<B::Hooks::Parser>, so I didn't have to write it myself), chocolateboy (for
suggesting that I don't even need L<B::Hooks::Parser>), Damien Learns Perl,
David Moreno, Evan Carroll, Elliot Shank, Andreas König, Father Chrysostomos,
Gryphon Shafer, Norbert E. Grüner, and Slaven Rezic for reporting bugs, filing
patches, and requesting features.

=head1 AUTHOR

chromatic

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by chromatic@wgz.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
