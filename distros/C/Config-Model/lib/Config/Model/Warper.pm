#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Warper 2.155;

use Mouse;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
use Storable qw/dclone/;
use Config::Model::Exception;
use List::MoreUtils qw/any/;
use Carp;

has 'follow' => ( is => 'ro', isa => 'HashRef[Str]', required => 1 );
has 'rules'  => ( is => 'ro', isa => 'ArrayRef',     required => 1 );

has 'warped_object' => (
    is       => 'ro',
    isa      => 'Config::Model::AnyThing',
    handles  => ['needs_check'],
    weak_ref => 1,
    required => 1
);

has '_values' => (
    traits  => ['Hash'],
    is      => 'ro',
    isa     => 'HashRef[HashRef | Str | Undef ]',
    default => sub { {} },
    handles => {
        _set_value  => 'set',
        _get_value  => 'get',
        _value_keys => 'keys',
    },
);

sub _get_value_gist {
    my $self = shift;
    my $warper_name  = shift;
    my $item = $self->_get_value($warper_name);

    return ref($item) eq 'HASH' ? join(',', each %$item) : $item;
}

has [qw/ _computed_masters _warped_nodes _registered_values/] => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef, # can't use this param in constructor
    default => sub { {} },
);

has allowed => ( is => 'rw', isa => 'ArrayRef' );
has morph   => ( is => 'ro', isa => 'Bool' );

my $logger = get_logger("Warper");

# create the object, check args, but don't do anything else
sub BUILD {
    my $self = shift;

    $logger->trace( "Warper new: created for " . $self->name );
    $self->check_warp_args;

    $self->register_to_all_warp_masters;
    $self->refresh_values_from_master;
    $self->do_warp;
}

# should be called only at startup
sub register_to_all_warp_masters {
    my $self = shift;

    my $follow = $self->follow;

    # now, follow is only { w1 => 'warp1', w2 => 'warp2'}
    foreach my $warper_name ( keys %$follow ) {
        $self->register_to_one_warp_master($warper_name);
    }

}

sub register_to_one_warp_master {
    my $self = shift;
    my $warper_name = shift || die "register_to_one_warp_master: missing warper_name";

    my $follow      = $self->follow;
    my $warper_path = $follow->{$warper_name};
    $logger->debug( "Warper register_to_one_warp_master: '", $self->name, "' follows '$warper_name'" );

    # need to register also to all warped_nodes found on the path
    my @command = ($warper_path);
    my $warper;
    my $warped_node;
    my $obj        = $self->warped_object;
    my $reg_values = $self->_registered_values;

    return if defined $reg_values->{$warper_name};

    while (@command) {

        # may return undef object
        ( $obj, @command ) = $obj->grab(
            step               => \@command,
            mode               => 'step_by_step',
            grab_non_available => 1,
        );

        if ( not defined $obj ) {
            $logger->debug("Warper register_to_one_warp_master: aborted steps. Left '@command'");
            last;
        }

        my $obj_loc = $obj->location;

        $logger->debug("Warper register_to_one_warp_master: step to master $obj_loc");

        if ( $obj->isa('Config::Model::Value') or $obj->isa('Config::Model::CheckList')) {
            $warper = $obj;
            if ( defined $warped_node ) {

                # keep obj ref to be able to unregister later on
                $self->_warped_nodes->{$warped_node}{$warper_name} = $obj;
            }
            last;
        }

        if ( $obj->isa('Config::Model::WarpedNode') ) {
            $logger->debug("Warper register_to_one_warp_master: register to warped_node $obj_loc");
            if ( defined $warped_node ) {

                # keep obj ref to be able to unregister later on
                $self->_warped_nodes->{$warped_node}{$warper_name} = $obj;
            }
            $warped_node = $obj_loc;
            $obj->register( $self, $warper_name );
        }
    }

    if ( defined $warper and scalar @command ) {
        Config::Model::Exception::Model->throw(
            object => $self->warped_object,
            error  => "Some steps are left (@command) from warper path $warper_path",
        );
    }

    $logger->debug(
        "Warper register_to_one_warp_master:",
        $self->name,
        " is warped by $warper_name => '$warper_path' location in tree is: '",
        defined $warper ? $warper->name : 'unknown', "'"
    );

    return unless defined $warper;

    Config::Model::Exception::Model->throw(
        object => $self->warped_object,
        error  => "warper $warper_name => '$warper_path' is not a leaf"
    ) unless $warper->isa('Config::Model::Value') or $obj->isa('Config::Model::CheckList');

    # warp will register this value object in another value object
    # (the warper).  When the warper gets a new value, it will
    # modify the warped object according to the data passed by the
    # user.

    my $type = $warper->register( $self, $warper_name );

    $reg_values->{$warper_name} = $warper;

    # store current warp master value
    if ( $type eq 'computed' ) {
        $self->_computed_masters->{$warper_name} = $warper;
    }
}

sub refresh_affected_registrations {
    my ( $self, $warped_node_location ) = @_;

    my $wnref = $self->_warped_nodes;

    $logger->debug( "Warper refresh_affected_registrations: called on",
        $self->name, " from $warped_node_location'" );

    #return unless defined $wnref ;

    # remove and unregister obj affected by this warped node
    my $ref = delete $wnref->{$warped_node_location};

    foreach my $warper_name ( keys %$ref ) {
        $logger->debug( "Warper refresh_affected_registrations: ",
            $self->name, " unregisters from $warper_name'" );
        delete $self->_registered_values->{$warper_name};
        $ref->{$warper_name}->unregister( $self->name );
    }

    $self->register_to_all_warp_masters;

    #map {  $self->register_to_one_warp_master($_) } keys %$ref;
}

# should be called only at startup
sub refresh_values_from_master {
    my $self = shift;

    # should get new value from warp master

    my $follow = $self->follow;

    # now, follow is only { w1 => 'warp1', w2 => 'warp2'}

    # should try to get values only for unregister or computed warp masters
    foreach my $warper_name ( keys %$follow ) {
        my $warper_path = $follow->{$warper_name};
        $logger->debug( "Warper trigger: ", $self->name, " following $warper_name" );

        # warper can itself be warped out (part of a warped out node).
        # not just 'not available'.

        my $warper = $self->warped_object->grab(
            step => $warper_path,
            mode => 'loose',
        );

        if ( defined $warper and $warper->get_type eq 'leaf' ) {
            # read the warp master values, so I can warp myself just after.
            my $warper_value = $warper->fetch('allow_undef');
            my $str = $warper_value // '<undef>';
            $logger->debug( "Warper: '$warper_name' value is: '$str'" );
            $self->_set_value( $warper_name => $warper_value );
        }
        elsif ( defined $warper and $warper->get_type eq 'check_list' ) {
            if ($logger->is_debug) {
                my $warper_value = $warper->fetch();
                $logger->debug( "Warper: '$warper_name' checked values are: '$warper_value'" );
            }
            # store checked values are data structure, not as string
            $self->_set_value( $warper_name => scalar $warper->get_checked_list_as_hash() );
        }
        elsif ( defined $warper ) {
            Config::Model::Exception::Model->throw(
                error => "warp error: warp 'follow' parameter "
                    . "does not point to a leaf element",
                object => $self->warped_object
            );
        }
        else {
            # consider that the warp master value is undef
            $self->_set_value( $warper_name, '' );
            $logger->debug("Warper:  '$warper_name' is not available");
        }
    }

}

sub name {
    my $self = shift;
    return "Warper of " . $self->warped_object->name;
}

# And I'm going to warp them ...
sub warp_them {
    my $self = shift;

    # retrieve current value if not provided
    my $value =
          @_
        ? $_[0]
        : $self->fetch_no_check;

    foreach my $ref ( @{ $self->{warp_these_objects} } ) {
        my ( $warped, $warp_index ) = @$ref;
        next unless defined $warped;    # $warped is a weak ref and may vanish

        # pure warp of object
        $logger->debug(
            "Warper ", $self->name,
            " warp_them: (value ",
            ( defined $value ? $value : 'undefined' ),
            ") warping '", $warped->name, "'"
        );
        $warped->warp( $value, $warp_index );
    }
}

sub check_warp_args {
    my $self = shift;

    # check that rules element are array ref and store them for
    # error checking
    my $rules_ref = $self->rules;

    my @rules =
          ref $rules_ref eq 'HASH'  ? %$rules_ref
        : ref $rules_ref eq 'ARRAY' ? @$rules_ref
        : Config::Model::Exception::Model->throw(
        error  => "warp error: warp 'rules' parameter " . "is not a ref ($rules_ref)",
        object => $self->warped_object
        );

    my $allowed = $self->allowed;

    for ( my $r_idx = 0 ; $r_idx < $#rules ; $r_idx += 2 ) {
        my $key_set = $rules[$r_idx];
        my @keys = ref($key_set) ? @$key_set : ($key_set);

        my $v = $rules[ $r_idx + 1 ];
        Config::Model::Exception::Model->throw(
            object => $self->warped_object,
            error  => "rules value for @keys is not a hash ref ($v)"
        ) unless ref($v) eq 'HASH';

        foreach my $pkey ( keys %$v ) {
            Config::Model::Exception::Model->throw(
                object => $self->warped_object,
                error  => "Warp rules error for '@keys': '$pkey' "
                    . "parameter is not allowed, "
                    . "expected '"
                    . join( "' or '", @$allowed ) . "'"
            ) unless any {$pkey eq $_}  @$allowed ;
        }
    }
}

sub _dclone_key {
    return map { ref $_ ? [@$_] : $_ } @_;
}

# Internal. This method will change element properties (like level) according to the warp effect.
# For instance, if a warp rule make a node no longer available in a model, its level must change to
# 'hidden'
sub set_parent_element_property {
    my ( $self, $arg_ref ) = @_;

    my $warped_object = $self->warped_object;

    my @properties = qw/level/;

    if ( defined $warped_object->index_value ) {
        $logger->debug("Warper set_parent_element_property: called on hash or list, aborted");
        return;
    }

    my $parent   = $warped_object->parent;
    my $elt_name = $warped_object->element_name;
    foreach my $property_name (@properties) {
        my $v = $arg_ref->{$property_name};
        if ( defined $v ) {
            $logger->debug( "Warper set_parent_element_property: set '",
                $parent->name, " $elt_name' $property_name with $v" );
            $parent->set_element_property(
                property => $property_name,
                element  => $elt_name,
                value    => $v,
            );
        }
        else {

            # reset ensures that property is reset to known state by default
            $logger->debug("Warper set_parent_element_property: reset $property_name");
            $parent->reset_element_property(
                property => $property_name,
                element  => $elt_name,
            );
        }
    }
}

# try to actually warp (change properties) of a warped object.
sub trigger {
    my $self = shift;

    my %old_value_set = %{ $self->_values };

    if (@_) {
        my ( $value, $warp_name ) = @_;
        $logger->debug(
            "Warper: trigger called on ",
            $self->name,
            " with value '",
            defined $value ? $value : '<undef>',
            "' name $warp_name"
        );
        $self->_set_value( $warp_name => $value || '' );
    }

    # read warp master values that are computed
    my $cm = $self->_computed_masters;
    foreach my $name ( keys %$cm ) {
        $self->_set_value( $name => $cm->{$name}->fetch );
    }

    # check if new values are different from old values
    my $same = 1;
    foreach my $name ( $self->_value_keys ) {
        my $old = $old_value_set{$name};
        my $new = $self->_get_value_gist($name);
        $same = 0
            if ( $old ? 1 : 0 xor $new ? 1 : 0 )
            or ( $old and $new and $new ne $old );
    }

    if ($same) {
        no warnings "uninitialized";
        if ( $logger->is_debug ) {
            $logger->debug(
                "Warper: warp skipped because no change in value set ",
                "(old: '", join( "' '", %old_value_set ),
                "' new: '", join( "' '", %{ $self->_values() } ), "')"
            );
        }
        return;
    }

    $self->do_warp;
}

# undef values are changed to '' so compute_bool no longer returns
# undef. It returns either 1 or 0
sub compute_bool {
    my $self = shift;
    my $expr = shift;

    $logger->trace("Warper compute_bool: called for '$expr'");

    #    my $warp_value_set = $self->_values   ;
    $logger->debug( "Warper compute_bool: data:\n",
        Data::Dumper->Dump( [ $self->_values ], ['data'] ) );

    # checklist: $stuff.is_set(&index)
    # get_value of a checklist gives { 'val1' => 1, 'val2' => 0,...}
    $expr =~ s/(\$\w+)\.is_set\(([&$"'\w]+)\)/$1.'->{'.$2.'}'/eg;

    $expr =~ s/&(\w+)/\$warped_obj->$1/g;

    my @init_code;
    my %eval_data ;
    foreach my $warper_name ( $self->_value_keys ) {
        $eval_data{$warper_name} = $self->_get_value($warper_name) ;
        push @init_code, "my \$$warper_name = \$eval_data{'$warper_name'} ;";
    }

    my $perl_code = join( "\n", @init_code, $expr );
    $logger->trace("Warper compute_bool: eval code '$perl_code'");

    my $ret;
    {
        my $warped_obj = $self->warped_object ;
        no warnings "uninitialized";
        $ret = eval($perl_code); ## no critic (ProhibitStringyEval)
    }

    if ($@) {
        Config::Model::Exception::Model->throw(
            object => $self->warped_object,
            error  => "Warp boolean expression failed:\n$@" . "eval'ed code is: \n$perl_code"
        );
    }

    $logger->debug( "compute_bool: eval result: ", ( $ret ? 'true' : 'false' ) );
    return $ret;
}

sub do_warp {
    my $self = shift;

    my $warp_value_set = $self->_values;
    my $rules          = dclone( $self->rules );
    my %rule_hash      = @$rules;

    # try all boolean expression with warp_value_set to get the
    # correct rule

    my $found_rule = {};
    my $found_bool = '';    # this variable may be used later in error message

    foreach my $bool_expr (@$rules) {
        next if ref($bool_expr);    # it's a rule not a bool expr
        my $res = $self->compute_bool($bool_expr);
        next unless $res;
        $found_bool = $bool_expr;
        $found_rule = $rule_hash{$bool_expr} || {};
        $logger->trace(
            "do_warp found rule for '$bool_expr':\n",
            Data::Dumper->Dump( [$found_rule], ['found_rule'] ) );
        last;
    }

    if ( $logger->is_info ) {
        my @warp_str = map { defined $_ ? $_ : 'undef' } keys %$warp_value_set;

        $logger->info(
            "do_warp: warp called from '$found_bool' on '",
            $self->warped_object->name,
            "' with elements '",
            join( "','", @warp_str ),
            "', warp rule is ",
            ( scalar %$found_rule ? "" : 'not ' ),
            "found"
        );
    }

    $logger->trace( "do_warp: call set_parent_element_property on '",
        $self->name, "' with ", Data::Dumper->Dump( [$found_rule], ['found_rule'] ) );

    $self->set_parent_element_property($found_rule);

    $logger->debug(
        "do_warp: call set_properties on '",
        $self->warped_object->name,
        "' with ", Data::Dumper->Dump( [$found_rule], ['found_rule'] ) );
    eval { $self->warped_object->set_properties(%$found_rule); };

    if ($@) {
        my @warp_str = map { defined $_ ? $_ : 'undef' } keys %$warp_value_set;
        my $e        = $@;
        my $msg      = ref $e ? $e->as_string : $e;
        Config::Model::Exception::Model->throw(
            object => $self->warped_object,
            error  => "Warp failed when following '"
                . join( "','", @warp_str )
                . "' from \"$found_bool\". Check model rules:\n\t"
                . $msg
        );
    }
}

# Usually a warp error occurs when the item is not actually available
# or when a setting is wrong. Then guiding the user toward a warp
# master value that has a rule attached to it is a good idea.

# But sometime, the user wants to remove and item. In this case it
# must be warped out by setting a warp master value that has not rule
# attached. This case is indicated when $want_remove is set to 1
sub warp_error {
    my ($self) = @_;

    return '' unless defined $self->{warp};
    my $follow = $self->{warp}{follow};
    my @rules  = @{ $self->{warp}{rules} };

    # follow is either ['warp1','warp2',...]
    # or { warp1 => {....} , ...} or 'warp'
    my @warper_paths =
          ref($follow) eq 'ARRAY' ? @$follow
        : ref($follow) eq 'HASH'  ? values %$follow
        :                           ($follow);

    my $str =
          "You may solve the problem by modifying "
        . ( @warper_paths > 1 ? "one or more of " : '' )
        . "the following configuration parameters:\n";

    my $expected_error = 'Config::Model::Exception::UnavailableElement';

    foreach my $warper_path (@warper_paths) {
        my $warper_value;
        my $warper;

        # try
        eval {
            $warper       = $self->get_warper_object($warper_path);
            $warper_value = $warper->fetch;
        };
        my $e = $@;
        # catch
        if ( ref($e) eq $expected_error ) {
            $str .= "\t'$warper_path' which is unavailable\n";
            next;
        }

        $warper_value = 'undef' unless defined $warper_value;

        my @choice =
              defined $warper->choice ? @{ $warper->choice }
            : $warper->{value_type} eq 'boolean' ? ( 0, 1 )
            :                                      ();

        my @try = sort grep { $_ ne $warper_value } @choice;

        $str .= "\t'" . $warper->location . "': Try ";

        my $a = $warper->{value_type} =~ /^[aeiou]/ ? 'an' : 'a';

        $str .=
            @try
            ? "'" . join( "' or '", @try ) . "' instead of "
            : "$a $warper->{value_type} value different from ";

        $str .= "'$warper_value'\n";

        if ( defined $warper->{compute} ) {
            $str .= "\n\tHowever, '" . $warper->name . "' " . $warper->compute_info . "\n";
        }
    }

    $str .= "Warp parameters:\n" . Data::Dumper->Dump( [ $self->{warp} ], ['warp'] )
        if $logger->is_debug;

    return $str;
}

__PACKAGE__->meta->make_immutable;

# ABSTRACT: Warp tree properties

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::Warper - Warp tree properties

=head1 VERSION

version 2.155

=head1 SYNOPSIS

 # internal class 

=head1 DESCRIPTION

Depending on the value of a warp master (In fact a L<Config::Model::Value> or a L<Config::Model::CheckList> object),
this class changes the properties of a node (L<Config::Model::WarpedNode>),
a hash (L<Config::Model::HashId>), a list (L<Config::Model::ListId>), 
a checklist (L<Config::Model::CheckList>) or another value.

=head1 Warper and warped

Warping an object means that the properties of the object is
changed depending on the value of another object.

The changed object is referred as the I<warped> object.

The other object that holds the important value is referred as the
I<warp master> or the I<warper> object.

You can also set up several warp master for one warped object. This
means that the properties of the warped object is changed
according to a combination of values of the warp masters.

=head1 Warp arguments

Warp arguments are passed in a hash ref whose keys are C<follow> and
and C<rules>:

=head2 Warp follow argument

L<Grab string|Config::Model::Role::Grab/grab> leading to the
C<Config::Model::Value> or L<Config::Model::CheckList> warp master. E.g.:

 follow => '! tree_macro' 

In case of several warp master, C<follow> is set to an array ref
of several L<grab string|Config::Model::Role::Grab/grab>:

 follow => [ '! macro1', '- macro2' ]

You can also use named parameters:

 follow => { m1 => '! macro1', m2 => '- macro2' }

Note: By design C<follow> argument of warper module is a plain path to keep
warp mechanism (relatively) simple. C<follow> argument
of L<Config::Model::ValueComputer> has more features and is documented
L<there|Config::Model::ValueComputer/"Compute variables">

=head2 Warp rules argument

String, hash ref or array ref that specify the warped object property
changes.  These rules specifies the actual property changes for the
warped object depending on the value(s) of the warp master(s). 

E.g. for a simple case (rules is a hash ref) :

 follow => '! macro1' ,
 rules => { A => { <effect when macro1 is A> },
            B => { <effect when macro1 is B> }
          }

In case of similar effects, you can use named parameters and
a boolean expression to specify the effect. The first match
is applied. In this case, rules is a list ref:

  follow => { m => '! macro1' } ,
  rules => [ '$m eq "A"'               => { <effect for macro1 == A> },
             '$m eq "B" or $m eq"C "'  => { <effect for macro1 == B|C > }
           ]

In case of several warp masters, C<follow> must use named parameters, and
rules must use boolean expression:

 follow => { m1 => '! macro1', m2 => '- macro2' } ,
 rules => [
           '$m1 eq "A" && $m2 eq "C"' => { <effect for A C> },
           '$m1 eq "A" && $m2 eq "D"' => { <effect for A D> },
           '$m1 eq "B" && $m2 eq "C"' => { <effect for B C> },
           '$m1 eq "B" && $m2 eq "D"' => { <effect for B D> },
          ]

Of course some combinations of warp master values can have the same
effect:

 follow => { m1 => '! macro1', m2 => '- macro2' } ,
 rules => [
           '$m1 eq "A" && $m2 eq "C"' => { <effect X> },
           '$m1 eq "A" && $m2 eq "D"' => { <effect Y> },
           '$m1 eq "B" && $m2 eq "C"' => { <effect Y> },
           '$m1 eq "B" && $m2 eq "D"' => { <effect Y> },
          ]

In this case, you can use different boolean expression to save typing:

 follow => { m1 => '! macro1', m2 => '- macro2' } ,
 rules => [
           '$m1 eq "A" && $m2 eq "C"' => { <effect X> },
           '$m1 eq "A" && $m2 eq "D"' => { <effect Y> },
           '$m1 eq "B" && ( $m2 eq "C" or $m2 eq "D") ' => { <effect Y> },
          ]

Note that the boolean expression is sanitized and used in a Perl
eval, so you can use most Perl syntax and regular expressions.

Functions (like C<&foo>) are called like C<< $self->foo >> before evaluation
of the boolean expression.

The rules must be declared with a slightly different way when a
check_list is used as a warp master: a check_list has not a simple
value. The rule must check whether a value is checked or not amongs
all the possible items of a check list.

For example, let's say that C<$cl> in the rule below point to a check list whose
items are C<A> and C<B>. The rule must verify if the item is set or not:

  rules => [
       '$cl.is_set(A)' =>  { <effect when A is set> },
       '$cl.is_set(B)' =>  { <effect when B is set> },
       # can be combined
       '$cl.is_set(B) and $cl.is_set(A)' =>  { <effect when A and B are set> },
   ],

With this feature, you can control with a check list whether some element must
be shown or not (assuming C<FooClass> and C<BarClass> classes are declared):

    element => [
        # warp master
        my_check_list => {
            type       => 'check_list',
            choice     => ['has_foo','has_bar']
        },
        # controlled element that show up only when has_foo is set
        foo => {
            type => 'warped_node',
            level => 'hidden',
            config_class_name => 'FooClass',
            follow => {
                selected => '- my_check_list'
            },
            'rules' => [
                '$selected.is_set(has_foo)' => {
                    level => 'normal'
                }
            ]
        },
        # controlled element that show up only when has_bar is set
        bar => {
            type => 'warped_node',
            level => 'hidden',
            config_class_name => 'BarClass',
            follow => {
                selected => '- my_check_list'
            },
            'rules' => [
                '$selected.is_set(has_bar)' => {
                    level => 'normal'
                }
            ]
        }
    ]

=head1 Methods

=head2 warp_error

This method returns a string describing:

=over

=item *

The location(s) of the warp master

=item *

The current value(s) of the warp master(s)

=item *

The other values accepted by the warp master that can be tried (if the
warp master is an enumerated type)

=back

=head1 How does this work ?

=over

=item Registration

=over

=item *

When a warped object is created, the constructor registers to the
warp masters. The warp master are found by using the special string
passed to the C<follow> parameter. As explained in 
L<grab method|Config::Model::Role::Grab/grab>,
the string provides the location of the warp master in the
configuration tree using a symbolic form. 

=item *

Then the warped object retrieve the value(s) of the warp master(s)

=item *

Then the warped object warps itself using the above
value(s). Depending on these value(s), the properties of the warped
object are modified.

=back

=item Master update

=over

=item *

When a warp master value is updated, the warp master calls I<all>
its warped object and pass them the new master value.

=item *

Then each warped object modifies properties according to the
new warp master value.

=back

=back

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model::AnyThing>,
L<Config::Model::HashId>,
L<Config::Model::ListId>,
L<Config::Model::WarpedNode>,
L<Config::Model::Value>

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
