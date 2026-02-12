package Concierge::Sessions::Base v0.8.4;
use v5.36;

sub new {
    my ($class, %args) = @_;
    return bless {}, $class;
}

# Define interface methods that must be implemented by subclasses
sub create_session { die "Subclass must implement create_session" }
sub get_session_info { die "Subclass must implement get_session_info" }
sub update_session { die "Subclass must implement update_session" }
sub delete_session { die "Subclass must implement delete_session" }
sub cleanup_sessions { die "Subclass must implement cleanup_sessions" }
sub delete_user_session { die "Subclass must implement delete_user_session" }

# Utilities
sub generate_session_id {
    my $uuid = qx(uuidgen 2>/dev/null);
    if ($? == 0 and defined $uuid) {
        chomp $uuid;
        return lc $uuid;
    }
    # Fallback: UUID v4-like random token
    my $pseudo_uuid = sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        rand(0x10000), rand(0x10000),  # 8 hex digits
        rand(0x10000),                  # 4 hex digits
        (rand(0x10000) & 0x0fff) | 0x4000,  # 4 hex digits, version 4
        (rand(0x10000) & 0x3fff) | 0x8000,  # 4 hex digits, variant bits
        rand(0x10000), rand(0x10000), rand(0x10000)  # 12 hex digits
    );
    return lc $pseudo_uuid;
}

1;

__END__

=head1 NAME

Concierge::Sessions::Base - Base class for session storage backends

=head1 VERSION

version 0.8.4

=head1 SYNOPSIS

    # This is a base class - do not use directly
    # Backend implementations inherit from this class:

    package Concierge::Sessions::MyBackend;
    use parent 'Concierge::Sessions::Base';

    sub create_session {
        my ($self, %args) = @_;
        # Implementation...
    }

    # Implement other required methods...

=head1 DESCRIPTION

Concierge::Sessions::Base is a base class that defines the interface for
session storage backends. Backend implementations (SQLite, File) inherit
from this class and must implement the defined methods.

This class also provides utility methods such as generate_session_id().

Users typically do not interact with this class directly - they use
Concierge::Sessions which manages backend objects internally.

=head1 REQUIRED METHODS

Backend implementations must implement the following methods:

=head2 create_session

Creates a new session in the backend storage.

    my $result = $backend->create_session(
        user_id         => 'user123',
        session_timeout => 3600,
        data            => \%session_data,
    );

Must return:

    {
        success => 1,
        session_id => 'uuid-string',
    }

=head2 get_session_info

Retrieves session information from backend storage.

    my $result = $backend->get_session_info($session_id);

Must return:

    {
        success => 1,
        info => {
            session_id      => 'uuid',
            user_id         => 'user123',
            session_timeout => 3600,
            data            => \%data,
            created_at      => $timestamp,
            expires_at      => $timestamp,
            last_updated    => $timestamp,
            status          => { state => 'active', dirty => 0 },
        },
    }

Or on error:

    {
        success => 0,
        message => "Error description",
    }

=head2 update_session

Updates session data and metadata in backend storage.

    my $result = $backend->update_session(
        $session_id,
        {
            data       => \%new_data,
            expires_at => $new_expiration,
        },
    );

Must return:

    {
        success => 1,
    }

Or on error:

    {
        success => 0,
        message => "Error description",
    }

=head2 delete_session

Deletes a session from backend storage.

    my $result = $backend->delete_session($session_id);

Must return:

    {
        success => 1,
        message => "Session deleted",
    }

=head2 cleanup_sessions

Removes all expired sessions from backend storage.

    my $result = $backend->cleanup_sessions();

Must return:

    {
        success => 1,
        deleted_count => 15,
    }

=head2 delete_user_session

Deletes all sessions for a specific user from backend storage.

    my $result = $backend->delete_user_session($user_id);

Must return:

    {
        success => 1,
        deleted_count => 3,
    }

=head1 UTILITY METHODS

=head2 generate_session_id

Generates a unique session ID using UUID v4 format.

    my $uuid = $backend->generate_session_id();

Returns: Lowercase UUID string such as 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'.

This method attempts to use the system's C<uuidgen> command if available,
with a fallback to a Perl-based UUID v4 generator.

=head1 SEE ALSO

L<Concierge::Sessions::SQLite> - SQLite backend implementation

L<Concierge::Sessions::File> - File backend implementation

L<Concierge::Sessions> - Session manager

=head1 AUTHOR

Bruce Van Allen <bva@cruzio.com>

=head1 LICENSE

Artistic License 2.0

=cut
