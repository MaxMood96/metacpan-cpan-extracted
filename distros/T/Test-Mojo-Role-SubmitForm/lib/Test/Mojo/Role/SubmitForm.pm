package Test::Mojo::Role::SubmitForm;

use Mojo::Base -base;
use Role::Tiny;
use Carp qw/croak/;

our $VERSION = '1.004004'; # VERSION

sub click_ok {
    my ( $self, $selector_or_dom, $extra_params ) = @_;
    $extra_params ||= {};

    my $el = eval { $selector_or_dom->isa('Mojo::DOM') }
        ? $selector_or_dom
        : $self->tx->res->dom->at($selector_or_dom)
            || croak 'Test::Mojo::Role::SubmitForm::click_ok()'
                . " Did not find element matching selector $selector_or_dom";
    unless ( $el->tag eq 'form' ) {
        if (length $el->{name}) {
            if ( ($el->{type}//'') eq 'image' ) {
                $extra_params->{ $el->{name} . '.x' } = 1;
                $extra_params->{ $el->{name} . '.y' } = 1;
            }
            else {
                $extra_params->{ $el->{name} } = $el->val;
            }
        }

        $el = $el->ancestors('form')->first;
    }

    for ( sort keys %$extra_params ) {
        next unless ref $extra_params->{$_} eq 'CODE';
        ( my $name = $_ ) =~ s/"/\\"/g;
        $extra_params->{$_} = $extra_params->{$_}->(
            $self->_gather_vals( $el->find(qq{[name="$name"]})->each )
        );
    }

    my %form = (
        $self->_get_controls($el),
        %$extra_params,
    );
    for (keys %form) {
        delete $form{$_} unless defined $form{$_}
    }

    if ( $ENV{MOJO_SUBMITFORM_DEBUG} ) {
        warn "\n########## SUBMITTING FORM ##########\n";
        require Mojo::Util;
        warn Mojo::Util::dumper(\%form);
        warn "##########    END FORM     ##########\n\n";
    }

    my $tx = $self->ua->build_tx(
        $el->{method}||'GET' => defined $el->{action} && $el->{action} ne '' ? $el->{action} : $self->tx->req->url
            => form => \%form,
    );

    $self->request_ok( $tx );
}

sub _gather_vals {
    my ( $self, @els ) = @_;
    my @vals;
    for ( @els ) {
        next if $_
        ->matches('[type=radio]:not(:checked), [type=checkbox]:not(:checked)');

        defined( my $val = $_->val ) or next;
        push @vals, ref $val ? @$val : $val;
    }
    return @vals == 1 ? $vals[0] : @vals ? \@vals : undef;
}

sub _get_controls {
    my ( $self, $form ) = @_;

    my @els = $form->find(
        'input:not([type=button]):not([type=submit]):not([type=image]):not([disabled]),' .
        'select:not([disabled]),' .
        'textarea:not([disabled])'
    )->each;

    # remove controls defined in templates
    @els = grep { $_->ancestors('template')->size() == 0 } @els;

    my %controls;
    for ( @els ) {
        defined(my $vals = $self->_gather_vals( $_ )) or next;
        push @{ $controls{$_->{name}} }, ref $vals ? @$vals : $vals;
    }
    $#$_ or $_= $_->[0] for values %controls; # chage 1-el arrayrefs to strings

    return %controls;
}

q|
The fantastic element that explains the appeal of games to
many developers is neither the fire-breathing monsters nor the
milky-skinned, semi-clad sirens; it is the experience of
carrying out a task from start to finish without any change
in the user requirements.
|;

__END__

=encoding utf8

=for stopwords Znet Zoffix app  Subrefs subrefs ENV VARS

=head1 NAME

Test::Mojo::Role::SubmitForm - Test::Mojo role that allows to submit forms

=head1 SYNOPSIS

=for html  <div style="display: table; height: 91px; background: url(http://zoffix.com/CPAN/Dist-Zilla-Plugin-Pod-Spiffy/icons/section-code.png) no-repeat left; padding-left: 120px;" ><div style="display: table-cell; vertical-align: middle;">

    use Test::More;
    use Test::Mojo::WithRoles 'SubmitForm';
    my $t = Test::Mojo::WithRoles->new('MyApp');

    # Submit a form without clicking any buttons: pass selector to the form
    $t->get_ok('/')->status_is(200)->click_ok('form#one')->status_is(200);

    # Click a particular button
    $t->get_ok('/')->status_is(200)->click_ok('[type=submit]')->status_is(200);

    # Submit a form while overriding form data
    $t->get_ok('/')->status_is(200)
        ->click_ok('form#one', {
            input1        => '42',
            select1       => [ 1..3 ],
            other_select  => sub { my $r = shift; [ @$r, 42 ] },
            another_input => sub { shift . 'offix'}
        })->status_is(200);

    done_testing;

=for html  </div></div>

=head1 DESCRIPTION

A L<Test::Mojo> role that allows you submit forms, optionally overriding
any of the values already present

=head1 METHODS

You have all the methods provided by L<Test::Mojo>, plus these:

=head2 C<click_ok>

    $t->click_ok('form');
    $t->click_ok('#button');

    $t->click_ok( $dom->at('form') );

    $t->click_ok('#button', {
        input1        => '42',
        select1       => [ 1..3 ],
        remove_me     => undef,
        other_select  => sub { my $r = shift; [ @$r, 42 ] },
        another_input => sub { shift . 'offix'}
    })

First parameter specifies a CSS selector matching or L<Mojo::DOM> object
containing C<< <form> >> you want to
submit or a particular C<< <button> >>, C<< <input type="submit"> >>,
or C<< <input type="image"> >> (contained in a C<< <form> >>)
you want to click.

Specifying a second parameter allows you to override the form control values:
the keys are C<name="">s of controls to override and values can be either
plain scalars (use arrayrefs for multiple values) or subrefs. Subrefs
will be evaluated and their first C<@_> element will be the current value
of the form control. Use C<undef> as value to remove form's parameter.

=head1 DEBUGGING / ENV VARS

To see what form data is being submitted, set C<MOJO_SUBMITFORM_DEBUG>
environmental variable to a true value:

    MOJO_SUBMITFORM_DEBUG=1 prove -vlr t/02-app.t

Sample output:

    ok 36 - GET /
    ok 37 - 200 OK

    ########## SUBMITTING FORM ##########
    {
      "\$\"bar" => 5,
      "a" => 42,
      "b" => "B",
      "e" => "Zoffix",
      "mult_b" => [
        "C",
        "D",
        "E"
      ],
      "\x{a9}\x{263a}\x{2665}" => 55
    }
    ##########    END FORM     ##########

    [Wed Sep 23 17:34:00 2015] [debug] POST "/test"

=head1 CAVEATS

Note that you cannot override the value of buttons you're clicking on.
In those cases, simply "click" the form itself, while passing the new values
for buttons.

=head1 SEE ALSO

L<Test::Mojo>, L<Mojo::DOM>

=for html <div style="background: url(http://zoffix.com/CPAN/Dist-Zilla-Plugin-Pod-Spiffy/icons/hr.png);height: 18px;"></div>

=head1 REPOSITORY

=for html  <div style="display: table; height: 91px; background: url(http://zoffix.com/CPAN/Dist-Zilla-Plugin-Pod-Spiffy/icons/section-github.png) no-repeat left; padding-left: 120px;" ><div style="display: table-cell; vertical-align: middle;">

Fork this module on GitHub:
L<https://github.com/zoffixznet/Test-Mojo-Role-SubmitForm>

=for html  </div></div>

=head1 BUGS

=for html  <div style="display: table; height: 91px; background: url(http://zoffix.com/CPAN/Dist-Zilla-Plugin-Pod-Spiffy/icons/section-bugs.png) no-repeat left; padding-left: 120px;" ><div style="display: table-cell; vertical-align: middle;">

To report bugs or request features, please use
L<https://github.com/zoffixznet/Test-Mojo-Role-SubmitForm/issues>

If you can't access GitHub, you can email your request
to C<bug-test-mojo-role-SubmitForm at rt.cpan.org>

=for html  </div></div>

=head1 AUTHOR

=for html  <div style="display: table; height: 91px; background: url(http://zoffix.com/CPAN/Dist-Zilla-Plugin-Pod-Spiffy/icons/section-author.png) no-repeat left; padding-left: 120px;" ><div style="display: table-cell; vertical-align: middle;">

=for html   <span style="display: inline-block; text-align: center;"> <a href="http://metacpan.org/author/ZOFFIX"> <img src="http://www.gravatar.com/avatar/328e658ab6b08dfb5c106266a4a5d065?d=http%3A%2F%2Fwww.gravatar.com%2Favatar%2F627d83ef9879f31bdabf448e666a32d5" alt="ZOFFIX" style="display: block; margin: 0 3px 5px 0!important; border: 1px solid #666; border-radius: 3px; "> <span style="color: #333; font-weight: bold;">ZOFFIX</span> </a> </span>

=for html  </div></div>

=head1 CONTRIBUTORS

=for html  <div style="display: table; height: 91px; background: url(http://zoffix.com/CPAN/Dist-Zilla-Plugin-Pod-Spiffy/icons/section-contributors.png) no-repeat left; padding-left: 120px;" ><div style="display: table-cell; vertical-align: middle;">

L<Guillaume "guillomovitch" Rousse|https://github.com/guillomovitch>

=for html   <span style="display: inline-block; text-align: center;"> <a href="http://metacpan.org/author/PLICEASE"> <img src="http://www.gravatar.com/avatar/0640fb1c0a5e82f5a777f2306efcac77?d=http%3A%2F%2Fwww.gravatar.com%2Favatar%2F0640fb1c0a5e82f5a777f2306efcac77" alt="PLICEASE" style="display: block; margin: 0 3px 5px 0!important; border: 1px solid #666; border-radius: 3px; "> <span style="color: #333; font-weight: bold;">PLICEASE</span> </a> </span>

=for html  </div></div>

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut
