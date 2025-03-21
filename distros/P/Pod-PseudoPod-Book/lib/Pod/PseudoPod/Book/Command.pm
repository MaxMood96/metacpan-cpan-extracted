package Pod::PseudoPod::Book::Command;
# ABSTRACT: base class for all ppbook commands

use strict;
use warnings;

use App::Cmd::Setup -command;
use File::Spec;
use File::Slurp ();

sub config
{
    my ($self, $path) = @_;
    $path           ||= '.';
    my $conf_file     = File::Spec->catfile( $path, 'book.conf' );
    return Config::Tiny->read( $conf_file );
}

sub opt_spec
{
    my ($class, $app) = @_;
    return $class->options( $app );
}

sub options
{
    my ($self, $app) = @_;
    my $conf         = $app->config;

    return
    [
        'author_name=s' => "Author's name",
        { default => $conf->{book}{author_name} },

        'copyright_year=s' => 'Copyright year',
        { default => $conf->{book}{copyright_year} },

        'cover_image=s' => 'Path to cover image',
        { default => $conf->{book}{cover_image} },

        'language=s' => 'Language code for contents',
        { default => $conf->{book}{language} },

        'title=s' => 'Book title',
        { default => $conf->{book}{title} },
    ];
}

sub get_build_prefix
{
    my $self              = shift;
    my $chapter_build_dir = $self->config->{layout}{chapter_build_directory};
    return File::Spec->catdir( 'build', $chapter_build_dir );
}

sub get_built_chapters
{
    my $self           = shift;
    my $conf           = $self->config;
    my $chapter_prefix = $conf->{layout}{chapter_name_prefix};
    my $glob           = $conf->{book}{build_chapters}
                       ? "${chapter_prefix}_*.pod"
                       : '*.pod';

    return glob File::Spec->catfile( $self->get_build_prefix, $glob );
}

sub get_built_html
{
    my ($self, $suffix) = @_;
    my @order           = $self->chapter_order;

    return glob File::Spec->catfile(  qw( build html ), "*.$suffix" )
           unless @order;

    push @order, 'theindex' if $self->config->{book}{build_index};

    return map { File::Spec->catfile( qw( build html ), "$_.$suffix" ) }
                  @order;
}

sub get_anchor_list
{
    my ($self, $suffix) = splice @_, 0, 2;
    my $chapter_prefix  = $self->config->{layout}{chapter_name_prefix};
    my %anchors;

    for my $chapter (@_)
    {
        my ($file)   = $chapter =~ /(${chapter_prefix}_\d+)./;
        my $contents = File::Slurp::read_file($chapter);

        while ($contents =~ /(?:^=head\d (.*?)|\A)\n\nZ<(.*?)>/mg)
        {
            $anchors{$2} = [ $file . $suffix, $1 ];
        }
    }

    return \%anchors;
}

sub chapter_order
{
    my $self   = shift;
    my $config = $self->config;
    return unless my $order = $config->{chapter_order};

    return map { $order->{$_} } sort { $a <=> $b } keys %$order;
}

sub map_chapters_to_output
{
    my ($self, $suffix, $dir) = splice @_, 0, 3;
    my $conf                  = $self->config;
    my $build_dir             = $conf->{layout}{chapter_build_directory};

    return map
    {
        my $dest = $_;
        $dest =~ s!/$build_dir/!/$dir/!;
        $dest =~ s/\.pod$/\.$suffix/;
        [ $_ => $dest ];
    } @_;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pod::PseudoPod::Book::Command - base class for all ppbook commands

=head1 VERSION

version 1.20210620.2051

=head1 AUTHOR

chromatic <chromatic@wgz.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by chromatic.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
