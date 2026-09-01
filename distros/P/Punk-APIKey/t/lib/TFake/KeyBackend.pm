package TFake::KeyBackend;

# A second in-memory backend, for the api_keys and users tables. Separate from
# TFake::Backend because a Punk application has one backend class per
# `database` declaration and these tests need two tables in one application.
#
# Keyed by id rather than name, and it assigns ids on create the way a
# bigserial column would - which the plugin relies on to hand back a row it
# can revoke.

use strict;
use warnings;

our @KEYS;          # api_keys rows
our @USERS;         # users rows
our $KEY_CALLS  = 0;
our $USER_CALLS = 0;
our $NEXT_ID    = 1;
our $DIE_KEYS   = 0;
our $DIE_USERS  = 0;

sub reset_all {
    @KEYS = (); @USERS = ();
    $KEY_CALLS = $USER_CALLS = 0; $NEXT_ID = 1;
    $DIE_KEYS = $DIE_USERS = 0;
    return;
}

sub keys_rows   { \@KEYS }
sub users_rows  { \@USERS }
sub key_calls   { $KEY_CALLS }
sub user_calls  { $USER_CALLS }
sub reset_calls { $KEY_CALLS = $USER_CALLS = 0; return }
sub set_users   { shift; @USERS = @_; return }
sub die_keys    { shift; $DIE_KEYS = $_[0]; return }
sub die_users   { shift; $DIE_USERS = $_[0]; return }

# Punk hands a backend `database`, `table`, `primary` and `columns` at
# construction (xs/model.xs:132-141), so which table this instance serves is
# known here rather than guessed per call.
sub new {
    my ($class, %o) = @_;
    return bless { table   => $o{table}   || '',
                   primary => $o{primary} || 'id' }, $class;
}

sub _store {
    my ($self) = @_;
    return (\@USERS, \$USER_CALLS, \$DIE_USERS)
        if $self->{table} eq 'users';
    return (\@KEYS, \$KEY_CALLS, \$DIE_KEYS);
}

sub _match {
    my ($self, $row, %key) = @_;
    for my $f (keys %key) {
        my $want = $key{$f};
        return 0 unless defined $row->{$f} && defined $want;
        return 0 unless "$row->{$f}" eq "$want";
    }
    return 1;
}

sub get {
    my ($self, %key) = @_;
    my ($rows, $calls, $die) = $self->_store;
    $$calls++;
    die "the database is away\n" if $$die;
    for my $r (@$rows) { return { %$r } if $self->_match($r, %key) }
    return undef;
}

sub search {
    my ($self, $filter, $opts) = @_;
    my ($rows, $calls, $die) = $self->_store;
    $$calls++;
    die "the database is away\n" if $$die;
    my @out = grep { $self->_match($_, %{ $filter || {} }) } @$rows;
    return { rows => [ map { +{ %$_ } } @out ], has_more_data => 0,
             next => undef };
}

sub count {
    my ($self, $filter) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    return scalar grep { $self->_match($_, %{ $filter || {} }) } @$rows;
}

sub all {
    my ($self) = @_;
    return $self->search({}, {});
}

sub create {
    my ($self, $data) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    my %row = %$data;
    $row{id} = $NEXT_ID++ unless defined $row{id};
    push @$rows, \%row;
    return { %row };
}

sub update {
    my ($self, $data) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    for my $r (@$rows) {
        next unless defined $r->{id} && defined $data->{id}
                 && "$r->{id}" eq "$data->{id}";
        %$r = ( %$r, %$data );
        return { %$r };
    }
    return undef;
}

sub delete {
    my ($self, %key) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    my $before = @$rows;
    @$rows = grep { !$self->_match($_, %key) } @$rows;
    return $before - @$rows;
}

1;
