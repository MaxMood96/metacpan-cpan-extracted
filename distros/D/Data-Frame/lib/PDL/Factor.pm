package PDL::Factor;
$PDL::Factor::VERSION = '0.006004';
# ABSTRACT: PDL subclass for keeping categorical data

use 5.016;
use warnings;

use failures qw/levels::mismatch levels::number/;

use PDL::Lite ();   # PDL::Lite is the minimal to get PDL work
use PDL::Core qw(pdl);
use PDL::Primitive qw(which);

use Module::Load;
use Ref::Util qw(is_plain_arrayref);
use Safe::Isa;
use Scalar::Util qw(blessed);
use Type::Params;
use Types::Standard qw(slurpy ArrayRef ConsumerOf Int);
use List::AllUtils ();

use parent 'PDL';
use Class::Method::Modifiers;

use Role::Tiny::With;
with qw(PDL::Role::Enumerable);

use overload
  '==' => \&_eq,
  'eq' => \&_eq,
  '!=' => \&_ne,
  'ne' => \&_ne,
  fallback => 1;

# after stringifiable role is added, the string method will exist
eval q{
	use overload (
        '""'   =>  \&PDL::Factor::string,
    );
};


# check if given levels have duplicates
sub _check_levels {
    my ( $class, $levels ) = @_;

    my %levels;
    for my $i ( 0 .. $#$levels ) {
        if ( ( $levels{ $levels->[$i] }++ ) > 0 ) {
            die "levels element [$i] is duplicated";
        }
    }
}

# extract levels from piddle or arrayref
sub _extract_levels {
    my ( $class, $x ) = @_;

    state $levels_from_arrayref = sub {
        my ($aref) = @_;

        # Sort levels if levels is not given on construction.
        my @uniq = sort { $a cmp $b } List::AllUtils::uniq(@$aref);
        return \@uniq;
    };

    if ( $x->$_DOES('PDL') ) {    # PDL
        $x = $x->slice( which( $x->isgood ) ) if $x->badflag;
        if ( $x->$_DOES('PDL::SV') ) {
            return $levels_from_arrayref->( [ $x->list ] );
        }
        else {
            return $levels_from_arrayref->( [ $x->uniq->qsort->list ] );
        }
    }
    else {    # arrayref
        return $levels_from_arrayref->($x);
    }
}

sub new {
    my ( $class, @args ) = @_;

    my $data;
    if( @args % 2 != 0 ) {
        $data = shift @args; # first arg
    }
    my %opt = @args;
    
    if ($data->$_DOES('PDL::Factor')) {
        unless (exists $opt{levels}) {
            return $data->copy;
        }

        #TODO: this does not support ND piddle yet.

        # reorder levels
        my @levels      = @{ delete $opt{levels} };
        my @integer_old = $data->{PDL}->list;
        my @levels_old = @{ $data->levels };
        my %levels_new = do {
            my $i = 0;
            map { $_ => $i++ } @levels;
        };
        my @integer_new = do {
            no warnings 'numeric';
            map {
                my $level = $levels_old[$_];
                defined $level ? $levels_new{$level} : -1;
            } @integer_old;
        };

        my $new = $class->new( [ $levels[0] ], levels => \@levels, %opt );
        my $p = PDL::Core::indx( \@integer_new );
        $p = $p->setbadif( $data->isbad ) if $data->badflag;
        $new->{PDL} = $p;
        return $new;
    }

    my $enum = $data;
    if ( !ref($enum) ) {    # make sure $enum is arrayref
        $enum = [$enum];
    }

    my $levels;
    if( my $levels_opt = $opt{levels} ) {
        # add the levels first if given levels option
        $class->_check_levels($levels_opt);
        $levels = $levels_opt;
    }
    else {
        $levels = $class->_extract_levels($enum);
    }

    # this is faster than Data::Rmap::rmap().
    state $rmap = sub {
        my ( $x, $levels ) = @_;
        is_plain_arrayref($x)
          ? [ map { __SUB__->( $_, $levels ) } @$x ]
          : ( $levels->{$x} // -1 );
    };

    my %levels = do {
        my $i = 0;
        map { $_ => $i++; } @$levels;
    };
    $enum =
      $rmap->( ( $enum->$_DOES('PDL') ? $enum->unpdl : $enum ), \%levels );

    my $self = $class->initialize();

    # BAD for integer enum data outside the range of level indices
    # For indx type, setnantobad() does not work, have to setvaltobad($neg).
    my $integer = PDL::Core::indx($enum)->setvaltobad(-1);
    $integer = $integer->setbadif($integer >= @$levels);

    $self->{PDL} .= $integer;
    $self->levels($levels);

    # rebless to PDL::Factor::Ordered if necessary
    my $class_ordered = 'PDL::Factor::Ordered';
    if ($opt{ordered} and not $class->DOES($class_ordered)) {
        load $class_ordered;
        bless $self, $class_ordered;
    }

    return $self;
}

sub levels {
    my $self = shift;

    if (@_) {
        my $val =
          ( @_ == 1 and is_plain_arrayref( $_[0] ) ) ? $_[0] : \@_;
        if ( defined $self->{_levels} and @$val != $self->number_of_levels ) {
            failure::levels::number->throw(
                {
                    msg   => "incorrect number of levels",
                    trace => failure->croak_trace,
                }
            );
        }
        $self->{_levels} = $val;
    }
    return $self->{_levels};
}

sub initialize {
    my ($class) = @_;
    return bless( { PDL => PDL::Core::null }, ref $class || $class );
}


sub glue {
    my $self = shift;

    state $check =
      Type::Params::compile( Int,
        slurpy ArrayRef [ ConsumerOf ['PDL::Factor'] ] );
    my ( $dim, $others ) = $check->(@_);
    
    my $class = ref($self);

    for my $x (@$others) {
        unless ( $self->_compare_levels( $self->levels, $x->levels ) ) {
            die "All piddles must have same levels to glue";
        }
    }

    if ( $dim != 0 ) {
        die('PDL::Factor::glue does not yet support $dim != 0');
    }

    my $new = $class->new( $self->levels, levels => $self->levels );
    $new->{PDL} = $self->{PDL}->glue( 0, map { $_->{PDL} } @$others );
    return $new;
}

sub copy {
    my ($self) = @_;
    my ($class) = ref($self);

    my $new = $class->new( $self->levels, levels => $self->levels );
    $new->{PDL} = $self->{PDL}->copy;
    return $new;
}

sub inplace {
    my $self = shift;
    $self->{PDL}->inplace(@_);
    return $self;
}

sub _call_on_pdl {
    my ($method) = @_;

    return sub {
        my $self = shift;
        return $self->{PDL}->$method(@_);
    };
}

for my $method (qw(isbad isgood ngood nbad)) {
    no strict 'refs';
    *{$method} = _call_on_pdl($method);
}

sub setbadif {
    my $self = shift;

    my $new = $self->copy;
    $new->{PDL} = $new->{PDL}->setbadif(@_);
    return $new;
}

around string => sub {
	my $orig = shift;
	my ($self, %opt) = @_;
	my $ret = $orig->(@_);
	if( exists $opt{with_levels} ) {
		my @level_string = grep { defined } $self->levels->flatten;
		$ret .= "\n";
		$ret .= "Levels: @level_string";
	}
	$ret;
};

sub _compare_levels {
    my ($class, $a, $b) = @_;

    return unless @$a == @$b;

    my $ea = List::AllUtils::each_arrayref($a, $b);
    while ( my ($x, $y) = $ea->() ) {
        return 0 unless $x eq $y;
    }
    return 1;
}

# TODO overload, compare factor level sets
#
#R
# > g <- iris
# > levels(g$Species) <- c( levels(g$Species), "test")
# > iris$Species == g$Species
# : Error in Ops.factor(iris$Species, g$Species) :
# :   level sets of factors are different
#
# > g <- iris
# > levels(g$Species) <- levels(g$Species)[c(3, 2, 1)]
# > iris$Species == g$Species
# : # outputs a logical vector where only 'versicolor' indices are TRUE
sub _eq {
	my ($self, $other, $d) = @_;
	# TODO need to look at $d to determine direction
	if( blessed($other) && $other->isa('PDL::Factor') ) {
		if( $self->_compare_levels($self->levels, $other->levels) ) {
			return $self->{PDL} == $other->{PDL};
			# TODO return a PDL::Logical
		} else {
			failure::levels::mismatch->throw({
					msg => "level sets of factors are different",
					trace => failure->croak_trace,
					payload => {
						self_levels => $self->levels,
						other_levels => $other->levels,
					}
				}
			);
		}
	} else {
		# TODO hacky. need to test this more
        my $key_idx = List::AllUtils::first_index { $_ eq $other }
                                                  @{$self->levels};
		return $self->{PDL} == $key_idx;
	}
}

sub _ne { !_eq(@_); }


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

PDL::Factor - PDL subclass for keeping categorical data

=head1 VERSION

version 0.006004

=head1 SYNOPSIS

    use PDL::Factor ();

    # extract levels from input
    my $blood_types = PDL::Factor->new( [ qw(B A AB A B A B O AB O) ] );

    # explicitly specify levels
    my $blood_types2 = PDL::Factor->new( [ qw(B A AB A B A B O AB O) ],
                                         levels => [ qw(A B AB O) ] );

=head1 METHODS

=head2 new( $data, %opt )

levels => $array_ref

=head2 glue

    $c = $a->glue($dim, $b, ...);

Glue two or more PDLs together along an arbitrary dimension.
For now it only supports 1D PDL::Factor piddles, and C<$dim> has to be C<0>.

=head1 SEE ALSO

L<PDL>

=head1 AUTHORS

=over 4

=item *

Zakariyya Mughal <zmughal@cpan.org>

=item *

Stephan Loyd <sloyd@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014, 2019-2022 by Zakariyya Mughal, Stephan Loyd.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
