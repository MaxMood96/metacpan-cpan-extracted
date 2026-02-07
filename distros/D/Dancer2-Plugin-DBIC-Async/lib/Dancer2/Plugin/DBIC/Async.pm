package Dancer2::Plugin::DBIC::Async;

$Dancer2::Plugin::DBIC::Async::VERSION   = '0.06';
$Dancer2::Plugin::DBIC::Async::AUTHORITY = 'cpan:MANWAR';

use strict;
use warnings;
use feature 'state';

use Dancer2::Plugin;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;
use Module::Runtime qw(use_module);

=encoding utf8

=head1 NAME

Dancer2::Plugin::DBIC::Async - High-concurrency DBIx::Class bridge for Dancer2

=head1 VERSION

Version 0.06

=head1 BENEFITS

The primary benefit of this plugin is B<Concurrency Throughput>. Unlike traditional
database plugins that block your Dancer2 worker during a query, this plugin
delegates I/O to a background worker pool.

=head2 Non-Blocking I/O (Concurrency)

In a traditional sync app, if a database query takes B<500ms>, that L<Dancer2>
worker is B<"busy"> and cannot accept any other incoming requests for that
B<half a second>.

=over 4

=item Sync

B<10 workers> can handle exactly B<10 simultaneous long-running queries>. The
11th user must wait in the B<TCP queue>.

=item Async

A single worker can initiate dozens of database queries. While the database is
processing the data, the worker remains free to handle other incoming requests
or perform other I/O tasks.

=back

=head2 Parallelism within a Single Route

With the sync plugin, if you need to fetch data from five different tables that don't depend on
each other, you must do them sequentially. With the async plugin, you can fire all five queries
simultaneously.

    # Regular Sync (Total time = sum of all queries)
    my $user    = rset('User')->find(1);
    my $posts   = rset('Post')->search({ uid => 1 });
    my $friends = rset('Friend')->search({ uid => 1 });

    # Async (Total time = the time of the single slowest query)
    my $user_f    = async_rs('User')->find(1);
    my $posts_f   = async_rs('Post')->search({ uid => 1 });
    my $friends_f = async_rs('Friend')->search({ uid => 1 });

    # Wait for all to finish
    my ($user, $posts, $friends) = Future->wait_all($user_f, $posts_f, $friends_f)->get;

=head2 Key Technical Differences

=over 4

=item B<Context Switching>

In the sync version, the operating system might pause the process (context switch)
while waiting for the disk. In the async version, the Event Loop (L<IO::Async>) manages
this, which is much lighter on the CPU.

=item B<Wait vs. Block>

In the async version, we use B<wait_all> or B<then>. This tells the server:
B<"Keep this request in mind, but go help other users until the data comes back.">

=item B<Error Handling>

L<Futures> have built-in B<on_fail> handlers, making it easier to manage database
timeouts without crashing the whole worker process.

=back

=head2 Better Resource Utilisation

Sync apps often solve scaling issues by adding more worker processes (e.g., increasing B<Starman> workers).
However, each worker consumes significant B<RAM>.

=over 4

=item Sync Scaling

High Memory usage (100 workers = 100x memory).

=item Async Scaling

Low Memory usage (1 worker handles 100 connections).

=back

=head1 SYNOPSIS

    # In config.yml
    plugins:
      "DBIC::Async":
        default:
          schema_class: "MyApp::Schema"
          dsn: "dbi:SQLite:dbname=myapp.db"
          async:
            workers: 4

    # In your Dancer2 app
    use Dancer2;
    use Dancer2::Plugin::DBIC::Async;
    use Future;

    # Basic non-blocking count
    get '/count' => sub {
        my $count = async_count('User')->get;
        return to_json({ total_users => $count });
    };

    # Advanced: Parallel queries (non-blocking)
    get '/dashboard' => sub {
        my $query = query_parameters->get('q');

        # 1. Fire multiple queries simultaneously
        my $search_f = async_search('User', { name => { -like => "%$query%" } });
        my $count_f  = async_count('User');

        # 2. Wait for all background workers to finish
        Future->wait_all($search_f, $count_f)->get;

        # 3. Retrieve results (already deflated to HashRefs)
        my @users = @{ $search_f->get };
        my $total = $count_f->get;

        template 'dashboard' => {
            users => \@users,
            total => $total,
        };
    };

    # Flexible Update (Scalar ID or HashRef query)
    post '/user/:id/deactivate' => sub {
        my $id = route_parameters->get('id');
        async_update('User', $id, { active => 0 })->get;
        return "User deactivated";
    };

=head1 KEYWORDS

=head2 async_db

    my $schema = async_db();
    my $schema = async_db('custom_connection');

Returns the underlying L<DBIx::Class::Async::Schema> instance for the
specified connection. Use this for complex operations like C<txn_do> or
direct storage management. The connection name defaults to C<'default'>.

=head2 async_rs

    my $rs = async_rs('User');
    my $f  = $rs->search({ active => 1 })->page(2)->all;

Returns a L<DBIx::Class::ResultSet> proxy for the specified source. Methods
called on this proxy return L<Future> objects instead of data. This is the
most flexible way to build complex, non-blocking queries.

=head2 async_count

    my $f = async_count('User');
    my $f = async_count('User', 'custom_connection');

Returns a L<Future> that resolves to the integer count of records in the
specified source.

=head2 async_find

    my $f = async_find('User', $id);
    my $f = async_find('User', $id, 'custom_connection');

Returns a L<Future> that resolves to a single record (as a deflated HashRef)
matching the provided primary key. Returns C<undef> if no record is found.

=head2 async_search

    my $f = async_search('Contact', { active => 1 });
    my $f = async_search('Contact', { id => 5 }, 'archive');

Returns a L<Future> that resolves to an ArrayRef of HashRefs representing
the rows. This is the recommended way to fetch multiple records for
non-blocking templates or JSON responses.

=head2 async_create

    my $f = async_create('User', { name => 'Alice', email => 'alice@example.com' });

Returns a L<Future> that resolves to the newly created record as a deflated HashRef.

=head2 async_update

    my $f = async_update('User', $id, { status => 'inactive' });
    my $f = async_update('User', { status => 'pending' }, { status => 'active' });

Returns a L<Future> that resolves to the number of rows updated (as an integer).

B<Note:> The second argument can be either a scalar primary key (assumed to
be the column C<'id'>) or a standard L<DBIx::Class> search HashRef for
complex updates.

=head2 async_delete

    my $f = async_delete('User', $id);
    my $f = async_delete('User', { status => 'spam' });

Returns a L<Future> that resolves to the number of rows deleted (as an integer).

B<Note:> Like C<async_update>, the second argument can be a scalar primary
key (targeting the column C<'id'>) or a search HashRef.

=head1 DATA FORMAT

All keywords that return row data (C<async_find>, C<async_search>, C<async_create>)
return B<deflated HashRefs> rather than L<DBIx::Class::Row> objects. This
ensures that the data is safe to use outside of the background worker's event
loop and is ready for serialization to JSON or rendering in templates.

=cut

my %INSTANCES;

plugin_keywords qw(
    async_db
    async_rs
    async_count
    async_find
    async_search
    async_create
    async_update
    async_delete
);

sub async_db :PluginKeyword {
    my ($plugin, $name) = @_;
    return _get_async($plugin, $name);
}

sub async_rs :PluginKeyword {
    my ($plugin, $source, $name) = @_;
    return _get_async($plugin, $name)->resultset($source);
}

sub async_count :PluginKeyword {
    my ($plugin, $source, $name) = @_;
    return _get_async($plugin, $name)->resultset($source)->count->transform(
        done => sub {
            my $count = shift;
            return $count + 0;
        }
    );
}

sub async_find :PluginKeyword {
    my ($plugin, $source, $id, $name) = @_;

    # If the user passed a HashRef into the $name slot, they likely forgot
    # the connection name is optional.
    $name = undef if ref $name;

    return _get_async($plugin, $name)->resultset($source)->find($id)->transform(
        done => sub {
            my $row = shift;
            return undef unless $row;
            return { $row->get_columns };
        }
    );
}

sub async_search :PluginKeyword {
    my ($plugin, $source, $cond, $name) = @_;

    # Defensive check: If $cond was skipped and $name was passed in 3rd slot
    # or if $name is a HashRef (meaning it's actually the condition).
    if (ref $name eq 'HASH') {
        # This shouldn't happen with the current signature, but protects
        # against users confusing argument order.
        my $tmp = $cond;
        $cond = $name;
        $name = $tmp;
    }

    # Pass $name to _get_async; our improved _get_async
    # will handle it if it's undef or invalid.
    return _get_async($plugin, $name)
        ->resultset($source)
        ->search($cond)
        ->all
        ->transform(
            done => sub {
                my $rows = shift;
                return [ map {
                    my %data = $_->get_columns;
                    \%data
                } @$rows ];
            }
        );
}

sub async_create :PluginKeyword {
    my ($plugin, $source, $data, $name) = @_;

    $name = undef if ref $name;

    return _get_async($plugin, $name)->resultset($source)->create($data)->transform(
        done => sub {
            my $row = shift;
            return { $row->get_columns };
        }
    );
}

sub async_update :PluginKeyword {
    my ($plugin, $source, $query, $data, $name) = @_;

    # Defensive check: if $query is just a scalar ID, turn it into a hashref
    $query = { id => $query } unless ref $query;
    $name  = undef if ref $name;

    return _get_async($plugin, $name)
        ->resultset($source)
        ->search($query)
        ->update($data)
        ->transform(
            done => sub {
                my $result = shift;
                # DBIC update returns the number of rows affected.
                # We ensure it's returned as a pure integer.
                return int($result // 0);
            }
        );
}

sub async_delete :PluginKeyword {
    my ($plugin, $source, $query, $name) = @_;

    # Defensive check: handle scalar ID for backward compatibility in tests
    $query = { id => $query } unless ref $query;
    $name  = undef if ref $name;

    return _get_async($plugin, $name)
        ->resultset($source)
        ->search($query)
        ->delete
        ->transform(
            done => sub {
                my $result = shift;
                # Return strictly as an integer
                return int($result // 0);
            }
        );
}

sub _get_async {
    my ($plugin, $name) = @_;

    # If $name is a reference (like a condition hash) or missing,
    # it's clearly not the connection name.
    if (!defined $name || ref $name) {
        $name = 'default';
    }

    return $INSTANCES{$name} if $INSTANCES{$name};

    my $app    = $plugin->app;
    my $config = $app->config->{plugins}{'DBIC::Async'}{$name}
        or die "No configuration for DBIC::Async connection '$name'";

    my $schema_class = $config->{schema_class} or die "schema_class required";
    use_module($schema_class);

    state $loop = IO::Async::Loop->new;

    my $schema = DBIx::Class::Async::Schema->connect(
        $config->{dsn},
        $config->{user},
        $config->{password},
        $config->{options} || {},
        {
            schema_class => $schema_class,
            loop         => $loop,
            %{ $config->{async} || {} },
        }
    );

    $INSTANCES{$name} = $schema;
    return $schema;
}

=head1 AUTHOR

Mohammad Sajid Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/manwar/Dancer2-Plugin-DBIC-Async>

=head1 BUGS

Please report any bugs or feature requests through the web interface at L<https://github.com/manwar/Dancer2-Plugin-DBIC-Async/issues>.
I will  be notified and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer2::Plugin::DBIC::Async

You can also look for information at:

=over 4

=item * BUG Report

L<https://github.com/manwar/Dancer2-Plugin-DBIC-Async/issues>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dancer2-Plugin-DBIC-Async>

=item * Search MetaCPAN

L<https://metacpan.org/dist/Dancer2-Plugin-DBIC-Async/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Mohammad Sajid Anwar.

This program  is  free software; you can redistribute it and / or modify it under
the  terms  of the the Artistic License (2.0). You may obtain a  copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any  use,  modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License.By using, modifying or distributing the Package,
you accept this license. Do not use, modify, or distribute the Package, if you do
not accept this license.

If your Modified Version has been derived from a Modified Version made by someone
other than you,you are nevertheless required to ensure that your Modified Version
 complies with the requirements of this license.

This  license  does  not grant you the right to use any trademark,  service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license
to make,  have made, use,  offer to sell, sell, import and otherwise transfer the
Package with respect to any patent claims licensable by the Copyright Holder that
are  necessarily  infringed  by  the  Package. If you institute patent litigation
(including  a  cross-claim  or  counterclaim) against any party alleging that the
Package constitutes direct or contributory patent infringement,then this Artistic
License to you shall terminate on the date that such litigation is filed.

Disclaimer  of  Warranty:  THE  PACKAGE  IS  PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS  "AS IS'  AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES    OF   MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR  PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS
REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE
OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Dancer2::Plugin::DBIC::Async
