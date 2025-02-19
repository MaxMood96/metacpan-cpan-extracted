package Mite::Shim;

# NOTE: Since the intention is to ship this file with a project, this file
# cannot have any non-core dependencies.

use strict;
use warnings;

sub _is_compiling {
    return $ENV{MITE_COMPILE} ? 1 : 0;
}

sub import {
    my $class = shift;
    my($caller, $file) = caller;

    # Turn on warnings and strict in the caller
    warnings->import;
    strict->import;

    if( _is_compiling() ) {
        require Mite::Project;
        Mite::Project->default->inject_mite_functions(
            package     => $caller,
            file        => $file,
        );
    }
    else {
        # Work around Test::Compile's tendency to 'use' modules.
        # Mite.pm won't stand for that.
        return if $ENV{TEST_COMPILE};

        # Changes to this filename must be coordinated with Mite::Compiled
        my $mite_file = $file . ".mite.pm";
        if( !-e $mite_file ) {
            require Carp;
            Carp::croak("Compiled Mite file ($mite_file) for $file is missing");
        }

        {
            local @INC = ('.', @INC);
            require $mite_file;
        }

        no strict 'refs';
        *{ $caller .'::has' } = sub {
            my $names = shift;
            $names = [$names] unless ref $names;
            my %args = @_;
            for my $name ( @$names ) {
               $name =~ s/^\+//;

               my $default = $args{default};
               if ( ref $default eq 'CODE' ) {
                   ${$caller .'::__'.$name.'_DEFAULT__'} = $default;
               }

               my $builder = $args{builder};
               if ( ref $builder eq 'CODE' ) {
                   *{"$caller\::_build_$name"} = $builder;
               }

               my $trigger = $args{trigger};
               if ( ref $trigger eq 'CODE' ) {
                   *{"$caller\::_trigger_$name"} = $trigger;
               }
            }

            return;
        };

        # Inject blank Mite routines
        for my $name (qw( extends )) {
            no strict 'refs';
            *{ $caller .'::'. $name } = sub {};
        }
    }
}

1;
