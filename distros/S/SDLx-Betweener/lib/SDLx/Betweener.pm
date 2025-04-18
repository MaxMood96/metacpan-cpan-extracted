package SDLx::Betweener;

use 5.010001;
use strict;
use warnings;
use Scalar::Util qw(weaken);
use SDL;
use SDLx::Betweener::Timeline;

our $VERSION = '0.0105';

require XSLoader;
XSLoader::load('SDLx::Betweener', $VERSION);

# tween types

use constant { TWEEN_INT  => 0, TWEEN_FLOAT => 1, TWEEN_PATH => 2,
               TWEEN_RGBA => 3, };
my @Tween_Lookup = qw(_tween_int _tween_float _tween_path _tween_rgba);

# proxy types

use constant { DIRECT_PROXY => 1, CALLBACK_PROXY => 2, METHOD_PROXY => 3 };
my %Proxy_Lookup = do { my $i = 1; map { $_ => $i++ } qw(ARRAY CODE HASH)};
$Proxy_Lookup{SCALAR} = DIRECT_PROXY;

# path types

use constant { LINEAR_PATH => 0, CIRCULAR_PATH => 1 };
my %Path_Lookup = do { my $i = 0; map { $_ => $i++ } qw(
    linear circular polyline
)};

# ease types

my @Ease_Names = qw(
    linear
    p2_in p2_out p2_in_out
    p3_in p3_out p3_in_out
    p4_in p4_out p4_in_out
    p5_in p5_out p5_in_out
    sine_in sine_out sine_in_out
    circular_in circular_out circular_in_out
    exponential_in exponential_out exponential_in_out
    elastic_in elastic_out elastic_in_out
    back_in back_out back_in_out
    bounce_in bounce_out bounce_in_out
);
my %Ease_Lookup = do { my $i = 0; map { $_ => $i++ } @Ease_Names };
sub Ease_Names { @Ease_Names }

sub new {
    my ($class, %args) = @_;
    my $timeline       = SDLx::Betweener::Timeline->new;
    my $move_handler   = sub { $timeline->tick };
    my $app            = delete $args{app};
    $app->add_move_handler($move_handler) if $app;
    my $self = bless {
        timeline     => $timeline,
        move_handler => $move_handler,
        app          => $app,
        %args,
    }, $class;
    weaken $self->{app};
    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->{app}->remove_move_handler($self->{move_handler})
        if $self->{app};
}

sub tick {
    my ($self, $now) = @_;
    $self->{timeline}->tick($now? $now: ());
}

sub tween_int {
    my ($self, %args) = @_;
    return $self->tween(TWEEN_INT, %args);
}

sub tween_float {
    my ($self, %args) = @_;
    return $self->tween(TWEEN_FLOAT, %args);
}

sub tween_path {
    my ($self, %args) = @_;
    return $self->tween(TWEEN_PATH, %args);
}

sub tween_spawn {
    my ($self, %args) = @_;
    my $on    = $args{on}                || die 'No "on" given';
    my $proxy = $Proxy_Lookup{ref $on}   || die "unknown proxy type: $on";
    my $waves = delete($args{waves})     || die 'No "waves" given to spawn tween';
    my $ease  = $Ease_Lookup{$args{ease} || 'linear'};

    die 'tween_spawn only supports linear ease, mail me if you need non-linear'
        if $ease;

    # inner callback calls the user given proxy
    # inner callback used by outer proxy which, which is a CALLBACK_PROXY 
    my $inner = $proxy == CALLBACK_PROXY? $on:
                $proxy == METHOD_PROXY  ? do {
                    my $method = [keys   %$on]->[0];
                    my $obj    = [values %$on]->[0];
                    weaken($obj);
                    sub { $obj->$method(@_) };
                }: die 'Cannot use direct proxy on spawn tween';
    
    # we need the tween object for the "on" arg to the tween, because the
    # spawn tween proxy needs to do calculation using tween properties
    # but to get the tween we need the "on" arg, a required constructor arg
    # so we close the "on" closure on a dummy lexical, and change it after
    # creating the tween, making sure the tween's ref to itself is weak

    # better would be a special kind of proxy, like CALLBACK_PROXY but also
    # sends the tween as parameter

    my $copy = 'Tween not set yet';

    # TODO wave skipping
    $args{on} = sub {
        my $top_wave      = shift;
        my $cycle_start_t = $copy->get_cycle_start_time;
        my $total_pause_t = $copy->get_total_pause_time;
        my $inter_wave_t  = $copy->get_duration / ($waves - 1);
        my $start_t       = $cycle_start_t + $total_pause_t + $top_wave * $inter_wave_t;
        $inner->($top_wave, $start_t);
    };

    $args{from} = 0;
    $args{to}   = $waves - 1;

    my $tween = $self->tween_int(%args);

    $copy = $tween;
    weaken($copy);

    return $tween;
}

sub tween_seek {
    my ($self, %args) = @_;
    my $on     = $args{on}              || die 'No "on" given';
    my $speed  = $args{speed}           || die 'No "speed" given';
    my $proxy  = $Proxy_Lookup{ref $on} || die "unknown proxy type: $on";

    my ($from, $to) = extract_range($proxy, $on, %args);

    $on = [%$on] if $proxy == METHOD_PROXY;

    return $self->{timeline}->_tween_seek(
        $proxy,
        $on,
        $speed,
        $from,
        $to,
        extract_completer(\%args),
    );
}

sub tween_fade {
    my ($self, %args) = @_;
    my $on    = $args{on}              || die 'No "on" given';
    my $proxy = $Proxy_Lookup{ref $on} || die "unknown proxy type: $on";

    my ($from, $to) = extract_range($proxy, $on, %args);;

    # 'to' is given as byte of final opacity, we turn it into final
    # rgba value using 'from'
    $to = ($from & 0xFFFFFF00) | $to;

    $args{from} = $from;
    $args{to}   = $to;

    return $self->tween_rgba(%args);
}

sub tween_rgba {
    my ($self, %args) = @_;
    my $builder = $Tween_Lookup[TWEEN_RGBA];
    my $on      = $args{on}                || die 'No "on" given';
    my $t       = $args{t}                 || die 'No "t" for duration given';
    my $proxy   = $Proxy_Lookup{ref $on}   || die "unknown proxy type: $on";
    my $ease    = $Ease_Lookup{$args{ease} || 'linear'};

    my ($from, $to) = extract_range($proxy, $on, %args);;

    $on = [%$on] if $proxy == METHOD_PROXY;

    return $self->{timeline}->$builder(
        $proxy,
        $on,
        $t,
        $from, $to,
        $ease,
        $args{forever} || 0,
        $args{repeat}  || 1,
        $args{bounce}  || 0,
        $args{reverse} || 0,
        extract_completer(\%args),
    );
}

sub tween {
    my ($self, $type, %args) = @_;
    my $builder = $Tween_Lookup[$type];
    my $on      = $args{on}                || die 'No "on" given';
    my $t       = $args{t}                 || die 'No "t" for duration given';
    my $proxy   = $Proxy_Lookup{ref $on}   || die "unknown proxy type: $on";
    my $ease    = $Ease_Lookup{$args{ease} || 'linear'};

    # these 2 only used for 1d tweens
    my ($from, $to);

    # these 2 only used for TWEEN_PATH type
    my $path = $args{path}? $Path_Lookup{$args{path}->[0] || die 'no path type'}
                          : LINEAR_PATH;
    my $path_args;

    # these tweens need from/to syntax sugar
    if (($type == TWEEN_INT  || $type == TWEEN_FLOAT) ||
        ($type == TWEEN_PATH && $path == LINEAR_PATH)) {

        ($from, $to) = extract_range($proxy, $on, %args);;
        $path_args = {from=>$from, to=>$to} if $type == TWEEN_PATH;

    } else { # then we are building a non linear path tween
             # no need for from/to but needs path_args
        $path_args = $args{path}->[1];
    }

    $on = [%$on] if $proxy == METHOD_PROXY;

    return $self->{timeline}->$builder(
        $proxy,
        $on,
        $t,
        ($type == TWEEN_PATH? ($path, $path_args): ($from, $to)),
        $ease,
        $args{forever} || 0,
        $args{repeat}  || 1,
        $args{bounce}  || 0,
        $args{reverse} || 0,
        extract_completer(\%args),
    );
}

sub extract_completer {
    my ($args) = @_;
    my $done = $args->{done} || sub {};
    $done = [%$done] if ref($done) eq 'HASH';
    return $done;
}

# extracts range from args
sub extract_range {
    my ($proxy, $on, %args) = @_;
    my ($from, $to);

    # try to get 'from/to' from range
    ($args{from}, $args{to}) = @{ $args{range} } if $args{range};
    # must have "to" by now
    $to = $args{to};
    die 'No "to" defined' unless defined $to;

    $from = $args{from};
    unless (defined $from) {
        # if we have no 'from' lets try to get it from the proxy
        if ($proxy == DIRECT_PROXY) {
            $from = ref($on) eq 'SCALAR'? $$on: $on;
        } elsif ($proxy == METHOD_PROXY) {
            my $method = [keys %$on]->[0];
            $from = [values %$on]->[0]->$method;
        } elsif ($proxy == CALLBACK_PROXY)
            { die 'No "from" given for callback proxy' }
    }
    return ($from, $to);
}

1;

=head1 NAME

SDLx::Betweener - SDL Perl XS Tweening Animation Library

=head1 SYNOPSIS

  # simple linear tween
  use SDLx::Betweener;
  
  # if you are writing a Perl SDL program, you probably have an app object
  $sdlx_app = SDLx::App->new(...);

  # tweener is the tween factory, gets ticks from app
  $tweener = SDLx::Betweener->new(app => $sdlx_app);

  $xy = [0, 0]; # tween the position stored in this array ref

  # animate the position $xy for 1 second from [0,0] to [640,480] linearly
  $tween = $tweener->tween_path(on => $xy, t => 1_000, to => [640, 480]);

  # tween will not do anything until started
  $tween->start;

  # xy will now be tweened between [0, 0] and [640, 480] for 1 second 
  # and then the tween will stop
  $sdlx_app->run;

  # tween accessors
  $msec = $tween->get_cycle_start_time;
  $msec = $tween->get_total_pause_time;
  $msec = $tween->get_duration;
  $bool = $tween->is_active;
  $msec = $tween->is_paused;

  # tween methods
  $tween->set_duration($new_duration); # hasten/slow a tween
  $tween->start($optional_ideal_cycle_start_time);  
  $tween->stop;
  $tween->pause($optional_ideal_pause_time);
  $tween->resume($optional_ideal_resume_time);

  # tween types, each with its own constructor args, but all 
  # sharing a common set, see below for more info
  $tween = $tweener->tween_int(...);
  $tween = $tweener->tween_float(...);
  $tween = $tweener->tween_path(...);
  $tween = $tweener->tween_spawn(...);
  $tween = $tweener->tween_rgba(...);
  $tween = $tweener->tween_fade(...);

  # seek behavior makes one position follow another at given speed
  $tail = $timeline->tail(
      speed => 50/1_000,  # advance a distance of 50 pixels a sec 
      on    => $xy,       # array ref of xy to update
      to    => $target,   # array ref of xy to follow
      done  => \&collide, # completer to call on collision
  );


=head1 DESCRIPTION

C<SDLx::Betweener> is a library for animating Perl SDL elements. It lets you
move game objects (GOBs) around in various ways, rotate and scale things,
animate sprites and colors, make GOBs spawn at a given rate, and generally
bring about changes in the game over time. It lets you do these things
declaratively, without writing complex C<SDLx::Controller> C<move_handlers()>.

See L</WHY> and L</FEATURES> for an introduction to tweening, or continue for
the technical details.


=head1 DECLARING TWEENING BEHAVIORS


=head2 THE TWEEN FACTORY

Use an C<SDLx::Betweener> object to create tweens. Create with an
C<SDLx::App>:

  $tweener = SDLx::Betweener->new(app => $app);

There are some cases where you would want to create more than one
tweener, see L</MULTIPLE TWEENERS>.


=head2 THE TWEEN

A tween is a behavior of some game property vs. time. It sets the target game
property using a proxy, according to some path, at a time computed by an easing
function, for a given duration.

A tween is created from the tweener using the specific constructor for the tween
type required. There are many options, described below, that you can configure
through the tween constructor.

Once you create the tween you can control its cycle: start/stop, pause/resume,
and change cycle duration.

The simplest tween uses the method proxy to call a game method with the tweened
value. It uses the default linear path to tween a value between a range given
by the C<range> arg. Speed of change will be constant, because the tween uses
the default linear easing function.

The simplest tween, animating a turret turning half a circle clockwise in 1
second:

  $tween = $timeline->tween_float(
      on    => {angle => $turret},
      t     => 1_000,
      range => [0, pi], # pi from Math::Trig
  );

There are tween constructors like C<tween_float> for all kinds of tweens.


=head2 TWEEN TYPES

=over 4

=item tween_int

Tween a 1D integer value over a range.

  # print once per second the numbers 1..10
  $tween = $timeline->tween_int(
      on    => sub { say shift },
      t     => 10_000,
      range => [1, 10],
  );

The value in your code is only updated when the integer tweened value changes,
not on every tick.

If the tween arg C<bounce> is true then the tweened value will be rounded into
an integer, otherwise it will be floored.

=item tween_float

Tween a 1D floating point value over a range.

  # Call scale() method every tick from its current value
  # to 2.5 over 1 second
  $tween = $timeline->tween_float(
      on => {scale => $shape},
      t  => 1_000,
      to => 2.5,
  );

=item tween_path

Tween a 2D integer position along a path through the plane.

  # move $enemy around in a circle
  # xy() will be called with array ref of 2 integers
  # when ticks cause position to change
  $tween   = $timeline->tween_path(
      on   => {xy => $enemy},
      t    => 2_000,
      path => [circular => {
        center => [320,240],
        radius => 140,
        from   => 0,
        to     => 2*pi,
    }],
  );

There are other paths available besides C<circular>. See L</PATHS> for the full
list.

=item tween_spawn

Useful when you want to spawn waves of creeps, bullets from a machine gun,
and generally call GOB constructors over time. Requires C<waves> constructor
arg, providing how many waves to spawn. Does not work with C<direct proxy>, only
with code calling proxies.

Unlike other tweens, your code gets called with I<two> args.  Besides the
tweened value as 1st parameter (in this case the wave number, starting from 1),
you also get the ideal spawn time for the GOBs you are about to spawn. This is
useful if they themselves are animated, see L</ACCURACY> for more info.

  # float 60 balloons at rate of 2 balloons/sec from the $balloons array
  $spawner = $tweener->tween_spawn(
      t     => 30_000,
      waves => 60,
      on    => sub {
          my ($balloon_num, $start_t) = @_;
          $balloons[ $balloon_num - 1 ]->float_to_sky($start_t);
      },
  );

=item tween_fade

Tween the opacity of an SDL color over a range. Provide the starting color in
the C<from> key (Uint32 color), and the final opacity (Uint8) in the C<to> key.

  # fade away a red curtain to reveal what is behind it
  $tween = $tweener->tween_fade(
      t    => 2_000,
      from => 0xFF0000FF,
      to   => 0x00,
      on   => \&set_curtain_color,
  );

=item tween_rgba

Tween a 32bit RGBA value over a range. Th color given in the C<from> key, will be
blended into the C<to> color.

  # slowly transform a blue circle into a semi-transparent green one
  $tween = $tweener->tween_rgba(
      t    => 10_000,
      from => 0x0000FFFF,
      to   => 0x00FF0099,
      on   => {set_color => $circle},
  );

=item tween_seek

The seeker is a simple behavior for making one GOB follow another moving GOB.
Useful for homing missiles following a moving target at a constant velocity.
It is more limited than other tween types in that there is no cycle control or
easing (see below for info on these tween features), but you gain the ability
to tween towards a dynamic, rather than static, target.

  # the circle will follow the cursor at a constant velocity
  # of 50 pixels/sec
  # you can change the $cursor position in a mouse move event handler,
  # and the circle will seek the new value until it reaches the cursor

  $circle = {xy => [  0,  0]}; # starts at   0,  0, set by tween
  $cursor = {xy => [100,100]}; # starts at 100,100, set by mouse event handler
  $seeker = $tweener->tween_seek(
      on    => $circle->{xy},
      to    => $cursor->{xy},
      speed => 100 / 1_000,
  );      

=back


=head2 CYCLE CONTROL

A tween has a duration and a cycle start time. These define its cycle. Several
tween constructor arguments help to control the tween cycle:

=over 4

=item t

C<integer> Duration of the tween from start to stop in msec

=item forever

C<boolean> Repeat the cycle forever, restarting on each cycle completion.

=item repeat

C<integer> Repeat the cycle C<n> times, then stop.

=item reverse

C<bool> Should the tween start reversed.

=item bounce

C<bool> If the cycle is repeating, on each cycle completion reverse the
tween direction, I<bouncing> the tween between its edge points.

=item done

C<CODE> or C<HASH> ref of method name and object. Code or method to be called
when tween cycle completes.

=back

Cycle control methods:

=over 4

=item start/stop/pause/resume

A C<start()/stop()> sequence will reset the tween. A C<pause()/resume()>
sequence will resume it from its last position before the C<pause()>. These all
take an optional ideal event time in SDL msec since game start, see
L</ACCURACY> for more info. 

=item is_active

true if tween is started.

=item is_paused

true for paused tweens.

=item get_cycle_start_time

Returns the tween cycle start time, in SDL style msec since game start.

=item get/set_duration

Get/set the tween duration, in msec. This lets you slow/haste a tween as
it is animating.

=back


=head2 PROXIES

The tween computes its tweened value on each tick, and uses the proxy to
deposit it inside your code. You can use a proxy to call a method, call a
callback, or directly set a Perl value. The proxy is set using the C<on> key of
the tween constructor. There are several proxy types:

=over 4

=item method proxy

Create by setting C<on> to a hash with one key- method name, and one value-
some Perl object.

  # as part of the tween constructor arg hash
  on => {method_name => $game_object},

The tween value will be set by calling the given method on the given object.

Some tweens require a range (e.g. C<tween_path> with a linear path). If none is
supplied, the method defined for the proxy is used to I<get> the initial tween
value. In this case the proxy method is expected to support get and set. This
is mere syntax sugar for not specifying the initial value in the range. You can
always provide a C<from> key explicitly in constructor, or use the C<range> key
for setting C<from> and C<to> at once.

=item callback proxy

If the C<on> key points at a code ref, then it will be called with the tweened
value on each tick.

  # as part of the tween constructor arg hash
  on => sub { my $v = shift; say "tweened value=$v" },

=item direct proxy

If the tween constructor arg C<on> is a scalar ref on a number, or a 2D numeric
array ref (for path tweens), then the tween will use the direct proxy:

  $color = 0xFF0000FF;
  ...
  # as part of the tween constructor arg hash
  on => \$color,

The numeric color value will be updated on each tick. This is very fast, but
you lose any semblance of encapsulation.

=back


=head2 EASING

The default tween changes in constant speed because it uses the linear easing
function. The time used by the path to compute position of the tween value,
advances in a linear rate.

By setting the C<ease> arg in the tween constructor you can make time advance
according to a non-linear curve. For example to make the tween go slow at
first, then go fast:

  # as part of the tween constructor arg hash
  ease => 'p2_in',

This will cause time to advance in a quadratic curve. At normalized time
C<$t> where C< $t=$elapsed/$duration > and $t is between 0 and 1, the C<p2_in>
tween will be where a linear tween would be at time C<$t**2>.

All easing functions except linear ease have 3 variants: C<_in>, C<_out>, and
C<_in_out>. C<_out> is reverse of C<_in>. C<_in_out> suffix variant is C<_in>
followed by C<_out>. E.g. C<exponential_in> starts slow then speeds up,
C<exponential_out> starts fast and slows down, and C<exponential_in_out> starts
slow, speeds up, then slows down.

These are the available easing functions. See C<eg/04-easing.pl> in the
distribution for a visual explanation. See
L<https://github.com/warrenm/AHEasing/blob/master/AHEasing/easing.c> for a math
explanation. The tweening functions originate from
L<http://robertpenner.com/easing/penner_chapter7_tweening.pdf>.

=over 4

=item *

linear

=item *

p2

=item *

p3

=item *

p4

=item *

p5

=item *

sine

=item *

circular

=item *

exponential

=item *

elastic

=item *

back

=item *

bounce

=back


=head2 PATHS

Simple tweens follow a linear path, and this is the only option when tweening a
1D value.

When building a tween of type C<tween_path>, you can customize the path the
tween takes through the plane. The path is given in the C<path> arg of the
tween constructor hash. It is given as an array ref of, whose 1st value is the
path name, and the other array values are path args to specify the path
construction.

=over 4

=item linear

Requires one of 2 constructor args: C<range> or C<from + to>. If no C<range>
and no C<from> are given then the value is taken from the tween target using
the proxy. Thus you can tween a GOB from its current position to another
without specifying the current position twice. Here are the 3 options for
using the default linear path:

  # option 1: construct a tween only with "to", from is taken from the target
  to       => [320, 200]

  # option 2: provide "from" + "to"
  from     => [  0,   0]
  to       => [320, 200]

  # option 3: provide "range"
  range    => [[0, 0], [320, 200]]

Linear path, being the default and the simplest of the paths, needs no
C<path> key. Just make sure the tween has a way to get C<from> and C<to>.

=item circular

Tweens a value along a circle with a given radius and center, between 2 angles.

  path => [circular => {
      center => [320, 200],
      radius => 100,
      from   => 0,
      to     => 2*pi,
  }],

=item polyline

Tweens a value along an array of segments, specified by the xy coordinates of
the waypoints. The tween will start at the 1st waypoint and continue until the
last following a linear path between them.

  path => [polyline => [
        [200, 200],
        [600, 200],
        [200, 400],
        [600, 400],
        [200, 200],
  ]],

=back


=head2 MEMORY MANAGEMENT

There are two issues with tween memory management: how do you keep a ref to the
tween in game objects, and how does the tween keep ref to the game elements it 
changes.

The C<SDLx::Betweener> only keeps weak refs to active tweens. This means you
must keep a strong ref to the tween somewhere, usually in the game object. When
the game object goes out of the scope, the tween will stop, be destroyed, and
cleaned out of the tweener automatically.

The tween only keeps weak refs to the game elements (objects or array refs) it
changes. Usually other game object will have strong refs to them, as part of
the game scene graph. When the game object that is the target of the tween
goes out of scope, you must stop the tween, and never use it again.


=head2 MULTIPLE TWEENERS

A tween tick can trigger user code, e.g. a C<done> handler could call a user method.
This code could destroy tweens, e.g. a missile hitting a target. In this case the
two tweens should be created using two different C<SDLx::Betweener> objects.

B<TODO> fix and delete this section.


=head2 ACCURACY

C<SDLx::Betweener> takes into account rounding errors, the inaccuracy of the
C<SDLx::Controller> C<move_handler>, and the inaccuracy of time/distance limits
on behaviors. Used correctly, 2 tweens on the same path, one with duration 1
sec and the other 2 sec, will always meet every 2 cycles, even 100 years later.

To get this absolute accuracy with no errors growing over time, you need to set
ideal C< start/pause/resume> times when controlling tween cycles.

Here is an example of starting 2 tweens which is I<NOT> accurate:

  # dont do this!
  $t1 = $tweener->tween_int(...);
  $t1->start;
  $t2 = $tweener->tween_int(...);
  $t2->start;


C<$t1> and C<$t2> will not have the same C<cycle_start_time>, and this applies
to all cycle control methods.

If accuracy is needed, use the optional ideal time argument of the cycle
control methods:

  # or this
  $start_time = SDL::get_ticks;
  $t1 = $tweener->tween_int(...);
  $t1->start($start_time);
  $t2 = $tweener->tween_int(...);
  $t2->start($start_time);


When chaining tweens, the 2nd tween ideal start time should be set as the 1st  
tween start time + the tween duration. Tween completion handlers (the C<done>
arg) are given the tween ideal stop time so you don't need to compute this:

  $tween = $tweener->tween_int(
      ...
      # start time for next tween is this tween cycle complete time
      done => sub { $next_tween->start(shift) },

When spawning tweens the second parameter in the spawn handler is the ideal
spawn time. Use this for the animation start time on the spawned GOB.

B<TODO> fix and delete this section.


=head1 WHY

Writing Perl SDL game move handlers is hard. Consider a missile with 3 states:

=over 4

=item *

firing - some sprite animation

=item *

flying towards enemy - need to update its position until it hits enemy

=item *

exploding - another sprite animation

=back    

The move handler for this game object (GOB) is hard to write, because it needs to:

=over 4

=item *

update GOB properties

=item *

you must take into account acceleration and paths in the computation of these
values

=item *

you need to set limits of the values, wait for the limits

=item *

GOBs need to act differently according to their state, so you need to manage
that as well

=item *

it all must be very accurate, or animations will miss each other

=item *

it has to be fast- this code is run per each GOB per each update

=back

As a game becomes more wonderful, the GOB move handlers become more hellish.
Brave souls have done it, but even they could not do it in a way us mortals
can reuse or even understand.

C<SDLx::Betweener> solves the missile requirements. Instead of writing a move
handler, declare tweens on your GOBs. C<SDLx::Betweener> will take care of the move
handler for you.

Instead of writing a move handler which updates the position of $my_gob 
from its current position to x=100 in 1 second, you can go:

    $tween = $timline->tween(on => [x => $my_gob], to =>100, t => 1_000);

C<SDLx::Betweener> will setup the correct move handler.

According to L<http://en.wikipedia.org/wiki/Tweening>:

    "In the inbetweening workflow of traditional hand-drawn animation, the
    senior or key artist would draw the keyframes ... and then would hand over
    the scene to his or her assistant the inbetweener who does the rest."

Let SDLx-Betweener be your inbetweener.


=head1 FEATURES

Perl SDL move handlers are rarely a simple linear progression. An ideal
tweening library should feature:

=over 4

=item *

tween any method, e.g. a Moose get/set accessor, or directly on an array

=item *

tween a property with several dimensions, e.g. xy position, some 4D color space

=item *

tween xy position not on a line, but on some curve

=item *

round the tween values, and pass only values when they change

=item *

smooth the motion with acceleration/deceleration using easing functions

=item *

make the tween bounce, reverse, and repeat for N cycles or forever

=item *

pause/resume tweens

=item *

hasten/slow a tween, for example when creeps are suddenly given a speed bonus

=item *

follow a moving target, e.g. a homing missile with constant acceleration

=item *

chain tweens, parallelize tween, e.g. start explode tween after reaching target

=item *

tween sprite frames, color/opacity/brightness/saturation/hue, volume/pitch,
spawning, rotation, size, camera position

=item *

delay before/after tweens

=item *

rewind/ffw/reverse/seek tweens, and generally play with elastic time for making
the game faster or slower

=back

C<SDLx::Betweener> doesn't do everything yet.  See the C<TODO> file in the
distribution for planned features, and the docs above for supported features.


=head1 EXAMPLES

Tweening examples in the distribution dir C< eg/>:

=over 4

=item C<01-circle.pl>

the hello world of tweening, a growing circle

=item C<02-starfield.pl>

many concurrent path tweens

=item C<03-polyline.pl>

polyline path demo

=item C<04-easing.pl>

demo of all easing functions available

=item C<05-colors.pl>

demo of color transitions

=item C<06-chaining.pl>

how to chain tweens

=item C<07-seeker.pl>

demo of many seekers following cursor

=item C<08-sprite.pl>

a simple example of how to write a sprite GOB which animates using a tween

=back


=head1 SEE ALSO

Development is at L<https://github.com/PerlGameDev/SDLx-Betweener>.

Interesting implementations of the tweening idea:

=over 4

=item *

http://www.greensock.com/tweenlite/

=item *

http://drawlogic.com/2010/04/11/itween-tweening-and-easing-animation-library-for-unity-3d/

=item *

http://www.leebyron.com/else/shapetween/

=back


=head1 BUGS

Very little safety in XS code. Lose your ref to the tween target (object or
ref being updated) and horrible things will happen on next tick. See C<TODO>
file in distribution for more issues.


=head1 DESIGN

Timeline has a std::set of Tween objects. It broadcasts tick(Uint32 now)
to them.

The Tween tick method normalizes the time given using now/tween_duration,
so that it is between 0 and 1.

Then the time is passed through the easing function, which maps it to some 
eased time value, useful for non-linear speed animations.

The tween then calls tick(Uint32 now) on its ITweenForm. The tween form
translates the eased time into some domain value and pushes it into the
tween target using the tween proxy.

LinearTweenForm interpolates between 2 values ("from" and "to") in a linear
path. The values tweened are Vector<typename T, int DIM>.

PathTweenForm is more general. It lets you tween a Vector<int,2> along a 2D
path, given in construction. LinearPath makes the form behave like a
LinearTweenForm.  CircularPath tweens along a circle or a pie slice from it.
PolylinePath tweens along a set of linear segments.

A tween form uses an IProxy for pushing the value into Perl. There are proxies
for setting Perl values (scalar for 1D tween, array ref for 2D) directly,
for calling a callback with the tweened value, and for calling a method.

A tween uses a CycleControl object for controlling cycle repeat and cycle
reverse. A tween can be made to run forever, to reverse on cycle completion
(bounce), to start reversed, and to repeat N times.

Tween start/stop registers/unregisters the tween on a timeline.


=head1 AUTHOR

eilara <ran.eilam@gmail.com>

Big thanks to:

  Sam Hocevar, from 14 rue de Plaisance, 75014 Paris, France
  https://raw.github.com/warrenm

For his excellent AHEasing lib which C<SDLx-Betweener> uses for easing
functions: L<https://github.com/warrenm/AHEasing>. Check that page for some
great info about easing functions.

Huge thanks to Zohar Kelrich <lumimies@gmail.com> for patient listening and
advice.


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Ran Eilam

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

