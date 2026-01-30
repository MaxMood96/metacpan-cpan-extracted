# Prefer numeric version for backwards compatibility
BEGIN { require 5.008_009 }; ## no critic ( RequireUseStrict, RequireUseWarnings )
use strict;
use warnings;

package MooX::Role::HasLogger;

$MooX::Role::HasLogger::VERSION = 'v1.0.0';

use Log::Any                     ();
use MooX::Role::HasLogger::Types qw( Logger );
use Moo::Role                    qw( has );

has logger => ( is => 'ro', isa => Logger, lazy => 1, builder => 'build_logger' );

sub build_logger { Log::Any->get_logger( category => ref shift ) }

1
