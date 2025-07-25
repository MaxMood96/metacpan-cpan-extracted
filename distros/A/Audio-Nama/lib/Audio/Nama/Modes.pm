# ----------- Modes: mastering, preview, doodle ---------

package Audio::Nama;
use v5.36;
{
sub set_preview_mode {

	# set preview mode, releasing doodle mode if necessary
	
	logsub((caller(0))[3]);

	# do nothing if already in 'preview' mode
	
	return if $mode->preview;
	disable_preview_modes();
	{
	no warnings 'uninitialized';
	$mode->{preview}++;
	}

	pager( <<'MSG');
Setting preview mode. Recording of audio files is disabled.

Type 'arm' to enable recording.
MSG

}
sub set_doodle_mode {

	logsub((caller(0))[3]);
	return if $this_engine->started() and Audio::Nama::ChainSetup::really_recording();
	disable_preview_modes();
	{
	no warnings 'uninitialized';
	$mode->{doodle}++;
	}

	$tn{Mixdown}->set(rw => OFF);
	
	# reconfigure_engine will generate setup and start transport
	
pager( <<'MSG' );
Setting doodle mode. Using live inputs only. Duplicate
inputs are excluded. Recording of audio files is disabled.

Exit using 'preview' or 'arm' commands
MSG
}
sub exit_preview_modes {
		logsub((caller(0))[3]);
		return unless $mode->{preview} or $mode->{doodle};
		disable_preview_modes();
		stop_transport();
		pager("Exiting preview/doodle mode");
}
sub disable_preview_modes {
	undef $mode->{preview};
	undef $mode->{doodle}; 
}

sub master_on {

	return if $mode->mastering;
	
	# create mastering tracks if needed
	
	# we use hiding/unhiding status of Eq track to indicate
	# mastering mode, so no explicity use of $mode->{mastering}
	
	if ( ! $tn{Eq} ){  
	
		local $this_track;
		add_mastering_tracks();
		add_mastering_effects();
	} else { 
		unhide_mastering_tracks();
		map{ $ui->track_gui($tn{$_}->n) } @{$mastering->{track_names}};
	}

}
sub master_off {
	return if ! $mode->mastering;
	hide_mastering_tracks();
	map{ $ui->remove_track_gui($tn{$_}->n) 
		} @{$mastering->{track_names}};
	$this_track = $tn{Main} if grep{ $this_track->name eq $_} @{$mastering->{track_names}};
;
}

sub add_mastering_tracks {

	map{ 
		my $track = Audio::Nama::MasteringTrack->new(
			name => $_,
			rw => MON,
			group => 'Mastering', 
		);
		$ui->track_gui( $track->n );

 	} grep{ $_ ne 'Boost' } @{$mastering->{track_names}};
	my $track = Audio::Nama::BoostTrack->new(
		name 		=> 'Boost', 
		rw 			=> MON,
		group 		=> 'Mastering', 
		width		=> 2,
		source_type => undef,
		source_id	=> undef,
	);
	$ui->track_gui( $track->n );

	
}


sub add_mastering_effects {
	
	$this_track = $tn{Eq};

	nama_cmd("add_effect $mastering->{fx_eq}");

	$this_track = $tn{Low};

	nama_cmd("add_effect $mastering->{fx_low_pass}");
	nama_cmd("add_effect $mastering->{fx_compressor}");
	nama_cmd("add_effect $mastering->{fx_spatialiser}");

	$this_track = $tn{Mid};

	nama_cmd("add_effect $mastering->{fx_mid_pass}");
	nama_cmd("add_effect $mastering->{fx_compressor}");
	nama_cmd("add_effect $mastering->{fx_spatialiser}");

	$this_track = $tn{High};

	nama_cmd("add_effect $mastering->{fx_high_pass}");
	nama_cmd("add_effect $mastering->{fx_compressor}");
	nama_cmd("add_effect $mastering->{fx_spatialiser}");

	$this_track = $tn{Boost};
	
	nama_cmd("add_effect $mastering->{fx_limiter}"); # insert after vol
}

sub unhide_mastering_tracks {
	nama_cmd("for Mastering; set_track hide 0 rw MON");
}

sub hide_mastering_tracks {
	nama_cmd("for Mastering; set_track hide 1 rw OFF");
 }
}
		
1;
__END__