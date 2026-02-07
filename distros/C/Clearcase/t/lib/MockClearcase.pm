package MockClearcase;

use strict;
use warnings;
use base 'Clearcase';

# Override new to avoid real executable checks
sub new {
  my ($class) = @_;
  my $self = bless {
    client        => 'mock_client',
    region        => 'mock_region',
    registry_host => 'mock_registry',
    version       => '7.x',
    os            => 'linux',
    status        => 0,
    output        => '',
    lastcmd       => '',
  }, $class;
  return $self;
} ## end sub new

# Override execute to provide canned responses
sub execute {
  my ($self, $cmd) = @_;
  $self->{lastcmd} = "cleartool $cmd";

  my ($status, @output);
  $status = 0;

  if ($cmd eq 'lsregion') {
    @output = ('mock_region');
  } elsif ($cmd eq 'hostinfo -long') {
    @output = (
      'Client: mock_client',
      'Product: ClearCase 7.x',
      'Operating system: Linux',
      'Registry host: mock_registry',
      'Registry region: mock_region',
    );
  } elsif ($cmd =~ /^lsvob -s/) {
    @output = ('/vobs/mock_vob');
  } elsif ($cmd =~ /^lsvob -long\s*(.*)/) {
    my $tag = $1 || '/vobs/mock_vob';
    @output = (
      "Tag: $tag",
      "Global path: /net/mock_host/vobs/mock_vob.vbs",
      "Server host: mock_host",
      "Access: public",
      "Mount options: rw",
      "Region: mock_region",
      "Active: YES",
      "Vob tag replica uuid: 12345",
      "Vob on host: mock_host",
      "Vob server access path: /vobs/store/mock_vob.vbs",
      "Vob family uuid: abcde",
      "Vob registry attributes: none"
    );
  } elsif ($cmd =~ /^lsview -s/) {
    @output = ('mock_view');
  } elsif ($cmd =~ /^describe -fmt "%Na" vob:(.*)/) {
    my $vob = $1;
    @output = ("Name=$vob");
  } elsif ($cmd =~ /^describe -fmt "%Na" view:(.*)/) {
    my $view = $1;
    @output = ("Name=$view");
  } else {

    # Default fallback
    @output = ("Mock output for: $cmd");
  }

  $self->{status} = $status;
  $self->{output} = join "\n", @output;
  return ($status, @output);
} ## end sub execute

sub status {shift->{status}}
sub output {shift->{output}}

1;
