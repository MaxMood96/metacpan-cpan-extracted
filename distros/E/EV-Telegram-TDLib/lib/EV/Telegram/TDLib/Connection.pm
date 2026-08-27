package EV::Telegram::TDLib::Connection;

use strict;
use warnings;

our $VERSION = '0.02';

sub CLONE_SKIP { 1 }

our %UPDATES = (
    updateConnectionState => \&_update_connection_state,
    updateOption          => \&_update_option,
);

# TDLib pushes its options as updates, my_id among them right after login,
# so the account's own id is known without a getMe round trip
sub _update_option {
    my ($self, $obj) = @_;
    my $name = $obj->{name};
    return unless defined $name;
    my $v = $obj->{value} // {};
    my $type = $v->{'@type'} // '';
    $self->{cache}{options}{$name} =
          $type eq 'optionValueEmpty' ? undef
        : $type eq 'optionValueBoolean' ? ($v->{value} ? 1 : 0)
        : $v->{value};
}

sub option {
    my ($self, $name) = @_;
    return $self->{cache}{options}{$name};
}

sub my_id { $_[0]{cache}{options}{my_id} }

sub _update_connection_state {
    my ($self, $obj) = @_;
    my $state = $obj->{state} or return;
    my $type = $state->{'@type'} // '';
    return unless length $type;
    $self->{cache}{connection_state} = $type;
    if (my $cb = $self->{on_connection_state}) { $cb->($type) }
}

sub connection_state { $_[0]{cache}{connection_state} }

sub on_connection_state {
    my ($self, $cb) = @_;
    $self->{on_connection_state} = $cb if $cb;
    return $self->{on_connection_state};
}

1;
