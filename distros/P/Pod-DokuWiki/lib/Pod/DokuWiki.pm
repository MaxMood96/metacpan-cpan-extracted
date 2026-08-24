use v5.36;
package Pod::DokuWiki 0.02;
use parent qw(Pod::Simple);
use URI::Escape qw(uri_escape_utf8);
use Carp qw(croak);

sub _dokuwiki_escape($text) {
    $text =~ s{%%}{%%<nowiki>%%</nowiki>%%}g;
    $text = '%%' . $text . '%%';
    $text =~ s/%%%%//g;
    $text
}

sub resolve_pod_link($module, $section) {
    my $to = $module // '';
    if (length $to) {
        if ($to =~ /\Aperl\w*\z/a) {
            $to = "https://perldoc.perl.org/$to";
        } else {
            $to = "https://metacpan.org/pod/" . uri_escape_utf8($to);
        }
    }
    if (length $section) {
        $to .= '#' . $section =~ tr[a-zA-Z0-9_/\-][-]csr;
    }
    $to
}

sub resolve_man_link($n, $page, $section) {
    my $to = "https://www.man7.org/linux/man-pages/man$n/" . uri_escape_utf8($page) . ".$n.html";
    if (length $section) {
        $to .= '#' . uri_escape_utf8($section);
    }
    $to
}

sub new($class, %args) {
    my $resolve_pod_link = delete $args{resolve_pod_link} // \&resolve_pod_link;
    my $resolve_man_link = delete $args{resolve_man_link} // \&resolve_man_link;
    croak "Unrecognized constructor parameter(s) " . join(', ', map "'$_'", sort keys %args)
        if %args;
    my $self = $class->SUPER::new;
    $self->nbsp_for_S(1);
    $self->accept_targets('dokuwiki', 'highlighter');
    $self->strip_verbatim_indent(sub ($lines) {
        my $lvl = ~0;
        for my $line (@$lines) {
            $line =~ /\S/ or next;
            my $c = $-[0];
            $lvl = $c
                if $c < $lvl;
        }
        substr($_, 0, $lvl) = ''
            for @$lines;
        undef
    });
    $self->{_dw_stack} = [];
    $self->{_dw_plain} = 0;
    $self->{_dw_passthrough} = 0;
    $self->{_dw_highlighter} = 0;
    $self->{_dw_list} = '';
    $self->{_dw_buf} = '';
    $self->{_dw_code_language} = '';
    $self->{_dw_ccolumn} = 0;
    $self->{_dw_coffset} = 0;
    $self->{_dw_resolve_pod_link} = $resolve_pod_link;
    $self->{_dw_resolve_man_link} = $resolve_man_link;
    $self
}

sub _emit($self, $text) {
    my $n = length $text;
    $self->{_dw_coffset} += $n;
    if ((my $p = rindex $text, "\n") >= 0) {
        $self->{_dw_ccolumn} = $n - $p - 1;
    } else {
        $self->{_dw_ccolumn} += $n;
    }

    my $fh = $self->output_fh // return;
    print $fh $text;
}

sub _at_bol($self) {
    $self->{_dw_ccolumn} == 0
}

sub _extract_buf_verbatim($self) {
    my $text = $self->{_dw_buf};
    $self->{_dw_buf} = '';
    $text
}

sub _extract_buf($self) {
    $self->_extract_buf_verbatim =~ tr/\r\n/ /r
}

sub _emit_item_marker($self) {
    $self->_emit("  " x length($self->{_dw_list}) . substr($self->{_dw_list}, -1) . " ");
}

sub _emit_block_start($self) {
    if (!$self->{_dw_list}) {
        $self->_emit("\n\n") if $self->{_dw_coffset};
        return;
    }

    if ($self->_at_bol) {
        $self->_emit_item_marker;
    } else {
        $self->_emit(" \\\\ ");
    }
}

sub _nop (@) {}

my (%handler_start, %handler_end);

sub _handle_element_start($self, $elem, $attr, @) {
    push $self->{_dw_stack}->@*, [$elem];
    my $fn = $handler_start{$elem} // die "Internal error: unhandled element '$elem'";
    $self->$fn($attr);
}

sub _handle_element_end($self, $elem, @) {
    my $fn = $handler_end{$elem} // die "Internal error: unhandled element '$elem' (end)";
    $self->$fn();
    pop $self->{_dw_stack}->@*;
}

sub _handle_text($self, $text, @) {
    if ($self->{_dw_highlighter} || !$self->{_dw_passthrough}) {
        $self->{_dw_buf} .= $text;
    } else {
        $self->_emit($text);
    }
}

$handler_start{Document} = \&_nop;
$handler_end{Document} = sub ($self) {
    if (!$self->_at_bol) {
        $self->_emit("\n");
    }
};

$handler_start{for} = sub ($self, $attr) {
    my $ctx = $self->{_dw_stack}[-1];
    if ($attr->{target} eq 'highlighter') {
        $ctx->[1] = $attr->{target};
        $ctx->[2] = $self->_extract_buf_verbatim;
        $self->{_dw_highlighter}++;
    } elsif ($attr->{target} eq 'dokuwiki') {
        $ctx->[1] = $attr->{target};
        $self->{_dw_passthrough}++;
        $self->_emit("\n\n");
    } else {
        die "Internal error: unhandled =for target '$attr->{target}'";
    }
};

$handler_end{for} = sub ($self) {
    my $ctx = $self->{_dw_stack}[-1];
    if ($ctx->[1] eq 'highlighter') {
        my $data = $self->_extract_buf;
        $self->{_dw_buf} = $ctx->[2];
        $self->{_dw_highlighter}--;
        my %settings =
            map /\A([^=]*)=(.*)\z/s
                ? ($1 => $2)
                : (language => $_),
            split ' ', $data;
        $self->{_dw_code_language} = $settings{language} // '';
    } elsif ($ctx->[1] eq 'dokuwiki') {
        $self->{_dw_passthrough}--;
    } else {
        die "Internal error: unhandled =for target '$ctx->[1]' (end)";
    }
};

$handler_start{Data} = \&_nop;
$handler_end{Data} = \&_nop;

for my $i (1 .. 6) {
    $handler_start{'head' . $i} = sub ($self, $) {
        my $plain = $self->{_dw_plain}++;
        if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $plain) {
            return;
        }
        $self->_emit_block_start;
    };

    $handler_end{'head' . $i} = sub ($self) {
        $self->{_dw_plain}--;
        if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
            return;
        }

        my $text = $self->_extract_buf;

        if ($i == 6 || $self->{_dw_list}) {
            $self->_emit('//' . _dokuwiki_escape($text) . '//');
        } else {
            my $marker = '=' x (7 - $i);
            $self->_emit("$marker $text $marker");
        }
    };
}

$handler_start{Para} = sub ($self, $) {
    if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
        return;
    }

    $self->_emit_block_start;
};

$handler_end{Para} = sub ($self) {
    if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
        return;
    }

    my $text = $self->_extract_buf;
    $self->_emit(_dokuwiki_escape($text));
};


$handler_start{Verbatim} = sub ($self, $) {
    my $plain = $self->{_dw_plain}++;
    if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $plain) {
        return;
    }

    if ($self->{_dw_list}) {
        $self->_emit(" ");
    } elsif ($self->_at_bol) {
        $self->_emit("\n");
    } else {
        $self->_emit("\n\n");
    }
};

$handler_end{Verbatim} = sub ($self) {
    $self->{_dw_plain}--;
    if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
        return;
    }

    my $text = $self->_extract_buf_verbatim;

    my $attr = $self->{_dw_code_language} ? " $self->{_dw_code_language}" : '';
    my $tag;
    if ($text =~ m{</code>} && $text !~ m{</file>}) {
        $tag = 'file';
    } else {
        $tag = 'code';
        $text =~ s{</code\K(?=>)}{\N{U+200B}}g;
    }
    $self->_emit("<$tag$attr>\n$text\n</$tag>");
};

$handler_start{L} = sub ($self, $attr) {
    my $plain = $self->{_dw_plain}++;
    if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $plain) {
        return;
    }

    my $text = $self->_extract_buf;
    $self->_emit(_dokuwiki_escape($text) . '[[');

    my $type = $attr->{type};
    my $to = $attr->{to};
    if ($type eq 'url') {
    } elsif ($type eq 'man') {
        $to =~ s/\((\d+)\)\z//a or die "Internal error: unhandled 'man' link target '$to'";
        $to = $self->{_dw_resolve_man_link}($1, $to, $attr->{section});
    } elsif ($type eq 'pod') {
        $to = $self->{_dw_resolve_pod_link}($to, $attr->{section});
    } else {
        die "Internal error: unhandled link type '$type'";
    }

    $to =~ s/\[/%5B/g;
    $to =~ s/\]/%5D/g;
    $to =~ s/\|/%7C/g;

    $self->_emit("$to|");
};

$handler_end{L} = sub ($self) {
    $self->{_dw_plain}--;
    if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
        return;
    }

    my $text = $self->_extract_buf;
    $self->_emit($text =~ s/\]\K(?=\])/\N{U+200B}/gr . ']]');
};

{
    my %markup = (
        B => "**",
        C => "''",
        I => "//",
        U => "__",
    );

    for my $fmt (keys %markup) {
        my $marker = $markup{$fmt};
        $handler_start{$fmt} = $handler_end{$fmt} = sub ($self, @) {
            if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
                return;
            }
            my $text = $self->_extract_buf;
            $self->_emit(_dokuwiki_escape($text) . $marker);
        };
    }
}

{
    my %marker = (
        number => '-',
        bullet => '*',
        text   => '*',
    );
    
    for my $list_type (keys %marker) {
        my $marker = $marker{$list_type};

        $handler_start{"over-$list_type"} = sub ($self, $) {
            $self->{_dw_list} .= $marker;
        };

        $handler_end{"over-$list_type"} = sub ($self) {
            chop $self->{_dw_list};
            if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
                return;
            }
            if (!$self->_at_bol) {
                $self->_emit("\n");
            }
        };

        $handler_start{"item-$list_type"} = sub ($self, $) {
            if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
                return;
            }
            if (!$self->_at_bol) {
                $self->_emit("\n");
            }
            $self->_emit_item_marker;

            if ($list_type eq 'text') {
                $self->_emit("//");
            }
        };

        $handler_end{"item-$list_type"} = sub ($self) {
            if ($self->{_dw_passthrough} || $self->{_dw_highlighter} || $self->{_dw_plain}) {
                return;
            }
            my $text = $self->_extract_buf;
            $self->_emit(_dokuwiki_escape($text));
            if ($list_type eq 'text') {
                $self->_emit("//");
            }
        };
    }
}

'ok'

__END__

=encoding utf-8

=head1 NAME

Pod::DokuWiki - Convert POD to DokuWiki

=head1 SYNOPSIS

=for highlighter language=perl

    use Pod::DokuWiki;
    my $parser = Pod::DokuWiki->new;

    $parser->output_fh(\*STDOUT);
    # -or-
    $parser->output_string(\my $result);

    $parser->parse_file(\*STDIN);
    # -or-
    $parser->parse_string_document($pod);

=head1 DESCRIPTION

This module converts POD to L<DokuWiki
syntax|https://www.dokuwiki.org/wiki:syntax>. The conversion is "best-effort"
because DokuWiki cannot represent all POD elements faithfully (in particular,
DokuWiki lists are fairly limited).

In addition to regular POD markup, this module picks up sections labeled
C<highlighter> and C<dokuwiki>.

=over

=item C<highlighter>

A directive like C<< =for highlighter language=perl >> marks the language of
all following code blocks (until the next C<< =for highlighter >> directive).
This affects syntax highlighting in DokuWiki.

=item C<dokuwiki>

Any code between C<< =begin dokuwiki >> and C<< =end dokuwiki >> is included
verbatim in the generated document. This lets you add custom DokuWiki markup
(e.g. for images or tables).

=back

=head2 Methods

Pod::DokuWiki subclasses L<Pod::Simple>, which see for the main methods to
specify the input/output for the conversion: L<Pod::Simple/MAIN METHODS>.

In addition, the C<new> constructor optionally accepts the following named
parameters to customize the behavior of the converter:

=over

=item C<resolve_man_link>

Code reference. Called with 3 arguments: The section number, the page name, and
the POD "section" (page part) to link to. (The latter is normally C<undef>.)

For example, C<< LE<lt>man(1)> >> calls this function with C<< ('1', 'man',
undef) >> and C<< LE<lt>termcap(5)/SEE ALSO> >> calls it with C<< ('5',
'termcap', 'SEE ALSO') >>.

Must return a URL.

=item C<resolve_pod_link>

Code reference. Called with 2 arguments: The module or perldoc page name, and
the section to link to. Either of these arguments (but not both) may be
C<undef>.

For example, C<< LE<lt>Scalar::Util> >> calls this function with C<<
('Scalar::Util', undef) >>, C<< LE<lt>/SYNOPSIS> >> calls it with C<< (undef,
'SYNOPSIS') >>, and C<< LE<lt>Scalar::Util/SYNOPSIS> >> calls it with C<<
('Scalar::Util', 'SYNOPSIS') >>.

Must return a URL.

The default implementation resolves perldoc pages (matching C</^perl\w*\z/>) to
L<https://perldoc.perl.org/> and anything else to L<https://metacpan.org/>.

=back

=head1 SEE ALSO

L<Pod::Simple>

=begin :README

=head1 INSTALLATION

To install this module, run the following commands:

=for highlighter language=sh

    perl Makefile.PL
    make
    make test
    make install

=head1 SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc Pod::DokuWiki

You can also look for information at:

=over

=item *

MetaCPAN: L<https://metacpan.org/pod/Pod::DokuWiki>

=item *

The source repository on Codeberg:
L<https://codeberg.org/mauke/Pod-DokuWiki>

=item *

The module's bug tracker: L<https://codeberg.org/mauke/Pod-DokuWiki/issues>

=back

=end :README

=head1 AUTHOR

Lukas Mai, C<< <l.mai at web.de> >>

=head1 COPYRIGHT & LICENSE

Copyright © 2026 Lukas Mai.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

See L<https://www.gnu.org/licenses/> for more information.

=cut
