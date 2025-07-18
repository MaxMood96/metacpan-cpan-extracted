package Daje::Controller::Signup;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use v5.40;

# NAME
# ====
#
# Daje::Controller::Signup - It's new $module
#
# SYNOPSIS
# ========
#
#     use Daje::Controller::Signup;
#
# DESCRIPTION
# ===========
#
# Daje::Controller::Signup is ...
#
# LICENSE
# =======
#
# Copyright (C) janeskil1525.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# AUTHOR
# ======
#
# janeskil1525 E<lt>janeskil1525@gmail.comE<gt>
#

use Mojo::JSON qw{ decode_json };
use Data::Dumper;

our $VERSION = "0.04";

sub signup($self) {

    my $data->{context} = decode_json ($self->req->body);

    say Dumper($data);
    $self->workflow->context($data);
    $self->workflow->workflow_name("new_client");

    $self->workflow->process('new_client');

    if ($self->workflow->error->has_error() == 1) {
        my $error = $self->workflow->error->error();
        $self->render(
            json =>
            {
                result => 'failure',
                error => "Signup failed '$error'"
            }
        );
    } else {
        $self->render(json => { result => 'success'});
        say 'Success';
    }
}

1;

__END__






#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME


Daje::Controller::Signup - It's new $module



=head1 SYNOPSIS


    use Daje::Controller::Signup;



=head1 DESCRIPTION


Daje::Controller::Signup is ...



=head1 REQUIRES

L<Data::Dumper> 

L<Mojo::JSON> 

L<v5.40> 

L<Mojo::Base> 


=head1 METHODS

=head2 signup($self)

 signup($self)();


=head1 AUTHOR


janeskil1525 E<lt>janeskil1525@gmail.comE<gt>



=head1 LICENSE


Copyright (C) janeskil1525.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.



=cut

