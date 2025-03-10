package Daje::Workflow::Database::Model::Workflow;
use Mojo::Base -base, -signatures;

# NAME
#
# Daje::Workflow::Database::Model::Workflow
#
#
# REQUIRES
# ========
#
# Mojo::Base>
#
#
# METHODS
#
#  load($self)
#
#  save();
#
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



has 'db';
has 'workflow_pkey';
has 'workflow';

sub load($self) {

    my $result = $self->_load();
    unless (defined $result) {
        my $data->{name} = $self->workflow();
        $data->{state} = 'INITIAL';
        $data->{workflow_pkey} = 0;
        my $workflow_pkey = $self->save($data);
        $self->workflow_pkey($workflow_pkey);
        $result = $self->_load();
    }
    return $result;
}

sub _load($self) {
    my $data = $self->db->select(
        'workflow', ['*'],
        {
            workflow_pkey => $self->workflow_pkey
        }
    );

    my $hash;
    $hash = $data->hash if $data->rows > 0;

    return $hash;
}

sub save ($self, $data) {
    my $workflow_pkey;
    $data->{workflow_pkey} = 0 unless exists $data->{workflow_pkey};
    if ($data->{workflow_pkey} > 0) {
        $self->db->update(
            'workflow',
            {
                %$data
            },
            {
                workflow_pkey => $data->{workflow_pkey}
            }
        )
    } else {
        delete %$data{workflow_pkey};
        $workflow_pkey = $self->db->insert(
            'workflow',
                {
                    %$data
                },
                {
                    returning => 'workflow_pkey'
                }
        )->hash->{workflow_pkey}
    }

    return $workflow_pkey;
}
1;
















#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

Daje::Workflow::Database::Model::Workflow


=head1 DESCRIPTION

NAME

Daje::Workflow::Database::Model::Workflow




=head1 REQUIRES


Mojo::Base>


METHODS

 load($self)

 save();




=head1 METHODS

=head2 load($self)

 load($self)();

=head2 save

 save();


=head1 AUTHOR


janeskil1525 E<lt>janeskil1525@gmail.comE<gt>



=head1 LICENSE


Copyright (C) janeskil1525.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.



=cut

