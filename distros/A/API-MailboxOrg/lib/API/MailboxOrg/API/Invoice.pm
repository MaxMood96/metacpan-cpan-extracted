package API::MailboxOrg::API::Invoice;

# ABSTRACT: MailboxOrg::API::Invoice

# ---
# This class is auto-generated by bin/get_mailbox_api.pl
# ---

use v5.24;

use strict;
use warnings;

use Moo;
use Types::Standard qw(Enum Str Int InstanceOf ArrayRef);
use API::MailboxOrg::Types qw(HashRefRestricted Boolean);
use Params::ValidationCompiler qw(validation_for);

extends 'API::MailboxOrg::APIBase';

with 'MooX::Singleton';

use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '1.0.2'; # VERSION

my %validators = (
    'get' => validation_for(
        params => {
            token => { type => Str, optional => 0 },

        },
    ),
    'list' => validation_for(
        params => {
            account => { type => Str, optional => 0 },

        },
    ),

);


sub get ($self, %params) {
    my $validator = $validators{'get'};
    %params       = $validator->(%params) if $validator;

    my %opt = ();

    return $self->_request( 'account.invoice.get', \%params, \%opt );
}

sub list ($self, %params) {
    my $validator = $validators{'list'};
    %params       = $validator->(%params) if $validator;

    my %opt = (needs_auth => 1);

    return $self->_request( 'account.invoice.list', \%params, \%opt );
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

API::MailboxOrg::API::Invoice - MailboxOrg::API::Invoice

=head1 VERSION

version 1.0.2

=head1 SYNOPSIS

    use API::MailboxOrg;

    my $user     = '1234abc';
    my $password = '1234abc';

    my $api      = API::MailboxOrg->new(
        user     => $user,
        password => $password,
    );

=head1 METHODS

=head2 get

PDF binary of an invoice

Parameters:

=over 4

=item * token

=back

returns: array

    $api->invoice->get(%params);

=head2 list

Returns a list of downloadable invoices

Available for admin, reseller, account

Parameters:

=over 4

=item * account

=back

returns: array

    $api->invoice->list(%params);

=head1 AUTHOR

Renee Baecker <reneeb@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Renee Baecker.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
