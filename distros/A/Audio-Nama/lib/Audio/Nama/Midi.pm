# ------------- MIDI routines -----------

package Audio::Nama;
use v5.36;
#use Audio::Nama::Log qw(logpkg);
use Carp;

{
my ($pid, $sel);
my @handles = my ($fh_midi_write, $fh_midi_read, $fh_midi_error) = map{ IO::Handle->new() } 1..3;
map{ $_->autoflush(1) } @handles;

sub start_midish_process {
	logsub((caller(0))[3]);
	my $executable = qx(which midish);
	chomp $executable;
	$executable or say("Midish not found!"), return;
	$pid = open3($fh_midi_write, $fh_midi_read, $fh_midi_error,"$executable -v")
		or warn "Midish failed to start!";

	$sel = IO::Select->new();
	$sel->add($fh_midi_read);
	$sel->add($fh_midi_error);
	midish_cmd( qq(print "Midish is ready.") );
	write_aux_midi_commands();
	midish_cmd( q(exec ").$file->aux_midi_commands.q(") );
	$pid
}
sub midish_cmd {
	my $command = shift;
	logsub((caller(0))[3]);
	return unless $config->{use_midi};
	
	print $fh_midi_write "$command\n";
	#say "applied midish command: $command";
	$project->{midi_history} //=[];
	push  @{ $project->{midi_history} },$command;

	my $length = 2**16;
	sleeper(0.05);
	my @result;
	foreach my $h ($sel->can_read) 
	{
		my $buf = '';
		if ($h eq $fh_midi_error)
		{
			sysread($fh_midi_error,$buf,$length);
			if($buf){print "MIDISH ERR-> $buf\n"}
		}
		else
		{
			sysread($fh_midi_read,$buf,$length);
			if($buf){push @result, grep{ !/\+ready/ } split "\n", $buf}
		}
	}
	join "\n", @result;
}

sub close_midish {
	save_midish();
	say "reaping midish";
	kill_and_reap($pid);
}	
sub save_midish {
	my $fname = $file->midi_store;
	midish_cmd( qq<save "$fname">);
}

sub reconfigure_midi {
	add_midi_track($config->{midi_record_buffer}, n => 999, hide => 1) 
		if not $tn{$config->{midi_record_buffer}}
		and $this_track->current_midi
		and $this_track->rec;

	my $midi_rec = $tn{$config->{midi_record_buffer}};

	# mute all

	my @all = $bn{Midi}->track_o;

	$_->mute for @all; # same as setting OFF for MidiTracks

	# unmute audible

	my @audible = grep{ $_->play } @all;
	$_->unmute for @audible;

	# unset filters

	do { $_->select_track; midish_cmd("fdel ".$_->name) } for @all;

	# set filters for PLAY and MON tracks

	do { $_->select_track; midish_cmd(join ' ', 'rnew', $_->source_id, $_->send_id) } for @audible;

	my ($rec) = my @rec = $en{midish}->rec_tracks;

	# maybe we're done?
	
	return unless @rec;
 	throw("more than one midi REC track ", join " ", map{$_->name} @rec),
		return if @rec > 1;

	# mute the actual track since we'll record using the special-purpose track
	
	$rec->mute;
	$midi_rec->select_track;

	# use routing of target track on $midi_rec track

	my $cmd = 'rnew';
	$cmd = join ' ', $cmd, $rec->source_id, $rec->send_id;
	midish_cmd($cmd);
}
sub start_midi_transport {
	my $start_command = $en{midish}->rec_tracks ? 'r' : 'p';
	midish_cmd($start_command);
	$setup->{midish_running}++;
}
sub stop_midi_transport {
	return unless midish_running();
	midish_cmd('s'); 
	delete $setup->{midish_running};
}
sub midi_rec_cleanup {
	my ($track) = $en{midish}->rec_tracks; 
	# midish allows one recording track 
	defined $track or return;
	my $length = midish_cmd('print [mend]');
	$length > 0 or return;

	my $version = $track->current_version;
	$track->set_version($version);
		push @{$track->midi_versions}, $version;
		$track->set(rw => PLAY);
		my $cmd = join ' ', 'chdup', $config->{midi_record_buffer}, $track->source_id, $track->midi_version;
		say "cmd: $cmd";
		midish_cmd($cmd);
		midish_cmd("clr $config->{midi_record_buffer} $length");
		$track->unmute();
		save_midish();
}
}
sub write_aux_midi_commands {
	write_file($file->aux_midi_commands,  get_data_section('aux_midi_commands'))
		unless -e $file->aux_midi_commands
}
sub add_midi_track {
	my ($name, @args) = @_;
	my $track = Audio::Nama::add_track( 
		$name, 
		class => 'Audio::Nama::MidiTrack',
		group => 'Midi', 
		source_id => 'midi', 
		source_type => 'midi',
		midi_versions => [],
		novol => 1,
		engine_group => $config->{midi_engine_name},
		nopan => 1,
		@args,
	);
}
sub user_midi_tracks { grep { $_->class =~ /Midi/ } grep { !  $_->hide } all_tracks()  }

	
=comment
chdup aux_recorder dx7 piano 
		
tnew synth                                                                                               
rnew nord nord # play the nord keyboard sound with the nord keyboard                                     
tnew piano                                                                                               
rnew tr dx7 # route the tr keyboard to the dx7 synth sound engine                                        
tnew aux_recorder                                                                                        
rnew nord nord                                                                                           
radd tr dx7 # not sure if this works, must recheck my code                                               
r                                                                                                        
s                                                                                                        

let complete_length = [mend];                                                                            
2. clear the auxiliary track                                                                             
clr aux_recorder $complete_length  
=cut
1;
__END__