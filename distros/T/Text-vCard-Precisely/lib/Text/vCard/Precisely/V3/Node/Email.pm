package Text::vCard::Precisely::V3::Node::Email;

use Carp;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Email qw/EmailAddress/;

extends 'Text::vCard::Precisely::V3::Node';

has name    => ( is => 'ro', default => 'EMAIL', isa => 'Str' );
has content => ( is => 'ro', default => '',      isa => EmailAddress );

has preferred => ( is => 'rw', default => 0, isa => 'Bool' );

subtype 'EmailType' => as 'Str' => where {
    m/^(?:work|home)$/s or    # common
        m/^(?:contact|acquaintance|friend|met|co-worker|colleague|co-resident|neighbor|child|parent|sibling|spouse|kin|muse|crush|date|sweetheart|me|agent|emergency)$/is # 本当にこれでいのか怪しい
} => message {"The Email you provided, $_, was not supported in 'Type'"};

subtype 'EmailTypes' => as 'ArrayRef[EmailType]';
coerce 'EmailTypes'  => from 'Str' => via { [$_] };
has types            => ( is => 'rw', isa => 'EmailTypes', default => sub { [] }, coerce => 1 );

override 'as_string' => sub {
    my ($self) = @_;
    my @lines;
    push @lines, $self->name() || croak "Empty name";
    push @lines, 'ALTID=' . $self->altID() if $self->can('altID') and $self->altID();
    push @lines, 'PID=' . join ',', @{ $self->pid() } if $self->can('pid') and $self->pid();

    my @types = map {uc} grep {length} @{ $self->types() };
    push @types, 'PREF' if $self->preferred();
    my $types = 'TYPE="' . join( ',', @types ) . '"' if @types;
    push @lines, $types if $types;

    my $string = join( ';', @lines ) . ':' . $self->content();
    return $self->fold( $string, -force => 1 );
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
