package Clearquest::REST;

use strict;
use warnings;

=pod

=head1 NAME REST.pm

Clearquest REST client - Provide access to Clearquest via the REST interface

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 2.16 $

=item Created

Wed May 30 11:43:41 PDT 2011

=item Modified

2013/03/26 02:24:01

=back

=head1 SYNOPSIS

Provides a RESTful interface to Clearquest

=head1 DESCRIPTION

This module implements a simple interface to Clearquest. The backend uses REST
however this module hides all of the ugly details of the REST implementation.
Since REST is used, however, this module can be used by any normal Perl. See 
Perl Modules below of a list of Perl modules required.

This module is object oriented so you need to instantiate an object. Be careful
to make sure that you properly disconect from this object (See disconnect 
method).

The methods exported are simple: add, delete, get, modify... In most cases you
simply need to supply the table name and a hash of name value pairs to perform
actions. Record hashes representing name/value parts for the fields in the 
records are returned to you. 

Here's an example of use:

 use Clearquest;
 
 my $cq;
 
 END {
   $cq->disconnect if $cq;
 } # END

 $cq = Clearquest->new (CQ_MODULE => 'rest');
 
 $cq->connect;
 
 my %record = $cq->get ('Project', 'Athena');

 my %update = (
   Deprecated => 1,
   Projects   => 'Island', '21331', 'Hera' ],
 );
 
 $cq->modify ('VersionInfo', '1.0', 'Modify', \%update);
 
 if ($cq->error) {
   die "Unable to modify record\n" . $cq->errmsg;
 }
 
=head2 NOTES

Multiline text strings are limited to only 2000 characters by default. In order
to expand this you need to change the cqrest.properties file in:

C:\Program Files (x86)\IBM\RationalSDLC\common\CM\profiles\cmprofile\installedApps\dfltCell\TeamEAR.ear\cqweb.war\WEB-INF\classes

on the web server. Multiline text strings can theoretically grow to 2 gig, 
however when set even as small as 10 meg REST messes up! 

=head1 METHODS

The following methods are available:

=cut

use File::Basename;
use Carp;

use CGI qw (escapeHTML);
use Encode;
use LWP::UserAgent;
use HTTP::Cookies;
use MIME::Base64;
use REST::Client;
use XML::Simple;

use Clearquest;
use GetConfig;
use Utils;

use parent 'Clearquest';

our $VERSION = '$Revision: 2.16 $';
($VERSION) = ($VERSION =~ /\$Revision: (.*) /);

=pod

=head1 Options

Options are keep in the cq.conf file in the etc directory. They specify the
default options listed below. Or you can export the option name to the env(1) to 
override the defaults in cq.conf. Finally you can programmatically set the
options when you call new by passing in a %parms hash. The items below are the
key values for the hash.

=for html <blockquote>

=over

=item CQ_SERVER

The web host to contact with leading http://

=item CQ_USERNAME

User name to connect as (Default: From cq.conf)

=item CQ_PASSWORD

Password for CQ_USERNAME

=item CQ_DATABASE

Name of database to connect to (Default: From cq.conf)

=item CQ_DBSET

Database Set name (Default: From cq.conf)

=back

=cut

our (%RECORDS, %FIELDS);

# FieldTypes ENUM
my $UNKNOWN          = -1;
my $STRING           = 0;
my $MULTILINE_STRING = 1;
my $REFERENCE        = 2;
my $REFERENCE_LIST   = 3;
my $JOURNAL          = 4;
my $ATTACHMENT_LIST  = 5;
my $INT              = 6;
my $DATE_TIME        = 7;
my $DBID             = 8;
my $RECORD_TYPE      = 9;

sub _callREST ($$$;%) {
  my ($self, $type, $url, $body, %parms) = @_;

  # Set error and errmsg to no error
  $self->error (0);
  $self->{errmsg} = '';

  # Upshift the call type as the calls are actually like 'GET' and not 'get'
  $type = uc $type;

  # We only support these call types
  croak "Unknown call type \"$type\""
    unless $type eq 'GET'
    or $type eq 'POST'
    or $type eq 'PATCH'
    or $type eq 'OPTIONS'
    or $type eq 'PUT'
    or $type eq 'DELETE'
    or $type eq 'HEAD';

  # If the caller did not give us authorization then use the login member we
  # already have in the object
  unless ($parms{Authorization}) {
    $parms{$_} = $self->{login}{$_} foreach (keys %{$self->{login}});
  }    # unless

  # We need to use OSLC 2.0 for the conditional "is not null". So if we see a
  # "oslc.where" in the URL then add OSLC-Core-Version => '2.0' to %parms.
  if ($url =~ /oslc.where/) {
    $parms{'OSLC-Core-Version'} = '2.0';
  }    # if

  # Remove the host portion if any
  $url =~ s/^http.*$self->{server}//;

  # Call the REST call (Different calls have different numbers of parameters)
  if ( $type eq 'GET'
    or $type eq 'DELETE'
    or $type eq 'OPTIONS'
    or $type eq 'HEAD')
  {
    $self->{rest}->$type ($url, \%parms);
  } else {
    $self->{rest}->$type ($url, $body, \%parms);
  }    # if

  return $self->error;
}    # _callREST

sub _getRecordName ($) {
  my ($self, $query) = @_;

  $self->_callREST ('get', $query);

  if ($self->error) {
    $self->errmsg ("Unable to get record name for $query");

    return;
  }    # if

  my %record = %{XMLin ($self->{rest}->responseContent)};

  return $record{element}{name};
}    # _getRecordName

sub _getAttachmentList ($$) {
  my ($self, $result, $fields) = @_;

  croak ((caller (0))[3] . ' is not implemented');

  return;
}    # _getAttachmentList

sub _getInternalID ($$) {
  my ($self, $table, $key) = @_;

  my $query =
"/cqweb/oslc/repo/$self->{dbset}/db/$self->{database}/record/?rcm.type=$table&";

  $query .= "rcm.name=$key";

  $self->_callREST ('get', $query);

  unless ($self->error) {
    my %result = %{XMLin ($self->{rest}->responseContent)};

    return $result{entry}{id};
  } else {
    $self->errmsg ("Record not found (Table: $table, Key: \"$key\")");

    return $self->errmsg;
  }    # unless
}    # _getInternalID

sub _getRecord ($$@) {
  my ($self, $table, $url, @fields) = @_;

  $self->{fields} = [$self->_setFields ($table, @fields)];

  $self->_callREST ('get', $url);

  return if $self->error;

  # Now parse the results
  my %result = %{XMLin ($self->{rest}->responseContent)};

  if ($result{entry}{content}{$table}) {
    return $self->_parseFields ($table, %{$result{entry}{content}{$table}});
  } elsif (ref \%result eq 'HASH') {

    # The if test above will create an empty $result{entry}{content}. We need
    # to delete that
    delete $result{entry};

    return $self->_parseFields ($table, %result);
  } else {
    return;
  }    # if
}    # _getRecord

sub _getRecordID ($) {
  my ($self, $table) = @_;

  $self->records;

  return $RECORDS{$table};
}    # _getRecordID

sub _getRecordURL ($$;@) {
  my ($self, $table, $url, @fields) = @_;

  $self->{fields} = [$self->_setFields ($table, @fields)];

  $self->error ($self->_callREST ('get', $url));

  return if $self->error;

  return $self->_parseFields ($table,
    %{XMLin ($self->{rest}->responseContent)});
}    # _getRecordURL

sub _getReferenceList ($$) {
  my ($self, $url, $field) = @_;

  $self->error ($self->_callREST ('get', $url));

  return if $self->error;

  my %result = %{XMLin ($self->{rest}->responseContent)};

  my @values;

  # Need to find the field array here...
  foreach my $key (keys %result) {
    if (ref $result{$key} eq 'ARRAY') {
      foreach (@{$result{$key}}) {
        push @values, $$_{'oslc_cm:label'};
      }    # foreach

      last;
    } elsif (ref $result{$key} eq 'HASH' and $result{$key}{'oslc_cm:label'}) {
      push @values, $result{$key}{'oslc_cm:label'};
    }    # if
  }    # foreach

  return @values;
}    # _getReferenceList

sub _parseCondition ($$) {
  my ($self, $table, $condition) = @_;

  # Parse simple conditions only
  my ($field, $operator, $value);

  if ($condition =~
    /(\w+)\s*(==|=|!=|<>|<=|>=|<|>|in|is\s+null|is\s+not\s+null)\s*(.*)/i)
  {
    $field    = $1;
    $operator = $2;
    $value    = $3;

    if ($operator eq '==') {
      $operator = '=';
    } elsif ($operator eq '<>') {
      $operator = '!=';
    } elsif ($operator =~ /is\s+null/i) {
      return "$field in [\"\"]";
    } elsif ($operator =~ /is\s+not\s+null/i) {
      return "$field in [*]";
    } elsif ($operator =~ /in/i) {
      return "$field in [$value]";
    }    # if
  }    # if

  if ($operator eq '=' and $value =~ /^null$/i) {
    return "$field in [\"\"]";
  } elsif ($operator eq '!=' and $value =~ /^null$/i) {
    return "$field in [*]";
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

  # Convert datetimes to Zulu
  if (  $self->fieldType ($table, $field) == $DATE_TIME
    and $value !~ /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
  {
    $value = Clearquest::_UTCTime ($value);
  }    # if

  return "$field $operator \"$value\"";
}    # _parseCondition

sub _parseConditional ($$) {
  my ($self, $table, $condition) = @_;

  return 'oslc_cm.query=' unless $condition;

  my $parsedConditional;

  # Special case when the condition is ultra simple
  if ($condition !~
    /(\w+)\s*(==|=|!=|<>|<|>|<=|>=|in|is\s+null|is\s+not\s+null)\s*(.*)/i)
  {
    return "rcm.name=$condition";
  }    # if

  # TODO: This section needs improvement to handle more complex conditionals
  while () {
    if ($condition =~ /(.+?)\s+(and|or)\s+(.+)/i) {
      my $leftSide = $self->_parseCondition ($table, $1);

      $parsedConditional .= "$leftSide $2 ";
      $condition = $3;
    } else {
      $parsedConditional .= $self->_parseCondition ($table, $condition);

      last;
    }    # if
  }    # while

  # TODO: How would this work if we have a condition like 'f1 = "value" and
  # f2 is not null'?
  if ($parsedConditional =~ /in \[\*\]/) {
    return "oslc.where=$parsedConditional";
  } else {
    return "oslc_cm.query=$parsedConditional";
  }    # if
}    # _parseConditional

sub _parseFields ($%) {
  my ($self, $table, %record) = @_;

  foreach my $field (keys %record) {
    if ( $field =~ /:/
      or $field eq 'xmlns'
      or grep {/^$field$/} @{$self->{fields}} == 0)
    {
      delete $record{$field};

      next;
    }    # if

    my $fieldType = $self->fieldType ($table, $field);

    if (ref $record{$field} eq 'HASH') {
      if ($fieldType == $REFERENCE) {
        $record{$field} = $record{$field}{'oslc_cm:label'};
      } elsif ($fieldType == $REFERENCE_LIST) {
        my @values =
          $self->_getReferenceList ($record{$field}{'oslc_cm:collref'}, $field);

        $record{$field} = \@values;
      } elsif ($fieldType == $ATTACHMENT_LIST) {
        my @attachments =
          $self->_getAttachmentList ($record{$field}{'oslc_cm:collref'},
          $field);

        $record{$field} = \@attachments;
      } elsif ($fieldType == $RECORD_TYPE) {
        $record{$field} = $record{$field}{'oslc_cm:label'};
      } elsif (!%{$record{$field}}) {
        $record{$field} = undef;
      }    # if
    }    # if

    $record{$field} ||= '' if $self->{emptyStringForUndef};

    if ($fieldType == $DATE_TIME) {
      $record{$field} = Clearquest::_UTC2Localtime $record{$field};
    }    # if
  }    # foreach

  return %record;
}    # _parseFields

sub _parseRecordDesc ($) {
  my ($self, $table) = @_;

  # Need to get fieldType info
  my $recordID = $self->_getRecordID ($table);

  return unless $recordID;

  my $url = "$self->{uri}/record-type/$recordID";

  $self->_callREST ('get', $url);

  return if $self->error;

  my %result = %{XMLin ($self->{rest}->responseContent)};

  # Reach in deep for field definitions
  my %fields = %{$result{element}{complexType}{choice}{element}};

  foreach (keys %fields) {
    if ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:reference') {
      $FIELDS{$table}{$_}{FieldType} = $REFERENCE;
      $FIELDS{$table}{$_}{References} =
        $self->_getRecordName ($fields{$_}{'cq:refURI'});
    } elsif ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:multilineString') {
      $FIELDS{$table}{$_}{FieldType} = $MULTILINE_STRING;
    } elsif ($fields{$_}{simpleType}) {
      if ($fields{$_}{simpleType}{restriction}{base}) {
        if ($fields{$_}{simpleType}{restriction}{base} eq 'string') {
          $FIELDS{$table}{$_}{FieldType} = $STRING;
        } elsif (
          $fields{$_}{simpleType}{union}{simpleType}[0]{restriction}{base} eq
          'string')
        {
          $FIELDS{$table}{$_}{FieldType} = $STRING;
        } else {
          $FIELDS{$table}{$_}{FieldType} = $UNKNOWN;
        }    # if
      } elsif (
        $fields{$_}{simpleType}{union}{simpleType}[0]{restriction}{base} eq
        'string')
      {
        $FIELDS{$table}{$_}{FieldType} = $STRING;
      } elsif (
        $fields{$_}{simpleType}{union}{simpleType}[0]{restriction}{base} eq
        'cqf:integer')
      {
        $FIELDS{$table}{$_}{FieldType} = $INT;
      } else {
        $FIELDS{$table}{$_} = $UNKNOWN;
      }    # if
    } elsif ($fields{$_}{complexType} and $fields{$_}{'cq:refURI'}) {
      $FIELDS{$table}{$_}{FieldType} = $REFERENCE_LIST;
      $FIELDS{$table}{$_}{References} =
        $self->_getRecordName ($fields{$_}{'cq:refURI'});
    } elsif ($fields{$_}{complexType}
      and
      $fields{Symptoms}{complexType}{sequence}{element}{simpleType}{union}
      {simpleType}[1]{restriction}{base} eq 'string')
    {
      $FIELDS{$table}{$_}{FieldType} = $MULTILINE_STRING;
    } elsif ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:journal') {
      $FIELDS{$table}{$_}{FieldType} = $JOURNAL;
    } elsif ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:attachmentList') {
      $FIELDS{$table}{$_}{FieldType} = $ATTACHMENT_LIST;
    } elsif ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:integer') {
      $FIELDS{$table}{$_}{FieldType} = $INT;
    } elsif ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:dateTime') {
      $FIELDS{$table}{$_}{FieldType} = $DATE_TIME;
    } elsif ($fields{$_}{type} and $fields{$_}{type} eq 'cqf:recordType') {
      $FIELDS{$table}{$_}{FieldType} = $RECORD_TYPE;
    } else {
      $FIELDS{$table}{$_}{FieldType} = $UNKNOWN;
    }    # if

    if (  $fields{$_}{'cq:systemOwned'}
      and $fields{$_}{'cq:systemOwned'} eq 'true')
    {
      $FIELDS{$table}{$_}{SystemField} = 1;
    } else {
      $FIELDS{$table}{$_}{SystemField} = 0;
    }    # if
  }    # foreach

  return;
}    # _parseRecordDesc

sub _isSystemField ($$) {
  my ($self, $table, $fieldName) = @_;

  if ($FIELDS{$table}) {

    # If we already have this fieldType just return it
    if (defined $FIELDS{$table}{$fieldName}) {
      return $FIELDS{$table}{$fieldName}{SystemField};
    } else {
      return 0;
    }    # if
  }    # if

  $self->_parseRecordDesc ($table);

  if (defined $FIELDS{$table}{$fieldName}) {
    return $FIELDS{$table}{$fieldName}{SystemField};
  } else {
    return 0;
  }    # if
}    # _isSystemField

sub _setFields ($@) {
  my ($self, $table, @fields) = @_;

  # Cause %FIELDS to be expanded for $table
  $self->_parseRecordDesc ($table);

  unless (@fields) {
    foreach ($self->fields ($table)) {
      unless ($self->{returnSystemFields}) {
        next if $FIELDS{$table}{$_}{SystemField};
      }    # unless

      push @fields, $_;
    }    # foreach
  }    # unless

  push @fields, 'dbid' unless grep {/dbid/} @fields;

  return @fields;
}    # _setFields

sub _setFieldValue ($$$) {
  my ($self, $table, $fieldName, $fieldValue) = @_;

  return if $self->_isSystemField ($table, $fieldName);

  my $xml .= "<$fieldName>";

  my $fieldType = $self->fieldType ($table, $fieldName);

  if ( $fieldType == $STRING
    or $fieldType == $MULTILINE_STRING
    or $fieldType == $INT
    or $fieldType == $DATE_TIME)
  {
    # Fix MULTILINE_STRINGs
    if ($fieldType == $MULTILINE_STRING and ref $fieldValue eq 'ARRAY') {
      chomp @{$fieldName};

      $fieldValue = join "\n", @$fieldValue;
    }    # if

    $xml .= escapeHTML $fieldValue;
  } elsif ($fieldType == $REFERENCE) {
    my $tableReferenced = $self->fieldReference ($table, $fieldName);

    if ($tableReferenced) {
      $xml .= $self->_getInternalID ($tableReferenced, $fieldValue);
    } else {
      $self->error  (600);
      $self->errmsg ("Could not determine reference for $fieldName");

      return;
    }    # if
  } elsif ($fieldType == $REFERENCE_LIST) {

    # We'll allow either an array reference or a single value, which we will
    # turn into an array
    my @values;

    @values =
      ref $fieldValue eq 'ARRAY'
      ? @$fieldValue
      : ($fieldValue);

    my $tableReferenced = $self->fieldReference ($table, $fieldName);

    unless ($tableReferenced) {
      $self->error  (600);
      $self->errmsg ("Could not determine reference for $fieldName");

      return;
    }    # if

    foreach (@values) {
      my $internalID = $self->_getInternalID ($tableReferenced, $_);

      if ($internalID) {
        $xml .= "<value rdf:resource=\"$internalID\" oslc_cm:label=\"$_\"/>\n";
      } else {
        $self->error (600);
        $self->errmsg (
          "Could not find a valid/active $tableReferenced with a key of \"$_\""
        );

        return;
      }    # if
    }    # foreach
  } else {
    croak "Unable to handle field $fieldName fieldType: "
      . $self->fieldTypeName ($table, $fieldName);
  }    # if

  $xml .= "</$fieldName>\n";

  return $xml;
}    # _setFieldValue

sub _startXML ($) {
  my ($table) = @_;

  my $xml = << "XML";
<?xml version="1.0" encoding="UTF-8"?>
<$table
  xmlns="http://www.ibm.com/xmlns/prod/rational/clearquest/1.0/"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/terms/"
  xmlns:oslc_cm="http://open-services.net/xmlns/cm/1.0/">
XML

  return $xml;
}    # _startXML

sub add ($$;@) {
  my ($self, $table, $record, @ordering) = @_;

=pod

=head2 add ($table, %record)

Adds a %record to $table.

Parameters:

=for html <blockquote>

=over

=item $table

Table to add a record to (e.g. 'Defect')

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

=item $errmsg

Error message (if any)

=back

=for html </blockquote>

=cut

  my %record = %$record;
  my $xml    = _startXML $table;
  my $uri    = $self->{uri} . '/record';

  # First process all fields in the @ordering, if specified
  $xml .= $self->_setFieldValue ($table, $_, $record{$_}) foreach (@ordering);

  foreach my $field (keys %record) {
    next if InArray $field, @ordering;

    $xml .= $self->_setFieldValue ($table, $field, $record{$field});
  }    # foreach

  $xml .= "</$table>";

  $self->_callREST ('post', $uri, $xml);

  # Get the DBID of the newly created record
  if ($self->{rest}{_res}{_headers}{location} =~ /-(\d+)$/) {
    return $1;
  } else {
    return;
  }    # if
}    # add

sub connect (;$$$$) {
  my ($self, $username, $password, $database, $dbset) = @_;

=pod

=head2 connect (;$$$$)

This method doesn't really connect but is included to be similar to the
Clearquest::connect method. It does set any of the username, password, 
database and/or dbset members

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

  if (ref $username eq 'HASH') {
    my %opts = %$username;

    $self->{username} = delete $opts{CQ_USERNAME};
    $self->{password} = delete $opts{CQ_PASSWORD};
    $self->{database} = delete $opts{CQ_DATABASE};
    $self->{dbset}    = delete $opts{CQ_DBSET};
  } else {
    $self->{username} = $username if $username;
    $self->{password} = $password if $password;
    $self->{database} = $database if $database;
    $self->{dbset}    = $dbset    if $dbset;
  }    # if

  # Set URI in case anything changed
  $self->{uri}      = "/cqweb/oslc/repo/$self->{dbset}/db/$self->{database}";
  $self->{loggedin} = 1;

  return 1;
}    # connect

sub connected () {
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

sub database () {
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

sub dbset () {
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

sub dbsets () {
  croak ((caller (0))[3] . ' is not implemented');
}    # dbsets

sub delete ($$) {
  my ($self, $table, $key) = @_;

=pod

=head2 delete ($table, $key)

Deletes a %record from $table.

Parameters:

=for html <blockquote>

=over

=item $table

Table from which to delete a record from (e.g. 'Defect')

=item $key

Key of the record to delete

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $errmsg

Error message (if any)

=back

=for html </blockquote>

=cut

  my $query = $self->_getInternalID ($table, $key);

  # Need to remove $self->{server} from beginning of $query
  $query =~ s/^http.*$self->{server}//;

  $self->_callREST ('delete', $query);

  return $self->errmsg;
}    # delete

sub DESTROY () {
  my ($self) = @_;

  # Attempt to delete session if we still have a rest object. Note that during
  # global destruction (like when you die or exit), the ordering of destruction
  # is unpredictable so we might not succeed.
  return unless $self->{rest};

  # Delete session - ignore error as there's really nothing we can do if this
  # fails.
  $self->_callREST ('delete', '/cqweb/oslc/session/');

  croak "Unable to release REST session in destructor" if $self->error;

  return;
}    # DESTROY

sub disconnect () {
  my ($self) = @_;

=pod

=head2 disconnect ()

Disconnects from REST. Note you should take care to call disconnect or use undef
to undefine your instantiated Clearquest::REST object. If your script dies or
exits without disconnecting you may cause web sessions to remain. You might try
something like:

 use Clearquest::REST;
 
 my $cq = Clearquest::REST->new;
 
  END {
    $cq->disconnect if $cq;
  } # END

Parameters:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $error

Error number (if any)

=back

=for html </blockquote>

=cut

  return unless $self->{rest};

  $self->_callREST ('delete', '/cqweb/oslc/session/');

  return $self->error;
}    # disconnect

sub errmsg (;$) {
  my ($self, $errmsg) = @_;

=pod

=head2 errmsg ($errmsg)

Returns the last error message. Optionally sets the error message if specified.

Parameters:

=for html <blockquote>

=over

=item $errmsg

Error message to set

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $errmsg

Last error message

=back

=for html </blockquote>

=cut

  if ($errmsg) {
    $self->{errmsg} = $errmsg;
  } else {

    # User defined errors are in the 600 series. If we have a user defined
    # error and the caller did not supply us an errmsg to set then they want
    # the user defined error we set so just return that.
    if ($self->{responseCode} >= 600) {
      return $self->{errmsg};
    } else {
      my $response = $self->response;

      if ($response and $response ne '') {
        my %xml = %{XMLin ($self->response)};

        if ($xml{Error}{message}) {
          $self->{errmsg} = $xml{Error}{message};
        } elsif (ref $xml{message} ne 'HASH' and $xml{message}) {
          $self->{errmsg} = $xml{message};
        } else {
          $self->{errmsg} = 'Unknown error';
        }    # if
      } else {
        $self->{errmsg} = '';
      }    # if
    }    # if
  }    # if

  return $self->{errmsg};
}    # errmsg

sub error (;$) {
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

  if (defined $error) {
    $self->{responseCode} = $error;
  } else {

    # If the user has not yet called any underlying REST functionality yet (for
    # example, they could have called the find method but have not asked for the
    # $nbrRecs) then we cannot call $self->{rest}->responseCode because the
    # REST::Client object has not been instantiated yet. So we'll return no
    # error.
    if ($self->{rest}{_res}) {
      $self->{responseCode} = $self->{rest}->responseCode;
    } else {
      $self->{responseCode} = 0;
    }    # if
  }    # if

  return 0 if $self->{responseCode} >= 200 and $self->{responseCode} < 300;
  return $self->{responseCode};
}    # error

sub fields ($) {
  my ($self, $table) = @_;

=pod

=head2 fields ($table)

Returns an array of the fields in a table

Parameters:

=for html <blockquote>

=over

=item $table

Table to return field info from.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item @fields

Array of the fields names for $table

=back

=for html </blockquote>

=cut

  my $recordID = $self->_getRecordID ($table);

  return unless $recordID;

  my $url = "$self->{uri}/record-type/$recordID";

  $self->_callREST ('get', $url);

  return if $self->error;

  my %result = %{XMLin ($self->{rest}->responseContent)};

  my @fields = keys %{$result{element}{complexType}{choice}{element}};

  return @fields;
}    # fields

sub fieldType ($$) {
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

  # If we've already computed the fieldTypes for the fields in this table then
  # return the value
  if ($FIELDS{$table}) {

    # If we already have this fieldType just return it
    if (defined $FIELDS{$table}{$fieldName}) {
      return $FIELDS{$table}{$fieldName}{FieldType};
    } else {
      return $UNKNOWN;
    }    # if
  }    # if

  $self->_parseRecordDesc ($table);

  if (defined $FIELDS{$table}{$fieldName}) {
    return $FIELDS{$table}{$fieldName}{FieldType};
  } else {
    return $UNKNOWN;
  }    # if
}    # fieldType

sub fieldReference ($$) {
  my ($self, $table, $fieldName) = @_;

=pod

=head2 fieldReference ($table, $fieldname)

Returns the name of the table this reference or reference list field references
or undef if this is not a reference or reference list field.

Parameters:

=for html <blockquote>

=over

=item $table

Table to return field reference from.

=item $fieldname

Fieldname to return the field type from.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $fieldType

Name of table this reference or reference list field references or undef if
this is not a reference or reference list field.

=back

=for html </blockquote>

=cut

  # If we've already computed the fieldTypes for the fields in this table then
  # return the value
  return $FIELDS{$table}{$fieldName}{References} if $FIELDS{$table};

  $self->_parseRecordDesc ($table);

  return $FIELDS{$table}{$fieldName}{References};
}    # fieldReference

sub find ($;$@) {
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

  $self->{url} = "$self->{uri}/record/?rcm.type=$table&"
    . $self->_parseConditional ($table, $condition);

  @fields = $self->_setFields ($table, @fields);

  # Remove dbid for find
  @fields = grep {$_ ne 'dbid'} @fields;

  if (@fields) {
    $self->{url} .= "&oslc_cm.properties=";
    $self->{url} .= join ',', @fields;
  }    # if

  # Save some fields for getNext
  $self->{fields} = \@fields;
  $self->{table}  = $table;

  $self->{url} .= "&oslc_cm.pageSize=1";

  return $self->{url} unless wantarray;

  # If the user wants an array then he wants ($reesult, $nbrRecs) and so we need
  # to go out and get that info.
  $self->_callREST ('get', $self->{url});

  return (undef, 0) if $self->error;

  # Now parse the results
  my %result = %{XMLin ($self->{rest}->responseContent)};

  return ($self->{url}, $result{'oslc_cm:totalCount'}{content});
}    # find

sub get ($$;@) {
  my ($self, $table, $key, @fields) = @_;

=pod

=head2 get ($table, $key, @fields)

Retrieve records from $table matching $key. Note $key can be a condition (e.g.
Project = 'Athena'). Return back @fields. If @fields is not specified then all
fields are returned.

Warning: Some Clearquest records are large. It's always better and faster to
return only the fields that you need.

Parameters:

=for html <blockquote>

=over

=item $table

Table to get records from (e.g. 'Defect')

=item $key

Key to use to get the record. Key is the field that is designated to be the key
for the record. 

=item @fields

An array of field names to return. It's usually better to specify only those
fields that you need.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %record

An hash representing the qualifying record.

=back

=for html </blockquote>

=cut

  my $url = "$self->{uri}/record/?rcm.type=$table&rcm.name=$key";

  if (@fields) {
    $url .= "&oslc_cm.properties=";
    $url .= 'dbid,' unless grep {/dbid/i} @fields;
    $url .= join ',', @fields;
  }    # if

  return $self->_getRecord ($table, $url, @fields);
}    # get

sub getDBID ($$;@) {
  my ($self, $table, $dbid, @fields) = @_;

=pod

=head2 get ($table, $key, @fields)

Retrieve records from $table matching $key. Note $key can be a condition (e.g.
Project = 'Athena'). Return back @fields. If @fields is not specified then all
fields are returned.

Warning: Some Clearquest records are large. It's always better and faster to
return only the fields that you need.

Parameters:

=for html <blockquote>

=over

=item $table

Table to get records from (e.g. 'Defect')

=item $key

Key to use to get the record. Key is the field that is designated to be the key
for the record. 

=item @fields

An array of field names to return. It's usually better to specify only those
fields that you need.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %record

An hash representing the qualifying record.

=back

=for html </blockquote>

=cut

  my $url = "$self->{uri}/record/";
  $url .= $self->_getRecordID ($table);
  $url .= '-';
  $url .= $dbid;

  if (@fields) {
    $url .= "?oslc_cm.properties=";
    $url .= 'dbid,' unless grep {/dbid/i} @fields;
    $url .= join ',', @fields;
  }    # if

  return $self->_getRecord ($table, $url);
}    # getDBID

sub getDynamicList () {
  croak ((caller (0))[3] . ' is not implemented');
}    # getDynamicList

sub getNext ($) {
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

  return unless $self->{url};

  my $url = $self->{url};

  $self->_callREST ('get', $url);

  return if $self->error;

  # Now parse the results
  my %result = %{XMLin ($self->{rest}->responseContent)};

  # Get the next link
  undef $self->{url};

  if (ref $result{link} eq 'ARRAY') {
    foreach (@{$result{link}}) {
      if ($$_{rel} eq 'next') {
        ($self->{url}) = ($$_{href} =~ /^http.*$self->{server}(.*)/);

        last;
      }    # if
    }    # foreach
  }    # if

  my %record;

  if (ref $result{entry}{content}{$self->{table}} eq 'HASH') {
    %record = $self->_parseFields ($self->{table},
      %{$result{entry}{content}{$self->{table}}});
  } elsif (ref $result{entry} eq 'HASH') {
    if ($result{entry}{id}) {
      %record = $self->_getRecordURL (
        $self->{table},
        $result{entry}{id},
        @{$self->{fields}}
      );
    }    # if
  }    # if

  # Get dbid
  if ($result{entry}{link}{href} =~ /-(\d+)$/) {
    $record{dbid} = $1;
  }    # if

  return %record;
}    # getNext

sub key ($$) {
  my ($self, $table, $dbid) = @_;

=pod

=head2 key ($$)

Return the key of the record given a $dbid 

NOTE: Not supported in REST implementation.

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

  croak "The method key is not support in the REST interface";
}    # key

sub modify ($$$$;@) {
  my ($self, $table, $key, $action, $values, @ordering) = @_;

=pod

=head2 modify ($table, $key, $action, $values, @ordering)

Updates records from $table matching $key.

Parameters:

=for html <blockquote>

=over

=item $table

Table to modify records (e.g. 'Defect')

=item $key

The $key of the record to modify.

=item $action

Action to use for modification (Default: Modify). You can use this to change
state for stateful records.

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

Error message (if any)

=back

=for html </blockquote>

=cut

  my %values = %$values;
  my $xml    = _startXML $table;

  $action ||= 'Modify';

  my $query = $self->_getInternalID ($table, $key);

  # Remove host portion
  $query =~ s/^http.*$self->{server}//;

  # Add on action
  $query .= "?rcm.action=$action";

  # First process all fields in the @ordering, if specified
  $xml .= $self->_setFieldValue ($table, $_, $values{$_}) foreach (@ordering);

  foreach my $field (keys %values) {
    next if InArray $field, @ordering;

    $xml .= $self->_setFieldValue ($table, $field, $values{$field});
  }    # foreach

  $xml .= "</$table>";

  $self->_callREST ('put', $query, $xml);

  return $self->errmsg;
}    # modify

sub modifyDBID ($$$$;@) {
  my ($self, $table, $dbid, $action, $values, @ordering) = @_;

=pod

=head2 modifyDBID ($table, $dbid, $action, %update)

Updates records from $table matching $dbid.

Parameters:

=for html <blockquote>

=over

=item $table

Table to modify records (e.g. 'Defect')

=item $dbid

The $dbid of the record to modify.

=item $action

Action to use for modification (Default: Modify). You can use this to change
state for stateful records.

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

Error message (if any)

=back

=for html </blockquote>

=cut

  my %values = %$values;
  my $xml    = _startXML $table;

  $action ||= 'Modify';

  my $query = "$self->{uri}/record/";
  $query .= $self->_getRecordID ($table);
  $query .= '-';
  $query .= $dbid;

  # Add on action
  $query .= "?rcm.action=$action";

  # First process all fields in the @ordering, if specified
  $xml .= $self->_setFieldValue ($table, $_, $values{$_}) foreach (@ordering);

  foreach my $field (keys %values) {
    next if InArray $field, @ordering;

    $xml .= $self->_setFieldValue ($table, $field, $values{$field});
  }    # foreach

  $xml .= "</$table>";

  $self->_callREST ('put', $query, $xml);

  return $self->errmsg;
}    # modifyDBID

sub new (;%) {
  my ($class, $self) = @_;

=pod

=head2 new (%parms)

Instantiate a new REST object. You can override the standard options by passing
them in as a hash in %parms.

Parameters:

=for html <blockquote>

=over

=item %parms

Hash of overriding options

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item REST object

=back

=for html </blockquote>

=cut

  $self->{server} ||= $Clearquest::OPTS{CQ_SERVER};

  $$self{base_url} = "$self->{server}/cqweb/oslc",
    $$self{uri} = "/cqweb/oslc/repo/$self->{dbset}/db/$self->{database}",
    $$self{login} = {

    #    'OSLC-Core-Version' => '2.0',
    Accept        => 'application/xml',
    Authorization => 'Basic '
      . encode_base64 "$self->{username}:$self->{password}",
    };

  bless $self, $class;

  # We create this UserAgent and Cookie Jar so we can set cookies to be
  # remembered and passed back and forth automatically. By doing this we re-use
  # the JSESSIONID cookie we allows us to reuse our login and to dispose of the
  # login session properly when we are destroyed.
  my $userAgent = LWP::UserAgent->new;

  # Set the cookie jar to use in-memory cookie management, cookies can be
  # persisted to disk, see HTTP::Cookies for more info.
  $userAgent->cookie_jar (HTTP::Cookies->new);

  $self->{rest} = REST::Client->new (
    host      => $self->{server},
    timeout   => 15,
    follow    => 1,
    useragent => $userAgent,
  );

  return $self;
}    # new

sub records () {
  my ($self) = @_;

=pod

=head2 records ()

Returns a hash of all records and their record numbers

Parameters:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %records

Hash of records and their record numbers

=back

=for html </blockquote>

=cut

  return if %RECORDS;

  my $url = "$self->{uri}/record-type/";

  $self->_callREST ('get', $url);

  unless ($self->error) {
    my %result = %{XMLin ($self->{rest}->responseContent)};

    foreach my $uri (keys %{$result{entry}}) {
      my ($recordID) = ($uri =~ /\/(\d+)/);

      $RECORDS{$result{entry}{$uri}{title}} = $recordID;
    }    # foreach
  }    # unless

  return %RECORDS;
}    # records

sub response () {
  my ($self) = @_;

=pod

=head2 response ()

Returns the response content

Parameters:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $respondContent

Response content from the last REST call

=back

=for html </blockquote>

=cut

  return $self->{rest}->responseContent;
}    # response

sub username () {
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

1;

=pod

=head1 CONFIGURATION AND ENVIRONMENT

DEBUG: If set then $debug is set to this level.

VERBOSE: If set then $verbose is set to this level.

TRACE: If set then $trace is set to this level.

=head1 DEPENDENCIES

=head2 Perl Modules

L<Carp>

L<Encode>

L<File::Basename|File::Basename>

L<HTTP::Cookies|HTTP::Cookies>

L<LWP::UserAgent|LWP::UserAgent>

L<MIME::Base64|MIME::Base64>

L<REST::Client|REST::Client>

L<XML::Simple|XML::Simple>

L<MIME::Base64|MIME::Base64>

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

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
