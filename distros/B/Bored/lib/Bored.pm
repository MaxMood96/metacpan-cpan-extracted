package Bored;
use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Bored', $VERSION);

=head1 NAME

Bored - Do nothing, but with XS

=head1 SYNOPSIS

    use Bored;
    
    Bored::do_nothing_efficiently();  # Finally!
    
    my $pointless = Bored::is_pointless("meetings");  # Always true
    
    Bored::sigh();      # *sigh x8*
    Bored::whatever();  # ¯\_(ツ)_/¯
    Bored::meh(7);      # "meeeeeh"
    
    # Stare into the void (it stares back)
    my $void = Bored::stare_into_void();
    $void->stare_back();  # 👁️

=head1 DESCRIPTION

C<Bored> is what happens when you have XS skills but nothing useful to do.

It's a module that does nothing, but does it I<really fast>. We're talking
O(1) nothing here. That's right - constant time nothing, regardless of how
much nothing you need to not do.

=head2 WHY?

Because sometimes you need to not do something, and you need to not do it
at maximum speed.

=head2 FEATURES

=over 4

=item * XS-accelerated doing nothing

=item * SIMD-optimized sighing (8 sighs per cycle)

=item * Calibrated "meh" with adjustable intensity

=item * The void (it's a singleton, there's only one void)

=item * Certified 100% pointless

=back

=cut

# The Boredom constant - it's always 42
use constant BOREDOM_LEVEL => 42;

# The Void - there's only one, it's a singleton
{
    package Bored::Void;
    
    my $instance;
    
    sub new {
        return $instance //= bless { stared => 0 }, shift;
    }
    
    sub stare_back {
        shift->{stared}++;
        return "👁️";
    }
    
    sub depth { 'infinite' }
    sub whisper { return; }  # *crickets*
}

=head1 FUNCTIONS

=head2 how_Bored()

Returns how Bored you are (always 42).

=cut

sub how_Bored { BOREDOM_LEVEL }

=head2 is_pointless($thing)

Determines if something is pointless. Spoiler: it is.

=cut

sub is_pointless {
    my ($thing) = @_;
    return xs_is_pointless($thing);  # XS-accelerated truth
}

=head2 stare_into_void()

Returns a Void object representing infinite nothingness.

=cut

sub stare_into_void {
    stare_into_void_xs();  # XS contemplation
    return Bored::Void->new();
}

=head2 sigh()

Emits a SIMD-optimized sigh.

=cut

sub sigh {
    return accelerated_sigh();  # XS SIMD sigh
}

=head2 whatever()

The ultimate expression of apathy.

=cut

sub whatever {
    return ultimate_nothing();
}

=head2 meh($intensity)

Returns a calibrated "meh" (0-10 intensity).

=cut

sub meh {
    my ($intensity) = @_;
    $intensity //= 5;
    return xs_meh($intensity);  # XS-accelerated meh
}

=head2 wait_around($seconds)

Waits around for a bit. Does nothing during that time.

=cut

sub wait_around {
    my ($seconds) = @_;
    $seconds //= 1;
    select(undef, undef, undef, $seconds);
    return "done waiting";
}

=head1 EXPORTS

By default, Bored exports nothing. This is intentional and thematic.

=cut

sub import {
    my $class = shift;
    my $caller = caller;
    
    for my $func (@_) {
        no strict 'refs';
        *{"${caller}::${func}"} = \&{"${class}::${func}"};
    }
}

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE

Whatever. Do what you want.

=cut

1;

__END__
