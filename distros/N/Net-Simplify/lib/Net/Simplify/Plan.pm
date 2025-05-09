package Net::Simplify::Plan;

=head1 NAME

Net::Simplify::Plan - A Simplify Commerce Plan object

=head1 SYNOPSIS

  use Net::Simplify;


  $Net::Simplify::public_key = 'YOUR PUBLIC KEY';
  $Net::Simplify::private_key = 'YOUR PRIVATE KEY';

  # Create a new Plan.
  my $plan = Net::Simplify::Plan->create{ {...});

  # Retrieve a Plan given its ID.
  my $plan = Net::Simplify::Plan->find('a7e41');

  # Update existing Plan.
  my $plan = Net::Simplify::Plan->find('a7e41');
  $plan->{PROPERTY} = "NEW VALUE";
  $plan->update();

  # Delete
  my $plan = Net::Simplify::Plan->find('a7e41');
  $plan->delete();

  # Retrieve a list of objects
  my $plans = Net::Simplify::Plan->list({max => 10});
  foreach my $v ($plans->list) {
      # ...
  }

=head1 DESCRIPTION

=head2 METHODS

=head3 create(%params, $auth)

Creates a C<Net::Simplify::Plan> object.  The parameters are:

=over 4

=item C<%params>

Hash map containing initial values for the object.  Valid keys are:

=over 4

=item amount

Amount of payment for the plan in the smallest unit of your currency. Example: 100 = $1.00 (B<required>) 

=item billingCycle

How the plan is billed to the customer. Values must be AUTO (indefinitely until the customer cancels) or FIXED (a fixed number of billing cycles). [default: AUTO] 

=item billingCycleLimit

The number of fixed billing cycles for a plan. Only used if the billingCycle parameter is set to FIXED. Example: 4 

=item currency

Currency code (ISO-4217) for the plan. Must match the currency associated with your account. [default: USD] (B<required>) 

=item frequency

Frequency of payment for the plan. Used in conjunction with frequencyPeriod. Valid values are "DAILY", "WEEKLY", "MONTHLY" and "YEARLY". [default: MONTHLY] (B<required>) 

=item frequencyPeriod

Period of frequency of payment for the plan. Example: if the frequency is weekly, and periodFrequency is 2, then the subscription is billed bi-weekly. [min value: 1, default: 1] (B<required>) 

=item name

Name of the plan [max length: 50, min length: 2] (B<required>) 

=item renewalReminderLeadDays

If set, how many days before the next billing cycle that a renewal reminder is sent to the customer. If null, then no emails are sent. Minimum value is 7 if set. 

=item trialPeriod

Plan free trial period selection.  Must be Days, Weeks, or Month [default: NONE] (B<required>) 

=item trialPeriodQuantity

Quantity of the trial period.  Must be greater than 0 and a whole number. [min value: 1] 


=back

=item C<$auth>

Authentication object for accessing the API.  If no value is passed the global keys
C<$Net::Simplify::public_key> and C<$Net::Simplify::private_key> are used.

=back




=head3 delete()

Deletes the C<Net::Simplify::Plan> object.  Authentication is done using the same credentials used when the AccessToken was created.



=head3 list(%criteria, $auth)

Retrieve a list of C<Net::Simplify::Plan> objects.  The parameters are:

=over 4

=item C<%criteria>

Hash map representing the criteria to limit the results of the list operation.  Valid keys are:

=over 4

=item C<filter>

<table class="filter_list"><tr><td>filter.id</td><td>Filter by the plan Id</td></tr><tr><td>filter.text</td><td>Filter by the name of the plan</td></tr><tr><td>filter.frequency</td><td>Filter by the frequency of the plan</td></tr><tr><td>filter.amountMin & filter.amountMax</td><td>The filter amountMin must be used with amountMax to find plans with plan values between the min and max figures</td></tr><tr><td>filter.dateCreatedMin<sup>*</sup></td><td>Filter by the minimum created date you are searching for - Date in UTC millis</td></tr><tr><td>filter.dateCreatedMax<sup>*</sup></td><td>Filter by the maximum created date you are searching for - Date in UTC millis</td></tr><tr><td>filter.q</td><td>You can use this to filter by the Id, the name or the amount of the plan</td></tr></table><br><sup>*</sup>Use dateCreatedMin with dateCreatedMax in the same filter if you want to search between two created dates



=item C<max>

Allows up to a max of 50 list items to return. [min value: 0, max value: 50, default: 20]



=item C<offset>

Used in paging of the list.  This is the start offset of the page. [min value: 0, default: 0]



=item C<sorting>

Allows for ascending or descending sorting of the list.
The value maps properties to the sort direction (either C<asc> for ascending or C<desc> for descending).  Sortable properties are:

=over 4

=item C<dateCreated>

=item C<amount>

=item C<frequency>

=item C<name>

=item C<id>


=back




=back

=back



=head3 find($id, $auth)

Retrieve a C<Net::Simplify::Plan> object from the API.  Parameters are:

=over 4

=item C<$id>

Identifier of the object to retrieve.

=item C<$auth>

Authentication object for accessing the API.  If no value is passed the global keys
C<$Net::Simplify::public_key> and C<$Net::Simplify::private_key> are used.

=back




=head3 update()

Update C<Net::Simplify::Plan> object.
The properties that can be updated are:

=over 4



=item C<name>

Name of the plan. [min length: 2] (B<required>) 

Authentication is done using the same credentials used when the AccessToken was created.

=back




=head1 SEE ALSO

L<Net::Simplify>,
L<Net::Simplify::Domain>,
L<Net::Simplify::DomainList>,
L<Net::Simplify::Authentication>,
L<Net::Simplify::ApiException>,
L<http://www.simplify.com>

=head1 VERSION

1.6.0

=head1 LICENSE

Copyright (c) 2013 - 2022 MasterCard International Incorporated
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are 
permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of 
conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of 
conditions and the following disclaimer in the documentation and/or other materials 
provided with the distribution.
Neither the name of the MasterCard International Incorporated nor the names of its 
contributors may be used to endorse or promote products derived from this software 
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; 
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING 
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
SUCH DAMAGE.

=head1 SEE ALSO

=cut

use 5.006;
use strict;
use warnings FATAL => 'all';

use Net::Simplify::Domain;
use Net::Simplify::DomainList;

our @ISA = qw(Net::Simplify::Domain);

sub create {

    my ($class, $params, $auth) = @_;
    
    $auth = Net::Simplify::SimplifyApi->get_authentication($auth);
    my $result = Net::Simplify::SimplifyApi->send_api_request("plan", 'create', $params, $auth);

    $class->SUPER::new($result, $auth);
}

sub delete {

    my ($self) = @_;

    my $auth = Net::Simplify::SimplifyApi->get_authentication($self->{_authentication});

    my $id = $self->{id};
    $self->merge(Net::Simplify::SimplifyApi->send_api_request("plan", 'delete', {id => $id}, $auth));
}

sub list {
    my ($class, $criteria, $auth) = @_;
   
    $auth = Net::Simplify::SimplifyApi->get_authentication($auth);
    my $result = Net::Simplify::SimplifyApi->send_api_request("plan", 'list', $criteria, $auth);

    Net::Simplify::DomainList->new($result, $class, $auth);
}

sub find {
    my ($class, $id, $auth) = @_;

    $auth = Net::Simplify::SimplifyApi->get_authentication($auth);
    my $result = Net::Simplify::SimplifyApi->send_api_request("plan", 'find', { id => $id }, $auth);

    $class->SUPER::new($result, $auth);
}

sub update {

    my ($self) = @_;

    my $auth = Net::Simplify::SimplifyApi->get_authentication($self->{_authentication});
    my $params = { %$self };
    delete $params->{_authentication};

    $self->merge(Net::Simplify::SimplifyApi->send_api_request("plan", 'update', $params, $auth));
}


1;
