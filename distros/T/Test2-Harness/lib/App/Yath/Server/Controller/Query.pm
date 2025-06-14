package App::Yath::Server::Controller::Query;
use strict;
use warnings;

our $VERSION = '2.000005';

use App::Yath::Server::Response qw/resp error/;
use Test2::Harness::Util::JSON qw/encode_json decode_json/;

use parent 'App::Yath::Server::Controller';
use Test2::Harness::Util::HashBase;

sub title { 'Query' }

my %ALLOWED = (
    projects   => {arg => 0},
    versions   => {arg => 1},
    categories => {arg => 1},
    tiers      => {arg => 1},
    builds     => {arg => 1},
);

sub handle {
    my $self = shift;
    my ($route) = @_;

    my $req = $self->{+REQUEST};
    my $res = resp(200);
    my $user = $req->user;
    my $schema = $self->schema;

    die error(404 => 'Missing route') unless $route;
    my $it = $route->{name} or die error(400 => 'No query specified');
    my $spec = $ALLOWED{$it} or die error(400);
    my $arg = $route->{arg};
    die error(400 => 'Missing Argument') if $spec->{args} && !defined($arg);

    my $q = App::Yath::Schema::Queries->new(config => $self->{+SCHEMA_CONFIG});
    my $data = $q->$it($arg);

    $res->stream(
        env          => $req->env,
        content_type => 'application/x-jsonl',

        done  => sub { !@$data },
        fetch => sub {
            my $item = shift @$data or return;
            return encode_json($item) . "\n";
        },
    );

    return $res;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Yath::Server::Controller::Query - Controller for using queries.

=head1 DESCRIPTION

=head1 SYNOPSIS

TODO

=head1 SOURCE

The source code repository for Test2-Harness-UI can be found at
F<http://github.com/Test-More/Test2-Harness-UI/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut

=pod

=cut POD NEEDS AUDIT

