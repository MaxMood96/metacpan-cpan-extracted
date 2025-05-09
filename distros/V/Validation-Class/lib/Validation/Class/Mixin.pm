# Mixin Object for Validation::Class Classes

# Validation::Class::Mixin provides functions for processing for mixin objects
# and provides accessors for mixin directives. This class is derived from the
# L<Validation::Class::Mapping> class.

package Validation::Class::Mixin;

use strict;
use warnings;

use Validation::Class::Directives;
use Validation::Class::Errors;

use Validation::Class::Util '!has';
use Carp 'confess';

our $VERSION = '7.900059'; # VERSION

use base 'Validation::Class::Mapping';

my $directives = Validation::Class::Directives->new;

foreach my $directive ($directives->values) {

    # create accessors from default configuration (once)

    if ($directive->mixin) {

        my $name = $directive->name;

        next if __PACKAGE__->can($name);

        # errors object
        if ($name eq 'errors') {
            my %spec =
                ($name => sub { Validation::Class::Errors->new });
                Validation::Class::Util::has(%spec);
        }

        # everything else
        else {
            my %spec =
                ($name => sub { undef });
                Validation::Class::Util::has(%spec);
        }

    }

}

sub new {

    my $class = shift;

    my $config = $class->build_args(@_);

    confess "Can't create a new mixin object without a name attribute"
        unless $config->{name}
    ;

    my $self = bless {}, $class;

    $self->add($config);

    return $self;

}

1;
