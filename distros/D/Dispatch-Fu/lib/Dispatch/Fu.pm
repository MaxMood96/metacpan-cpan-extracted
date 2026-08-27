package Dispatch::Fu;

use strict;
use warnings;
use Exporter qw/import/;
use Carp qw/carp croak/;

our $VERSION       = q{1.07};
our @EXPORT        = qw(dispatch on cases xdefault xshift_and_deref);
our @EXPORT_OK     = qw(dispatch on cases xdefault xshift_and_deref);

my $DISPATCH_TABLE = {};

# sub for introspection, returns the string names of each case
# added using the C<on> keyword
sub cases() {
    return sort keys %$DISPATCH_TABLE;
}

sub _reset_default_handler() {
    $DISPATCH_TABLE = {
        default => sub {
            carp qq{Supported cases are:\n};
            foreach my $case (cases) {
                print qq{\t$case\n};
            };
        },
    };
    return;
}

_reset_default_handler;

sub dispatch (&@) {
    my $code_ref  = shift;    # catch sub ref that was coerced from the 'dispatch' BLOCK
    my $match_ref = shift;    # catch the input reference passed after the 'dispatch' BLOCK

    # A failed dispatch can exit before the normal reset below. Start every
    # dispatch from a clean table so cases never leak between calls.
    _reset_default_handler;

    croak qq{Dispatch::Fu [warning]: no cases defined. Make sure no semicolons are in places that need commas!} if not @_;

    # build up dispatch table for each k/v pair preceded by 'on'
    while (@_) {
        my $key = shift @_;
        my $HV  = shift @_;
        $DISPATCH_TABLE->{$key} = _to_sub($HV);
    }

    # call $code_ref that needs to return a valid bucket name
    my $key = $code_ref->($match_ref);

    croak qq{Computed static bucket "$key" not found\n} if not $DISPATCH_TABLE->{$key} or 'CODE' ne ref $DISPATCH_TABLE->{$key};

    # call subroutine ref defined as the v in the k/v $DISPATCH_TABLE->{$key} slot
    my $sub_to_call = $DISPATCH_TABLE->{$key};

    # Reset before invoking the selected handler so one dispatch cannot leak
    # cases into the next call, even if the handler dies. C<cases> is intended
    # for introspection while the classification block is running.
    _reset_default_handler;

    return $sub_to_call->($match_ref);
}

# on accumulator: accepts a key/value pair where the key is a static case name and the value is a subroutine reference
sub on (@) {
    my ($key, $val) = @_;
    # Detect situations where "on" follows a semicolon instead of a comma.
    carp qq{Dispatch::Fu [warning]: "on $key" used in void context is always a mistake. The "on" method always follows a comma!} unless wantarray;
    return @_;
}

# if $case is in cases(), return $case; otherwise return $default
# Note: $default defaults to q{default}; i.e., if the name of the
# default case is not specified, the string 'default' is returned
sub xdefault($;$) {
    my ($case, $default) = @_;
    if (defined $case and grep { $_ eq $case } cases) {
        return $case;
    }
    return (defined $default) ? $default : q{default};
}

# for multi-assignment syntax, given the first reference in the parameter list; e.g., "my ($x, $y, $z) = ..."
sub xshift_and_deref(@) {
    return %{ +shift } if ref $_[0] eq q{HASH};
    return @{ +shift } if ref $_[0] eq q{ARRAY};
    return ${ +shift } if ref $_[0] eq q{SCALAR};
    return;
}

# utility sub to force a BLOCK into a sub reference
sub _to_sub (&) {
    shift;
}

1;

__END__

=pod

=head1 NAME

Dispatch::Fu - Compute a static key and dispatch to the corresponding Perl handler

=head1 SYNOPSIS

  use strict;
  use warnings;
  use Dispatch::Fu;

  my $input = [qw/1 2 3 4 5/];

  my $result = dispatch {
      my $values = shift;

      return scalar(@$values) > 5
        ? q{bucket5}
        : sprintf q{bucket%d}, scalar @$values;
  }
  $input,
    on bucket0 => sub { return q{bucket 0} },
    on bucket1 => sub { return q{bucket 1} },
    on bucket2 => sub { return q{bucket 2} },
    on bucket3 => sub { return q{bucket 3} },
    on bucket4 => sub { return q{bucket 4} },
    on bucket5 => sub { return q{bucket 5} };

  print "$result\n";    # bucket 5

C<Dispatch::Fu> exports C<dispatch>, C<on>, C<cases>, C<xdefault>, and
C<xshift_and_deref> by default. The same names are also available through
C<@EXPORT_OK>.

=head1 DESCRIPTION

C<Dispatch::Fu> provides a small, idiomatic layer around Perl's familiar
hash-based dispatch-table pattern. Instead of requiring the input value to
already be a suitable hash key, a C<dispatch> block computes a static key from
whatever input and application rules are appropriate. That key selects a
handler registered with C<on>.

This is useful when the decision depends on ranges, several values, request
metadata, normalization, or other logic that would otherwise grow into a long
C<if>/C<elsif> chain. The classification logic remains ordinary Perl; the
resulting action remains an ordinary hash-style dispatch.

For example, a traditional dispatch table works naturally when C<$action> is
already one of a fixed set of keys:

  my $handlers = {
      start => sub { ... },
      stop  => sub { ... },
  };

  die "Unsupported action\n"
    if not defined $action or not exists $handlers->{$action};

  my $result = $handlers->{$action}->();

C<Dispatch::Fu> adds a classification stage when the key must first be derived:

  my $result = dispatch {
      my $value = shift;

      return q{small}  if $value < 10;
      return q{medium} if $value < 100;
      return q{large};
  }
  $value,
    on small  => sub { ... },
    on medium => sub { ... },
    on large  => sub { ... };

The value passed to C<dispatch> is passed unchanged to both the classification
block and the selected handler.

=head1 API

=head2 dispatch BLOCK, INPUT, CASES

  my $result = dispatch {
      my $input = shift;
      return q{some_case};
  }
  $input,
    on some_case  => sub { ... },
    on other_case => sub { ... };

C<dispatch> coerces C<BLOCK> to a subroutine reference. The block receives the
single C<INPUT> scalar and must return the name of a registered case.

C<INPUT> can be any scalar value, including a reference. A reference is often
convenient when the classification decision needs several values:

  my $input = {
      method => q{POST},
      role   => q{admin},
  };

  my $result = dispatch {
      my $input = shift;

      return q{admin_post}
        if $input->{method} eq q{POST} and $input->{role} eq q{admin};

      return q{other};
  }
  $input,
    on admin_post => sub { ... },
    on other      => sub { ... };

The selected handler receives the original C<INPUT> scalar unchanged.
C<dispatch> returns whatever the handler returns and preserves the caller's
context. A handler may therefore return a scalar, a reference, a list, or any
other normal Perl return value.

  my @values = dispatch {
      return q{numbers};
  }
  undef,
    on numbers => sub { return qw/1 2 3 4 5/ };

If the classification block returns a key that is not registered to a C<CODE>
reference, C<dispatch> throws an exception with C<croak>.

Each call to C<dispatch> starts with a fresh internal dispatch table. Cases from
a previous successful or failed dispatch are never carried into the next call.

=head2 on KEY => CODEREF

  on start => sub { ... }

C<on> contributes a static case name and handler to the current C<dispatch>
call. The handler must be a C<CODE> reference.

The C<on> expressions are part of the argument list to C<dispatch>, so they
must be separated with commas. Accidentally ending one with a semicolon moves
C<on> into void or scalar context. C<Dispatch::Fu> detects that common mistake
and emits a warning with C<carp>.

  my $result = dispatch {
      return q{start};
  }
  $input,
    on start => sub { ... },
    on stop  => sub { ... };

=head2 cases

  my @cases = cases;

C<cases> returns the currently registered case names as a sorted list.

During the C<dispatch> classification block, the list contains all cases
registered by C<on> plus the built-in C<default> case. This makes C<cases>
useful for introspection while deciding which key to return:

  my $result = dispatch {
      my $candidate = shift;
      my %supported = map { $_ => 1 } cases;

      return $supported{$candidate} ? $candidate : q{default};
  }
  $action,
    on default => sub { ... },
    on start   => sub { ... },
    on stop    => sub { ... };

The internal table is reset before the selected handler is invoked. Therefore,
outside the classification block, including from inside a selected handler,
C<cases> reflects only the built-in C<default> case. This reset is deliberate:
it keeps one dispatch operation isolated from the next, even when an earlier
operation fails.

=head2 xdefault CASE, [DEFAULT]

  my $key = xdefault $candidate;
  my $key = xdefault $candidate, q{not_found};

C<xdefault> is a shortcut for the common case where the candidate value itself
should be used as the dispatch key when it exactly matches one of the currently
registered cases.

Matching is literal string equality, not substring or regular-expression
matching. False-but-defined keys such as C<"0"> are valid case names.

If C<CASE> is undefined or does not exactly match a registered case,
C<xdefault> returns C<DEFAULT>. When C<DEFAULT> is omitted, it returns the
string C<default>.

It is particularly convenient as the last expression in a classification
block:

  my $result = dispatch {
      xdefault shift;
  }
  $action,
    on default => sub { ... },
    on start   => sub { ... },
    on stop    => sub { ... };

A custom fallback key works the same way:

  my $result = dispatch {
      xdefault shift, q{not_found};
  }
  $action,
    on not_found => sub { ... },
    on start     => sub { ... },
    on stop      => sub { ... };

=head2 xshift_and_deref LIST

  my ($x, $y, $z) = xshift_and_deref @_;

C<xshift_and_deref> removes common unpacking boilerplate when C<INPUT> is a
reference. It examines the first value in C<LIST>, shifts it, and dereferences
it according to its reference type.

It supports C<HASH>, C<ARRAY>, and C<SCALAR> references:

  my @values = xshift_and_deref \@array;
  my %values = xshift_and_deref \%hash;
  my $value  = xshift_and_deref \$scalar;

For unsupported reference types or non-reference values, it returns C<undef>
in scalar context (or an empty list in list context).

A typical dispatch using an array reference can be written as:

  my $result = dispatch {
      my ($left, $right) = xshift_and_deref @_;
      return $left > $right ? q{left} : q{right};
  }
  [ $left, $right ],
    on left => sub {
        my ($left, $right) = xshift_and_deref @_;
        return $left;
    },
    on right => sub {
        my ($left, $right) = xshift_and_deref @_;
        return $right;
    };

=head1 EXAMPLES

=head2 Dispatching on several conditions

The classification block can combine as many inputs as needed while still
reducing the final action to a small set of static keys:

  my $job = {
      priority => 9,
      retries  => 0,
      enabled  => 1,
  };

  my $result = dispatch {
      my $job = shift;

      return q{disabled} if not $job->{enabled};
      return q{urgent}   if $job->{priority} >= 8 and $job->{retries} < 2;
      return q{normal};
  }
  $job,
    on disabled => sub { ... },
    on urgent   => sub { ... },
    on normal   => sub { ... };

=head2 CGI::Tiny request dispatch

C<Dispatch::Fu> can also provide a compact routing layer for a small CGI
application. C<CGI::Tiny> exposes the request method and path directly, while
C<Dispatch::Fu> reduces those values to a static handler name. The original
C<CGI::Tiny> object is then passed to the selected handler.

  #!/usr/bin/env perl
  use strict;
  use warnings;
  use CGI::Tiny;
  use Dispatch::Fu;

  cgi {
      my $cgi = $_;

      dispatch {
          my $cgi = shift;
          my $method = $cgi->method;
          my $path   = $cgi->path;

          return q{home}
            if $method eq q{GET} and $path eq q{/};

          return q{create_item}
            if $method eq q{POST} and $path eq q{/item};

          return q{not_found};
      }
      $cgi,
        on home => sub {
            my $cgi = shift;
            return $cgi->render(html => q{<h1>Home</h1>});
        },
        on create_item => sub {
            my $cgi = shift;
            my $name = $cgi->param(q{name});
            return $cgi->render(text => qq{created: $name});
        },
        on not_found => sub {
            my $cgi = shift;
            $cgi->set_response_status(404);
            return $cgi->render(text => q{Not Found});
        };
  };

This is not intended to replace a full routing framework. It is useful when a
small CGI program already has a modest, static set of actions and the route or
action key needs to be computed from several pieces of request state.

=head1 DEFAULT HANDLER

Every dispatch table contains an internal C<default> handler. If a
classification block returns C<default> and the caller has not supplied its
own C<on default =E<gt> ...> handler, the built-in handler warns with
C<carp> and prints the currently supported case names.

Applications normally provide their own C<default> handler when default
behavior is expected:

  my $result = dispatch {
      xdefault shift;
  }
  $action,
    on default => sub { return q{unsupported} },
    on start   => sub { return q{started} };

=head1 DIAGNOSTICS

C<Dispatch::Fu> uses C<Carp> so diagnostics are reported from the caller's
perspective.

=over 4

=item * No cases supplied

Calling C<dispatch> without any C<on> cases throws an exception with C<croak>.
This often indicates that a semicolon ended the argument list too early.

=item * Unsupported or invalid computed key

If the classification block returns a key that is not mapped to a C<CODE>
handler, C<dispatch> throws an exception with C<croak>.

=item * C<on> used in void or scalar context

C<on> emits a warning with C<carp>. This is commonly caused by using a
semicolon where the C<dispatch> argument list required a comma.

=back

=head1 STABILITY

C<Dispatch::Fu> is maintained as production code with a deliberately small
public API and core-only runtime dependencies. Changes should preserve existing
calling conventions and the lightweight nature of the module. The test suite
covers normal dispatch, defaults, introspection, diagnostics, return context,
reference unpacking, invalid handlers, state isolation, and false-but-valid
case keys.

=head1 BUGS

Please report bugs and feature ideas through the project issue tracker.

=head1 AUTHOR

O. ODLER 558 L<< <oodler@cpan.org> >>.

=head1 LICENSE AND COPYRIGHT

Same terms as Perl itself.

=cut

