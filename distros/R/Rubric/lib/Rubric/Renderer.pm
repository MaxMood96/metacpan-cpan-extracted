use strict;
use warnings;
package Rubric::Renderer 0.157;
# ABSTRACT: the rendering interface for Rubric

#pod =head1 DESCRIPTION
#pod
#pod Rubric::Renderer provides a simple interface for rendering entries, entry sets,
#pod and other things collected by Rubric::WebApp.
#pod
#pod =cut

use Carp;
use File::ShareDir;
use File::Spec;
use HTML::Widget::Factory 0.03;
use Rubric;
use Rubric::Config;
use Template 2.00;
use Template::Filters;

#pod =head1 METHODS
#pod
#pod =head2 register_type($type => \%arg)
#pod
#pod This method registers a format type by providing a little data needed to render
#pod to it.  The hashref of arguments must include C<content_type>, used to set the
#pod MIME type of the returned ouput; and C<extension>, used to find the primary
#pod template.
#pod
#pod This method returns a Template object, which is registered as the renderer for
#pod this type.  This return value may change in the future.
#pod
#pod =cut

my %renderer;

sub register_type {
  my ($class, $type, $arg) = @_;
  $renderer{$type} = $arg;
  $renderer{$type}{renderer} = Template->new({
    PROCESS      => ("template.$arg->{extension}"),
    INCLUDE_PATH => [
      Rubric::Config->template_path,
      File::Spec->catdir(File::ShareDir::dist_dir('Rubric'), 'templates'),
    ],
  });
}

__PACKAGE__->register_type(@$_) for (
  [ html => { content_type => 'text/html; charset="utf-8"', extension => 'html' } ],
  [ rss  => { content_type => 'application/rss+xml', extension => 'rss'  } ],
  [ txt  => { content_type => 'text/plain',          extension => 'txt'  } ],
  [ api  => { content_type => 'text/xml',            extension => 'api'  } ],
);

#pod =head2 process($template, $type, \%stash)
#pod
#pod This method renders the named template using the registered renderer for the
#pod given type, using the passed stash variables.
#pod
#pod The type must be rendered with Rubric::Renderer before this method is called.
#pod
#pod In list context, this method returns the content type and output document as a
#pod two-element list.  In scalar context, it returns the output document.
#pod
#pod =cut

my $xml_escape = sub {
  for (shift) {
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/"/&quot;/g;
    s/'/&apos;/g;
    return $_;
  }
};

sub process {
  my ($class, $template, $type, $stash) = @_;
  return unless $renderer{$type};

  $stash->{xml_escape} = $xml_escape;
  $stash->{version}    = Rubric->VERSION || 0;
  $stash->{widget}     = HTML::Widget::Factory->new;
  $stash->{basename}   = Rubric::Config->basename;
  # 2007-05-07
  # XXX: we only should create one factory per request, tops -- rjbs,

  $template .= '.' . $renderer{$type}{extension};
  $renderer{$type}{renderer}->process($template, $stash, \(my $output))
    or die "Couldn't render template: " . $renderer{$type}{renderer}->error;

  die "template produced no content" unless $output;

  return wantarray
    ? ($renderer{$type}{content_type}, $output)
    :  $output;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Rubric::Renderer - the rendering interface for Rubric

=head1 VERSION

version 0.157

=head1 DESCRIPTION

Rubric::Renderer provides a simple interface for rendering entries, entry sets,
and other things collected by Rubric::WebApp.

=head1 PERL VERSION

This code is effectively abandonware.  Although releases will sometimes be made
to update contact info or to fix packaging flaws, bug reports will mostly be
ignored.  Feature requests are even more likely to be ignored.  (If someone
takes up maintenance of this code, they will presumably remove this notice.)
This means that whatever version of perl is currently required is unlikely to
change -- but also that it might change at any new maintainer's whim.

=head1 METHODS

=head2 register_type($type => \%arg)

This method registers a format type by providing a little data needed to render
to it.  The hashref of arguments must include C<content_type>, used to set the
MIME type of the returned ouput; and C<extension>, used to find the primary
template.

This method returns a Template object, which is registered as the renderer for
this type.  This return value may change in the future.

=head2 process($template, $type, \%stash)

This method renders the named template using the registered renderer for the
given type, using the passed stash variables.

The type must be rendered with Rubric::Renderer before this method is called.

In list context, this method returns the content type and output document as a
two-element list.  In scalar context, it returns the output document.

=head1 AUTHOR

Ricardo SIGNES <rjbs@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
