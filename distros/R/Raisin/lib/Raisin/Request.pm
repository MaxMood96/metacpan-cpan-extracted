#!perl
#PODNAME: Raisin::Request
#ABSTRACT: Request class for Raisin.

use strict;
use warnings;

package Raisin::Request;
$Raisin::Request::VERSION = '0.94';
use parent 'Plack::Request';

sub prepare_params {
    my ($self, $declared, $named) = @_;

    $self->{'raisin.declared'} = $declared;

    # PRECEDENCE:
    #   - path
    #   - query
    #   - body
    my %params = (
        %{ $self->env->{'raisinx.body_params'} || {} },
        %{ $self->query_parameters->as_hashref_mixed || {} },
        %{ $named || {} },
    );

    $self->{'raisin.parameters'} = \%params;

    my $retval = 1;

    foreach my $p (@$declared) {
        my $name = $p->name;
        my $value = $params{$name};

        if (not $p->validate(\$value)) {
            $retval = 0;
            $p->required ? return : next;
        }

        $value //= $p->default if defined $p->default;
        next if not defined($value);

        $self->{'raisin.declared_params'}{$name} = $value;
    }

    $retval;
}

sub declared_params { shift->{'raisin.declared_params'} }
sub raisin_parameters { shift->{'raisin.parameters'} }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Raisin::Request - Request class for Raisin.

=head1 VERSION

version 0.94

=head1 SYNOPSIS

    Raisin::Request->new($self, $env);

=head1 DESCRIPTION

Extends L<Plack::Request>.

=head1 METHODS

=head3 declared_params

=head3 prepare_params

=head3 raisin_parameters

=head1 AUTHOR

Artur Khabibullin

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Artur Khabibullin.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
