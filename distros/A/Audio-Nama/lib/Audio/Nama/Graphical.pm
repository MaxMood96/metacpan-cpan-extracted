# ------------ Graphical User Interface ------------

package Audio::Nama::Graphical;  ## gui routines
use v5.36; use Carp;
our $VERSION = 1.071;
use Audio::Nama::Globals qw($text $prompt);

use Module::Load::Conditional qw(can_load);
use Audio::Nama::Assign qw(:all);
use Audio::Nama::Util qw(colonize);
no warnings 'uninitialized';

our @ISA = 'Audio::Nama';      ## default to root namespace, e.g.  Refresh_subs, Graphical_subs
						# actually this doesn't seem like a
						# good idea
# widgets

## The following methods belong to the Graphical interface class

sub hello {"make a window";}
sub loop {
  	while (1) {
  		my ($user_input) = $text->{term}->readline($prompt) ;
  		Audio::Nama::process_line( $user_input );
  	}
}

sub initialize_tk { 
	my $result1 = can_load( modules => { Tk => undef } ) ;
	my $result2 = can_load( modules => { 'Tk::PNG' => undef } );
	$result1
}

# the following graphical methods are placed in the root namespace
# allowing access to root namespace variables 
# with a package path

package Audio::Nama;
# gui handling

# in the $gui variable, keys with leading _underscore
# indicate variables
#
# $gui->{_project_name}  # scalar/array/hash var
# $gui->{mw}             # Tk objects (widgets, frames, etc.)

sub init_gui {

	logsub((caller(0))[3]);

	init_palettefields(); # keys only


	### 	Tk root window 

	# Tk main window
 	$gui->{mw} = MainWindow->new;  
	get_saved_colors();
	$gui->{mw}->optionAdd('*font', 'Helvetica 12');
	$gui->{mw}->optionAdd('*BorderWidth' => 1);
	$gui->{mw}->title("Ecasound/Nama"); 
	$gui->{mw}->deiconify;

	### init effect window

	$gui->{ew} = $gui->{mw}->Toplevel;
	$gui->{ew}->title("Effect Window");
	$gui->{ew}->deiconify; 
#	$gui->{ew}->withdraw;


	### init waveform window

	if ($config->{display_waveform})
	{
		$gui->{ww} = $gui->{mw}->Toplevel;
		$gui->{ww}->title("Waveform Window");
		$gui->{ww}->deiconify; 
		$gui->{ww}->bind('<Control-Key-c>' => sub { exit } );
		$gui->{ww}->bind('<Control-Key- >' => \&toggle_transport); 
	}

	### Exit via Ctrl-C 

	$gui->{mw}->bind('<Control-Key-c>' => sub { exit } ); 
	$gui->{ew}->bind('<Control-Key-c>' => sub { exit } );

    ## Press SPACE to start/stop transport

	$gui->{mw}->bind('<Control-Key- >' => \&toggle_transport); 
	$gui->{ew}->bind('<Control-Key- >' => \&toggle_transport); 
	
	if ($config->{display_waveform})
	{
		$gui->{wwcanvas} = $gui->{ww}->Scrolled('Canvas')->pack;
		configure_waveform_window();
	}


	$gui->{fx_canvas} = $gui->{ew}->Scrolled('Canvas')->pack;
	configure_effects_window();

	$gui->{fx_frame} = $gui->{fx_canvas}->Frame;
	my $id = $gui->{fx_canvas}->createWindow(30,30, -window => $gui->{fx_frame},
											-anchor => 'nw');

	$gui->{project_head} = $gui->{mw}->Label->pack(-fill => 'both');

	$gui->{time_frame} = $gui->{mw}->Frame(
	#	-borderwidth => 20,
	#	-relief => 'groove',
	)->pack(
		-side => 'bottom', 
		-fill => 'both',
	);
	$gui->{mark_frame} = $gui->{time_frame}->Frame->pack(
		-side => 'bottom', 
		-fill => 'both');
	$gui->{seek_frame} = $gui->{time_frame}->Frame->pack(
		-side => 'bottom', 
		-fill => 'both');
	$gui->{transport_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
	# $oid_frame = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
	$gui->{clock_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
	#$gui->{group_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
 	$gui->{track_canvas}= $gui->{mw}->Scrolled('Canvas')->pack(-side => 'bottom', -fill => 'both');
	configure_track_canvas();
	$gui->{track_frame} = $gui->{track_canvas}->Frame; # ->pack(-fill => 'both');
	#$gui->{track_frame} = $gui->{mw}->Frame;
 	my $id2 = $gui->{track_canvas}->createWindow(0,0,
		-window => $gui->{track_frame}, 
		-anchor => 'nw');
 	#$gui->{group_label} = $gui->{group_frame}->Menubutton(-text => "GROUP",
 #										-tearoff => 0,
 #										-width => 13)->pack(-side => 'left');
		
	$gui->{add_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
	$gui->{perl_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
	$gui->{iam_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
	$gui->{load_frame} = $gui->{mw}->Frame->pack(-side => 'bottom', -fill => 'both');
#	my $blank = $gui->{mw}->Label->pack(-side => 'left');



	$gui->{project_label} = $gui->{load_frame}->Label(
		-text => "    Project name: "
	)->pack(-side => 'left');
	$gui->{project_entry} = $gui->{load_frame}->Entry(
		-textvariable => \$gui->{_project_name},
		-width => 25
	)->pack(-side => 'left');

	$gui->{load_project} = $gui->{load_frame}->Button->pack(-side => 'left');;
	$gui->{new_project} = $gui->{load_frame}->Button->pack(-side => 'left');;
	$gui->{quit} = $gui->{load_frame}->Button->pack(-side => 'left');
	$gui->{save_project} = $gui->{load_frame}->Button->pack(-side => 'left');
	$gui->{savefile_entry} = $gui->{load_frame}->Entry(
									-textvariable => \$gui->{_save_id},
									-width => 15
									)->pack(-side => 'left');
	$gui->{load_savefile} = $gui->{load_frame}->Button->pack(-side => 'left');
	$gui->{palette} = $gui->{load_frame}->Menubutton(-tearoff => 0)
		->pack( -side => 'left');
	$gui->{nama_palette} = $gui->{load_frame}->Menubutton(-tearoff => 0)
		->pack( -side => 'left');
	$gui->{add_track}->{label} = $gui->{add_frame}->Label(
		-text => "New track name: ")->pack(-side => 'left');
	$gui->{add_track}->{text_entry} = $gui->{add_frame}->Entry(
		-textvariable => \$gui->{_track_name}, 
		-width => 12
	)->pack(-side => 'left');
	$gui->{add_track}->{rec_label} = $gui->{add_frame}->Label(
		-text => "Input channel or client:"
	)->pack(-side => 'left');
	$gui->{add_track}->{rec_text} = $gui->{add_frame}->Entry(
		-textvariable => \$gui->{_chr}, 
		-width => 10
	)->pack(-side => 'left');
	$gui->{add_track}->{add_mono} = $gui->{add_frame}->Button->pack(-side => 'left');;
	$gui->{add_track}->{add_stereo}  = $gui->{add_frame}->Button->pack(-side => 'left');;

	$gui->{load_project}->configure(
		-text => 'Load',
		-command => sub{ load_project(
			name => remove_spaces($gui->{_project_name}),
			)});
	$gui->{new_project}->configure( 
		-text => 'Create',
		-command => sub{ load_project(
							name => remove_spaces($gui->{_project_name}),
							create => 1)});
	$gui->{save_project}->configure(
		-text => 'Save settings',
		-command => #sub { print "save_id: $gui->{_save_id}\n" });
		 sub {save_state($gui->{_save_id}) });
	$gui->{load_savefile}->configure(
		-text => 'Recall settings',
 		-command => sub {load_project (name => $project->{name},  # current project 
 										settings => $gui->{_save_id})},
				);
	$gui->{quit}->configure(-text => "Quit",
		 -command => sub { 
				stop_transport() if $this_engine->started;
				save_state($gui->{_save_id});
				pager("Exiting... \n");
				#$text->{term}->tkRunning(0);
				#$gui->{ew}->destroy;
				#$gui->{mw}->destroy;
				#Audio::Nama::nama_cmd('quit');
				exit;
				 });
	$gui->{palette}->configure(
		-text => 'Palette',
		-relief => 'raised',
	);
	$gui->{nama_palette}->configure(
		-text => 'Nama palette',
		-relief => 'raised',
	);

my @color_items = map { [ 'command' => $_, 
							-command  => colorset('mw', $_ ) ]
						} @{$gui->{_palette_fields}};
$gui->{palette}->AddItems( @color_items);

@color_items = map { [ 'command' => $_, 
							-command  => namaset( $_ ) ]
						} @{$gui->{_nama_fields}};

	$gui->{add_track}->{add_mono}->configure( 
			-text => 'Add Mono Track',
			-command => sub { 
					return if $gui->{_track_name} =~ /^\s*$/;	
			add_track(remove_spaces($gui->{_track_name})) }
	);
	$gui->{add_track}->{add_stereo}->configure( 
			-text => 'Add Stereo Track',
			-command => sub { 
								return if $gui->{_track_name} =~ /^\s*$/;	
								add_track(remove_spaces($gui->{_track_name}));
								nama_cmd('stereo');
	});

	my @labels = 
		qw(Track Name Version Status Source Send Volume Mute Unity Pan Center Effects);
	my @widgets;
	map{ push @widgets, $gui->{track_frame}->Label(-text => $_)  } @labels;
	$widgets[0]->grid(@widgets[1..$#widgets]);


}
sub configure_waveform_window {
	my ($width, $height) = @_;
	return if not $config->{display_waveform};

	$gui->{wwcanvas}->configure(
		-scrollregion =>[0,0,$width//$config->{waveform_canvas_x},$height//$config->{waveform_canvas_y}],
		-width => $width//$config->{waveform_canvas_x},
		-height => $height//$config->{waveform_canvas_y},
		);

}
sub configure_effects_window {
	$gui->{fx_canvas}->configure(
		scrollregion =>[2,2,10000,10000],
		-width => 1200,
		-height => 700,	
		);
}
sub configure_track_canvas {
 	$gui->{track_canvas}->configure(
 		-scrollregion =>[2,2,400,9600],
 		-width => 400,
 		-height => 400,	
 		);
}
sub wwgeometry { wh($gui->{wwcanvas}) }
sub wh {
	my $widget = shift;
	$widget->update;
	my ($width,$height,$sign1,$xpos,$sign2,$ypos) 
		= $widget->geometry =~ /(\d+)x(\d+)([+-])(\d+)([+-])(\d+)/;
	$width,$height
}

sub transport_gui {
	my $ui = shift;
	logsub((caller(0))[3]);

	$gui->{engine_label} = $gui->{transport_frame}->Label(
		-text => 'TRANSPORT',
		-width => 12,
		)->pack(-side => 'left');;
	$gui->{engine_start} = $gui->{transport_frame}->Button->pack(-side => 'left');
	$gui->{engine_stop} = $gui->{transport_frame}->Button->pack(-side => 'left');

	$gui->{engine_stop}->configure(-text => "Stop",
	-command => sub { 
					stop_transport();
				}
		);
	$gui->{engine_start}->configure(
		-text => "Start",
		-command => sub { 
		return if $this_engine->started;
		my $color = engine_mode_color();
		$ui->project_label_configure(-background => $color);
		start_transport();
				});

#preview_button();
#mastering_button();

}
sub time_gui {
	my $ui = shift;
	logsub((caller(0))[3]);

	my $time_label = $gui->{clock_frame}->Label(
		-text => 'TIME', 
		-width => 12);
	#print "bg: $gui->{_nama_palette}->{ClockBackground}, fg:$gui->{_nama_palette}->{ClockForeground}\n";
	$gui->{clock} = $gui->{clock_frame}->Label(
		-text => '0:00', 
		-width => 8,
		-background => $gui->{_nama_palette}->{ClockBackground},
		-foreground => $gui->{_nama_palette}->{ClockForeground},
		);
	my $length_label = $gui->{clock_frame}->Label(
		-text => 'LENGTH',
		-width => 10,
		);
	$gui->{setup_length} = $gui->{clock_frame}->Label(
	#	-width => 8,
		);

	for my $w ($time_label, $gui->{clock}, $length_label, $gui->{setup_length}) {
		$w->pack(-side => 'left');	
	}

	$gui->{mark_frame} = $gui->{time_frame}->Frame->pack(
		-side => 'bottom', 
		-fill => 'both');
	$gui->{seek_frame} = $gui->{time_frame}->Frame->pack(
		-side => 'bottom', 
		-fill => 'both');
	# jump

	my $jump_label = $gui->{seek_frame}->Label(-text => q(JUMP), -width => 12);
	my @pluses = (1, 5, 10, 30, 60);
	my @minuses = map{ - $_ } reverse @pluses;
	my @fw = map{ my $d = $_; $gui->{seek_frame}->Button(
			-text => $d,
			-command => sub { jump($d * $gui->{_seek_unit} ) },
			)
		}  @pluses ;
	my @rew = map{ my $d = $_; $gui->{seek_frame}->Button(
			-text => $d,
			-command => sub { jump($d * $gui->{_seek_unit} ) },
			)
		}  @minuses ;
	my $beg = $gui->{seek_frame}->Button(
			-text => 'Beg',
			-command => \&jump_to_start,
			);
	my $end = $gui->{seek_frame}->Button(
			-text => 'End',
			-command => \&jump_to_end,
			);

	$gui->{seek_unit} = $gui->{seek_frame}->Button( 
			-text => 'Sec',
			);
		for my $w($jump_label, @rew, $beg, $gui->{seek_unit}, $end, @fw){
			$w->pack(-side => 'left')
		}

	$gui->{seek_unit}->configure (-command => sub { &toggle_unit; &show_unit });

	# Marks
	
	my $mark_label = $gui->{mark_frame}->Label(
		-text => q(MARK), 
		-width => 12,
		)->pack(-side => 'left');
		
	my $drop_mark = $gui->{mark_frame}->Button(
		-text => 'Place',
		-command => \&drop_mark,
		)->pack(-side => 'left');	
		
	$gui->{mark_remove} = $gui->{mark_frame}->Button(
		-text => 'Remove',
		-command => \&arm_mark_toggle,
	)->pack(-side => 'left');	

}
sub toggle_unit {
	if ($gui->{_seek_unit} == 1){
		$gui->{_seek_unit} = 60;
		
	} else{ $gui->{_seek_unit} = 1; }
}
sub show_unit { $gui->{seek_unit}->configure(
	-text => ($gui->{_seek_unit} == 1 ? 'Sec' : 'Min') 
)}

sub paint_button {
	my $ui = shift;
	my ($button, $color) = @_;
	$button->configure(-background => $color,
						-activebackground => $color);
}

sub engine_mode_color {
		if ( user_rec_tracks()  ){ 
				$gui->{_nama_palette}->{RecBackground} # live recording 
		} elsif ( Audio::Nama::ChainSetup::really_recording() ){ 
				$gui->{_nama_palette}->{Mixdown}	# mixdown only 
		} elsif ( user_play_tracks() ){  
				$gui->{_nama_palette}->{Play}; 	# just playback
		} else { $gui->{_old_bg} } 
}
sub user_rec_tracks { some_user_tracks(REC) }
sub user_play_tracks { some_user_tracks(PLAY) }

sub some_user_tracks {
	my $which = shift;
	my @user_tracks = Audio::Nama::audio_tracks();
	splice @user_tracks, 0, 2; # drop Main and Mixdown tracks
	return unless @user_tracks;
	my @selected_user_tracks = grep { $_->rec_status eq $which } @user_tracks;
	return unless @selected_user_tracks;
	map{ $_->n } @selected_user_tracks;
}

sub flash_ready {

	my $color = engine_mode_color();
	logpkg(__FILE__,__LINE__,'debug', "flash color: $color");
	$ui->length_display(-background => $color);
	$ui->project_label_configure(-background => $color) unless $mode->{preview};
	# TODO update for preview mode
 	start_event(heartbeat =>  timer(5, 0, \&reset_engine_mode_color_display));
}
sub reset_engine_mode_color_display { $ui->project_label_configure(
	-background => $gui->{_nama_palette}->{OffBackground} )
}
sub set_engine_mode_color_display { $ui->project_label_configure(-background => engine_mode_color()) }
sub group_gui {  
	my $ui = shift;
	my $group = $bn{Main}; 
	my $dummy = $gui->{track_frame}->Label(-text => ' '); 
	$gui->{group_label} = 	$gui->{track_frame}->Label(
			-text => "G R O U P",
			-foreground => $gui->{_nama_palette}->{GroupForeground},
			-background => $gui->{_nama_palette}->{GroupBackground},

 );
	$gui->{group_version} = $gui->{track_frame}->Menubutton( 
		-text => q( ), 
		-tearoff => 0,
		-foreground => $gui->{_nama_palette}->{GroupForeground},
		-background => $gui->{_nama_palette}->{GroupBackground},
);
	$gui->{group_rw} = $gui->{track_frame}->Menubutton( 
		-text    => $group->rw,
	 	-tearoff => 0,
		-foreground => $gui->{_nama_palette}->{GroupForeground},
		-background => $gui->{_nama_palette}->{GroupBackground},
);


		
		$gui->{group_rw}->AddItems([
			'command' => MON,
			-background => $gui->{_old_bg},
			-command => sub { 
				return if $this_engine->started();
				$group->set(rw => MON);
				$gui->{group_rw}->configure(-text => MON);
				refresh();
				Audio::Nama::reconfigure_engine()
				}
			],[
			'command' => OFF,
			-background => $gui->{_old_bg},
			-command => sub { 
				return if $this_engine->started();
				$group->set(rw => OFF);
				$gui->{group_rw}->configure(-text => OFF);
				refresh();
				Audio::Nama::reconfigure_engine()
				}
			]);
			$dummy->grid($gui->{group_label}, $gui->{group_version}, $gui->{group_rw});
			#$ui->global_version_buttons;

}
sub global_version_buttons {
	my $version = $gui->{group_version};
	$version and map { $_->destroy } $version->children;
		
	logpkg(__FILE__,__LINE__,'debug', "making global version buttons range: " ,
		join ' ',1..$bn{Main}->last);

			$version->radiobutton( 

				-label => (''),
				-value => 0,
				-command => sub { 
					$bn{Main}->set(version => 0); 
					$version->configure(-text => " ");
					Audio::Nama::reconfigure_engine();
					refresh();
					}
			);

 	for my $v (1..$bn{Main}->last) { 

	# the highest version number of all tracks in the
	# $bn{Main} group
	
	my @user_track_indices = grep { $_ > 2 } map {$_->n} Audio::Nama::audio_tracks();
	
		next unless grep{  grep{ $v == $_ } @{ $ti{$_}->versions } }
			@user_track_indices;
		

			$version->radiobutton( 

				-label => ($v ? $v : ''),
				-value => $v,
				-command => sub { 
					$bn{Main}->set(version => $v); 
					$version->configure(-text => $v);
					Audio::Nama::reconfigure_engine();
					refresh();
					}

			);
 	}
}
sub track_gui { 
	logsub((caller(0))[3]);
	my $ui = shift;
	my $n = shift;
	pager("track_gui already generated"), return
		if defined $gui->{tracks}->{$n} ;
	return if $ti{$n}->hide;
	
	logpkg(__FILE__,__LINE__,'debug', "found index: $n");
	my @rw_items = @_ ? @_ : (
			[ 'command' => "REC",
				-foreground => 'red',
				-command  => sub { 
					return if $this_engine->started();
					$ti{$n}->set(rw => "REC");
					
					$ui->refresh_track($n);
					#refresh_group();
					Audio::Nama::reconfigure_engine();
			}],
			[ 'command' => "PLAY",
				-command  => sub { 
					return if $this_engine->started();
					$ti{$n}->set(rw => "PLAY");
					$ui->refresh_track($n);
					#refresh_group();
					Audio::Nama::reconfigure_engine();
			}],
			[ 'command' => "MON",
				-foreground => 'red',
				-command  => sub { 
					return if $this_engine->started();
					$ti{$n}->set(rw => "MON");
					
					$ui->refresh_track($n);
					#refresh_group();
					Audio::Nama::reconfigure_engine();
			}],
			[ 'command' => "OFF", 
				-command  => sub { 
					return if $this_engine->started();
					$ti{$n}->set(rw => "OFF");
					$ui->refresh_track($n);
					#refresh_group();
					Audio::Nama::reconfigure_engine();
			}],
		);
	my ($number, $name, $version, $rw, $ch_r, $ch_m, $vol, $mute, $solo, $unity, $pan, $center);
	$number = $gui->{track_frame}->Label(-text => $n,
									-justify => 'left');
	my $stub = " ";
	$stub .= $ti{$n}->version;
	$name = $gui->{track_frame}->Label(
			-text => $ti{$n}->name,
			-justify => 'left');
	$version = $gui->{track_frame}->Menubutton( 
					-text => $stub,
					# -relief => 'sunken',
					-tearoff => 0);
	my @versions = '';
	#push @versions, @{$ti{$n}->versions} if @{$ti{$n}->versions};
	my $ref = ref $ti{$n}->versions ;
		$ref =~ /ARRAY/ and 
		push (@versions, @{$ti{$n}->versions}) or
		croak "chain $n, found unexpectedly $ref\n";;
	my $indicator;
	for my $v (@versions) {
					$version->radiobutton(
						-label => $v,
						-value => $v,
						-variable => \$indicator,
						-command => 
		sub { 
			$ti{$n}->set( version => $v );
			return if $ti{$n}->rec;
			$version->configure( -text=> $ti{$n}->current_version );
			Audio::Nama::reconfigure_engine();
			}
					);
	}

	$ch_r = $gui->{track_frame}->Menubutton(
					# -relief => 'groove',
					-tearoff => 0,
				);
	my @range;
	push @range, 1..$config->{soundcard_channels} if $n > 2; # exclude Main/Mixdown
	
	for my $v (@range) {
		$ch_r->radiobutton(
			-label => $v,
			-value => $v,
			-command => sub { 
				return if $this_engine->started();
			#	$ti{$n}->set(rw => REC);
				$ti{$n}->source($v);
				$ui->refresh_track($n) }
			)
	}
	@range = ();

	push @range, "off" if $n > 2;
	push @range, 1..$config->{soundcard_channels} if $n != 2; # exclude Mixdown

	$ch_m = $gui->{track_frame}->Menubutton(
					-tearoff => 0,
					# -relief => 'groove',
				);
				for my $v (@range) {
					$ch_m->radiobutton(
						-label => $v,
						-value => $v,
						-command => sub { 
							return if $this_engine->started();
							local $this_track = $ti{$n};
							if( $v eq 'off' )
								 { nama_cmd('nosend') }
							else { $this_track->set_send($v) }
							$ui->refresh_track($n);
							Audio::Nama::reconfigure_engine();
 						}
				 		)
				}
	$rw = $gui->{track_frame}->Menubutton(
		-text => $ti{$n}->rw,
		-tearoff => 0,
		# -relief => 'groove',
	);
	map{$rw->AddItems($_)} @rw_items; 

 
	my $p_num = 0; # needed when using parameter controllers
	# Volume
	
	if ( Audio::Nama::need_vol_pan($ti{$n}->name, "vol") ){

		my $vol_id = $ti{$n}->vol;

		logpkg(__FILE__,__LINE__,'debug', "vol effect_id: $vol_id");
		my %p = ( 	parent => \$gui->{track_frame},
				chain  => $n,
				type => 'ea',
				id => $vol_id,
				p_num		=> $p_num,
				length => 300, 
				);


		 logpkg(__FILE__,__LINE__,'debug',sub{my %q = %p; delete $q{parent}; print
		 "=============\n%p\n",json_out(\%q)});

		$vol = make_scale( \%p );
		# Mute

		$mute = $gui->{track_frame}->Button(
			-command => sub { 
				my $FX = fxn($vol_id);
				if (	$FX->params->[0] != $config->{mute_level}->{$FX->type} 
					and $FX->params->[0] != $config->{fade_out_level}->{$FX->type} 
				) {  # non-zero volume
					$ti{$n}->mute;
					$mute->configure(-background => $gui->{_nama_palette}->{Mute});
				}
				else {
					$ti{$n}->unmute;
					$mute->configure(-background => $gui->{_nama_palette}->{OffBackground})
				}
			}	
		  );

		# Unity

		$unity = $gui->{track_frame}->Button(
				-command => sub { 
					my $FX = fxn($vol_id);
					Audio::Nama::update_effect(
						$vol_id, 
						0, 
						$config->{unity_level}->{$FX->type});
				}
		  );
	} else {

		$vol = $gui->{track_frame}->Label;
		$mute = $gui->{track_frame}->Label;
		$unity = $gui->{track_frame}->Label;

	}

	if ( Audio::Nama::need_vol_pan($ti{$n}->name, "pan") ){
	  
		# Pan
		
		my $pan_id = $ti{$n}->pan;
		
		logpkg(__FILE__,__LINE__,'debug', "pan effect_id: $pan_id");
		$p_num = 0;           # first parameter
		my %q = ( 	parent => \$gui->{track_frame},
				chain  => $n,
				type => 'epp',
				id => $pan_id,
				p_num		=> $p_num,
				);
		# logpkg(__FILE__,__LINE__,'debug',sub{ my %q = %p; delete $q{parent}; print "x=============\n%p\n",json_out(\%q) });
		$pan = make_scale( \%q );

		# Center

		$center = $gui->{track_frame}->Button(
			-command => sub { 
				Audio::Nama::update_effect($pan_id, 0, 50);
			}
		  );
	} else { 

		$pan = $gui->{track_frame}->Label;
		$center = $gui->{track_frame}->Label;
	}
	
	my $effects = $gui->{fx_frame}->Frame->pack(-fill => 'both');;

	# effects, held by track_widget->n->effects is the frame for
	# all effects of the track

	@{ $gui->{tracks}->{$n} }{qw(name version rw ch_r ch_m mute effects)} 
		= ($name,  $version, $rw, $ch_r, $ch_m, $mute, \$effects);#a ref to the object
	#logpkg(__FILE__,__LINE__,'debug', "=============$gui->{tracks}\n",sub{json_out($gui->{tracks})});
	my $independent_effects_frame 
		= ${ $gui->{tracks}->{$n}->{effects} }->Frame->pack(-fill => 'x');


	my $controllers_frame 
		= ${ $gui->{tracks}->{$n}->{effects} }->Frame->pack(-fill => 'x');
	
	# parents are the independent effects
	# children are controllers for various paramters

	$gui->{tracks}->{$n}->{parents} = $independent_effects_frame;

	$gui->{tracks}->{$n}->{children} = $controllers_frame;
	
	$independent_effects_frame
		->Label(-text => uc $ti{$n}->name )->pack(-side => 'left');

	#logpkg(__FILE__,__LINE__,'debug',"Number: $n"),MainLoop if $n == 2;
	my @tags = qw( EF P1 P2 L1 L2 L3 L4 );
	my @starts =   ( $fx_cache->{split}->{cop}{a}, 
					 $fx_cache->{split}->{preset}{a}, 
					 $fx_cache->{split}->{preset}{b}, 
					 $fx_cache->{split}->{ladspa}{a}, 
					 $fx_cache->{split}->{ladspa}{b}, 
					 $fx_cache->{split}->{ladspa}{c}, 
					 $fx_cache->{split}->{ladspa}{d}, 
					);
	my @ends   =   ( $fx_cache->{split}->{cop}{z}, 
					 $fx_cache->{split}->{preset}{b}, 
					 $fx_cache->{split}->{preset}{z}, 
					 $fx_cache->{split}->{ladspa}{b}-1, 
					 $fx_cache->{split}->{ladspa}{c}-1, 
					 $fx_cache->{split}->{ladspa}{d}-1, 
					 $fx_cache->{split}->{ladspa}{z}, 
					);
	my @add_effect;

	map{push @add_effect, effect_button($n, shift @tags, shift @starts, shift @ends)} 1..@tags;
	
	$number->grid($name, $version, $rw, $ch_r, $ch_m, $vol, $mute, $unity, $pan, $center, @add_effect);

	$gui->{tracks_remove}->{$n} = [
		grep{ $_ } (
			$number, 
			$name, 
			$version, 
			$rw, 
			$ch_r, 
			$ch_m, 
			$vol,
			$mute, 
			$unity, 
			$pan, 
			$center, 
			@add_effect,
			$effects,
		)
	];

	$ui->refresh_track($n);

}

sub remove_track_gui {
 	my $ui = shift;
 	my $n = shift;
	logsub((caller(0))[3]);
	return unless $gui->{tracks_remove}->{$n};
 	map {$_->destroy  } @{ $gui->{tracks_remove}->{$n} };
	delete $gui->{tracks_remove}->{$n};
	delete $gui->{tracks}->{$n};
}

sub paint_mute_buttons {
	map{ $gui->{tracks}->{$_}{mute}->configure(
			-background 		=> $gui->{_nama_palette}->{Mute},

			)} grep { $ti{$_}->old_vol_level}# muted tracks
				map { $_->n } Audio::Nama::audio_tracks();  # track numbers
}

sub create_master_and_mix_tracks { 
	logsub((caller(0))[3]);


	my @rw_items = (
			[ 'command' => "MON",
				-command  => sub { 
						return if $this_engine->started();
						$tn{Main}->set(rw => "MON");
						$ui->refresh_track($tn{Main}->n);
			}],
			[ 'command' => "OFF", 
				-command  => sub { 
						return if $this_engine->started();
						$tn{Main}->set(rw => "OFF");
						$ui->refresh_track($tn{Main}->n);
			}],
		);

	$ui->track_gui( $tn{Main}->n, @rw_items );

	$ui->track_gui( $tn{Mixdown}->n); 

	#$ui->group_gui('Main');
}

sub update_version_button {
	my $ui = shift;
	my ($n, $v) = @_;
	carp ("no version provided \n") if ! $v;
	my $w = $gui->{tracks}->{$n}->{version};
					$w->radiobutton(
						-label => $v,
						-value => $v,
						-command => 
		sub { $gui->{tracks}->{$n}->{version}->configure(-text=>$v) 
				unless $ti{$n}->rec }
					);
}

sub add_effect_gui {
		logsub((caller(0))[3]);
		my $ui = shift;
		my %p 			= %{shift()};
		my ($n,$code,$id,$parent,$parameter,$FX) =
			@p{qw(chain type id parent parameter self)};
		my $i = $fx_cache->{full_label_to_index}->{$code};

		logpkg(__FILE__,__LINE__,'debug', sub{json_out(\%p)});

		logpkg(__FILE__,__LINE__,'debug', "id: $id, parent: $parent");
		# $id is determined by effect_init, which will return the
		# existing id if supplied

		# check display format, may be 'scale' 'field' or 'hidden'
		
		my $display_type = $FX->display; # individual setting
		defined $display_type or $display_type = $fx_cache->{registry}->[$i]->{display}; # template
		logpkg(__FILE__,__LINE__,'debug', "display type: $display_type");

		return if $display_type eq q(hidden);

		my $frame ;
		if ( ! $parent ){ # independent effect
			$frame = $gui->{tracks}->{$n}->{parents}->Frame->pack(
				-side => 'left', 
				-anchor => 'nw',)
		} else {                 # controller
			$frame = $gui->{tracks}->{$n}->{children}->Frame->pack(
				-side => 'top', 
				-anchor => 'nw')
		}

		$gui->{fx}->{$id} = $frame; 
		# we need a separate frame so title can be long

		# here add menu items for Add Controller, and Remove

		my $parentage = $fx_cache->{registry}->[
			$fx_cache->{full_label_to_index}->{$FX->type} 
		]->{name};
		$parentage and $parentage .=  " - ";
		logpkg(__FILE__,__LINE__,'debug', "parentage: $parentage");
		my $eff = $frame->Menubutton(
			-text => $parentage. $fx_cache->{registry}->[$i]->{name}, -tearoff => 0,);

		$eff->AddItems([
			'command' => "Remove",
			-command => sub { remove_effect($id) }
		]);
		$eff->grid();
		my @labels;
		my @sliders;

		# make widgets

		for my $p (0..$fx_cache->{registry}->[$i]->{count} - 1 ) {
		my @items;
		#logpkg(__FILE__,__LINE__,'debug', "p_first: $p_first, p_last: $p_last");
		for my $j ($fx_cache->{split}->{ctrl}{a}..$fx_cache->{split}->{ctrl}{z}) {   
			push @items, 				
				[ 'command' => $fx_cache->{registry}->[$j]->{name},
					-command => sub { add_effect({
							parent 	=> $id,
							chain 	=> $n,
							params 	=> [ $p  + 1 ],
							type 	=> $fx_cache->{registry}->[$j]->{code} })  }
				];

		}
		push @labels, $frame->Menubutton(
				-text => $fx_cache->{registry}->[$i]->{params}->[$p]->{name},
				-menuitems => [@items],
				-tearoff => 0,
		);
			logpkg(__FILE__,__LINE__,'debug', "parameter name: ",
				$fx_cache->{registry}->[$i]->{params}->[$p]->{name});
			my $v =  # for argument vector 
			{	parent => \$frame,
				id => $id, 
				p_num  => $p,
				self => $FX,
			};
			push @sliders,make_scale($v);
		}

		if (@sliders) {

			$sliders[0]->grid(@sliders[1..$#sliders]);
			 $labels[0]->grid(@labels[1..$#labels]);
		}
}


sub project_label_configure{ 
	my $ui = shift;
	$gui->{project_head}->configure( @_ ) }

sub length_display{ 
	my $ui = shift;
	$gui->{setup_length}->configure(@_)};

sub clock_config { 
	my $ui = shift;
	$gui->{clock}->configure( @_ )}

sub manifest { $gui->{ew}->deiconify() }

sub destroy_widgets {

	map{ $_->destroy } map{ $_->children } $gui->{fx_frame};
	#my @children = $gui->{group_frame}->children;
	#map{ $_->destroy  } @children[1..$#children];
	my @children = $gui->{track_frame}->children;
	# leave field labels (first row)
	map{ $_->destroy  } @children[11..$#children]; # fragile
	%{$gui->{marks}} and map{ $_->destroy } values %{$gui->{marks}};
}
sub remove_effect_gui { 
	my $ui = shift;
	logsub((caller(0))[3]);
	my $id = shift;
	my $FX = fxn($id);
	my $n = $FX->chain;
	logpkg(__FILE__,__LINE__,'debug', "id: $id, chain: $n");

	logpkg(__FILE__,__LINE__,'debug', "i have widgets for these ids: ", join " ",keys %{$gui->{fx}});
	logpkg(__FILE__,__LINE__,'debug', "preparing to destroy: $id");
	return unless defined $gui->{fx}->{$id};
	$gui->{fx}->{$id}->destroy();
	delete $gui->{fx}->{$id}; 

}

sub effect_button {
	logsub((caller(0))[3]);
	my ($n, $label, $start, $end) = @_;
	logpkg(__FILE__,__LINE__,'debug', "chain $n label $label start $start end $end");
	my @items;
	my $widget;
	my @indices = ($start..$end);
	if ($start >= $fx_cache->{split}->{ladspa}{a} and $start <= $fx_cache->{split}->{ladspa}{z}){
		@indices = ();
		@indices = @{$fx_cache->{ladspa_sorted}}[$start..$end];
		logpkg(__FILE__,__LINE__,'debug', "length sorted indices list: ",scalar @indices );
	logpkg(__FILE__,__LINE__,'debug', "Indices: @indices");
	}
		
		for my $j (@indices) { 
		push @items, 				
			[ 'command' => "$fx_cache->{registry}->[$j]->{count} $fx_cache->{registry}->[$j]->{name}" ,
				-command  => sub { 
					 add_effect( {chain => $n, type => $fx_cache->{registry}->[$j]->{code} } ); 
					$gui->{ew}->deiconify; # display effects window
					} 
			];
	}
	$widget = $gui->{track_frame}->Menubutton(
		-text => $label,
		-tearoff =>0,
		# -relief => 'raised',
		-menuitems => [@items],
	);
	$widget;
}

sub make_scale {
	
	logsub((caller(0))[3]);
	my $ref = shift;
	my %p = %{$ref};
# 	%p contains following:
# 	id   => operator id
# 	parent => parent widget, i.e. the frame
# 	p_num      => parameter number, starting at 0
# 	length       => length widget # optional 
	my $id = $p{id};
	my $FX = fxn($id) // $p{self};
	my $n = $FX->chain;
	my $code = $FX->type;
	my $p  = $p{p_num};
	my $i  = $fx_cache->{full_label_to_index}->{$code};

	logpkg(__FILE__,__LINE__,'debug', "id: $id code: $code");
	

	# check display format, may be text-field or hidden,

	logpkg(__FILE__,__LINE__,'debug',"i: $i code: $fx_cache->{registry}->[$i]->{code} display: $fx_cache->{registry}->[$i]->{display}");
	my $display_type = $FX->display;
	defined $display_type or $display_type = $fx_cache->{registry}->[$i]->{display};
	logpkg(__FILE__,__LINE__,'debug', "display type: $display_type");
	return if $display_type eq q(hidden);


	logpkg(__FILE__,__LINE__,'debug', "to: ", $fx_cache->{registry}->[$i]->{params}->[$p]->{end}) ;
	logpkg(__FILE__,__LINE__,'debug', "p: $p code: $code");
	logpkg(__FILE__,__LINE__,'debug', "is_log_scale: ".is_log_scale($i,$p));

	# set display type to individually specified value if it exists
	# otherwise to the default for the controller class


	
	if 	($display_type eq q(scale) ) { 

		# return scale type controller widgets
		my $frame = ${ $p{parent} }->Frame;
			

		#return ${ $p{parent} }->Scale(
		
		my $log_display;
		
		my $controller = $frame->Scale(
			-variable => \$FX->{params}->[$p],
			-orient => 'horizontal',
			-from   =>  $fx_cache->{registry}->[$i]->{params}->[$p]->{begin},
			-to     =>  $fx_cache->{registry}->[$i]->{params}->[$p]->{end},
			-resolution => resolution($i, $p),
		  -width => 12,
		  -length => $p{length} ? $p{length} : 100,
		  -command => sub { Audio::Nama::update_ecasound_effect($id, $p, $FX->params->[$p]) },
			-state => $FX->is_read_only($p) ? 'disabled' : 'normal',
		  );

		# auxiliary field for logarithmic display
		if ( is_log_scale($i, $p)  )
		#	or $code eq 'ea') 
			{
			my $log_display = $frame->Label(
				-text => exp $fx_cache->{registry}->[$i]->{params}->[$p]->{default},
				-width => 5,
				);
			$controller->configure(
				-variable => \$FX->{params_log}->[$p],
		  		-command => sub { 
					$FX->params->[$p] = exp $FX->params_log->[$p];
					Audio::Nama::update_ecasound_effect($id, $p, $FX->params->[$p]);
					$log_display->configure(
						-text => 
						$fx_cache->{registry}->[$i]->{params}->[$p]->{name} =~ /hz|frequency/i
							? int $FX->params->[$p]
							: dn($FX->params->[$p], 1)
						);
					}
				);
		$log_display->grid($controller);
		}
		else { $controller->grid; }

		return $frame;

	}	

	elsif ($display_type eq q(field) ){ 

	 	# then return field type controller widget

		return ${ $p{parent} }->Entry(
			-textvariable =>\$FX->params->[$p],
			-width => 6,
	#		-command => sub { Audio::Nama::update_ecasound_effect($id, $p, $FX->params->[$p]) },
			# doesn't work with Entry widget
			);	

	}
	else { croak "missing or unexpected display type: $display_type" }

}

sub is_log_scale {
	my ($i, $p) = @_;
	$fx_cache->{registry}->[$i]->{params}->[$p]->{hint} =~ /logarithm/ 
}
sub resolution {
	my ($i, $p) = @_;
	my $res = $fx_cache->{registry}->[$i]->{params}->[$p]->{resolution};
	return $res if $res;
	my $end = $fx_cache->{registry}->[$i]->{params}->[$p]->{end};
	my $beg = $fx_cache->{registry}->[$i]->{params}->[$p]->{begin};
	return 1 if abs($end - $beg) > 30;
	return abs($end - $beg)/100
}

sub arm_mark_toggle { 
	if ($gui->{_markers_armed}) {
		$gui->{_markers_armed} = 0;
		$gui->{mark_remove}->configure( -background => $gui->{_nama_palette}->{OffBackground});
	 } else{
		$gui->{_markers_armed} = 1;
		$gui->{mark_remove}->configure( -background => $gui->{_nama_palette}->{MarkArmed});
	}
}
sub marker {
	my $ui = shift;
	my $mark = shift; # Mark
	logpkg(__FILE__,__LINE__,'debug',"mark is ", ref $mark);
	my $pos = $mark->time;
	logpkg(__FILE__,__LINE__,'debug',$pos, " ", int $pos);
		$gui->{marks}->{$pos} = $gui->{mark_frame}->Button( 
			-text => (join " ",  colonize( int $pos ), $mark->name),
			-background => $gui->{_nama_palette}->{OffBackground},
			-command => sub { Audio::Nama::mark($mark) },
		)->pack(-side => 'left');
}

sub restore_time_marks {
	my $ui = shift;
	map{ $ui->marker($_) } Audio::Nama::Mark::all() ; 
	$gui->{seek_unit}->configure( -text => $gui->{_seek_unit} == 1 ? q(Sec) : q(Min) )
}
sub destroy_marker {
	my $ui = shift;
	my $pos = shift;
	$gui->{marks}->{$pos}->destroy; 
}

sub setup_playback_indicator {
	my $ui = shift;
	start_event(update_playback_position_display => timer(0, 0.1, \&update_indicator));
} 	
sub update_indicator {
	$gui->{wwcanvas}->delete('playback-indicator');
	my $pos = Audio::Nama::ecasound_iam("getpos");
	my $xpos = int( $pos * $config->{waveform_pixels_per_second} );
	$gui->{wwcanvas}->createLine(
			$xpos,0,
			$xpos,$config->{waveform_canvas_y},
			-fill => 'red',
			-width => 1,
			-tags => 'playback-indicator'
	);
}

sub get_saved_colors {
	logsub((caller(0))[3]);

	# aliases
	
	$gui->{_old_bg} = $gui->{_palette}{mw}{background};
	$gui->{_old_abg} = $gui->{_palette}{mw}{activeBackground};
	$gui->{_old_bg} //= '#d915cc1bc3cf';
	#print "pb: $gui->{_palette}{mw}{background}\n";


	my $pal = $file->gui_palette;
	$pal .= '.json' unless $pal =~ /\.json$/;
	logpkg(__FILE__,__LINE__,'debug',"pal $pal");
	$pal = -f $pal 
			? scalar read_file($pal)
			: get_data_section('default_palette_json');
	my $ref = decode($pal, 'json');
	#say "palette file",json_out($ref);

	assign_singletons({ data => $ref });
	
	$gui->{_old_abg} = $gui->{_palette}->{mw}{activeBackground};
	$gui->{_old_abg} = $gui->{project_head}->cget('-activebackground') unless $gui->{_old_abg};
	#print "1palette: \n", json_out( $gui->{_palette} );
	#print "\n1namapalette: \n", json_out($gui->{_nama_palette});
	my %setformat;
	map{ $setformat{$_} = $gui->{_palette}->{mw}{$_} if $gui->{_palette}->{mw}{$_}  } 
		keys %{$gui->{_palette}->{mw}};	
	#print "\nsetformat: \n", json_out(\%setformat);
	$gui->{mw}->setPalette( %setformat );
}
sub colorset {
	my ($widgetid, $field) = @_;
	sub { 
			my $widget = $gui->{$widgetid};
			#print "ancestor: $widgetid\n";
			my $new_color = colorchooser($field,$widget->cget("-$field"));
			if( defined $new_color ){
				
				# install color in palette listing
				$gui->{_palette}->{$widgetid}{$field} = $new_color;

				# set the color
				my @fields =  ($field => $new_color);
				push (@fields, 'background', $widget->cget('-background'))
					unless $field eq 'background';
				#print "fields: @fields\n";
				$widget->setPalette( @fields );
			}
 	};
}

sub namaset {
	my ($field) = @_;
	sub { 	
			#print "f: $field np: $gui->{_nama_palette}->{$field}\n";
			my $color = colorchooser($field,$gui->{_nama_palette}->{$field});
			if ($color){ 
				# install color in palette listing
				$gui->{_nama_palette}->{$field} = $color;

				# set those objects who are not
				# handled by refresh
	*rec = \$gui->{_nama_palette}->{RecBackground};
	*mon = \$gui->{_nama_palette}->{MonBackground};
	*off = \$gui->{_nama_palette}->{OffBackground};

				$gui->{clock}->configure(
					-background => $gui->{_nama_palette}->{ClockBackground},
					-foreground => $gui->{_nama_palette}->{ClockForeground},
				);
				$gui->{group_label}->configure(
					-background => $gui->{_nama_palette}->{GroupBackground},
					-foreground => $gui->{_nama_palette}->{GroupForeground},
				);
				refresh();
			}
	}

}

sub colorchooser { 
	logsub((caller(0))[3]);
	my ($field, $initialcolor) = @_;
	logpkg(__FILE__,__LINE__,'debug', "field: $field, initial color: $initialcolor");
	my $new_color = $gui->{mw}->chooseColor(
							-title => $field,
							-initialcolor => $initialcolor,
							);
	#print "new color: $new_color\n";
	$new_color;
}
sub init_palettefields {
	@{$gui->{_palette_fields}} = qw[ 
		foreground
		background
		activeForeground
		activeBackground
		selectForeground
		selectBackground
		selectColor
		highlightColor
		highlightBackground
		disabledForeground
		insertBackground
		troughColor
	];

	@{$gui->{_nama_fields}} = qw [
		RecForeground
		RecBackground
		MonForeground
		MonBackground
		OffForeground
		OffBackground
		ClockForeground
		ClockBackground
		Capture
		Play
		Mixdown
		GroupForeground
		GroupBackground
		SendForeground
		SendBackground
		SourceForeground
		SourceBackground
		Mute
		MarkArmed
	];
}

sub save_palette {
 	serialize (
 		file => $file->gui_palette,
		format => 'json',
 		vars => [ qw( $gui->{_palette} $gui->{_nama_palette} ) ],
 		class => 'Audio::Nama')
}

### end



## refresh functions

sub refresh_waveform_window {
	$gui->{wwcanvas}->delete('waveform',$_->name) for all_tracks();
 	my @playable = grep{ $_->play} user_tracks();
	map{ $_->waveform->display() } @playable;
	configure_waveform_window();
	generate_timeline(
			widget => $gui->{wwcanvas}, 
			y_pos => 600,
	);
}
sub height { $_[0] % 5 ? 5 : 10 }
sub generate_timeline {
	my %args = @_;
	my $length = ecasound_iam('cs-get-length');
	$length = int($length + 5.5);
	$args{seconds} = $length;
	my $pps = $config->{waveform_pixels_per_second};
	for (0..$args{seconds})
	{
		my $xpos = $_ * $pps;
		if ($_ % 10 == 0)
		{
			$args{widget}->createText( 
							$xpos, $args{y_pos} - 20, 
							-font => 'lucidasanstypewriter-bold-14', 
							-text => $_,
							);
		}
		$args{widget}->createLine(
			$xpos, $args{y_pos} - height($_),
			$xpos, $args{y_pos},
			-fill => 'black',
			-width => 1,
			-tags => 'timelime'
		);
	}

}
sub set_widget_color {
	my ($widget, $status) = @_;
	my %rw_foreground = (	REC  => $gui->{_nama_palette}->{RecForeground},
						 	PLAY => $gui->{_nama_palette}->{MonForeground},
						 	MON => $gui->{_nama_palette}->{MonForeground},
						 	OFF => $gui->{_nama_palette}->{OffForeground},
						);

	my %rw_background =  (	REC  => $gui->{_nama_palette}->{RecBackground},
							PLAY  => $gui->{_nama_palette}->{MonBackground},
						 	MON => $gui->{_nama_palette}->{MonBackground},
							OFF  => $gui->{_nama_palette}->{OffBackground});

	$widget->configure( -background => $rw_background{$status} );
	$widget->configure( -foreground => $rw_foreground{$status} );
}
sub refresh_group { 
	# main group, in this case we want to skip null group
	logsub((caller(0))[3]);
	
	
		my $status;
		if ( 	grep{ $_->rec} 
				map{ $tn{$_} }
				$bn{Main}->tracks ){

			$status = REC

		}elsif(	grep{ $_->play} 
				map{ $tn{$_} }
				$bn{Main}->tracks ){

			$status = PLAY

		}else{ 
		
			$status = OFF }

logit(__LINE__,'Audio::Nama::Refresh','debug', "group status: $status");

	set_widget_color($gui->{group_rw}, $status); 



	croak "some crazy status |$status|\n" if $status !~ m/rec|mon|off/i;
		#logit(__LINE__,'Audio::Nama::Refresh','debug', "attempting to set $status color: ", $take_color{$status});

	set_widget_color( $gui->{group_rw}, $status) if $gui->{group_rw};
}
sub refresh_track {
	
	my $ui = shift;
	my $n = shift;
	logsub((caller(0))[3]);
	
	my $rec_status = $ti{$n}->rec_status;
	logit(__LINE__,'Audio::Nama::Refresh','debug', "track: $n rec_status: $rec_status");

	return unless $gui->{tracks}->{$n}; # hidden track
	
	# set the text for displayed fields

	$gui->{tracks}->{$n}->{rw}->configure(-text => $rec_status);
	$gui->{tracks}->{$n}->{ch_r}->configure( -text => 
				$n > 2
					? $ti{$n}->source
					:  q() );
	$gui->{tracks}->{$n}->{ch_m}->configure( -text => $ti{$n}->send);
	$gui->{tracks}->{$n}->{version}->configure(-text => $ti{$n}->current_version || "");
	
	map{ set_widget_color( 	$gui->{tracks}->{$n}->{$_}, 
							$rec_status)
	} qw(name rw );
	
	set_widget_color( 	$gui->{tracks}->{$n}->{ch_r},
				
 							($rec_status eq REC
								and $n > 2 )
 								? REC
 								: OFF);
	
	set_widget_color( $gui->{tracks}->{$n}->{ch_m},
							$rec_status eq OFF
								? OFF
								: $ti{$n}->send 
									? MON
									: OFF);
}

sub refresh {  
	Audio::Nama::remove_riff_header_stubs();
	map{ $ui->refresh_track($_) } map{$_->n}  Audio::Nama::audio_tracks();
	refresh_waveform_window() if $gui->{wwcanvas};
}
### end


1;

__END__