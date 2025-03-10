package Net::Async::TravisCI::Account;
$Net::Async::TravisCI::Account::VERSION = '0.002';
use strict;
use warnings;

sub new { bless { @_[1..$#_] }, $_[0] }

=head2 type

=cut

sub type { shift->{type} }

=head2 name

=cut

sub name { shift->{name} }

=head2 id

=cut

sub id { shift->{id} }

=head2 subscribed

=cut

sub subscribed { shift->{subscribed} }

=head2 education

=cut

sub education { shift->{education} }

=head2 repos_count

=cut

sub repos_count { shift->{repos_count} }

=head2 avatar_url

=cut

sub avatar_url { shift->{avatar_url} }

=head2 login

=cut

sub login { shift->{login} }


1;

