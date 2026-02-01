# Mock logger for testing
package TestLogger;

sub new { bless { messages => [] }, shift }
sub error { push @{shift->{messages}}, 'ERROR: ' . join('', @_); }
sub warn { push @{shift->{messages}}, 'WARN: ' . join('', @_); }
sub debug { push @{shift->{messages}}, 'DEBUG: ' . join('', @_); }
sub get_messages { @{$_[0]->{messages}} }
sub clear { $_[0]->{messages} = [] }

1;
