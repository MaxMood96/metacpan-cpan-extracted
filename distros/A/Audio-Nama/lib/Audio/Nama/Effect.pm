{ 
package Audio::Nama::Effect;
use v5.36;
our $VERSION = 1.0;
use List::MoreUtils qw(first_index insert_after_string);
use Carp qw(carp cluck croak confess);
use Data::Dumper::Concise;
use Audio::Nama::Assign qw(json_out);
use Audio::Nama::Log qw(logsub logpkg);
use Audio::Nama::Util qw(timer start_event stop_event);
use Audio::Nama::Globals qw(
					$fx 
					$fx_cache 
					$ui 
					%ti 
					%tn 
					%bn 
					%en
					$config 
					$setup 
					$project
					$this_engine
					$this_track);


use Audio::Nama::Object qw(  
				id
				type
				chain
				class
				params
				params_log
				display
				parent
				owns
				bypassed
				name
				surname 
				predecessor

);
*this_op			= \&Audio::Nama::this_op;
*this_param			= \&Audio::Nama::this_param;
*this_stepsize		= \&Audio::Nama::this_stepsize;
our %by_id;
our $AUTOLOAD;
import_engine_subs();

sub initialize { 

	%by_id = () ;
	
	# effect variables - no object code (yet)
	$fx->{id_counter} = "A"; # autoincrement counter

	# volume settings
	$fx->{muted} = [];
}
sub AUTOLOAD {
	my $self = shift;
	#say "got self: $self", Audio::Nama::Dumper $self;
	die 'not object' unless ref $self;
	# get tail of method call
	my ($call) = $AUTOLOAD =~ /([^:]+)$/;
	# see if this can be satisfied by a field from
	# the corresponding effects registry entry
	$call = 'name' if $call eq 'fxname';
	$self->about->{$call}
}
sub DESTROY {}

sub new {
	my ($class, %args) = @_;

	my $is_restore = $args{restore};

	# remove arguments that won't be part of object
	delete $args{$_} for qw(restore before);
	
	my $self;

	my $id = $args{id};

	# return an existing object that has this ID
	# Why do this instead of throw an exception?
	if ($id and $self = fxn($id)){
		logpkg(__FILE__,__LINE__,'debug',"$id: returning existing object, constructor arguments ignored"); 
		return $self
	}

	my $i = effect_index($args{type});
	defined $i or confess "$args{type}: plugin not found.";

	# allocate effect ID if we don't have one yet
	#
	my	$how_allocated = $id ? 'recycled' : 'issued';
	$id //= new_effect_id();
	logpkg(__FILE__,__LINE__,'debug',"$id: effect ID $how_allocated for track $args{chain}");
	
	$args{id}		= $id;
	$args{display} 	//= $fx_cache->{registry}->[$i]->{display};
	$args{owns}		//= [];

	my $track = $ti{$args{chain}};

	my $parent_id = $args{parent};

	# set defaults for effects without values provided
	# but skip controllers
	
	# append_effect() also assigns defaults, so why not
	# do all the assigning here?
	
	if (! $parent_id and ! $args{params}){
		my @vals;
		logpkg(__FILE__,__LINE__,'debug', "no settings found, loading defaults if present");
		
		# if the effect is a controller (has a parent), we don't 
		# initialize the first parameter (the control target)
		
		for my $j (0..$fx_cache->{registry}->[$i]->{count} - 1) {
		
			push @vals, $fx_cache->{registry}->[$i]->{params}->[$j]->{default};
		}
		logpkg(__FILE__,__LINE__,'debug', "copid: $id defaults: @vals");
		$args{params} = \@vals;
	}

	logpkg(__FILE__,__LINE__,'debug', "effect args: ",Dumper \%args);
	
	$self = bless \%args, $class;
	$by_id{$self->id} = $self;
	
	return $self if $is_restore;

	if ($parent_id) {
		logpkg(__FILE__,__LINE__,'debug', "parent found: $parent_id");

		# store relationship

		my $parent = fxn($parent_id);
		my $owns = $parent->owns;
		logpkg(__FILE__,__LINE__,'debug',"parent owns @$owns");

		# register effect_id with parent unless it is already there
		push @$owns, $id unless grep { $id eq $_ } @$owns;

		logpkg(__FILE__,__LINE__,'debug',sub{join " ", "my attributes:", json_out($self->as_hash)});
		# find position of parent id in the track ops array 
 		# and insert child id immediately afterwards
 		# unless already present

		insert_after_string($parent_id, $id, @{$track->ops})
			unless grep {$id eq $_} @{$track->ops}
	}
	else { 

		# append effect_id to track list unless already present
		push @{$track->ops}, $id unless grep {$id eq $_} @{$track->ops}
	} 
	$self
}
# provide object
{
no warnings 'redefine';
sub parent {
	my $self = shift;
	fxn($self->{parent});
}
}

sub is_read_only {
    my ($self, $param) = @_;
	no warnings 'uninitialized';
	$self->about->{params}->[$param]->{dir} eq 'output'
}          
sub remove_name { my $self = shift; delete $self->{name} }
sub set_name    { my $self = shift; $self->{name} = shift }
sub set_surname { my $self = shift; $self->{surname} = shift}
sub is_controller { my $self = shift; $self->parent } 
sub is_channel_op { my $self = shift; $Audio::Nama::config->{ecasound_channel_ops}->{$self->type} }


sub has_read_only_param {
	my $self = shift;
	no warnings 'uninitialized';
	my $entry = $self->about;
		for(0..scalar @{$entry->{params}} - 1)
		{
			return 1 if $entry->{params}->[$_]->{dir} eq 'output' 
		}
}

sub registry_index {
	my $self = shift;
	$fx_cache->{full_label_to_index}->{ $self->type };
}
sub ecasound_controller_index { 
	logsub((caller(0))[3]);
	my $self = shift;
	my $n = $self->chain;
	my $id = $self->id;
	my $opcount = 0;
	logpkg(__FILE__,__LINE__,'debug', "id: $id, n: $n, ops: @{ $ti{$n}->ops }" );
	for my $op (@{ $ti{$n}->ops }) { 
		# increment only controllers
		next unless fxn($op)->is_controller;
		$opcount++;
		last if $op eq $id;
	} 
	$opcount;
}
sub ecasound_effect_index { 
	logsub((caller(0))[3]);
	my $self = shift;
	my $n = $self->chain;
	my $id = $self->id;
	my $opcount = 0;
	logpkg(__FILE__,__LINE__,'debug', "id: $id, n: $n, ops: @{ $ti{$n}->ops }" );
	for my $op (@{ $ti{$n}->ops }) { 
			my $fx = fxn($op);
 			next if $fx->is_controller;
			++$opcount;   # first index is 1
			last if $op eq $id
	} 
	no warnings 'uninitialized';
	$self->offset + $opcount;
}
sub ecasound_effect_index_ {
	my $self = shift;
	1 + first_index {$_->id eq $self->id } $self->track->ops_ecasound_order();
}
sub track_effect_index { # the position of the ID in the track's op array
	my $self = shift;
	my $id = $self->id;
	my $pos = first_index {$id eq $_} @{$self->track->ops} ;
	$pos
}
sub controllers {
	my $self = shift;
	my %children;
	# we want controllers with this parent, also controllers
	# whos parents are children of this parent, and children
	# of those children
	no warnings;
	my @ctrl =	map { $_->id }
				grep{ $_->{parent} eq $self->id 
					or $children{$_->{parent}} 
					and $children{$_->id}++ 
					} map{ fxn($_)} @{ $self->track->ops };

	@ctrl
}
sub sync_one_effect {
		my $self = shift;
		my $chain = $self->chain;
		$this_engine->current_chain($chain);
		$this_engine->current_chain_operator($self->ecasound_effect_index);
		$self->set(params => get_ecasound_cop_params( scalar @{$self->params} ));
}
sub offset {
	my $self = shift;
	$fx->{offset}->{$self->chain}
}
sub root_parent { 
	my $self = shift;
	my $parent = $self->parent;
	$parent and $parent->parent or $parent or $self
}
sub about {
	my $self = shift;
	$fx_cache->{registry}->[$self->registry_index]
}
sub track { $ti{$_[0]->chain} }
sub trackname { $_[0]->track->name }

sub ladspa_id {
	my $self = shift;
	$Audio::Nama::fx_cache->{ladspa_label_to_unique_id}->{$self->type} 
}
sub nameline {
	my $self = shift;
	my @attr_keys = qw(id name surname fxname type ladspa_id);
	my %display = map{ $_ => 1         } grep { !/fxname|type|ladspa_id|id/ } @attr_keys;
	my %attr    = map{ $_ => $self->$_ } @attr_keys ;
	my $bypassed = $self->{bypassed} ? " (bypassed)" : '';
	not defined $attr{$_} and delete $attr{$_} for @attr_keys;
	my $nameline =  join qq( ),  
			map{ $display{$_} ? "$_:$attr{$_}" : $attr{$_} } grep{$attr{$_}}  @attr_keys;
	$nameline .= "$bypassed\n";
	$nameline;
}
sub _effect_index { 
	my $self = shift;
	effect_index($self->type)
}
sub _modify_effect {
	my ($self, $parameter, $value, $sign) = @_;
	no warnings 'uninitialized';
	my $op_id = $self->id;

	$parameter--; # convert to zero-based
	my $code = $self->type;
	my $i = $self->_effect_index;
	defined $i or confess "undefined effect code for $op_id: ",Audio::Nama::Dumper $self;
	my $parameter_count = scalar @{ $self->about->{params} };
	Audio::Nama::pager("$op_id: parameter (", $parameter + 1, ") out of range, skipping.\n"), return 
		unless ($parameter >= 0 and $parameter < $parameter_count);
	Audio::Nama::pager("$op_id: parameter $parameter is read-only, skipping\n"), return 
		if $self->is_read_only($parameter);
		my $new_value;
		if ($sign) {
			$new_value = eval 
			(	join " ",
 				$self->params->[$parameter], 
 				$sign,
 				$value
			);
		}
		else { $new_value = $value }
	logpkg(__FILE__,__LINE__,'debug', "id $op_id p: $parameter, sign: $sign value: $value");
	update_effect( 
		$op_id, 
		$parameter,
		$new_value);
	1
}
sub _remove_effect { 
	logsub((caller(0))[3]);
	my $self = shift;
	my $id = $self->id;
	my $n 		= $self->chain;
	my $parent 	= $self->parent;
	my $owns	= $self->owns;
	logpkg(__FILE__,__LINE__,'debug', "id: $id", ($parent ? ". parent: ".$parent->id : '' ));

	my $object = $parent ? q(controller) : q(chain operator); 
	logpkg(__FILE__,__LINE__,'debug', qq(ready to remove $object "$id" from track "$n"));

	$ui->remove_effect_gui($id);

	# recursively remove children
	
	logpkg(__FILE__,__LINE__,'debug',"children found: ". join ",",@$owns) if defined $owns;
	map{ remove_effect($_) } @$owns if defined $owns;
;
	# remove chain operator
	
	if ( ! $parent ) { remove_op($id) } 

	# remove controller
	
	else { 
 			
 		remove_op($id);

		# remove parent ownership of deleted controller

		my $parent_owns = $parent->owns;
		logpkg(__FILE__,__LINE__,'debug',"parent $parent owns: ". join ",", @$parent_owns);

		@$parent_owns = (grep {$_ ne $id} @$parent_owns);
		logpkg(__FILE__,__LINE__,'debug',"parent $parent new owns list: ". join ",", @$parent_owns);

	}
	# remove effect ID from track
	
	if( my $track = $ti{$n} ){
		my @ops_list = @{$track->ops};
		my @new_list = grep  { $_ ne $id  } @ops_list;
		$track->{ops} =   [ @new_list ];
	}
	#set_current_op($this_track->ops->[0]);
	#set_current_param(1);
	delete $by_id{$self->id};
	return(); 
}
sub position_effect {
	#logsub((caller(0))[3]);
	my($self, $pos) = @_;

	my $op = $self->id;
	
	#Audio::Nama::pager("$op or $pos: controller not allowed, skipping.\n"), return 
	#	if grep{ fxn($_)->is_controller } $op, $pos;
	
	# first, modify track data structure
	
	my $track = $ti{$self->chain};

	my $op_index = $self->track_effect_index;
	my @children = $self->controllers;
	my $count = scalar @children + 1;
	my @new_op_list = @{$track->ops};

	# remove op and children
	my @op_and_ctrl = splice @new_op_list, $op_index, $count;

	if ( $pos eq 'ZZZ'){
		# put it at the end
		push @new_op_list, @op_and_ctrl
	}
	else { 
		my $POS = fxn($pos);
		my $track2 = $ti{$POS->chain};
		Audio::Nama::pager("$pos: position belongs to a different track, skipping.\n"), return
			unless $track eq $track2;
		my $new_op_index = $POS->track_effect_index; 
		# insert op
		splice @new_op_list, $new_op_index, 0, @op_and_ctrl;

	}
	# easier to reconfigure the engine than to code for
	# repositioning ecasound effects.
	say join " - ",@new_op_list;
	@{$track->ops} = @new_op_list;
	Audio::Nama::request_setup();
	$this_track = $track;
	nama_cmd('show_track');
}

sub apply_op {
	logsub((caller(0))[3]);
	my $self = shift;
	local $config->{category} = 'ECI_FX';
	my $id = $self->id;
	logpkg(__FILE__,__LINE__,'debug', "id: $id");
	logpkg(__FILE__,__LINE__,'logcluck', "$id: expected effect entry not found!"), return
		if effect_entry_is_bad($id);
	my $code = $self->type;
	my $dad = $self->parent;
	my $chain = $self->chain; 
	logpkg(__FILE__,__LINE__,'debug', "chain: $chain, type: $code");
	#  if code contains colon, then follow with comma (preset, LADSPA)
	#  if code contains no colon, then follow with colon (ecasound,  ctrl)
	
	$code = '-' . $code . ($code =~ /:/ ? q(,) : q(:) );
	my @vals = @{ $self->params };
	logpkg(__FILE__,__LINE__,'debug', "values: @vals");

	# we start to build iam command

	my $add_cmd = $dad ? "ctrl-add " : "cop-add "; 
	
	$add_cmd .= $code . join ",", @vals;

	# append the -kx  operator for a controller-controller
	$add_cmd .= " -kx" if $dad and $dad->is_controller;

	logpkg(__FILE__,__LINE__,'debug', "command: $add_cmd");

	$this_engine->current_chain($chain); 
	$this_engine->current_chain_operator($dad->ecasound_effect_index) if $dad;
	$this_engine->ecasound_iam($add_cmd);
	$this_engine->ecasound_iam("cop-bypass on") if $self->bypassed;

	my $owns = $self->owns;
	(ref $owns) =~ /ARRAY/ or croak "expected array";
	logpkg(__FILE__,__LINE__,'debug',"children found: ". join ",", @$owns);

}

#### Effect related routines, some exported, non-OO

# main namespace imports from us, we'll import manually
# to work around dependence issues

sub import_engine_subs {

	*ecasound_iam			= \&Audio::Nama::ecasound_iam;
	*sleeper			= \&Audio::Nama::sleeper;
	*nama_cmd    = \&Audio::Nama::nama_cmd;
	*pager				= \&Audio::Nama::pager;
	*this_op			= \&Audio::Nama::this_op;
	*this_param			= \&Audio::Nama::this_param;
	*this_stepsize		= \&Audio::Nama::this_stepsize;
}

use Exporter qw(import);
our %EXPORT_TAGS = ( 'all' => [ qw(

					effect_index
					full_effect_code

					effect_entry_is_bad
					check_fx_consistency

					new_effect_id
					add_effect
					_add_effect
					append_effect
					remove_effect
					remove_fader_effect
					modify_effect
					modify_multiple_effects

					update_ecasound_effect
					update_effect
					sync_effect_parameters
					find_op_offsets
					apply_ops
					expanded_ops_list
				
					bypass_effects
			
					restore_effects

					fxn

					set_current_op
					set_current_param
					set_param_stepsize
					increment_param
					decrement_param
					set_parameter_value

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = ();

no warnings 'uninitialized'; # needed to avoid confusing test TAP output
sub effect_entry_is_bad {
		my $id = shift;
		! defined $id
		or ! $Audio::Nama::Effect::by_id{$id}
}

# make sure the chain number (track index) is set

sub set_chain_value {
		
	my $p = shift;

	return if $p->{chain}; # return if already set
	
	# set chain from track if known
	
	if( $p->{track} )
	{ 
		$p->{chain} = $p->{track}->n;
	  	delete $p->{track}
	}

	# set chain from parent effect if known (add controller)
	
	elsif( $p->{parent_id})
	{ 
		$p->{chain} = fxn($p->{parent_id})->chain
	}
	# set chain from insert target if known (insert effect)
	
	elsif( $p->{before} )
	{
		$p->{chain} = fxn($p->{before})->chain;
	}
	#logpkg(__FILE__,__LINE__,'debug',(json_out($p));

}

#		How effect chains are added (by default before fader)
#		user command: add_effect <effect_chain_name>
#		add_effect(effect_chain => $fxc) calls insert_effect() 
#		insert_effect()
#				* removes preceding operators 
#				* calls append_effect(effect_chain => $fxc) 
#					+ which calls $fxc->add
#					+ which calls append_effect() for each effect
#				* restores the operators
		 
sub add_effect {
	#logsub((caller(0))[3]);
	my $args = shift;
	my $added = _add_effect($args);
	$added->[0]->id
}
sub _add_effect {
	my $p = shift;
	logsub((caller(0))[3]);
	#logpkg(__FILE__,__LINE__,'debug',sub{ "add effect arguments - 0:\n".json_out($p)});
	
	set_chain_value($p);

	### We prohibit creating effects on the Mixdown track	

	### We check $track->forbid_user_ops
	### which is set on the Mixdown track,

	### An alternative would be giving each
    ### Track its own add_effect method

	### For now this is a single case

	die "user effects forbidden on this track" 
		if $ti{$p->{chain}} 
		and $ti{$p->{chain}}->forbid_user_ops 
		and $p->{type} !~ /$config->{latency_op}/; 

	logpkg(__FILE__,__LINE__,'debug',sub{ "add effect arguments - 1:\n".json_out($p)});

	# either insert or add, depending on 'before' setting
	
	my $added = (defined $p->{before} and $p->{before} ne 'ZZZ')
				? insert_effect($p) 
				: append_effect($p);
}

sub append_effect {
	my $p = shift;
	logsub("&append_effect",Dumper $p);
	my %args = %$p;
	$args{params} //= [];
	my $track = $ti{$args{chain}};
	my $add_effects_sub; # we will execute this with engine stopped
	my @added;
	if( $args{effect_chain})
	{
		# we will create and apply the effects later

		$add_effects_sub = sub{ $args{effect_chain}->add($track)};
	}
	else 
	{
		# create the effect now, apply it later
		
		# assign defaults if no values supplied
		my $count = $fx_cache->{registry}->[effect_index($args{type})]->{count} ;
		my @defaults = @{fx_defaults($args{type})};
		if( @defaults )  
		{
			for my $i (0..$count - 1)
			{
				$args{params}[$i] = $defaults[$i] 
					if ! defined $args{params}[$i] or $args{params}[$i] eq '*' 
			}  
		}
		my $FX = Audio::Nama::Effect->new(%args);
		$args{self} = $FX;
		push @added, $FX;
		if( ! $FX->name )
		{
			while( my($alias, $type) = each %{$fx->{alias}} )
			{	
				$FX->set_name($track->unique_nickname($alias)), 
				# need to reset 'each'
				keys %{$fx->{alias}}, last if $type eq $FX->type 
			}
		}
		$ui->add_effect_gui(\%args) unless $track->hide;

		# XX we should announce that will take effect in new setup
		$add_effects_sub = $FX->is_channel_op ? sub { Audio::Nama::request_setup() } : sub{ $FX->apply_op };
	}
	if( $this_engine->valid_setup() )
	{
		if ($this_engine->started())
		{ 
			$track->mute;
			my $result = Audio::Nama::stop_do_start($add_effects_sub, 0.05);
			push @added, @$result if is_array($result);
			$track->unmute;
		}
		else { 
			my $result = $add_effects_sub->(); 
			push @added, @$result if is_array($result);
		}
	}
	\@added

}
sub is_array { ref $_[0] eq 'ARRAY' }
sub insert_effect {
	my $p = shift;
	logsub("&insert_effect",Dumper $p);
	my %args = %$p;
	local $config->{category} = 'ECI_FX';
	return(append_effect(\%args)) if $args{before} eq 'ZZZ';
	my $running = $this_engine->started();
	pager("Cannot insert effect while engine is recording.\n"), return 
		if $running and Audio::Nama::ChainSetup::really_recording();
	pager("Cannot insert effect before controller.\n"), return 
		if fxn($args{before})->is_controller;
	if ($running){
		$ui->stop_heartbeat;
		Audio::Nama::mute();
		$this_engine->stop_command;
		sleeper( 0.05); 
	}
	my $pos = fxn($args{before}) or die "$args{before}: effect ID not found";
	my $track = $pos->track;
	$this_track eq $pos->track or die "$args{before} is not on current track";
	#
	#logpkg(__FILE__,__LINE__,'debug', $track->name, $/;
	#logpkg(__FILE__,__LINE__,'debug', "@{$track->ops}")

	my $offset = $pos->track_effect_index;
	my $last_index = $#{$track->ops};

	# note ops after insertion point 
	my @after_ops = @{$track->ops}[$offset..$last_index];

	# remove corresponding chain operators from the engine
	logpkg(__FILE__,__LINE__,'debug',"ops to remove and re-apply: @after_ops");
	if ( $this_engine->valid_setup ){  
		map{ remove_op($_)} reverse @after_ops; # reverse order for correct index
	}

	# remove the corresponding ids from the track list
	splice @{$track->ops}, $offset;

	# add the new effect in the proper position
	my $added = append_effect(\%args);

	logpkg(__FILE__,__LINE__,'debug',"@{$track->ops}");

	# replace the effects that had been removed
	push @{$track->ops}, @after_ops;

	logpkg(__FILE__,__LINE__,'debug',sub{"@{$track->ops}"});

	# replace the corresponding Ecasound chain operators
	if ($this_engine->valid_setup){  
		map{ fxn($_)->apply_op } @after_ops;
	}
		
	if ($running){
		ecasound_iam('start');	
		sleeper(0.3);
		Audio::Nama::unmute();
		$ui->start_heartbeat;
	}
	$added;
}
sub modify_effect {
	logsub((caller(0))[3]);
	my ($op_id, $parameter, $sign, $value) = @_;
		# $parameter: one-based
	
	my $FX = fxn($op_id)
		or pager("$op_id: non-existing effect id. Skipping.\n"), return; 
	$FX->_modify_effect($parameter, $value, $sign);
}


sub modify_multiple_effects {
	logsub((caller(0))[3]);
	my ($op_ids, $parameters, $sign, $value) = @_;
	map{ my $op_id = $_;
		map{ 	my $parameter = $_;
				modify_effect($op_id, $parameter, $sign, $value);
				set_current_op($op_id);
				set_current_param($parameter);	
		} @$parameters;
	} @$op_ids;
}

sub remove_effect { 
	logsub((caller(0))[3]);
	my $id = shift;
	my $FX = fxn($id)
		or logpkg(__FILE__,__LINE__,'logcarp',"$id: does not exist, skipping...\n"), return;
	$FX->_remove_effect;
}

sub full_effect_code {
	# get text effect code from user input, which could be
	# - LADSPA Unique ID (number)
	# - LADSPA Label (el:something)
	# - abbreviated LADSPA label (something)
	# - Ecasound operator (something)
	# - abbreviated Ecasound preset (something)
	# - Ecasound preset (pn:something)
	# - user alias
	
	# there is no interference in these labels at present,
	# so we offer the convenience of using them without
	# el: and pn: prefixes.
	
	my $input = shift;
	my $code;
    if ($input !~ /\D/) # i.e. $input is all digits
	{
		$code = $fx_cache->{ladspa_id_to_label}->{$input};
	}
	elsif ( $fx_cache->{full_label_to_index}->{$input} )
	{
		$code = $input 
	}
	else 
	{ 
		$code = $fx_cache->{partial_label_to_full}->{$input} 
	}
	$code
}


# get integer effect index for Nama effect registry
# e.g. ea => 2
sub effect_index {
	my $code = shift;
	my $i = $fx_cache->{full_label_to_index}->{full_effect_code($code)};
	defined $i or $config->{opts}->{E} or warn("$code: effect index not found\n");
	$i
}

sub fx_defaults {
	my $code = shift;
	my $i = effect_index($code);
	my $values = [];
	foreach my $p ( @{ $fx_cache->{registry}->[$i]->{params} })
	{
		return [] unless defined $p->{default};
		push @$values, $p->{default};
	}
	$values
}
	

## Ecasound engine -- apply/remove chain operators

sub apply_ops {  # in addition to operators in .ecs file
	logsub((caller(0))[3]);
	for my $track ( Audio::Nama::audio_tracks() ) {
		my $n = $track->n;
 		next unless Audio::Nama::ChainSetup::is_ecasound_chain($n);
		logpkg(__FILE__,__LINE__,'debug', "chain: $n, offset: $fx->{offset}->{$n}");
		$this_engine->reset_ecasound_selections_cache();
		$this_engine->current_chain($n);
		$track->apply_ops;
	}
}

sub remove_op {
	# remove chain operator from Ecasound engine

	logsub((caller(0))[3]);
	local $config->{category} = 'ECI_FX';

	# only if engine is configured
	return unless $this_engine->valid_setup();

	my $id = shift;
	my $self = fxn($id);
	Audio::Nama::request_setup(), return if $self->is_channel_op;
	my $n = $self->chain;

	# select chain
	
	return unless $this_engine->valid_setup();
	
	$this_engine->current_chain($n);

	# deal separately with controllers and chain operators
	
	my $index;

	if ( ! $self->is_controller) { # chain operator
		logpkg(__FILE__,__LINE__,'debug', "no parent, assuming chain operator");
	
		$index = $self->ecasound_effect_index;
		logpkg(__FILE__,__LINE__,'debug', "ops list for chain $n: @{$ti{$n}->ops}");
		logpkg(__FILE__,__LINE__,'debug', "operator id to remove: $id");
		logpkg(__FILE__,__LINE__,'debug', "ready to remove from chain $n, operator id $id, index $index");
		logpkg(__FILE__,__LINE__,'debug',sub{ecasound_iam("cs")});
		$this_engine->current_chain_operator($self->ecasound_effect_index);
		logpkg(__FILE__,__LINE__,'debug',sub{"selected operator: ". ecasound_iam("cop-selected")});
		$this_engine->ecasound_iam("cop-remove");
		$this_engine->reset_ecasound_selections_cache();
		logpkg(__FILE__,__LINE__,'debug',sub{ecasound_iam("cs")});

	} else { # controller

		logpkg(__FILE__,__LINE__,'debug', "has parent, assuming controller");

		my $ctrl_index = $self->ecasound_controller_index;
		logpkg(__FILE__,__LINE__,'debug', ecasound_iam("cs"));
		$this_engine->current_chain_operator($self->root_parent->ecasound_controller_index);
		logpkg(__FILE__,__LINE__,'debug', "selected operator: ". ecasound_iam("cop-selected"));
		$this_engine->current_controller($ctrl_index);
		$this_engine->ecasound_iam("ctrl-remove");
		logpkg(__FILE__,__LINE__,'debug', ecasound_iam("cs"));
	}
}


# Track sax effects: A B C GG HH II D E F
# GG HH and II are controllers applied to chain operator C
# 
# to remove controller HH:
#
# for Ecasound, chain op index = 3, 
#               ctrl index     = 2
#                              = track_effect_index HH - track_effect_index C 
#               
#
# for Nama, chain op array index 2, 
#           ctrl arrray index = chain op array index + ctrl_index
#                             = effect index - 1 + ctrl_index 
#
#

## Nama effects 

## have a unique ID from capital letters
## IDs are kept in the $track->ops

## Rules for allocating IDs
## new_effect_id() - issues a new ID
## effect_init()    - initializes a Nama effect, should be called effect_init()
## add_effect

sub new_effect_id { 

		# increment $fx->{id_counter} if necessary
		# to find an unused effect_id 
		
		while( fxn($fx->{id_counter})){ $fx->{id_counter}++};
		$fx->{id_counter}
}



## synchronize Ecasound chain operator parameters 
#  with Nama effect parameter

sub update_ecasound_effect {
	local $config->{category} = 'ECI_FX';

	# update the parameters of the Ecasound chain operator
	# referred to by a Nama operator_id
	
	#logsub((caller(0))[3]);

	return unless $this_engine->valid_setup;
	#my $es = ecasound_iam("engine-status");
	#logpkg(__FILE__,__LINE__,'debug', "engine is $es");
	#return if $es !~ /not started|stopped|running/;

	my ($id, $param, $val) = @_;

	my $FX = fxn($id) or carp("$id: effect not found. skipping...\n"), return;
	$param++; # so the value at $p[0] is applied to parameter 1
	my $chain = $FX->chain;
	return unless Audio::Nama::ChainSetup::is_ecasound_chain($chain);

	logpkg(__FILE__,__LINE__,'debug', "chain $chain id $id param $param value $val");

	# $param is zero-based. 
	# $FX->params is  zero-based.

	$this_engine->current_chain($chain);

	# update Ecasound's copy of the parameter
	if( $FX->is_controller ){
		my $i = $FX->ecasound_controller_index;
		logpkg(__FILE__,__LINE__,'debug', "controller $id: track: $chain, index: $i, param: $param, value: $val");
		$this_engine->current_controller($i);
		$this_engine->current_controller_parameter($param);
		$this_engine->ecasound_iam("ctrlp-set $val");
	}
	else { # is operator
		my $i = $FX->ecasound_effect_index;
		logpkg(__FILE__,__LINE__,'debug', "operator $id: track $chain, index: $i, offset: ".  $FX->offset . " param $param, value $val");
		$this_engine->current_chain_operator($i);
		$this_engine->current_chain_operator_parameter($param);
		$this_engine->ecasound_iam("copp-set $val");
	}
}

# set both Nama effect and Ecasound chain operator
# parameters

sub update_effect {
	my ($id, $param, $val) = @_;
	return if ! defined fxn($id);
	fxn($id)->params->[$param] = $val;
	update_ecasound_effect( @_ );
}

sub sync_effect_parameters {
	logsub((caller(0))[3]);
	local $config->{category} = 'ECI_FX';

	# when a controller changes an effect parameter, the
	# parameter value can differ from Nama's value for that
	# parameter.
	#
	# this routine syncs them in prep for save_state()
	
 	return unless $this_engine->valid_setup();
   	push my @ops, ops_with_controller(), ops_with_read_only_params();
	return unless @ops;
	my $old_chain = $this_engine->current_chain;
	map{ $_->sync_one_effect } grep{ $_ }  map{ fxn($_) } @ops;
	$this_engine->current_chain($old_chain);
}

	

sub get_ecasound_cop_params {
	local $config->{category} = 'ECI_FX';
	my $count = shift;
	my @params;
	for (1..$count){
		$this_engine->current_chain_operator_parameter($_);
		push @params, ecasound_iam("copp-get");
	}
	\@params
}
		
sub ops_with_controller {
	grep{ ! $_->is_controller }
	grep{ scalar @{$_->owns} }
	map{ fxn($_) }
	map{ @{ $_->ops } } 
	Audio::Nama::ChainSetup::engine_tracks();
}
sub ops_with_read_only_params {
	grep{ $_->has_read_only_param() }
	map{ fxn($_) }
	map{ @{ $_->ops } } 
	Audio::Nama::ChainSetup::engine_tracks();
}


sub find_op_offsets {

	local $config->{category} = 'ECI_FX';
	logsub((caller(0))[3]);
	my @op_offsets = grep{ /"\d+"/} split "\n",ecasound_iam("cs");
	logpkg(__FILE__,__LINE__,'debug', join "\n\n",@op_offsets);
	for my $output (@op_offsets){
		my $chain_id;
		($chain_id) = $output =~ m/Chain "(\w*\d+)"/;
		# "print chain_id: $chain_id\n";
		next if $chain_id =~ m/\D/; # skip id's containing non-digits
									# i.e. M1
		my $quotes = $output =~ tr/"//;
		logpkg(__FILE__,__LINE__,'debug', "offset: $quotes in $output");
		$fx->{offset}->{$chain_id} = $quotes/2 - 1;  
	}
}

sub expanded_ops_list { # including controllers
						# we assume existing ops
	my @ops_list = @_;
	return () unless @_;
	my @expanded = ();
	map 
	{ push @expanded, 
		$_, 
		expanded_ops_list( reverse @{fxn($_)->owns} );

		# we reverse controllers listing so 
		# the first controller is applied last
		# the insert operation places it adjacent to 
		# its parent controller
		# as a result, the controllers end up
		# in the same order as the original
		#
		# which is convenient for RCS
		
 	} @ops_list;

	my %seen;
	@expanded = grep { ! $seen{$_}++ } @expanded;
}

sub intersect_with_track_ops_list {
	my ($track, @effects)  = @_;
	my %ops;
	map{ $ops{$_}++} @{$track->ops};
	my @intersection = grep { $ops{$_} } @effects;
	my @outersection = grep { !$ops{$_} } @effects;
	carp "@outersection: effects don't belong to track: ", $track->name, 
			". skipping." if @outersection;
	@intersection
}

sub bypass_effects {
	my($track, @ops) = @_;
	set_bypass_state($track, 'on', @ops);
}
sub restore_effects {
	my($track, @ops) = @_;
	set_bypass_state($track, 'off', @ops);
}

sub set_bypass_state {
	
	local $config->{category} = 'ECI_FX';
	my($track, $bypass_state, @ops) = @_;
	logsub((caller(0))[3]);

	# only process ops that belong to this track
	@ops = intersect_with_track_ops_list($track,@ops);

	$this_engine->current_chain($track->n);
	$track->mute;

	foreach my $op ( @ops)
	{ 
		my $FX = fxn($op);
		my $i = $FX->ecasound_effect_index;
		$this_engine->current_chain_operator($i);
		$this_engine->ecasound_iam("cop-bypass $bypass_state");
		$FX->set(bypassed => ($bypass_state eq 'on') ? 1 : 0);
	}
	$track->unmute;
}

sub remove_fader_effect {
	my ($track, $role) = @_;
	remove_effect($track->$role);
	delete $track->{$role} 
}
# Object interface for effects

sub fxn {
	my $id = shift;
 	$by_id{$id};
}
sub set_current_op {
	my $op_id = shift;
	my $FX = fxn($op_id);
	return unless $FX;
	$project->{current_op}->{$FX->trackname} = $op_id;
}
sub set_current_param {
	my $parameter = shift;
	$project->{current_param}->{Audio::Nama::this_op()} = $parameter;
}
sub set_param_stepsize {
	my $stepsize = shift;
	$project->{current_stepsize}->{Audio::Nama::this_op()}->[this_param()] = $stepsize;
}
sub increment_param { modify_effect(Audio::Nama::this_op(), this_param(),'+',this_stepsize())}
sub decrement_param { modify_effect(Audio::Nama::this_op(), this_param(),'-',this_stepsize())}
sub set_parameter_value {
	my $value = shift;
	modify_effect(Audio::Nama::this_op(), this_param(), undef, $value)
}


sub check_fx_consistency {

	my $result = {};
	my %seen_ids;
	my $is_error;
	map
	{     
		my $track = $_;
		my $name = $track->name;
		my @ops = @{ $track->{ops} };
		my $is_track_error;

		# check for missing special-purpose ops

		my $no_vol_op 		= ! $track->vol;
		my $no_pan_op 		= ! $track->pan;
		my $no_latency_op 	= ! $track->latency_op;

		# check for orphan special-purpose op entries

		$is_track_error++, $result->{track}->{$name}->{orphan_vol} = $track->vol 
			if $track->vol and !  grep { $track->vol eq $_ } @ops;
		$is_track_error++,$result->{track}->{$name}->{orphan_pan} = $track->pan 
			if $track->pan and !  grep { $track->pan eq $_ } @ops;

		# we don't check for orphan latency ops as this is
		# allowed in order to keep constant $op_id over
		# time (slower incrementing of fx counter)
		
		#$is_track_error++,$result->{track}->{$name}->{orphan_latency_op} = $track->latency_op 
		#	if $track->latency_op and !  grep { $track->latency_op eq $_ } @ops;

		# check for undefined op ids 
		
		my @track_undef_op_pos;

		my $i = 0;
		map { defined $_ or push @track_undef_op_pos, $i; $i++ } @ops;
		$is_track_error++,$result->{track}->{$name}->{undef_op_pos}
			= \@track_undef_op_pos if @track_undef_op_pos;

		# remove undefined op ids from list
		
		@ops = grep{ $_ } @ops;

		# check for op ids without corresponding entry 

		my @uninstantiated_op_ids;
		map { fxn($_) or push @uninstantiated_op_ids, $_ } @ops;

		$is_track_error++, $result->{track}->{$name}->{uninstantiated_op_ids} 
			= \@uninstantiated_op_ids if @uninstantiated_op_ids;

		$result->{track}->{$name}->{is_error}++ if $is_track_error;
		$result->{is_error}++ if $is_track_error;
	} Audio::Nama::audio_tracks();

	# check for objects missing fields
	
	my @incomplete_entries = 
		grep { ! fxn($_)->params or ! fxn($_)->type or !  fxn($_)->chain } 
		grep { $_ } keys %Audio::Nama::Effect::by_id;

	if(@incomplete_entries)
	{
		$result->{incomplete_entries} = \@incomplete_entries;
		$result->{is_error}++
	}
	$result;
}

sub fade {
	my $self = shift;
	# parameter starts at one
	my ($param, $from, $to, $seconds) = @_;

	my $id = $self->id;
	# no fade without Time::HiRes
	# no fade unless engine is running
	if ( $this_engine->started() and $config->{hires_timer} )
	{
		my $steps = $seconds * $config->{fade_resolution};
		my $wink  = 1/$config->{fade_resolution};
		my $size = ($to - $from)/$steps;
		logpkg(__FILE__,__LINE__,'debug', "id: $id, param: $param, from: $from, to: $to, seconds: $seconds");
		# first step by step
		for (1..$steps - 1){
			$self->_modify_effect($param, $size, '+');
			sleeper( $wink );
		}		
	}
	$self->_modify_effect($param, $to)
}

sub plan_fade {
	return unless $this_engine->started();
	my $self = shift;
	my %args = @_;
	my $param   = $args{param}   || 1;
	my $from    = $args{from}    || 0;
	my $to	    = $args{to}      || 0;
	my $seconds = $args{seconds} || 1;
	my $in_future 	= $args{in_future};
	my $steps 	= $seconds * $config->{fade_resolution};
	my $wink  	= 1/$config->{fade_resolution};
	my $id 		= $self->id;
	my $size 	= ($to - $from)/$steps;
	logpkg(__FILE__,__LINE__,'debug', "id: $id, param: $param, from: $from, to: $to, seconds: $seconds");
	if ( not $in_future ){
		for (1..$steps - 1){
			$self->_modify_effect($param, $size, '+');
			sleeper( $wink );
		}		
		$self->_modify_effect($param, $to)
	}
	else {
		my $advance = $in_future;
		my $coderef = sub { $self->_modify_effect($param, $size, '+') };
		for (1..$steps - 1){
			$advance += $wink;
			schedule_fade($advance, $coderef)
		}		
		$advance += $wink;
		schedule_fade($advance, sub { $self->_modify_effect($param, $to) } );
		sub schedule_fade {
			my ($after, $sub) = @_;
			start_event("fade_".$setup->{fade_counter}++ => timer( $after, 0, $sub ));
		}
	}
}

sub fadein {
	my $self = shift;
	my $to = shift;
	my $from  = $config->{fade_out_level}->{$self->type};
	$self->_modify_effect(1, $from);
	$self->fade(1, $from, $to, $config->{engine_fade_length_on_start_stop});
}
sub fadeout {
	my $self = shift;
	my $from  =	$self->params->[0];
	my $to	  = $config->{fade_out_level}->{$self->type};
	$self->fade(1, $from, $to, $config->{engine_fade_length_on_start_stop} );
	$self->_modify_effect(1, $config->{mute_level}->{$self->type});
}
sub mute_level {
	my $self = shift;
	my $level = $config->{mute_level}->{$self->type};
	#defined $level or die $self->nameline .  " cannot be muted."
	$level
}
sub fade_out_level {
	my $self = shift;
	$config->{fade_out_level}->{$self->type}
}
sub ecasound_format {
	my $self = shift;
	my $cmd = '-'.$self->code;
	$cmd .= ':'.join ',' ,@{$self->{params}} if $self->{params} and @{$self->{params}} > 0;
	$cmd
}

} # end package Effect

1