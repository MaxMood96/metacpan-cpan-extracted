use strict;
use warnings;

use Test::More import => [ qw( is ok ) ], tests => 5;

my $class = 'Foo';
my $role  = 'MooX::Role::HasLogger';

eval qq{
  package $class;

  use Moo;
  use MooX::TypeTiny;
  use MooX::Role::HasLogger::Types qw( LoggerAny );
  use namespace::clean;

  with qw( $role );

  has '+logger' => ( handles => LoggerAny->methods );

  1
};

is $@, '', "Moo class '$class' created dynamically" or die "\n";

is __PACKAGE__, 'main', "current package is 'main'";
ok $class->does( $role ), "class '$class' consumes role '$role'";

my $self = $class->new;
is $class, $self->category, "logger has 'category' attribute with value '$class'";

is $self->infof( 'log %s', 'something' ), 'log something',
  "delegating class '$class' uses method provided by the logger (the delegatee)"
