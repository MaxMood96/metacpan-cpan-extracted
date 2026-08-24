package Punk::Kit::Fakekit;

# t/1300 and t/1311's kit-seam fixture: `punk new X --kit fakekit` loads this
# and generates through it. It does the three things a real kit does - declares
# options, renders from its own skeleton, and overrides one of Punk's templates
# by name - and nothing else.

use strict;
use warnings;
use parent 'Punk::Generate';

sub abstract { 'a test fixture' }

sub options {
    return ( { spec => 'shout', doc => 'upper case the note' } );
}

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{shout} = $args{shout} ? 1 : 0;
    return $self;
}

sub run {
    my ($self) = @_;
    $self->SUPER::run;
    my $note = 'kit was here';
    $self->_render('kit_note.tmpl', 'KIT.txt',
                   { note => $self->{shout} ? uc $note : $note });
    return $self->written;
}

sub next_steps { return "\n  cd $_[0]{dir}\n  the kit said so\n" }

1;
