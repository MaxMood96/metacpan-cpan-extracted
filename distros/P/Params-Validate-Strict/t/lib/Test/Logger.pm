package Test::Logger;

# Mock logger for testing
sub new { bless { messages => [] }, shift }
sub error { push @{$_[0]->{messages}}, ['error', @_[1..$#_]] }
sub warn { push @{$_[0]->{messages}}, ['warn', @_[1..$#_]] }
sub debug { push @{$_[0]->{messages}}, ['debug', @_[1..$#_]] }
sub get_messages { @{shift->{messages}} }
sub clear { $_[0]->{messages} = [] }

1;
