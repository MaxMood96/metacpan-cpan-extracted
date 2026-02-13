package WWW::Bund::Cache;
our $VERSION = '0.001';
# ABSTRACT: GET response caching on disk

use Moo;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8 decode_utf8);
use File::Path qw(make_path);
use File::Spec;
use Carp qw(croak);
use namespace::clean;


has cache_dir => (
    is       => 'ro',
    required => 1,
);


has ttl => (
    is      => 'ro',
    default => 3600,
);


sub _ensure_dir {
    my ($self) = @_;
    my $dir = File::Spec->catdir($self->cache_dir, 'responses');
    make_path($dir) unless -d $dir;
    return $dir;
}

sub _cache_path {
    my ($self, $key) = @_;
    my $dir = $self->_ensure_dir;
    my $hash = md5_hex($key);
    return File::Spec->catfile($dir, $hash . '.cache');
}

sub get {
    my ($self, $key, $ttl) = @_;
    $ttl //= $self->ttl;
    my $path = $self->_cache_path($key);

    return undef unless -f $path;

    my $age = time() - (stat($path))[9];
    if ($age > $ttl) {
        unlink $path;
        return undef;
    }

    open my $fh, '<:raw', $path or return undef;
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}


sub set {
    my ($self, $key, $content) = @_;
    my $path = $self->_cache_path($key);

    my $bytes = utf8::is_utf8($content) ? encode_utf8($content) : $content;
    open my $fh, '>:raw', $path or croak "Cannot write cache file $path: $!";
    print $fh $bytes;
    close $fh;

    return 1;
}


sub clear {
    my ($self) = @_;
    my $dir = File::Spec->catdir($self->cache_dir, 'responses');
    return unless -d $dir;
    opendir my $dh, $dir or return;
    while (my $file = readdir $dh) {
        next unless $file =~ /\.cache$/;
        unlink File::Spec->catfile($dir, $file);
    }
    closedir $dh;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Cache - GET response caching on disk

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund::Cache;

    my $cache = WWW::Bund::Cache->new(
        cache_dir => '/path/to/cache',
        ttl       => 3600,  # default TTL in seconds
    );

    # Store response
    $cache->set($cache_key, $content);

    # Retrieve cached response
    my $content = $cache->get($cache_key);
    my $content = $cache->get($cache_key, 300);  # override TTL

    # Clear all cache
    $cache->clear;

=head1 DESCRIPTION

Disk-based cache for HTTP GET responses. Cache files are stored under
C<cache_dir/responses/> with MD5-hashed filenames. Each cached item has
a TTL (time-to-live) and is automatically invalidated when expired.

UTF-8 content is properly encoded as bytes before writing to disk.

=head2 cache_dir

Base directory for cache storage. Required.

Cache files are written to C<cache_dir/responses/>.

=head2 ttl

Default time-to-live in seconds for cached items. Defaults to C<3600> (1 hour).

Can be overridden per-call in C<get>.

=head2 get

    my $content = $cache->get($key);
    my $content = $cache->get($key, $ttl_override);

Retrieve cached content by key. Returns C<undef> if not cached or expired.

The optional C<$ttl_override> parameter overrides the default TTL for this lookup.

=head2 set

    $cache->set($key, $content);

Store content in cache. If C<$content> is a UTF-8 character string, it is
automatically encoded to bytes before writing.

=head2 clear

    $cache->clear;

Delete all cached files from C<cache_dir/responses/>.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
