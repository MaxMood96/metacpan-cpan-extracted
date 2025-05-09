package Yancy::Plugin::File;
our $VERSION = '1.088';
# ABSTRACT: Manage file uploads, attachments, and other assets

#pod =head1 SYNOPSIS
#pod
#pod     # Write a file
#pod     $c->yancy->file->write( $c->param( 'upload' ) );
#pod
#pod =head1 DESCRIPTION
#pod
#pod B<Note:> This module is C<EXPERIMENTAL> and its API may change before
#pod Yancy v2.000 is released.
#pod
#pod This plugin manages file uploads. Files are stored in the C<file_root> by
#pod
#pod This plugin API is meant to be subclassed by other asset storage
#pod mechanisms such as Hadoop or Amazon S3.
#pod
#pod =head2 Cleanup
#pod
#pod Files are B<NOT> immediately deleted after they are no longer needed.
#pod Instead, a L</cleanup> method exists to periodically clean up any files
#pod that are not referenced. You should schedule this to run daily or weekly
#pod in cron:
#pod
#pod     # Clean up files every week
#pod     0 0 * * 0 ./myapp.pl eval 'app->yancy->file->cleanup( app->yancy->backend, app->yancy->schema )'
#pod
#pod =head1 CONFIGURATION
#pod
#pod This plugin has the following configuration options.
#pod
#pod =head2 file_root
#pod
#pod The root path to store files. Defaults to C<public/uploads> in the application's home
#pod directory.
#pod
#pod =head2 url_root
#pod
#pod The URL used to reach the C<file_root>. Defaults to C</uploads>.
#pod
#pod =head2 moniker
#pod
#pod The name to use for the helper. Defaults to C<file> (creating a C<yancy.file> helper).
#pod Change this to add multiple file plugins.
#pod
#pod =head1 SEE ALSO
#pod
#pod L<Yancy>
#pod
#pod =cut

use Mojo::Base 'Mojolicious::Plugin';
use Yancy::Util qw( currym is_type );
use Digest;
use Mojo::Asset::File;
use Mojo::File qw( path );

has file_root =>;
has url_root =>;
has digest_type => 'SHA-1';
has moniker => 'file';

sub register {
    my ( $self, $app, $config ) = @_;
    my $file_root = $config->{file_root} ? path( $config->{file_root} ) : $app->home->child( 'public/uploads' );
    $self->file_root( $file_root );
    my $url_root = $config->{url_root} // '/uploads';
    $self->url_root( $url_root );
    my $moniker = $config->{moniker} // 'file';
    $self->moniker( $moniker );
    $app->helper( 'yancy.' . $moniker, sub { $self } );
}

#pod =method write
#pod
#pod     $url_path = $c->yancy->file->write( $upload );
#pod     $url_path = $c->yancy->file->write( $name, $asset );
#pod
#pod Write a file into storage. C<$upload> is a L<Mojo::Upload> object. C<$name>
#pod is a filename and C<$asset> is a L<Mojo::Asset> object. Returns the URL
#pod of the uploaded file.
#pod
#pod =cut

sub write {
    my ( $self, $name, $asset ) = @_;
    if ( ref $name eq 'Mojo::Upload' ) {
        $asset = $name->asset;
        $name = $name->filename;
    }
    my $digest = $self->_digest_file( $asset );
    my @path_parts = grep $_, split /(..)/, $digest, 3;
    my $root = $self->file_root;
    my $path = $root->child( @path_parts )->make_path;
    my $file_path = $path->child( $name );
    $file_path->spurt( $asset->slurp );
    return join '/', $self->url_root, $file_path->to_rel( $root );
}

#pod =method cleanup
#pod
#pod     $app->yancy->file->cleanup( $app->yancy->backend );
#pod     $app->yancy->file->cleanup( $app->yancy->backend, $app->yancy->schema );
#pod
#pod Clean up any files that do not exist in the given backend. Call this daily
#pod or weekly to remove files that aren't needed anymore.
#pod
#pod =cut

sub cleanup {
    my ( $self, $backend, $schema ) = @_;
    $schema ||= $backend->schema;
    # Clean up any unlinked files by scanning the entire database for
    # files and then leaving only those files.
    my ( %files, %linked );

    # List all the files
    for my $path ( $self->file_root->list_tree->each ) {
        $files{ $path }++;
    }

    # Find all the linked files
    for my $schema_name ( keys %$schema ) {
        my @path_fields;
        for my $property_name ( keys %{ $schema->{$schema_name}{properties} } ) {
            my $prop = $schema->{$schema_name}{properties}{$property_name};
            # ; use Data::Dumper;
            # ; say "Checking prop $property_name: " . Dumper $prop;
            if ( is_type( $prop->{type}, 'string' ) && $prop->{format} && $prop->{format} eq 'filepath' ) {
                push @path_fields, $property_name;
            }
        }

        # ; say "Got path fields: @path_fields";
        next if !@path_fields;

        # Fetch the rows with values in the path, slowly so that we
        # don't try to take up all the memory in the database
        my $per_page = 50;
        my $i = 0;
        my $file_root = $self->file_root;
        my $url_root = $self->url_root;
        my $items = $backend->list( $schema_name, {}, { limit => $per_page } );
        while ( $i < $items->{total} ) {
            for my $item ( @{ $items->{items} } ) {
                for my $field ( @path_fields ) {
                    # Add to linked records
                    my $path = $item->{ $field };
                    $path =~ s{^$url_root}{$file_root};
                    $linked{ $path }++;
                }
            }
            $i += @{ $items->{items} };
            $items = $backend->list( $schema_name, {}, { offset => $i, limit => $per_page } );
        }
    }

    # Any file that does not have a link must be deleted
    delete $files{ $_ } for keys %linked;
    # ; use Data::Dumper;
    # ; say "Linked: " . Dumper [ keys %linked ];
    # ; say "Deleting: " . Dumper [ keys %files ];
    for my $path ( keys %files ) {
        path( $path )->dirname->dirname->dirname->remove_tree;
    }

    return;
}

sub _digest_file {
    my ( $self, $asset ) = @_;
    # Using hex instead of base64 to support case-insensitive file
    # systems
    my $digest = Digest->new( $self->digest_type )->add( $asset->slurp )->hexdigest;
    return $digest;
}

1;

__END__

=pod

=head1 NAME

Yancy::Plugin::File - Manage file uploads, attachments, and other assets

=head1 VERSION

version 1.088

=head1 SYNOPSIS

    # Write a file
    $c->yancy->file->write( $c->param( 'upload' ) );

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

This plugin manages file uploads. Files are stored in the C<file_root> by

This plugin API is meant to be subclassed by other asset storage
mechanisms such as Hadoop or Amazon S3.

=head2 Cleanup

Files are B<NOT> immediately deleted after they are no longer needed.
Instead, a L</cleanup> method exists to periodically clean up any files
that are not referenced. You should schedule this to run daily or weekly
in cron:

    # Clean up files every week
    0 0 * * 0 ./myapp.pl eval 'app->yancy->file->cleanup( app->yancy->backend, app->yancy->schema )'

=head1 METHODS

=head2 write

    $url_path = $c->yancy->file->write( $upload );
    $url_path = $c->yancy->file->write( $name, $asset );

Write a file into storage. C<$upload> is a L<Mojo::Upload> object. C<$name>
is a filename and C<$asset> is a L<Mojo::Asset> object. Returns the URL
of the uploaded file.

=head2 cleanup

    $app->yancy->file->cleanup( $app->yancy->backend );
    $app->yancy->file->cleanup( $app->yancy->backend, $app->yancy->schema );

Clean up any files that do not exist in the given backend. Call this daily
or weekly to remove files that aren't needed anymore.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 file_root

The root path to store files. Defaults to C<public/uploads> in the application's home
directory.

=head2 url_root

The URL used to reach the C<file_root>. Defaults to C</uploads>.

=head2 moniker

The name to use for the helper. Defaults to C<file> (creating a C<yancy.file> helper).
Change this to add multiple file plugins.

=head1 SEE ALSO

L<Yancy>

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
