package Statocles::Site;
our $VERSION = '0.099';
# ABSTRACT: An entire, configured website

use Statocles::Base 'Class', 'Emitter';
use Scalar::Util qw( blessed );
use Text::Markdown;
use Mojo::URL;
use Mojo::Log;
use Statocles::Page::Plain;
use Statocles::Page::File;
use Statocles::Page::Document;
use Statocles::Util qw( derp );
use Statocles::Store;
use List::UtilsBy qw( uniq_by );

#pod =attr store
#pod
#pod The L<Store object|Statocles::Store> for the site.
#pod
#pod =cut

has store => (
    is => 'ro',
    isa => StoreType,
    coerce => StoreType->coercion,
    default => sub {
        return StoreType->coercion->( '.' );
    },
);

#pod =attr title
#pod
#pod The site title, used in templates.
#pod
#pod =cut

has title => (
    is => 'ro',
    isa => Str,
    default => sub { '' },
);

#pod =attr author
#pod
#pod     author: Doug Bell <doug@example.com>
#pod     author:
#pod         name: Doug Bell
#pod         email: doug@example.com
#pod
#pod The primary author of the site, which will be used as the default author
#pod for all content. This can be a string with the author's name, and an
#pod optional e-mail address wrapped in E<lt>E<gt>, or a hashref of
#pod L<Statocles::Person attributes|Statocles::Person/ATTRIBUTES>.
#pod
#pod Individual documents can have their own authors. See
#pod L<Statocles::Document/author>.
#pod
#pod =cut

has author => (
    is => 'ro',
    isa => PersonType,
    coerce => PersonType->coercion,
);

#pod =attr base_url
#pod
#pod The base URL of the site, including protocol and domain. Used mostly for feeds.
#pod
#pod This can be overridden by L<base_url in Deploy|Statocles::Deploy/base_url>.
#pod
#pod =cut

has base_url => (
    is => 'rw',
    isa => Str,
    default => sub { '/' },
);

#pod =attr theme
#pod
#pod The L<theme|Statocles::Theme> for this site. All apps share the same theme.
#pod
#pod =cut

has theme => (
    is => 'ro',
    isa => ThemeType,
    coerce => ThemeType->coercion,
    default => sub {
        my ( $self ) = @_;
        require Statocles::Theme;
        Statocles::Theme->new( path => '::default' );
    },
);

#pod =attr apps
#pod
#pod The applications in this site. Each application has a name
#pod that can be used later.
#pod
#pod =cut

has apps => (
    is => 'ro',
    isa => HashRef[ConsumerOf['Statocles::App']],
    default => sub { {} },
);

#pod =attr plugins
#pod
#pod The plugins in this site. Each plugin has a name that can be used later.
#pod
#pod =cut

has plugins => (
    is => 'ro',
    isa => HashRef[ConsumerOf['Statocles::Plugin']],
    default => sub { {} },
);

#pod =attr index
#pod
#pod The page path to use for the site index. Make sure to include the leading slash
#pod (but C</index.html> is optional). Defaults to C</>, so any app with C<url_root>
#pod of C</> will be the index.
#pod
#pod =cut

has index => (
    is => 'ro',
    isa => Str,
    default => sub { '/' },
);

#pod =attr nav
#pod
#pod Named navigation lists. A hash of arrays of hashes with the following keys:
#pod
#pod     title - The title of the link
#pod     href - The href of the link
#pod
#pod The most likely name for your navigation will be C<main>. Navigation names
#pod are defined by your L<theme|Statocles::Theme>. For example:
#pod
#pod     {
#pod         main => [
#pod             {
#pod                 title => 'Blog',
#pod                 href => '/blog',
#pod             },
#pod             {
#pod                 title => 'Contact',
#pod                 href => '/contact.html',
#pod             },
#pod         ],
#pod     }
#pod
#pod =cut

has _nav => (
    is => 'ro',
    isa => LinkHash,
    coerce => LinkHash->coercion,
    default => sub { {} },
    init_arg => 'nav',
);

#pod =attr links
#pod
#pod     # site.yml
#pod     links:
#pod         stylesheet:
#pod             - href: /theme/css/site.css
#pod         script:
#pod             - href: /theme/js/site.js
#pod
#pod Related links for this site. Links are used to build relationships
#pod to other web addresses. Link categories are named based on their
#pod relationship. Some possible categories are:
#pod
#pod =over 4
#pod
#pod =item stylesheet
#pod
#pod Additional stylesheets for this site.
#pod
#pod =item script
#pod
#pod Additional scripts for this site.
#pod
#pod =back
#pod
#pod Each category contains an arrayref of hashrefs of L<link objects|Statocles::Link>.
#pod See the L<Statocles::Link|Statocles::Link> documentation for a full list of
#pod supported attributes. The most common attributes are:
#pod
#pod =over 4
#pod
#pod =item href
#pod
#pod The URL for the link.
#pod
#pod =item text
#pod
#pod The text of the link. Not needed for stylesheet or script links.
#pod
#pod =back
#pod
#pod =cut

has _links => (
    is => 'ro',
    isa => LinkHash,
    default => sub { +{} },
    coerce => LinkHash->coercion,
    init_arg => 'links',
);

#pod =attr images
#pod
#pod     # site.yml
#pod     images:
#pod         icon: /images/icon.png
#pod
#pod Related images for this document. These are used by themes to display
#pod images in appropriate templates. Each image has a category, like
#pod C<title>, C<banner>, or C<icon>, mapped to an L<image
#pod object|Statocles::Image>.  See the L<Statocles::Image|Statocles::Image>
#pod documentation for a full list of supported attributes. The most common
#pod attributes are:
#pod
#pod =over 4
#pod
#pod =item src
#pod
#pod The source path of the image. Relative paths will be resolved relative
#pod to this document.
#pod
#pod =item alt
#pod
#pod The alternative text to display if the image cannot be downloaded or
#pod rendered. Also the text to use for non-visual media.
#pod
#pod =back
#pod
#pod Useful image names are:
#pod
#pod =over 4
#pod
#pod =item icon
#pod
#pod The shortcut icon for the site.
#pod
#pod =back
#pod
#pod =cut

has images => (
    is => 'ro',
    isa => HashRef[InstanceOf['Statocles::Image']],
    default => sub { +{} },
    coerce => sub {
        my ( $ref ) = @_;
        my %img;
        for my $name ( keys %$ref ) {
            my $attrs = $ref->{ $name };
            if ( !ref $attrs ) {
                $attrs = { src => $attrs };
            }
            $img{ $name } = Statocles::Image->new(
                %{ $attrs },
            );
        }
        return \%img;
    },
);

#pod =attr templates
#pod
#pod     # site.yml
#pod     templates:
#pod         sitemap.xml: custom/sitemap.xml
#pod         layout.html: custom/layout.html
#pod
#pod The custom templates to use for the site meta-template like
#pod C<sitemap.xml> and C<robots.txt>, or the site-wide default layout
#pod template. A mapping of template names to template paths (relative to the
#pod theme root directory).
#pod
#pod Developers should get site templates using L<the C<template>
#pod method|/template>.
#pod
#pod =cut

has _templates => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
    init_arg => 'templates',
);

#pod =attr template_dir
#pod
#pod The directory (inside the theme directory) to use for the site meta-templates.
#pod
#pod =cut

has template_dir => (
    is => 'ro',
    isa => Str,
    default => sub { 'site' },
);

#pod =attr deploy
#pod
#pod The L<deploy object|Statocles::Deploy> to use for C<deploy()>. This is
#pod intended to be the production deployment of the site. A build gets promoted to
#pod production by using the C<deploy> command.
#pod
#pod =cut

has deploy => (
    is => 'ro',
    isa => ConsumerOf['Statocles::Deploy'],
    required => 1,
    coerce => sub {
        if ( ( blessed $_[0] && $_[0]->isa( 'Path::Tiny' ) ) || !ref $_[0] ) {
            require Statocles::Deploy::File;
            return Statocles::Deploy::File->new(
                path => $_[0],
            );
        }
        return $_[0];
    },
);

#pod =attr data
#pod
#pod A hash of arbitrary data available to theme templates. This is a good place to
#pod put extra structured data like social network links or make easy customizations
#pod to themes like header image URLs.
#pod
#pod =cut

has data => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
);

#pod =attr log
#pod
#pod A L<Mojo::Log> object to write logs to. Defaults to STDERR.
#pod
#pod =cut

has log => (
    is => 'ro',
    isa => InstanceOf['Mojo::Log'],
    lazy => 1,
    default => sub {
        Mojo::Log->new( level => 'warn' );
    },
);

#pod =attr markdown
#pod
#pod The Text::Markdown object to use to turn Markdown into HTML. Defaults to a
#pod plain Text::Markdown object.
#pod
#pod Any object with a "markdown" method will work here.
#pod
#pod =cut

has markdown => (
    is => 'ro',
    isa => HasMethods['markdown'],
    default => sub { Text::Markdown->new },
);

#pod =attr disable_content_template
#pod
#pod This disables processing the content as a template. This can speed up processing
#pod when the content is not using template directives. 
#pod
#pod This can be also set in the application
#pod (L<Statocles::App/disable_content_template>), or for each document
#pod (L<Statocles::Document/disable_content_template>).
#pod
#pod =cut

has disable_content_template => (
    is => 'ro',
    isa => Bool,
    lazy => 1,
    default => 0,
    predicate => 'has_disable_content_template',
);

#pod =attr _pages
#pod
#pod A cache of all the pages that the site contains. This is generated
#pod during the C<build> phase and is available to all the templates
#pod while they are being rendered.
#pod
#pod =cut

has _pages => (
    is => 'rw',
    isa => ArrayRef[ConsumerOf['Statocles::Page']],
    default => sub { [] },
    lazy => 1,
    predicate => 'has_pages',
    clearer => 'clear_pages',
);

#pod =method BUILD
#pod
#pod Register this site as the global site.
#pod
#pod =cut

sub BUILD {
    my ( $self ) = @_;

    $Statocles::SITE = $self;
    for my $app ( values %{ $self->apps } ) {
        $app->site( $self );
    }
    for my $plugin ( values %{ $self->plugins } ) {
        $plugin->register( $self );
    }
}

#pod =method app
#pod
#pod     my $app = $site->app( $name );
#pod
#pod Get the app with the given C<name>.
#pod
#pod =cut

sub app {
    my ( $self, $name ) = @_;
    return $self->apps->{ $name };
}

#pod =method nav
#pod
#pod     my @links = $site->nav( $key );
#pod
#pod Get the list of links for the given nav C<key>. Each link is a
#pod L<Statocles::Link> object.
#pod
#pod     title - The title of the link
#pod     href - The href of the link
#pod
#pod If the named nav does not exist, returns an empty list.
#pod
#pod =cut

sub nav {
    my ( $self, $name ) = @_;
    return $self->_nav->{ $name } ? @{ $self->_nav->{ $name } } : ();
}

#pod =method build
#pod
#pod     $site->build( %options );
#pod
#pod Build the site in its build location. The C<%options> hash is passed in to every
#pod app's C<pages> method, allowing for customization of app behavior based on
#pod command-line.
#pod
#pod =cut

our %PAGE_PRIORITY = (
    'Statocles::Page::File' => -100,
);

sub pages {
    my ( $self, %options ) = @_;

    if ( $self->has_pages ) {
        #; say "Returning cached pages";
        return @{ $self->_pages };
    }

    # Load all the files/documents from the site directory
    my $drain = sub {
        my $iter = shift;
        my @f;
        while ( my $obj = $iter->() ) {
            next if $obj->path =~ /[.]ep$/;
            push @f, $obj;
        }
        return @f;
    };
    my @files = $drain->( $self->store->iterator );
    # $self->emit(
    #     'read_files',
    #     class => 'Statocles::Event::Files',
    #     files => \@files,
    # );

    # Build Page objects for each document
    my @pages = $self->_build_pages( \@files );
    #; say "Got all pages: " . join ", ", map { $_->path } @pages;
    # $self->emit(
    #     'read_pages',
    #     class => 'Statocles::Event::Pages',
    #     pages => \@pages,
    # );

    # Apply applications to specific subsets of pages
    my $apps = $self->apps;
    my %seen_paths;
    my @app_pages;
    for my $app_name ( keys %{ $apps } ) {
        my $app = $apps->{$app_name};
        my $app_root = $app->url_root;
        $app_root =~ s{^/}{}g;
        my $pages_for_app = [ grep { $_->path =~ m{^/?$app_root} } @pages ];
        push @app_pages, $app->pages(
            $pages_for_app,
            %options,
        );
    }

    push @pages, @app_pages;
    $self->emit(
        'collect_pages',
        class => 'Statocles::Event::Pages',
        pages => \@pages,
    );

    # @pages should not change after this, because it is being cached
    $self->_pages( \@pages );

    $self->emit(
        'before_build_write',
        class => 'Statocles::Event::Pages',
        pages => \@pages,
    );

    $self->_fix_internal_links( \@pages, \%options );

    push @pages,
        $self->_build_sitemap( \@pages ),
        $self->_build_robots,
        ;

    # Add the theme
    my $theme_root = $self->theme->url_root;
    $theme_root =~ s{^/}{}g;
    my $pages_for_theme = [ grep { $_->path =~ m{^/?$theme_root} } @pages ];
    $self->theme->site( $self );
    for my $page ( $self->theme->pages ) {
        push @pages, $page;
    }

    # @pages should not change after this, because it is being cached
    $self->_pages( \@pages );

    $self->emit(
        'build',
        class => 'Statocles::Event::Pages',
        pages => \@pages,
    );

    return @pages;
}

sub _build_pages {
    my ( $self, $files ) = @_;
    my @pages;
    for my $obj ( @$files ) {
        if ( $obj->isa( 'Statocles::Document' ) ) {
            my $page_path = $obj->path.'';
            $page_path =~ s{[.]\w+$}{.html};

            my %args = (
                path => $page_path,
                site => $self,
                layout => $self->template( 'layout.html' ),
                document => $obj,
            );

            push @pages, Statocles::Page::Document->new( %args );
        }
        else {
            # If there's a markdown file, don't keep the html file, since
            # we'll be building it from the markdown
            if ( $obj->path =~ /[.]html$/ ) {
                my $doc_path = $obj->path."";
                $doc_path =~ s/[.]html$/.markdown/;
                next if $self->store->has_file( $doc_path );
            }

            push @pages, Statocles::Page::File->new(
                site => $self,
                path => $obj->path->stringify,
                file_path => $self->store->path->child( $obj->path ),
            );
        }
    }
    return @pages;
}

sub _fix_internal_links {
    my ( $self, $pages, $options ) = @_;

    # Site-level munging of pages
    my $base_url = $options->{ base_url } || $self->base_url;
    $self->base_url( $base_url );
    my $base_path = Mojo::URL->new( $base_url )->path;
    $base_path =~ s{/$}{};

    # XXX: Should we allow sites without indexes?
    my $index_path = $self->index;
    if ( $index_path && $index_path !~ m{^/} ) {
        $self->log->warn(
            sprintf 'site "index" property should be absolute path to index page (got "%s")',
            $self->index,
        );
    }
    # Allow index to be path to document and not the resulting page
    # (so, ending in ".markdown" or ".md")
    my $doc_path = $index_path;
    my $doc_ext = join '|', @{ $self->store->document_extensions };
    $doc_path =~ s/$doc_ext/html/;
    my $index_path_re = qr{^$doc_path(?:/index[.]html)?$};

    # DEPRECATED: Index without leading / is an index app
    my $index_root  = $self->index =~ m{^/} ? $self->index
                    : $self->index ? $self->apps->{ $self->index }->url_root : '';
    $index_root =~ s{/index[.]html$}{};

    #; say "Got pages: \n" . join "\n", map { $_->path } @$pages;
    #; say "Looking for: $index_path_re";

    # First find the index file
    my ( $index_page ) = grep { $_->path =~ $index_path_re } @$pages;
    my $index_orig_path;
    if ( $index_page ) {
        #; say "Found index: " . $index_page->path;
        $index_orig_path = $index_page->path;
        $index_page->path( '/index.html' );
    }

    for my $page ( @$pages ) {
        my $is_index = $page->path eq '/index.html';

        if ( !$page->has_dom ) {
            next;
        }

        my $dom = $page->dom;
        for my $attr ( qw( src href ) ) {
            for my $el ( $dom->find( "[$attr]" )->each ) {
                my $url = $el->attr( $attr );

                # Fix relative non-anchor links on the index page
                if ( $is_index && $index_orig_path && $url !~ m{^([A-Za-z]+:|/|#)} ) {
                    my $clone = $index_orig_path->clone;
                    pop @$clone;
                    $url = join "/", $clone, $url;
                }

                next unless $url =~ m{^/(?:[^/]|$)};

                # Rewrite links to the index app's index page
                if ( $index_root && $url =~ m{^$index_root(?:/index[.]html)?$} ) {
                    $url = '/';
                }

                if ( $base_path =~ /\S/ ) {
                    $url = join "", $base_path, $url;
                }

                $el->attr( $attr, $url );
            }
        }
    }
}

sub _build_sitemap {
    my ( $self, $pages ) = @_;

    # Build the sitemap.xml
    # html files only
    # sorted by path to keep order and prevent spurious deploy commits
    my @indexed_pages = map { $_->[0] }
                        sort { $a->[1] cmp $b->[1] }
                        map { [ $_, $self->url( $_->path ) ] }
                        grep { $_->path =~ /[.]html?$/ }
                        @$pages;
    my $tmpl = $self->template( 'sitemap.xml' );
    my $sitemap = Statocles::Page::Plain->new(
        path => '/sitemap.xml',
        content => $tmpl->render( site => $self, pages => \@indexed_pages ),
    );
    return $sitemap;
}

sub _build_robots {
    my ( $self ) = @_;
    # robots.txt is the best way for crawlers to automatically discover sitemap.xml
    # We should do more with this later...
    my $robots_tmpl = $self->template( 'robots.txt' );
    my $robots = Statocles::Page::Plain->new(
        path => '/robots.txt',
        content => $robots_tmpl->render( site => $self ),
    );
    return $robots;
}

#pod =method links
#pod
#pod     my @links = $site->links( $key );
#pod     my $link = $site->links( $key );
#pod     $site->links( $key => $add_link );
#pod
#pod Get or append to the links set for the given key. See L<the links
#pod attribute|/links> for some commonly-used keys.
#pod
#pod If only one argument is given, returns a list of L<link
#pod objects|Statocles::Link>. In scalar context, returns the first link in
#pod the list.
#pod
#pod If two arguments are given, append the new link to the given key.
#pod C<$add_link> may be a URL string, a hash reference of L<link
#pod attributes|Statocles::Link/ATTRIBUTES>, or a L<Statocles::Link
#pod object|Statocles::Link>. When adding links, nothing is returned.
#pod
#pod =cut

sub links {
    my ( $self, $name, $add_link ) = @_;
    if ( $add_link ) {
        push @{ $self->_links->{ $name } }, LinkType->coerce( $add_link );
        return;
    }
    my @links = uniq_by { $_->href }
        $self->_links->{ $name } ? @{ $self->_links->{ $name } } : ();
    return wantarray ? @links : $links[0];
}

#pod =method url
#pod
#pod     my $url = $site->url( $page_url );
#pod
#pod Get the full URL to the given path by prepending the C<base_url>.
#pod
#pod =cut

sub url {
    my ( $self, $path ) = @_;
    my $base    = $self->base_url;

    # Remove index.html from the end of the path, since it's redundant
    $path =~ s{/index[.]html$}{/};

    # Remove the / from both sides of the join so we don't double up
    $base =~ s{/$}{};
    $path =~ s{^/}{};

    return join "/", $base, $path;
}

#pod =method template
#pod
#pod     my $template = $app->template( $tmpl_name );
#pod
#pod Get a L<template object|Statocles::Template> for the given template
#pod name. The default template is determined by the app's class name and the
#pod template name passed in.
#pod
#pod Applications should list the templates they have and describe what L<page
#pod class|Statocles::Page> they use.
#pod
#pod =cut

sub template {
    my ( $self, @parts ) = @_;

    if ( @parts == 1 ) {
        @parts      = $self->_templates->{ $parts[0] }
                    ? $self->_templates->{ $parts[0] }
                    : $parts[0] eq 'layout.html'
                    ? ( 'layout', 'default.html' )
                    : ( $self->template_dir, @parts );
    }

    # If the default layout doesn't exist, use the old default.
    # Remove this in v2.0
    if ( $parts[0] eq 'layout' && $parts[1] eq 'default.html'
        && !$self->theme->path->child( @parts )->is_file
        && $self->theme->path->child( site => 'layout.html.ep' )->is_file
    ) {
        derp qq{Using default layout "site/layout.html.ep" is deprecated and will be removed in v2.0. Move your default layout to "layout/default.html.ep" to fix this warning.};
        return $self->theme->template( qw( site layout.html ) );
    }

    return $self->theme->template( @parts );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Statocles::Site - An entire, configured website

=head1 VERSION

version 0.099

=head1 SYNOPSIS

    my $site = Statocles::Site->new(
        title => 'My Site',
        nav => [
            { title => 'Home', href => '/' },
            { title => 'Blog', href => '/blog' },
        ],
        apps => {
            blog => Statocles::App::Blog->new( ... ),
        },
    );

    $site->deploy;

=head1 DESCRIPTION

A Statocles::Site is a collection of L<applications|Statocles::App>.

=head1 ATTRIBUTES

=head2 store

The L<Store object|Statocles::Store> for the site.

=head2 title

The site title, used in templates.

=head2 author

    author: Doug Bell <doug@example.com>
    author:
        name: Doug Bell
        email: doug@example.com

The primary author of the site, which will be used as the default author
for all content. This can be a string with the author's name, and an
optional e-mail address wrapped in E<lt>E<gt>, or a hashref of
L<Statocles::Person attributes|Statocles::Person/ATTRIBUTES>.

Individual documents can have their own authors. See
L<Statocles::Document/author>.

=head2 base_url

The base URL of the site, including protocol and domain. Used mostly for feeds.

This can be overridden by L<base_url in Deploy|Statocles::Deploy/base_url>.

=head2 theme

The L<theme|Statocles::Theme> for this site. All apps share the same theme.

=head2 apps

The applications in this site. Each application has a name
that can be used later.

=head2 plugins

The plugins in this site. Each plugin has a name that can be used later.

=head2 index

The page path to use for the site index. Make sure to include the leading slash
(but C</index.html> is optional). Defaults to C</>, so any app with C<url_root>
of C</> will be the index.

=head2 nav

Named navigation lists. A hash of arrays of hashes with the following keys:

    title - The title of the link
    href - The href of the link

The most likely name for your navigation will be C<main>. Navigation names
are defined by your L<theme|Statocles::Theme>. For example:

    {
        main => [
            {
                title => 'Blog',
                href => '/blog',
            },
            {
                title => 'Contact',
                href => '/contact.html',
            },
        ],
    }

=head2 links

    # site.yml
    links:
        stylesheet:
            - href: /theme/css/site.css
        script:
            - href: /theme/js/site.js

Related links for this site. Links are used to build relationships
to other web addresses. Link categories are named based on their
relationship. Some possible categories are:

=over 4

=item stylesheet

Additional stylesheets for this site.

=item script

Additional scripts for this site.

=back

Each category contains an arrayref of hashrefs of L<link objects|Statocles::Link>.
See the L<Statocles::Link|Statocles::Link> documentation for a full list of
supported attributes. The most common attributes are:

=over 4

=item href

The URL for the link.

=item text

The text of the link. Not needed for stylesheet or script links.

=back

=head2 images

    # site.yml
    images:
        icon: /images/icon.png

Related images for this document. These are used by themes to display
images in appropriate templates. Each image has a category, like
C<title>, C<banner>, or C<icon>, mapped to an L<image
object|Statocles::Image>.  See the L<Statocles::Image|Statocles::Image>
documentation for a full list of supported attributes. The most common
attributes are:

=over 4

=item src

The source path of the image. Relative paths will be resolved relative
to this document.

=item alt

The alternative text to display if the image cannot be downloaded or
rendered. Also the text to use for non-visual media.

=back

Useful image names are:

=over 4

=item icon

The shortcut icon for the site.

=back

=head2 templates

    # site.yml
    templates:
        sitemap.xml: custom/sitemap.xml
        layout.html: custom/layout.html

The custom templates to use for the site meta-template like
C<sitemap.xml> and C<robots.txt>, or the site-wide default layout
template. A mapping of template names to template paths (relative to the
theme root directory).

Developers should get site templates using L<the C<template>
method|/template>.

=head2 template_dir

The directory (inside the theme directory) to use for the site meta-templates.

=head2 deploy

The L<deploy object|Statocles::Deploy> to use for C<deploy()>. This is
intended to be the production deployment of the site. A build gets promoted to
production by using the C<deploy> command.

=head2 data

A hash of arbitrary data available to theme templates. This is a good place to
put extra structured data like social network links or make easy customizations
to themes like header image URLs.

=head2 log

A L<Mojo::Log> object to write logs to. Defaults to STDERR.

=head2 markdown

The Text::Markdown object to use to turn Markdown into HTML. Defaults to a
plain Text::Markdown object.

Any object with a "markdown" method will work here.

=head2 disable_content_template

This disables processing the content as a template. This can speed up processing
when the content is not using template directives. 

This can be also set in the application
(L<Statocles::App/disable_content_template>), or for each document
(L<Statocles::Document/disable_content_template>).

=head2 _pages

A cache of all the pages that the site contains. This is generated
during the C<build> phase and is available to all the templates
while they are being rendered.

=head1 METHODS

=head2 BUILD

Register this site as the global site.

=head2 app

    my $app = $site->app( $name );

Get the app with the given C<name>.

=head2 nav

    my @links = $site->nav( $key );

Get the list of links for the given nav C<key>. Each link is a
L<Statocles::Link> object.

    title - The title of the link
    href - The href of the link

If the named nav does not exist, returns an empty list.

=head2 build

    $site->build( %options );

Build the site in its build location. The C<%options> hash is passed in to every
app's C<pages> method, allowing for customization of app behavior based on
command-line.

=head2 links

    my @links = $site->links( $key );
    my $link = $site->links( $key );
    $site->links( $key => $add_link );

Get or append to the links set for the given key. See L<the links
attribute|/links> for some commonly-used keys.

If only one argument is given, returns a list of L<link
objects|Statocles::Link>. In scalar context, returns the first link in
the list.

If two arguments are given, append the new link to the given key.
C<$add_link> may be a URL string, a hash reference of L<link
attributes|Statocles::Link/ATTRIBUTES>, or a L<Statocles::Link
object|Statocles::Link>. When adding links, nothing is returned.

=head2 url

    my $url = $site->url( $page_url );

Get the full URL to the given path by prepending the C<base_url>.

=head2 template

    my $template = $app->template( $tmpl_name );

Get a L<template object|Statocles::Template> for the given template
name. The default template is determined by the app's class name and the
template name passed in.

Applications should list the templates they have and describe what L<page
class|Statocles::Page> they use.

=head1 EVENTS

The site object exposes the following events.

=head2 collect_pages

This event is fired after all the pages have been collected, but before they
have been rendered. This allows you to edit the page's data or add/remove
pages from the list.

The event will be a
L<Statocles::Event::Pages|Statocles::Event/Statocles::Event::Pages> object
containing all the pages built by the apps.

=head2 before_build_write

This event is fired after the pages have been built by the apps, but before
any page is written to the C<build_store>.

The event will be a
L<Statocles::Event::Pages|Statocles::Event/Statocles::Event::Pages> object
containing all the pages built by the apps.

=head2 build

This event is fired after the site has been built and the pages written to the
C<build_store>.

The event will be a
L<Statocles::Event::Pages|Statocles::Event/Statocles::Event::Pages> object
containing all the pages built by the site.

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
