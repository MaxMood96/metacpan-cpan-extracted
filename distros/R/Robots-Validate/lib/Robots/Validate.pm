package Robots::Validate;

# ABSTRACT: Validate that IP addresses are associated with known robots

use v5.14;

use Moo 1;

use MooX::Const v0.4.0;
use List::Util 1.33 qw/ first none /;
use Net::DNS::Resolver;
use Ref::Util qw/ is_plain_hashref /;
use Types::Standard -types;

# RECOMMEND PREREQ: Type::Tiny::XS
# RECOMMEND PREREQ: Ref::Util::XS

use namespace::autoclean;

our $VERSION = 'v0.2.9';


has resolver => (
    is      => 'lazy',
    isa     => InstanceOf ['Net::DNS::Resolver'],
    builder => 1,
);

sub _build_resolver {
    return Net::DNS::Resolver->new;
}


has robots => (
    is  => 'const',
    isa => ArrayRef [
        Dict [
            name   => Str,
            agent  => Optional [RegexpRef],
            domain => RegexpRef,
        ]
    ],
    lazy    => 1,
    strict  => 0,
    builder => 1,
);

sub _build_robots {
    return [

        {
            name   => 'Amazonbot',
            agent  => qr/Amazonbot\b/,
            domain => qr/\.crawl\.amazonbot\.amazon$/,
        },

        {
            name   => 'Applebot',
            agent  => qr/Applebot\b/,
            domain => qr/\.applebot\.apple\.com$/,
        },

        {
            name   => 'Arquivo.pt',
            agent  => qr/arquivo-web-crawler/,
            domain => qr/\.arquivo\.pt$/,
        },

        {
            name   => 'Baidu',
            agent  => qr/Baiduspider\b/,
            domain => qr/\.crawl\.baidu\.com$/,

        },

        {
            name   => 'Bing',
            agent  => qr/(?:Bingbot|MSNBot|AdIdxBot|BingPreview)\b/i,
            domain => qr/\.search\.msn\.com$/,

        },

        {
            name   => 'CocCoc',
            agent  => qr/coccocbot-web\b/,
            domain => qr/\.coccoc\.com$/,
        },

        {
            name   => 'DataProvider',
            agent  => qr/Dataprovider\.com/,
            domain => qr/\.dataproviderbot\.com$/,
        },

        {
            name   => 'Embedly',
            agent  => qr/Embedly\b/,
            domain => qr/\.embed\.ly$/,
        },

        {
            name   => 'Headline',
            agent  => qr/ev-crawler\b/,
            domain => qr/\.headline\.com$/,
        },

        {
            name   => 'Exabot',
            agent  => qr/Exabot\b/i,
            domain => qr/\.exabot\.com$/,
        },

        {
            name   => 'Google',
            agent  => qr/Google(?:bot?)\b/i,
            domain => qr/\.google(?:bot)?\.com$/,
        },

        {
            name   => 'InfoTiger',
            agent  => qr/InfoTigerBot\b/,
            domain => qr/\.infotiger\.com$/,
        },

        {
            name   => 'IONOS',
            agent  => qr/IonCrawl\b/,
            domain => qr/\.1and1\.org$/,
        },

        {
            name   => 'LinkedIn',
            agent  => qr/LinkedInBot\b/,
            domain => qr/\.linkedin\.com$/,
        },

        {
            name   => 'Mojeek',
            agent  => qr/MojeekBot\b/,
            domain => qr/\.mojeek\.com$/,
        },

        {
            name   => 'Monsido',
            agent  => qr{Monsidobot\b}ao,
            domain => qr{\.monsido\.com$}ao,
        },

        {
            name   => 'PetalBot',
            agent  => qr/PetalBot\b/,
            domain => qr/\.petalsearch\.com$/,
        },

        {
            name   => 'Pinterest',
            agent  => qr/Pinterest\b/,
            domain => qr/\.pinterest\.com$/,
        },

        {
            name   => 'Qwant',
            agent  => qr/Qwantify\b/,
            domain => qr/\.qwant\.com$/,
        },

        {
            name   => 'SeznamBot',
            agent  => qr/Seznam\b/,
            domain => qr/\.seznam\.cz$/,
        },

        {
            name   => 'Sogou',
            agent  => qr/Sogou\b/,
            domain => qr/\.sogou\.com$/,
        },

        {
            name   => 'Yahoo',
            agent  => qr/Slurp/,
            domain => qr/\.crawl\.yahoo\.net$/,

        },

        {
            name   => "Yandex",
            agent  => qr/Yandex/,
            domain => qr/\.yandex\.(?:com|ru|net)$/,
        },

        {
            name   => 'Yeti',
            agent  => qr/naver\.me\b/,
            domain => qr/\.naver\.com$/,
        },

    ];
}


has die_on_error => (
    is      => 'lazy',
    isa     => Bool,
    default => 0,
);


sub validate {
    my ( $self, $ip, $args ) = @_;

    if (is_plain_hashref($ip) && !$args) {
        $args = { agent => $ip->{HTTP_USER_AGENT} };
        $ip   = $ip->{REMOTE_ADDR};
    }

    my $res = $self->resolver;

    # Reverse DNS

    my $hostname;

    if ( my $reply = $res->query($ip, 'PTR') ) {
        ($hostname) = map { $_->ptrdname } $reply->answer;
    }
    else {
        die $res->errorstring if $self->die_on_error;
    }

    return unless $hostname;

    $args //= {};

    my $agent = $args->{agent};
    my @matches =
      grep { !$agent || $agent =~ $_->{agent} } @{ $self->robots };

    my $reply = $res->search( $hostname, "A" )
      or $self->die_on_error && die $res->errorstring;

    return unless $reply;

    if (
        none { $_ eq $ip } (
            map  { $_->address }
            grep { $_->can('address') } $reply->answer
        )
      )
    {
        return;
    }

    if ( my $match = first { $hostname =~ $_->{domain} } @matches ) {

        return {
            %$match,
            hostname   => $hostname,
            ip_address => $ip,
        };

    }

    return;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Robots::Validate - Validate that IP addresses are associated with known robots

=head1 VERSION

version v0.2.9

=head1 SYNOPSIS

  use Robots::Validate;

  my $rv = Robots::Validate->new;

  ...

  if ( $rs->validate( $ip, \%opts ) ) { ...  }

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 C<resolver>

This is the L<Net::DNS::Resolver> used for DNS lookups.

=head2 C<robots>

This is an array reference of rules with information about
robots. Each item is a hash reference with the following keys:

=over

=item C<name>

The name of the robot.

=item C<agent>

A regular expression for matching against user agent names.

=item C<domain>

A regular expression for matching against the hostname.

=back

=head2 C<die_on_error>

When true, L</validate> will die on a L</resolver> failure.

By default it is false.

=head1 METHODS

=head2 C<validate>

  my $result = $rv->validate( $ip, \%opts );

This method attempts to validate that an IP address belongs to a known
robot by first looking up the hostname that corresponds to the IP address,
and then validating that the hostname resolves to that IP address.

If this succeeds, it then checks if the hostname is associated with a
known web robot.

If that succeeds, it returns a copy of the matched rule from L</robots>.

You can specify the following C<%opts>:

=over

=item C<agent>

This is the user-agent string. If it does not match, then the DNS lookups
will not be performed.

It is optional.

=back

Alternatively, you can pass in a Plack environment:

  my $result = $rv->validate($env);

=head1 KNOWN ISSUES

=head2 Undocumented Rules

Many of these rules are not documented, but have been guessed from web
traffic.

=head2 Limitations

The current module can only be used for systems that consistently
support reverse DNS lookups. This means that it cannot be used to
validate some robots from
L<Facebook|https://developers.facebook.com/docs/sharing/webmasters/crawler>
or Twitter.

=head1 SUPPORT FOR OLDER PERL VERSIONS

This module requires Perl v5.14 or later.

Future releases may only support Perl versions released in the last ten years.

=head1 SEE ALSO

=over

=item L<Verifying Bingbot|https://www.bing.com/webmaster/help/how-to-verify-bingbot-3905dc26>

=item L<Verifying Googlebot|https://support.google.com/webmasters/answer/80553>

=item L<How to check that a robot belongs to Yandex|https://yandex.com/support/webmaster/robot-workings/check-yandex-robots.html>

=back

=head1 SOURCE

The development version is on github at L<https://github.com/robrwo/Robots-Validate>
and may be cloned from L<git://github.com/robrwo/Robots-Validate.git>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/robrwo/Robots-Validate/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Robert Rothenberg <rrwo@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018-2024 by Robert Rothenberg.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
