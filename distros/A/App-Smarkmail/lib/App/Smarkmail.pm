use strict;
use warnings;
package App::Smarkmail 0.006;
# ABSTRACT: pipemailer that changes plaintext to multi/alt with Markdown

use Email::MIME;
use Email::MIME::Creator;
use Email::MIME::Modifier;
use HTML::Entities ();
use Text::Markdown;

#pod =head1 DESCRIPTION
#pod
#pod This module implements logic used by the F<smarkdown> command, which accepts an
#pod email message on standard input, tries to convert it from a plaintext message
#pod to multipart alternative, and then sends it via F<sendmail>
#pod
#pod All of this is really sketchy and probably has secret mail-damaging or
#pod mail-losing bugs.  -- rjbs, 2008-02-24
#pod
#pod =method markdown_email
#pod
#pod   my $email = App::Smarkmail->markdown_email($message, \%arg);
#pod
#pod This method accepts an email message, either as an Email::MIME object or as a
#pod string or a reference to a string, and returns an Email::MIME object.  If the
#pod method is I<passed> an object, the object will be altered in place.
#pod
#pod If the message is a single part plaintext message, or a multipart/mixed or
#pod multipart/related message in which the first part is plaintext, then the
#pod plaintext part will be replaced with a multipart/alternative part.  The
#pod multi/alt part will have two alternatives, text and HTML.  The HTML part will
#pod be generated by running the plaintext part through
#pod L<Text::Markdown|Text::Markdown>.
#pod
#pod If the text message ends in a signature -- that is, a line containing only
#pod "--\x20" followed by no more than five lines -- the signature will be excluded
#pod from Markdown processing and will be appended to the HTML part wrapped in
#pod C<pre> and C<code> tags.
#pod
#pod Note that the HTML alternative is listed second, even though it is I<less> true
#pod to the original composition than the first.  This is because the assumption is
#pod that you want the recipient to see the HTML part, if possible.
#pod Multipart/alternative messages with HTML parts listed before plaintext parts
#pod seem to tickle some bugs in some popular MUAs.
#pod
#pod =cut

sub markdown_email {
  my ($self, $msg, $arg) = @_;

  my $to_send = eval { ref $msg and $msg->isa('Email::MIME') }
              ? $msg
              : Email::MIME->new($msg);

  if ($to_send->content_type =~ m{^text/plain}) {
    my ($text, $html) = $self->_parts_from_text($to_send);

    $to_send->content_type_set('multipart/alternative');
    $to_send->parts_set([ $text, $html ]);
  } elsif ($to_send->content_type =~ m{^multipart/(?:related|mixed)}) {
    my @parts = $to_send->subparts;
    if ($parts[0]->content_type =~ m{^text/plain}) {
      my ($text, $html) = $self->_parts_from_text(shift @parts);

      my $alt = Email::MIME->create(
        attributes => { content_type => 'multipart/alternative' },
        parts      => [ $text, $html ],
      );

      $to_send->parts_set([ $alt, @parts ]);
    }
  }

  return $to_send;
}

sub _parts_from_text {
  my ($self, $email) = @_;

  my $text = $email->body;
  my ($body, $sig) = split /^-- $/m, $text, 2;

  if (($sig =~ tr/\n/\n/) > 5) {
    $body = $text;
    $sig  = '';
  }

  my $html = Text::Markdown::markdown($body, { tab_width => 2 });

  if ($sig) {
    $html .= sprintf "<pre><code>-- %s</code></pre>",
             HTML::Entities::encode_entities($sig);
  }

  my $html_part = Email::MIME->create(
    attributes => { content_type => 'text/html', },
    body       => $html,
  );

  my $text_part = Email::MIME->create(
    attributes => { content_type => 'text/plain', },
    body       => $text,
  );

  return ($text_part, $html_part);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Smarkmail - pipemailer that changes plaintext to multi/alt with Markdown

=head1 VERSION

version 0.006

=head1 DESCRIPTION

This module implements logic used by the F<smarkdown> command, which accepts an
email message on standard input, tries to convert it from a plaintext message
to multipart alternative, and then sends it via F<sendmail>

All of this is really sketchy and probably has secret mail-damaging or
mail-losing bugs.  -- rjbs, 2008-02-24

=head1 PERL VERSION

This module should work on any version of perl still receiving updates from
the Perl 5 Porters.  This means it should work on any version of perl released
in the last two to three years.  (That is, if the most recently released
version is v5.40, then this module should work on both v5.40 and v5.38.)

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 METHODS

=head2 markdown_email

  my $email = App::Smarkmail->markdown_email($message, \%arg);

This method accepts an email message, either as an Email::MIME object or as a
string or a reference to a string, and returns an Email::MIME object.  If the
method is I<passed> an object, the object will be altered in place.

If the message is a single part plaintext message, or a multipart/mixed or
multipart/related message in which the first part is plaintext, then the
plaintext part will be replaced with a multipart/alternative part.  The
multi/alt part will have two alternatives, text and HTML.  The HTML part will
be generated by running the plaintext part through
L<Text::Markdown|Text::Markdown>.

If the text message ends in a signature -- that is, a line containing only
"--\x20" followed by no more than five lines -- the signature will be excluded
from Markdown processing and will be appended to the HTML part wrapped in
C<pre> and C<code> tags.

Note that the HTML alternative is listed second, even though it is I<less> true
to the original composition than the first.  This is because the assumption is
that you want the recipient to see the HTML part, if possible.
Multipart/alternative messages with HTML parts listed before plaintext parts
seem to tickle some bugs in some popular MUAs.

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 CONTRIBUTOR

=for stopwords Ricardo Signes

Ricardo Signes <rjbs@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2008 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
