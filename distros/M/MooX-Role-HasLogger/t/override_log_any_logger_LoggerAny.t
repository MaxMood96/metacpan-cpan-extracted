use strict;
use warnings;

use Test::More import => [ qw( is ok ) ], tests => 5;
use Test::Output qw( stderr_is );

my $class = 'Foo';
my $role  = 'MooX::Role::HasLogger';

eval qq{
  package $class;

  use Moo;
  use MooX::TypeTiny;
  use MooX::Role::HasLogger::Types qw( LoggerAny );
  use Type::Tiny::Duck             ();
  use namespace::clean;

  with qw( $role );

  has '+logger' => ( isa => LoggerAny );

  sub build_logger { Log::Any->get_logger( category => ref shift, default_adapter => 'Stderr' ) }

  1
};

is $@, '', "Moo class '$class' created dynamically" or die "\n";

is __PACKAGE__, 'main', "current package is 'main'";
ok $class->does( $role ), "class '$class' consumes role '$role'";

my $logger = $class->new->logger;
is $class, $logger->category, "default logger has 'category' attribute with value '$class'";

stderr_is { $logger->infof( 'log %s', 'something' ) } "log something\n", "'Stderr' is the default 'Log::Any::Adapter'"
