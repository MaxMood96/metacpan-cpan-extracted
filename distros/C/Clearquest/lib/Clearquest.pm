package Clearquest;

use strict;
use warnings;

=pod

=head1 NAME

Clearquest - Object oriented interface to Clearquest.

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 2.23 $

=item Created

Fri Sep 22 09:21:18 CDT 2006

=item Modified

2013/03/28 22:48:07

=back

=head1 SYNOPSIS

Provides access to Clearquest database in an object oriented manner.

 # Create Clearquest object
 my $cq = Clearquest->new;

 # Connect to database (using all the defaults in cq.conf)
 $cq->connect;

 # Connect as non standard user;

 $cq->connect (CQ_USERNAME => 'me', CQ_PASSWORD => 'mypassword');

 # Get record (Default: all fields)
 my %record = $cq->get ($recordName, $key);

 # Get record with specific field list
 my %record =$cq->get ($recordName, $key, qw(field1 field2))

 # Modify a record
 my %update = (
   Description => 'This is a new description',
   Active      => 1,
 );
 $cq->modify ($recordName, $key, 'Modify', \%update);

 # Change state using modify with an alternate action. Note the use of @ordering
 my %fieldsToUpdate = (
   Project  => 'Carrier',
   Category => 'New Functionality',
   Groups   => [ 'Group1', 'Group2' ],
 );

 my @ordering qw(Project Category);

 $cq->modify ($recordName, $key, 'Open', \%fieldsToUpdate, @ordering);

 if ($cq->error) {
   error "Unable to update $key to Opened state\n"
       . $cq->errmsg;
 } # if

=head1 DESCRIPTION

This module provides a simple interface to Clearquest in a Perl like fashion.
There are three modes of talking to Clearquest using this module - api, rest
and client.

With module = 'api' you must have Clearquest installed locally and you must use
cqperl to execute your script. This mode of operation has the benefit of speed -
note that initial connection to the Clearquest database is not very speedy, but
all subsequent calls will operate at full speed. The 'api' module is free to
use. For the other modules contact Andrew DeFaria <Andrew@DeFaria.com>.

With module = 'rest' you can access Clearquest by using a RESTFull interface.
You can use any Perl which has the required CPAN modules (REST, XML::Simple -
see Clearquest::REST for a list of required CPAN modules). The REST interface is
a slower than the native api and requires the setup of Clearquest Web (cqweb) on
your network. To use the REST interface set CQ_MODULE to 'rest'.

With module = 'client' you access Clearquest through the companion
Clearquest::Server module and the cqd.pl server script. The server process is
started on a machine that has Clearquest installed locally. It uses the api
interface for speed and can operate in a multithreaded manner, spawning
processes which open and handle requests from Clearquest::Client requests. To
use the Client interface set CQ_MODULE to 'client'.

Other than setting CQ_MODULE to one of the three modes described above, the rest
of your script's usage of the Clearquest module should be exactly the same.

=head1 CONFIGURATION

This module reads configuration data from a file (../etc/cq.conf)
which sets default values described below. Or you can export the option name to
the env(1) to override the defaults in cq.conf. Finally you can programmatically
set the options when you call new by passing in a %parms hash. To specify the
%parms hash key remove the CQ_ portion and lc the rest.

=for html <blockquote>

=over

=item CQ_SERVER

Clearquest server to talk to. Also used for rest server (Default: From cq.conf)

=item CQ_PORT

Port to connect to (Default: From cq.conf)

=item CQ_WEBHOST

The web host to contact with leading http:// (Default: From cq.conf)

=item CQ_DATABASE

Name of database to connect to (Default: From cq.conf)

=item CQ_USERNAME

User name to connect as (Default: From cq.conf)

=item CQ_PASSWORD

Password for CQREST_USERNAME (Default: From cq.conf)

=item CQ_DBSET

Database Set name (Default: From cq.conf)

=item CQ_MODULE

One of 'api', 'rest' or 'client' (Default: From cq.conf)

=back

=head1 METHODS

The following methods are available:

=cut

use File::Basename;
use Carp;
use Time::Local;

sub _GetConfig($);

# Seed options from config file
my $config = $ENV{CQ_CONF} || '/etc/clearquest/cq.conf';

croak "Unable to find config file $config" unless -r $config;

our %OPTS = _GetConfig ($config);

my $DEFAULT_DBSET = $OPTS{CQ_DBSET};

our $VERSION = '2.23';

# Override options if in the environment
$OPTS{CQ_DATABASE} = $ENV{CQ_DATABASE} if $ENV{CQ_DATABASE};
$OPTS{CQ_DBSET}    = $ENV{CQ_DBSET}    if $ENV{CQ_DBSET};
$OPTS{CQ_MODULE}   = $ENV{CQ_MODULE}   if $ENV{CQ_MODULE};
$OPTS{CQ_PASSWORD} = $ENV{CQ_PASSWORD} if $ENV{CQ_PASSWORD};
$OPTS{CQ_PORT}     = $ENV{CQ_PORT}     if $ENV{CQ_PORT};
$OPTS{CQ_SERVER}   = $ENV{CQ_SERVER}   if $ENV{CQ_SERVER};
$OPTS{CQ_USERNAME} = $ENV{CQ_USERNAME} if $ENV{CQ_USERNAME};

# FieldTypes ENUM
our $UNKNOWN          = -1;
our $STRING           = 1;
our $MULTILINE_STRING = 2;
our $INT              = 3;
our $DATE_TIME        = 4;
our $REFERENCE        = 5;
our $REFERENCE_LIST   = 6;
our $ATTACHMENT_LIST  = 7;
our $ID               = 8;
our $STATE            = 9;
our $JOURNAL          = 10;
our $DBID             = 11;
our $STATETYPE        = 12;
our $RECORD_TYPE      = 13;

my %FIELDS;

my @objects;

my $SECS_IN_MIN  = 60;
my $SECS_IN_HOUR = $SECS_IN_MIN * 60;
my $SECS_IN_DAY  = $SECS_IN_HOUR * 24;

my $operatorRE = qr/
  (\w+)              # field name
  \s*                # whitespace
  (                  # operators
    ==               # double equals
    |=               # single equals
    |!=              # not equal
    |<>              # the other not equal
    |<=              # less than or equal
    |>=              # greater than or equal
    |<               # less than
    |>               # greater than
    |like            # like
    |not\s+like      # not like
    |between         # between
    |not\s*between   # not between
    |is\s+null       # is null
    |is\s+not\s+null # is not null
    |in              # in
    |not\s+in        # not in
  )
  \s*                # whitespace
  (.*)               # value
  /ix;

END {
  # Insure all instaniated objects have been destroyed
  $_->DESTROY for (@objects);
}    # END

# Internal methods
sub _commitRecord($) {
  my ($self, $entity) = @_;

  $self->{errmsg} = $entity->Validate;

  if ($self->{errmsg} eq '') {
    $self->{errmsg} = $entity->Commit;
    $self->{error}  = $self->{errmsg} eq '' ? 0 : 1;

    return $self->{errmsg};
  } else {
    $self->{error} = 1;

    $entity->Revert;

    return $self->{errmsg};
  }    # if
}    # _commitRecord

sub _is_leap_year($) {
  my ($year) = @_;

  return 0 if $year % 4;
  return 1 if $year % 100;
  return 0 if $year % 400;

  return 1;
}    # _is_leap_year

sub _dateToEpoch($) {
  my ($date) = @_;

  my $year    = substr $date, 0,  4;
  my $month   = substr $date, 5,  2;
  my $day     = substr $date, 8,  2;
  my $hour    = substr $date, 11, 2;
  my $minute  = substr $date, 14, 2;
  my $seconds = substr $date, 17, 2;

  my $days;

  for (my $i = 1970; $i < $year; $i++) {
    $days += _is_leap_year ($i) ? 366 : 365;
  }    # for

  my @monthDays = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334,);

  $days += $monthDays[$month - 1];

  $days++
    if _is_leap_year ($year)
    and $month > 2;

  $days += $day - 1;

  return ($days * $SECS_IN_DAY) +
    ($hour * $SECS_IN_HOUR) +
    ($minute * $SECS_IN_MIN) +
    $seconds;
}    # _dateToEpoch

sub _epochToDate($) {
  my ($epoch) = @_;

  my $year = 1970;
  my ($month, $day, $hour, $minute, $seconds);
  my $leapYearSecs = 366 * $SECS_IN_DAY;
  my $yearSecs     = $leapYearSecs - $SECS_IN_DAY;

  while () {
    my $amount = _is_leap_year ($year) ? $leapYearSecs : $yearSecs;

    last
      if $amount > $epoch;

    $epoch -= $amount;
    $year++;
  }    # while

  my $leapYearAdjustment = _is_leap_year ($year) ? 1 : 0;

  if ($epoch >= (334 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '12';
    $epoch -= (334 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (304 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '11';
    $epoch -= (304 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (273 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '10';
    $epoch -= (273 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (243 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '09';
    $epoch -= (243 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (212 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '08';
    $epoch -= (212 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (181 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '07';
    $epoch -= (181 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (151 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '06';
    $epoch -= (151 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (120 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '05';
    $epoch -= (120 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (90 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '04';
    $epoch -= (90 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= (59 + $leapYearAdjustment) * $SECS_IN_DAY) {
    $month = '03';
    $epoch -= (59 + $leapYearAdjustment) * $SECS_IN_DAY;
  } elsif ($epoch >= 31 * $SECS_IN_DAY) {
    $month = '02';
    $epoch -= 31 * $SECS_IN_DAY;
  } else {
    $month = '01';
  }    # if

  $day     = int (($epoch / $SECS_IN_DAY) + 1);
  $epoch   = $epoch % $SECS_IN_DAY;
  $hour    = int ($epoch / $SECS_IN_HOUR);
  $epoch   = $epoch % $SECS_IN_HOUR;
  $minute  = int ($epoch / $SECS_IN_MIN);
  $seconds = $epoch % $SECS_IN_MIN;

  $day     = "0$day"     if $day < 10;
  $hour    = "0$hour"    if $hour < 10;
  $minute  = "0$minute"  if $minute < 10;
  $seconds = "0$seconds" if $seconds < 10;

  return "$year-$month-$day $hour:$minute:$seconds";
}    # _epochToDate

sub _parseCondition($) {
  my ($self, $condition) = @_;

  # Parse simple conditions only
  my ($field, $operator, $value);

  if ($condition =~ $operatorRE) {
    $field    = $1;
    $operator = $2;
    $value    = $3;

    if ($operator eq '==' or $operator eq '=') {
      if ($value !~ /^null$/i) {
        $operator = $CQPerlExt::CQ_COMP_OP_EQ;
      } else {
        $operator = $CQPerlExt::CQ_COMP_OP_IS_NULL;
      }    # if
    } elsif ($operator eq '!=' or $operator eq '<>') {
      if ($value !~ /^null$/i) {
        $operator = $CQPerlExt::CQ_COMP_OP_NEQ;
      } else {
        $operator = $CQPerlExt::CQ_COMP_OP_IS_NOT_NULL;
      }    # if
    } elsif ($operator eq '<') {
      $operator = $CQPerlExt::CQ_COMP_OP_LT;
    } elsif ($operator eq '>') {
      $operator = $CQPerlExt::CQ_COMP_OP_GT;
    } elsif ($operator eq '<=') {
      $operator = $CQPerlExt::CQ_COMP_OP_LTE;
    } elsif ($operator eq '>=') {
      $operator = $CQPerlExt::CQ_COMP_OP_GTE;
    } elsif ($operator =~ /^like$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_LIKE;
    } elsif ($operator =~ /^not\s+like$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_NOT_LIKE;
    } elsif ($operator =~ /^between$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_BETWEEN;
    } elsif ($operator =~ /^not\s+between$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_NOT_BETWEEN;
    } elsif ($operator =~ /^is\s+null$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_IS_NULL;
    } elsif ($operator =~ /^is\s+not\s+null$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_IS_NOT_NULL;
    } elsif ($operator =~ /^in$/i) {
      $operator = $CQPerlExt::CQ_COMP_OP_IN;
    } elsif ($operator =~ /^not\s+in$/) {
      $operator = $CQPerlExt::CQ_COMP_OP_NOT_IN;
    } else {
      $self->_setError ("I can't understand the operator $operator");

      $operator = undef;

      return 1;
    }    # if
  } else {

    # TODO: How to handle more complicated $condition....
    $self->_setError (
      "I can't understand the conditional expression " . $condition);

    $operator = undef;

    return 1;
  }    # if

  # Trim quotes if any:
  if ($value =~ /^\s*\'/) {
    $value =~ s/^\s*\'//;
    $value =~ s/\'\s*$//;
  } elsif ($value =~ /^\s*\"/) {
    $value =~ s/^\s*\"//;
    $value =~ s/\"\s*$//;
  }    # if

  # Trim leading and trailing whitespace
  $value =~ s/^\s+//;
  $value =~ s/\s+$//;

  return ($field, $operator, $value);
}    # _parseCondition

sub _parseConditional($$;$);

sub _parseConditional($$;$) {
  my ($self, $query, $condition, $filterOperator) = @_;

  return if $condition eq '';

  my ($field, $operator, $value);

  if ($condition =~ /(.+?)\s+(and|or)\s+(.+)/i) {
    my $leftSide    = $1;
    my $conjunction = lc $2;
    my $rightSide   = $3;

    if ($conjunction eq 'and') {
      unless ($filterOperator) {
        $filterOperator =
          $query->BuildFilterOperator ($CQPerlExt::CQ_BOOL_OP_AND);
      } else {
        $filterOperator =
          $filterOperator->BuildFilterOperator ($CQPerlExt::CQ_BOOL_OP_AND);
      }    # unless
    } elsif ($conjunction eq 'or') {
      unless ($filterOperator) {
        $filterOperator =
          $query->BuildFilterOperator ($CQPerlExt::CQ_BOOL_OP_OR);
      } else {
        $filterOperator =
          $filterOperator->BuildFilterOperator ($CQPerlExt::CQ_BOOL_OP_OR);
      }    # unless
    }    # if

    $self->_setCondition ($self->_parseCondition ($leftSide), $filterOperator);

    $self->_parseConditional ($query, $rightSide, $filterOperator);
  } else {
    unless ($condition =~ $operatorRE) {
      $self->_setError ("Unable to parse condition \"$condition\"");

      return;
    }    # unless

    $filterOperator = $query->BuildFilterOperator ($CQPerlExt::CQ_BOOL_OP_AND)
      unless $filterOperator;

    $self->_setCondition ($self->_parseCondition ($condition), $filterOperator);
  }    # if

  # Actually clear error...
  $self->_setError;

  return;
}    # _parseConditional

sub _setCondition($$$) {
  my ($self, $field, $operator, $value, $filterOperator) = @_;

  return unless $operator;

  if ( $operator == $CQPerlExt::CQ_COMP_OP_IS_NULL
    or $operator == $CQPerlExt::CQ_COMP_OP_IS_NOT_NULL)
  {
    eval {$filterOperator->BuildFilter ($field, $operator, [()])};

    if ($@) {
      $self->_setError ($@);

      carp $@;
    }    # if
  } else {

    # If the operator is one of the operators that have mulitple values then we
    # need to make an array of $value
    if ( $operator == $CQPerlExt::CQ_COMP_OP_BETWEEN
      or $operator == $CQPerlExt::CQ_COMP_OP_NOT_BETWEEN
      or $operator == $CQPerlExt::CQ_COMP_OP_IN
      or $operator == $CQPerlExt::CQ_COMP_OP_NOT_IN)
    {
      my @values = split /,\s*/, $value;

      eval {$filterOperator->BuildFilter ($field, $operator, \@values)};

      if ($@) {
        $self->_setError ($@);

        carp $@;
      }    # if
    } else {
      eval {$filterOperator->BuildFilter ($field, $operator, [$value])};

      if ($@) {
        $self->_setError ($@);

        carp $@;
      }    # if
    }    # if
  }    # if

  return;
}    # _setCondition

sub _setFields($@) {
  my ($self, $table, @fields) = @_;

  my $entityDef;

  eval {$entityDef = $self->{session}->GetEntityDef ($table)};

  if ($@) {
    $self->_setError ($@, -1);

    return;
  }    # if

  unless (@fields) {
    for (@{$entityDef->GetFieldDefNames}) {
      unless ($self->{returnSystemFields}) {
        next if $entityDef->IsSystemOwnedFieldDefName ($_);
      }    # unless

      push @fields, $_;
    }    # for
  }    # unless

  # Always return dbid
  push @fields, 'dbid' unless grep {$_ eq 'dbid'} @fields;

  return @fields;
}    # _setFields

sub _setError(;$$) {
  my ($self, $errmsg, $error) = @_;

  $error ||= 0;

  if ($errmsg and $errmsg ne '') {
    $error = 1;

    $self->{errmsg} = $errmsg;
  } else {
    $self->{errmsg} = '';
  }    # if

  $self->error ($error);

  return;
}    # _setError

sub _setFieldValue($$$$) {
  my ($self, $entity, $table, $fieldName, $fieldValue) = @_;

  my $errmsg = '';

  my $entityDef = $self->{session}->GetEntityDef ($table);

  return $errmsg if $entityDef->IsSystemOwnedFieldDefName ($fieldName);

  unless (ref $fieldValue eq 'ARRAY') {

    # This is one of those rare instances where it is important to surround a
    # bare variable with double quotes otherwise the CQ API will wrongly
    # evaluate $fieldValue if $fieldValue is a simple number (e.g. 0, 1, etc.)
    $errmsg = $entity->SetFieldValue ($fieldName, "$fieldValue") if $fieldValue;
  } else {
    for (@$fieldValue) {
      $errmsg = $entity->AddFieldValue ($fieldName, $_);

      return $errmsg unless $errmsg eq '';
    }    # for
  }    # unless

  return $errmsg;
}    # _setFieldValues

sub _UTC2Localtime($) {
  my ($utcdatetime) = @_;

  return unless $utcdatetime;

  # If the field does not look like a UTC time then just return it.
  return $utcdatetime
    unless $utcdatetime =~ /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/;

  $utcdatetime =~ s/T/ /;
  $utcdatetime =~ s/Z//;

  my @localtime = localtime;

  return _epochToDate (_dateToEpoch ($utcdatetime) +
      (timegm (@localtime) - timelocal (@localtime)));
}    # _UTC2Localtime

sub add($$;@) {
  my ($self, $table, $values, @ordering) = @_;

=pod

=head2 add ($$;@)

Insert a new record into the database

Parameters:

=for html <blockquote>

=over

=item $table

The name of the table to insert into

=item $values

Hash reference of name/value pairs for the insertion

=item @ordering

Array containing field names that need to be processed in order. Not all fields
mentioned in the $values hash need be mentioned here. If you have fields that
must be set in a particular order you can mention them here. So, if you're
adding the Defect record, but you need Project set before Platform,  you need
only pass in an @ordering of qw(Project Platform). They will be done first, then
all of the rest of the fields in the $values hash. If you have no ordering
dependencies then you can simply omit @ordering.

Note that the best way to determine if you have an ordering dependency try using
a Clearquest client and note the order that you set fields in. If at anytime
setting one field negates another field via action hook code then you have just
figured out that this field needs to be set before the file that just got
negated.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $dbid

The DBID of the newly added record or undef if error.

=back

=for html </blockquote>

=cut

  $self->{errmsg} = '';

  unless ($self->connected) {
    $self->_setError ('You must connect to Clearquest before you can call add');

    return;
  }    # unless

  my %values = %$values;
  my $entity;

  eval {$entity = $self->{session}->BuildEntity ($table)};

  if ($@) {
    $self->_setError ("Unable to create new $table record:\n$@");

    return;
  }    # if

  # First process all fields in @ordering, if specified
  for (@ordering) {
    if ($values{$_}) {
      $self->{errmsg} =
        $self->_setFieldValue ($entity, $table, $_, $values{$_});
    } else {
      $self->_setError (
        "$_ from the ordering array is not present in the value hash", -1);
    }    # if

    last unless $self->{errmsg} eq '';
  }    # for

  return unless $self->{errmsg} eq '';

  # Now process the rest of the values
  for my $fieldName (keys %values) {
    next if grep {$fieldName eq $_} @ordering;

    $self->{errmsg} =
      $self->_setFieldValue ($entity, $table, $fieldName, $values{$fieldName});

    last unless $self->{errmsg} eq '';
  }    # for

  $self->_setError ($self->{errmsg});

  return unless $self->{errmsg} eq '';

  $self->{errmsg} = $self->_commitRecord ($entity);
  $self->{error}  = $self->{errmsg} eq '' ? 0 : 1;

  my $dbid = $entity->GetFieldValue ('dbid')->GetValue;

  return $dbid;
}    # add

sub connect(;$$$$) {
  my ($self, $username, $password, $database, $dbset) = @_;

=pod

=head2 connect (;$$$$)

Connect to the Clearquest database. You can supply parameters such as username,
password, etc and they will override any passed to Clearquest::new (or those
coming from ../etc/cq.conf)

Parameters:

=for html <blockquote>

=over

=item $username

Username to use to connect to the database

=item $password

Password to use to connect to the database

=item $database

Clearquest database to connect to

=item $dbset

Database set to connect to (Default: Connect to the default dbset)

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item 1

=back

=for html </blockquote>

=cut

  return unless $self->{module} eq 'api';

  eval {require CQPerlExt};

  croak "Unable to use Rational's CQPerlExt library - "
    . "You must use cqperl to use the Clearquest API back end\n$@"
    if $@;

  $self->{username} = $username if $username;
  $self->{password} = $password if $password;
  $self->{database} = $database if $database;
  $self->{dbset}    = $dbset    if $dbset;

  $self->{session} = CQSession::Build ();

  $self->{loggedin} = 0;

  eval {
    $self->{session}->UserLogon (
      $self->{username}, $self->{password},
      $self->{database}, $self->{dbset}
    );
  };

  if ($@) {
    chomp ($@);

    $self->_setError ($@, 1);
  } else {
    $self->{loggedin} = 1;

    $self->_setError ($_, 0);
  }    # if

  return $self->{loggedin};
}    # connect

sub connected() {
  my ($self) = @_;

=pod

=head2 connected ()

Returns 1 if we are currently connected to Clearquest

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item 1 if logged in - 0 if not

=back

=for html </blockquote>

=cut

  return $self->{loggedin};
}    # connected

sub connection($) {
  my ($self, $fullyQualify) = @_;

=pod

=head2 connection ()

Returns a connection string that describes the current connection

Parameters:

=for html <blockquote>

=over

=item $fullyQualify

If true the connection string will be fully qualified

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $connectionStr

A string describing the current connection. Generally
<username>@<database>[/<dbset>]. Note that <dbset> is only displayed if it is
not the default DBSet as defined in cq.conf.

=back

=for html </blockquote>

=cut

  my $connectionStr = $self->username () . '@' . $self->database ();

  if ($fullyQualify) {
    $connectionStr .= '/' . $self->dbset;
  } else {
    $connectionStr .= '/' . $self->dbset ()
      unless $self->dbset eq $DEFAULT_DBSET;
  }    # if

  return $connectionStr;
}    # connection

sub checkErr(;$$$) {
  my ($self, $msg, $die, $log) = @_;

=pod

=head2 checkErr (;$$)

Checks for error in the last Clearquest method call and prints error to STDERR.
Optionally prints a user message if $msg is specified. Dies if $die is true

Parameters:

=for html <blockquote>

=over

=item $msg

User error message

=item $die

Causes caller to croak if set to true

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $error

Returns 0 for no error, non-zero if error.

=back

=for html </blockquote>

=cut

  $die ||= 0;

  if ($self->{error}) {
    if ($msg) {
      $msg .= "\n" . $self->errmsg . "\n";
    } else {
      $msg = $self->errmsg . "\n";
    }    # if

    if ($die) {
      $log->err ($msg) if $log;
      croak $msg;
    } else {
      if ($log) {
        $log->err ($msg);
      } else {
        print STDERR "$msg\n";
      }    # if

      return $self->{error};
    }    # if
  }    # if

  return 0;
}    # checkErr

sub database() {
  my ($self) = @_;

=pod

=head2 database

Returns the current database (or the database that would be used)

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item database

=back

=for html </blockquote>

=cut

  return $self->{database};
}    # database

sub dbset() {
  my ($self) = @_;

=pod

=head2 dbset

Returns the current dbset (or the dbset that would be used)

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item dbset

=back

=for html </blockquote>

=cut

  return $self->{dbset};
}    # dbset

sub dbsets() {
  my ($self) = @_;

=pod

=head2 dbsets ()

Return the installed DBSets for this schema

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item @dbsets

An array of dbsets

=back

=for html </blockquote>

=cut

  unless ($self->connected) {
    $self->_setError (
      'You must connect to Clearquest before you can call DBSets', '-1');

    return;
  }    # unless

  return @{$self->{session}->GetInstalledDbSets};
}    # dbsets

sub delete($;$) {
  my ($self, $table, $key) = @_;

=pod

=head2 delete ($;$)

Deletes records from the database

Parameters:

=for html <blockquote>

=over

=item $table

Table to delete records from

=item $key

Key of the record to delete

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $errmsg

Error message or blank if no error

=back

=for html </blockquote>

=cut

  my $entity;

  eval {$entity = $self->{session}->GetEntity ($table, $key)};

  if ($@) {
    $self->_setError ($@, 1);

    return $@;
  }    # if

  eval {$self->{session}->DeleteEntity ($entity, 'Delete')};

  if ($@) {
    $self->_setError ($@, 1);

    return $@;
  }    # if

  return '';
}    # delete

sub DESTROY() {
  my ($self) = @_;

  CQSession::Unbuild ($self->{session}) if $self->{session};

  return;
}    # DESTROY

sub disconnect() {
  my ($self) = @_;

=pod

=head2 disconnect ()

Disconnect from Clearquest

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

  CQSession::Unbuild ($self->{session});

  undef $self->{session};

  $self->{loggedin} = 0;

  return;
}    # disconnect

sub errmsg(;$) {
  my ($self, $errmsg) = @_;

=pod

=head2 errmsg ()

Returns the last error message. Optionally sets the error message if specified.

Parameters:

=for html <blockquote>

=over

=item $errmsg

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $errmsg

Last $errmsg

=back

=for html </blockquote>

=cut

  $self->{errmsg} = $errmsg if $errmsg;

  return $self->{errmsg};
}    # errmsg

sub error(;$) {
  my ($self, $error) = @_;

=pod

=head2 error ($error)

Returns the last error number. Optional set the error number if specified

Parameters:

=for html <blockquote>

=over

=item $error

Error number to set

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $error

Last error

=back

=for html </blockquote>

=cut

  # Watch here as $error can very well be 0 which "if $error" would evaluate
  # to false leaving $self->{error} undefined
  $self->{error} = $error if defined $error;

  return $self->{error};
}    # error

sub fieldType($$) {
  my ($self, $table, $fieldName) = @_;

=pod

=head2 fieldType ($table, $fieldname)

Returns the field type for the $table, $fieldname combination.

Parameters:

=for html <blockquote>

=over

=item $table

Table to return field type from.

=item $fieldname

Fieldname to return the field type from.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $fieldType

Fieldtype enum

=back

=for html </blockquote>

=cut

  return $UNKNOWN unless $self->{loggedin};

  # If we've already computed the fieldTypes for the fields in this table then
  # return the value
  if ($FIELDS{$table}) {

    # If we already have this fieldType just return it
    if (defined $FIELDS{$table}{$fieldName}) {
      return $FIELDS{$table}{$fieldName};
    } else {
      return $UNKNOWN;
    }    # if
  }    # if

  my $entityDef = $self->{session}->GetEntityDef ($table);

  for (@{$entityDef->GetFieldDefNames}) {
    $FIELDS{$table}{$_} = $entityDef->GetFieldDefType ($_);
  }    # for

  if (defined $FIELDS{$table}{$fieldName}) {
    return $FIELDS{$table}{$fieldName};
  } else {
    return $UNKNOWN;
  }    # if
}    # fieldType

sub fieldTypeName($$) {
  my ($self, $table, $fieldName) = @_;

=pod

=head2 fieldTypeName ($table, $fieldname)

Returns the field type name for the $table, $fieldname combination.

Parameters:

=for html <blockquote>

=over

=item $table

Table to return field type from.

=item $fieldname

Fieldname to return the field type from.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $fieldTypeName

Fieldtype name

=back

=for html </blockquote>

=cut

  my $fieldType = $self->fieldType ($table, $fieldName);

  return $UNKNOWN unless $fieldType;

  if ($fieldType == $STRING) {
    return "STRING";
  } elsif ($fieldType == $MULTILINE_STRING) {
    return "MULTILINE_STRING";
  } elsif ($fieldType == $INT) {
    return "INT";
  } elsif ($fieldType == $DATE_TIME) {
    return "DATE_TIME";
  } elsif ($fieldType == $REFERENCE) {
    return "REFERENCE";
  } elsif ($fieldType == $REFERENCE_LIST) {
    return "REFERENCE_LIST";
  } elsif ($fieldType == $ATTACHMENT_LIST) {
    return "ATTACHMENT_LIST";
  } elsif ($fieldType == $ID) {
    return "ID";
  } elsif ($fieldType == $STATE) {
    return "STATE";
  } elsif ($fieldType == $JOURNAL) {
    return "JOURNAL";
  } elsif ($fieldType == $DBID) {
    return "DBID";
  } elsif ($fieldType == $STATETYPE) {
    return "STATETYPE";
  } elsif ($fieldType == $RECORD_TYPE) {
    return "RECORD_TYPE";
  } elsif ($fieldType == $UNKNOWN) {
    return "UNKNOWN";
  }    # if
}    # fieldTypeName

sub find($;$@) {
  my ($self, $table, $condition, @fields) = @_;

=pod

=head2 find ($;$@)

Find records in $table. You can specify a $condition and which fields you wish
to retrieve. Specifying a smaller set of fields means less data transfered and
quicker retrieval so only retrieve the fields you really need.

Parameters:

=for html <blockquote>

=over

=item $table

Name of the table to search

=item $condition

Condition to use. If you want all records then pass in undef. Only simple
conditions are supported. You can specify compound conditions (e.g. field1 ==
'foo' and field1 == 'bar' or field2 is not null). No parenthesizing is
supported (yet).

The following conditionals are supported

=over

=item Equal (==|=)

=item Not Equal (!=|<>)

=item Less than (<)

=item Greater than (>)

=item Less than or equal (<=)

=item Greater than or equal (>=)

=item Like

=item Is null

=item Is not null

=item In

=back

Note that "is not null" is currently not working in the REST module (it works
in the api and thus also in the client/server model). This because the
OLSC spec V1.0 does not support it.

As for "Like"", you'll need to specify "<fieldname> like '%var%'" for the
condition.

"In" is only available in the REST interface as that's what OLSC supports. It's
syntax would be "<fieldname> In 'value1', 'value2', 'value3'..."

Also conditions can be combined with (and|or) so in the api you could do "in"
as "<fieldname> = 'value1 or <fieldname> = 'value2" or <fieldname> = 'value3'".

Complicated expressions with parenthesis like "(Project = 'Athena' or Project =
'Hawaii') and Category = 'Aspen'" are not supported.

=item @fields

An array of fieldnames to retrieve

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $result or ($result, $nbrRecs)

Internal structure to be used with getNext. If in an array context then $nbrRecs
is also returned.

=back

=for html </blockquote>

=cut

  $condition ||= '';

  unless ($self->connected) {
    $self->_setError ('You must connect to Clearquest before you can call find',
      '-1');

    return;
  }    # unless

  my $entityDef;

  eval {$entityDef = $self->{session}->GetEntityDef ($table)};

  if ($@) {
    $self->_setError ($@, -1);

    return ($@, -1);
  }    # if

  @fields = $self->_setFields ($table, @fields);

  return unless @fields;

  my $query = $self->{session}->BuildQuery ($table);

  for (@fields) {
    eval {$query->BuildField ($_)};

    if ($@) {
      $self->_setError ($@);

      carp $@;
    }    # if
  }    # for

  $self->_parseConditional ($query, $condition);

  return if $self->error;

  my $result  = $self->{session}->BuildResultSet ($query);
  my $nbrRecs = $result->ExecuteAndCountRecords;

  $self->_setError;

  my %resultSet = (result => $result);

  if (wantarray) {
    return (\%resultSet, $nbrRecs);
  } else {
    return \%resultSet;
  }    # if
}    # find

sub findIDs($) {
  my ($str) = @_;

=pod

=head2 findIDs ($)

Given a $str or a reference to an array of strings, this function returns a list
of Clearquest IDs found in the $str. If called in a scalar context this function
returns a comma separated string of IDs found. Note that duplicate IDs are
eliminated. Also, the lists of IDs may refer to different Clearquest databases.

Parameters:

=for html <blockquote>

=over

=item $str

String or reference to an array of strings to search

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item @IDs or $strIDs

Either an array of CQ IDs or a comma separated list of CQ IDs.

=back

=for html </blockquote>

=cut

  $str = join ' ', @$str if ref $str eq 'ARRAY';

  my @IDs = $str =~ /([A-Za-z]\w{1,4}\d{8})/gs;

  my %IDs;

  map {$IDs{$_} = 1;} @IDs;

  if (wantarray) {
    return keys %IDs;
  } else {
    return join ',', keys %IDs;
  }    # if
}    # findIDs

sub get($$;@) {
  my ($self, $table, $id, @fields) = @_;

=pod

=head2 get ($$)

Return a record that you have the id or key of.

Parameters:

=for html <blockquote>

=over

=item $table

The $table to get the record from

=item $id

The $id or key to use to retrieve the record

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %record

Hash of name/value pairs for all the fields in $table

=back

=for html </blockquote>

=cut

  unless ($self->connected) {
    $self->_setError ('You must connect to Clearquest before you can call get',
      '-1');

    return;
  }    # unless

  @fields = $self->_setFields ($table, @fields);

  return unless @fields;

  my $entity;

  eval {$entity = $self->{session}->GetEntity ($table, $id)};

  if ($@) {
    $self->_setError ($@);

    return;
  }    # if

  my %record;

  for (@fields) {
    my $fieldType = $entity->GetFieldValue ($_)->GetType;

    if ($fieldType == $CQPerlExt::CQ_REFERENCE_LIST) {
      $record{$_} = $entity->GetFieldValue ($_)->GetValueAsList;
    } else {
      $record{$_} = $entity->GetFieldValue ($_)->GetValue;
      $record{$_} ||= '' if $self->{emptyStringForUndef};

      # Fix any UTC dates
      if ($fieldType == $CQPerlExt::CQ_DATE_TIME) {
        $record{$_} = _UTC2Localtime ($record{$_});
      }    # if
    }    # if
  }    # for

  $self->_setError;

  return %record;
}    # get

sub getDBID($$;@) {
  my ($self, $table, $dbid, @fields) = @_;

=pod

=head2 getDBID ($$;@)

Return a record that you have the dbid

Parameters:

=for html <blockquote>

=over

=item $table

The $table to get the record from

=item $dbid

The $dbid to use to retrieve the record

=item @fields

Array of field names to retrieve (Default: All fields)

Note: Avoid getting all fields for large records. It will be slow and bloat your
script's memory usage.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %record

Hash of name/value pairs for all the fields in $table

=back

=for html </blockquote>

=cut

  unless ($self->connected) {
    $self->_setError (
      'You must connect to Clearquest before you can call getDBID', '-1');

    return;
  }    # unless

  @fields = $self->_setFields ($table, @fields);

  my $entity;

  eval {$entity = $self->{session}->GetEntityByDbId ($table, $dbid)};

  if ($@) {
    $self->_setError ($@);

    return;
  }    # if

  my %record;

  for (@fields) {
    my $fieldType = $entity->GetFieldValue ($_)->GetType;

    if ($fieldType == $CQPerlExt::CQ_REFERENCE_LIST) {
      $record{$_} = $entity->GetFieldValue ($_)->GetValueAsList;
    } else {
      $record{$_} = $entity->GetFieldValue ($_)->GetValue;
      $record{$_} ||= '' if $self->{emptyStringForUndef};

      # Fix any UTC dates
      if ($fieldType == $CQPerlExt::CQ_DATE_TIME) {
        $record{$_} = _UTC2Localtime ($record{$_});
      }    # if
    }    # if
  }    # for

  $self->_setError;

  return %record;
}    # getDBID

sub getDynamicList($) {
  my ($self, $list) = @_;

=pod

=head2 getDynamicList ($)

Return the entries of a dynamic list

Parameters:

=for html <blockquote>

=over

=item $list

The name of the dynamic list

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item @entries

An array of entries from the dynamic list

=back

=for html </blockquote>

=cut

  return () unless $self->connected;

  return @{$self->{session}->GetListMembers ($list)};
}    # getDynamicList

sub getNext($) {
  my ($self, $result) = @_;

=pod

=head2 getNext ($)

Return the next record that qualifies from a preceeding call to the find method.

Parameters:

=for html <blockquote>

=over

=item $result

The $result returned from find.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %record

Hash of name/value pairs for the @fields specified to find.

=back

=for html </blockquote>

=cut

  unless ($self->connected) {
    $self->_setError (
      'You must connect to Clearquest before you can call getNext', '-1');

    return;
  }    # unless

# Here we need to do special processing to gather up reference list fields, if
# any. If we have a reference list field in the field list then Clearquest
# returns multiple records - one for each entry in the reference list. Thus if
# you were getting say the key field of a record and a reference list field like
# say Projects, you might see:
#
# Key Value     Projects
# ---------     --------
# key1          Athena
# key1          Apollo
# key1          Gemini
#
# Things get combinatoric when multiple reference list fields are involved. Our
# strategy here is to keep gathering all fields that change into arrays assuming
# they are reference fields as long as the dbid field has not changed.
  my %record;

  while () {
    unless ($result->{lastDBID}) {

      # Move to the first record
      last unless $result->{result}->MoveNext == $CQPerlExt::CQ_SUCCESS;
    } elsif ($result->{lastDBID} == $result->{thisDBID}) {

      # If the dbid is the same then we have at least one reference list field
      # in the request so we need to move to the next record
      last unless $result->{result}->MoveNext == $CQPerlExt::CQ_SUCCESS;
    } else {

      # If lastDBID != thisDBID then set lastDBID to thisDBID so we can process
      # this group
      $result->{lastDBID} = $result->{thisDBID};

      delete $result->{lastRecord};
    }    # unless

    my $nbrColumns = $result->{result}->GetNumberOfColumns;

    my $column = 1;

    # Format %record
    while ($column <= $nbrColumns) {
      my $name  = $result->{result}->GetColumnLabel ($column);
      my $value = $result->{result}->GetColumnValue ($column++);

      # Fix any UTC dates - _UTC2Localtime will only modify data if the data
      # matches a UTC datetime.
      $value = _UTC2Localtime ($value) if $value;

      $value ||= '' if $self->{emptyStringForUndef};

      $record{$name} = $value;
    }    # while

    %{$result->{lastRecord}} = %record unless $result->{lastRecord};

    # Store this record's DBID
    $result->{thisDBID} = $record{dbid};

    if ($result->{lastDBID}) {
      if ($result->{thisDBID} == $result->{lastDBID}) {

      # Since the dbid's are the same, we have at least one reference list field
      # and we need to compare all fields
        for my $field (keys %record) {

          # If the field is blank then skip it
          next if $record{$field} eq '';

          # Here we check the field in %lastRecord to see if it was a reference
          # list with more than one entry.
          if (ref \$result->{lastRecord}{$field} eq 'ARRAY') {

          # Check to see if this entry is already in the list of current entries
            next if grep {/^$record{$field}$/} @{$result->{lastRecord}{$field}};
          }    # if

         # This checks to see if the current field is a scalar and we have a new
         # value, then the scalar needs to be changed to an array
          if (ref \$result->{lastRecord}{$field} eq 'SCALAR') {

           # If the field is the same value then no change, no array. We do next
           # to start processing the next field
            next if $result->{lastRecord}{$field} eq $record{$field};

            # Changed $lastRecord{$_} to a reference to an ARRAY
            $result->{lastRecord}{$field} =
              [$result->{lastRecord}{$field}, $record{$field}];
          } else {

            # Push the value only if it does not already exists in the array
            push @{$result->{lastRecord}{$field}}, $record{$field}
              unless grep {/^$record{$field}$/}
              @{$result->{lastRecord}{$field}};
          }    # if
        }    # for

        # Transfer %lastRecord -> %record
        %record = %{$result->{lastRecord}};
      } else {
        %record = %{$result->{lastRecord}};

        last;
      }    # if
    }    # if

    # The $lastDBID is now $thisDBID
    $result->{lastDBID} = $result->{thisDBID};

    # Update %lastRecord
    %{$result->{lastRecord}} = %record;
  }    # while

  $self->_setError;

  # Never return dbid...
  delete $record{dbid};

  return %record;
}    # getNext

sub id2db($) {
  my ($ID) = @_;

=pod

=head2 id2db ($)

This function returns the database name given an ID.

Parameters:

=for html <blockquote>

=over

=item $ID

The ID to extract the database name from

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $database

Returns the name of the database the ID is part of or undef if not found.

=back

=for html </blockquote>

=cut

  if ($ID =~ /([A-Za-z]\w{1,4})\d{8}/) {
    return $1;
  } else {
    return;
  }    # if
}    # id2db

sub key($$) {
  my ($self, $table, $dbid) = @_;

=pod

=head2 key ($$)

Return the key of the record given a $dbid

Parameters:

=for html <blockquote>

=over

=item $table

Name of the table to lookup

=item $dbid

Database ID of the record to retrieve

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item key

=back

=for html </blockquote>

=cut

  unless ($self->connected) {
    $self->_setError ('You must connect to Clearquest before you can call key',
      '-1');

    return;
  }    # unless

  my $entity;

  eval {$entity = $self->{session}->GetEntityByDbId ($table, $dbid)};

  return $entity->GetDisplayName;
}    # key

sub modify($$$$;@) {
  my ($self, $table, $key, $action, $values, @ordering) = @_;

=pod

=head2 modify ($$$$;@)

Update record(s)

Parameters:

=for html <blockquote>

=over

=item $table

The $table to get the record from

=item $key

The $key identifying the record to modify

=item $action

Action to perform the modification under. Default is 'Modify'.

=item $values

Hash reference containing name/value that have the new values for the fields

=item @ordering

Array containing field names that need to be processed in order. Not all fields
mentioned in the $values hash need be mentioned here. If you have fields that
must be set in a particular order you can mention them here. So, if you're
modifying the Defect record, but you need Project set before Platform,  you need
only pass in an @ordering of qw(Project Platform). They will be done first, then
all of the rest of the fields in the $values hash. If you have no ordering
dependencies then you can simply omit @ordering.

Note that the best way to determine if you have an ordering dependency try using
a Clearquest client and note the order that you set fields in. If at anytime
setting one field negates another field via action hook code then you have just
figured out that this field needs to be set before the file that just got
negated.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $errmsg

The $errmsg, if any, when performing the update (empty string for success)

=back

=for html </blockquote>

=cut

  unless ($self->connected) {
    $self->_setError (
      'You must connect to Clearquest before you can call modify', '-1');

    return $self->{errmsg};
  }    # unless

  my %record = $self->get ($table, $key, qw(dbid));

  return $self->modifyDBID ($table, $record{dbid}, $action, $values, @ordering);
}    # modify

sub modifyDBID($$$$;@) {
  my ($self, $table, $dbid, $action, $values, @ordering) = @_;

=pod

=head2 modifyDBID ($$$%)

Update a unique record (by DBID)

Parameters:

=for html <blockquote>

=over

=item $table

The $table to get the record from

=item $dbid

The $dbid of the record to update. Note that the find method always includes the
dbid of a record in the hash that it returns.

=item $action

Action to perform the modification under. Default is 'Modify'.

=item %update

Hash containing name/value that have the new values for the fields

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $errmsg

The $errmsg, if any, when performing the update (empty string for success)

=back

=for html </blockquote>

=cut

  $action ||= 'Modify';

  my %values = ();

  %values = %$values if $values;

  my $entity;

  eval {$entity = $self->{session}->GetEntityByDbId ($table, $dbid)};

  if ($@) {
    $self->_setError ($@);

    return;
  }    # if

  eval {$entity->EditEntity ($action)};

  if ($@) {
    $self->_setError ($@);

    return $@;
  }    # if

  # First process all fields in @ordering, if specified
  for (@ordering) {
    if ($values{$_}) {
      $self->{errmsg} = $self->_setFieldValue ($table, $_, $values{$_});
    } else {
      $self->_setError (
        "$_ from the ordering array is not present in the value hash", -1);
    }    # if

    last unless $self->{errmsg} eq '';
  }    # for

  return $self->{errmsg} unless $self->{errmsg} eq '';

  # Now process the rest of the values
  for my $fieldName (keys %values) {
    next if grep {$fieldName eq $_} @ordering;

    $self->{errmsg} =
      $self->_setFieldValue ($entity, $table, $fieldName, $values{$fieldName});

    last unless $self->{errmsg} eq '';
  }    # for

  $self->_setError ($self->{errmsg});

  return $self->{errmsg} unless $self->{errmsg} eq '';

  $self->{errmsg} = $self->_commitRecord ($entity);
  $self->{error}  = $self->{errmsg} eq '' ? 0 : 1;

  return $self->{errmsg};
}    # modifyDBID

sub module() {
  my ($self) = @_;

=pod

=head2 module

Returns the current back end module we are using

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item module

=back

=for html </blockquote>

=cut

  return $self->{module};
}    # module

sub new(;%) {
  my ($class, %parms) = @_;

=pod

=head2 new ()

Construct a new Clearquest object.

Parameters:

Below are the key values for the %parms hash.

=for html <blockquote>

=over

=item CQ_SERVER

Webhost for REST module

=item CQ_USERNAME

Username to use to connect to the database

=item CQ_PASSWORD

Password to use to connect to the database

=item CQ_DATABASE

Clearquest database to connect to

=item CQ_DBSET

Database set to connect to

=item CQ_MODULE

One of 'rest', 'api' or 'client' (Default: From cq.conf). This determines which
backend module will be used.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearquest object

=back

=for html </blockquote>

=cut

  $parms{CQ_DATABASE} ||= $OPTS{CQ_DATABASE};
  $parms{CQ_USERNAME} ||= $OPTS{CQ_USERNAME};
  $parms{CQ_PASSWORD} ||= $OPTS{CQ_PASSWORD};
  $parms{CQ_DBSET}    ||= $OPTS{CQ_DBSET};

  my $self = bless {
    server              => $parms{CQ_SERVER},
    port                => $parms{CQ_PORT},
    database            => $parms{CQ_DATABASE},
    dbset               => $parms{CQ_DBSET},
    username            => $parms{CQ_USERNAME},
    password            => $parms{CQ_PASSWORD},
    emptyStringForUndef => 0,
    returnSystemFields  => 0,
  }, $class;

  my $module = delete $parms{CQ_MODULE};

  $module ||= $OPTS{CQ_MODULE};

  $module = lc $module;

  if ($module eq 'rest') {
    require Clearquest::REST;

    $self->{webhost} = $parms{CQ_WEBHOST} || $OPTS{CQ_WEBHOST};

    $self = Clearquest::REST->new ($self);
  } elsif ($module eq 'client') {
    require Clearquest::Client;

    $self->{server} = $parms{CQ_SERVER} || $OPTS{CQ_SERVER};
    $self->{port}   = $parms{CQ_PORT}   || $OPTS{CQ_PORT};

    $self = Clearquest::Client->new ($self);
  } elsif ($module ne 'api') {
    croak "Unknown interface requested - $module";
  }    # if

  $self->{module} = $module;

  # Save reference to instaniated instance of this object to insure that global
  # variables are properly disposed of
  push @objects, $self;

  return $self;
}    # new

sub server() {
  my ($self) = @_;

=pod

=head2 server

Returns the current server if applicable

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $server

For api this will return ''. For REST and client/server this will return the 
server name that we are talking to.

=back

=for html </blockquote>

=cut

  return $self->{server};
}    # server

sub setOpts(%) {
  my ($self, %opts) = @_;

=pod

=head2 setOpts

Set options for operating

Parameters:

=for html <blockquote>

=over

=item %opts

=back

Options to set. The only options currently supported are emptyStringForUndef
and returnSystemFields. If set emptyStringForUndef will return empty strings for
empty fields instead of undef. Default: Empty fields are represented with undef.

System-owned fields are used internally by IBM Rational ClearQuest to maintain
information about the database. You should never modify system fields directly
as it could corrupt the database. If returnSystemFields is set then system
fields will be returned. Default: System fields will not be returned unless
explicitly stated in the @fields parameter. This means that if you do not
specify any fields in @fields, all fields will be returned except system fields,
unless you set returnSystemFields via this method or you explicitly mention the
system field in your @fields parameter.

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  $self->{emptyStringForUndef} = $opts{emptyStringForUndef}
    if $opts{emptyStringForUndef};
  $self->{returnSystemFields} = $opts{returnSystemFields}
    if $opts{returnSystemFields};

  return;
}    # setOpts

sub getOpt($) {
  my ($self, $option) = @_;

=pod

=head2 getOpt

Get option

Parameters:

=for html <blockquote>

=over

=item $option

=back

Option to retrieve. If non-existant then undef is returned.

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $option or undef if option doesn't exist

=back

=for html </blockquote>

=cut

  my @validOpts = qw (emptyStringForUndef returnSystemFields);

  if (grep {$option eq $_} @validOpts) {
    return $self->{$option};
  } else {
    return;
  }    # if
}    # getOpt

sub username() {
  my ($self) = @_;

=pod

=head2 username

Returns the current username (or the username that would be used)

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item username

=back

=for html </blockquote>

=cut

  return $self->{username};
}    # username

sub webhost() {
  my ($self) = @_;

  return $self->{webhost};
}    # webhost

# Internal GetConfig replacement
sub _GC_interpolate($%) {
  my ($str, %opts) = @_;

  my $copyStr = $str;

  while ($copyStr =~ /\$(\w+)/) {
    my $var = $1;

    if (exists $opts{$var}) {
      $str     =~ s/\$$var/$opts{$var}/;
      $copyStr =~ s/\$$var/$opts{$var}/;
    } elsif (exists $ENV{$var}) {
      $str     =~ s/\$$var/$ENV{$var}/;
      $copyStr =~ s/\$$var/$ENV{$var}/;
    } else {
      $copyStr =~ s/\$$var//;
    }    # if
  }    # while

  return $str;
}    # _GC_interpolate

sub _GC_processFile($%) {
  my ($configFile, %opts) = @_;

  while (<$configFile>) {
    chomp;

    next if /^\s*[\#|\!]/;    # Skip comments

    if (/\s*(.*?)\s*[:=]\s*(.*)\s*/) {
      my $key   = $1;
      my $value = $2;

      # Strip trailing spaces
      $value =~ s/\s+$//;

      # Interpolate
      $value = _GC_interpolate $value, %opts;

      if ($opts{$key}) {

        # If the key exists already then we have a case of multiple values for
        # the same key. Since we support this we need to replace the scalar
        # value with an array of values...
        if (ref $opts{$key} eq "ARRAY") {

          # It's already an array, just add to it!
          push @{$opts{$key}}, $value;
        } else {

          # It's not an array so make it one
          my @a;

          push @a, $opts{$key};
          push @a, $value;
          $opts{$key} = \@a;
        }    # if
      } else {

        # It's a simple value
        $opts{$key} = $value;
      }    # if
    }    # if
  }    # while

  return %opts;
}    # _GC_processFile

sub _GetConfig($) {
  my ($filename) = @_;

  my %opts;

  open my $configFile, '<', $filename
    or carp "Unable to open config file $filename";

  %opts = _GC_processFile $configFile;

  close $configFile;

  return %opts;
}    # _GetConfig

1;

=pod

=head1 DEPENDENCIES

=head2 Perl Modules

L<File::Basename|File::Basename>

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module

Multithreading causes the database to be reopened for each thread. This can
cause performance issues if the database is large or if the database is
accessed by multiple threads.

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2026 Andrew DeFaria <Andrew@DeFaria.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone else, you are strictly prohibited from removing any
copyright notice from that Modified Version.

Copyright Holder makes no, and expressly disclaims any, representation
or warranty, should the Package be used for any purpose.  The liability
of the Copyright Holder is limited to the maximum extent permitted by
law.

=cut
