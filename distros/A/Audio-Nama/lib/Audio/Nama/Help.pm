# -------------------- Help ----------------------

package Audio::Nama;
use v5.36;

{
no warnings 'uninitialized';
sub helpline {
	my $cmd = shift;
	my $out = "Command: $cmd\n";
	$out .=  "Shortcuts: $text->{commands}->{$cmd}->{short}\n"
			if $text->{commands}->{$cmd}->{short};	
	$out .=  "Category: $text->{commands}->{$cmd}->{type}\n";
	my $what = munge_help($text->{commands}->{$cmd}->{what});
	$out .=  "Description: $what\n";
	$out .=  "Usage: $cmd "; 

	if ( $text->{commands}->{$cmd}->{parameters} 
			&& $text->{commands}->{$cmd}->{parameters} ne 'none' ){
		$out .=  $text->{commands}->{$cmd}->{parameters}
	}
	$out .= "\n";
	my $example = $text->{commands}->{$cmd}->{example};
	$example = munge_help($example);
	#$example =~ s/!n/\n/g;
	if ($example){
		$out .=  "Example: ";
		if ($example =~ /\n/s){
			$example = "\n$example";    # add leading newline
			$example =~ s(\n)(\n    )g; # indent
		}
		$out .=  $example;
		$out .= "\n";
	}
	($/, ucfirst $out, $/);
	
}
sub munge_help {
	my $text = shift;
	$text =~ s/(^\s*)!(\s*#)/$1 $2/mg;
	$text =~ s/(^\s*!)/#/mg;
	$text
}
}
sub helptopic {
	my $i  = shift;
	my $key = $help->{index}->{$i};
	format_help_topic($i, $key);
}

sub format_help_topic {
	my ($index, $key) = @_;
	my $title = $help->{display}->[$index];
	my @output;
	push @output, "\n-- $help->{title}->[$index] --\n\n";
	push @output, $help->{topic}->{$key}, $/;
	@output
}

sub help { 
	my $name = shift;
	$name =~ s/-/_/g;  # help indices require underscores
	chomp $name;
	#print "seeking help for argument: $name\n";
	$text->{iam}->{$name} and pager(<<IAM);

$name is an Ecasound command.  See 'man ecasound-iam'.
IAM
	my @output;
	if ( $help->{topic}->{$name}){
		@output = helptopic($name);
	} elsif ( $name =~ /^(\d+)$/ ){
		@output = helptopic($name)
	} else {
		my %helped = (); 
		my @help = ();
		if ( $text->{commands}->{$name} ){
			push @help, helpline($name);
			$helped{$name}++
		}
		map
		{  
			my $cmd = $_ ;
			if ($cmd =~ /$name/ )
			{
				push @help, helpline($cmd) unless $helped{$cmd}
					or $cmd =~ /-/; # skip hyphenated command forms
									# which lack full help
				$helped{$cmd}++ ;
			}
			no warnings 'uninitialized';
			if ( ! $helped{$cmd} and
					grep{ /$name/ } split " ", $text->{commands}->{$cmd}->{short})
			{
				push @help, helpline($cmd) 
			}
		} keys %{$text->{commands}};

		if ( @help ){ push @output, 
			qq("$name" matches the following commands:\n\n), @help;
		}
	}
	if (@output){
		map{ s/_/-/g } @output;
		Audio::Nama::pager( @output ); 
	} else { throw("$name: no help found.\n"); }
	
}
sub help_effect {
	my ($input, $id, $no_match, @output);
	$id = $input = shift;
	push @output, "\n";

	# e.g. help tap_reverb    
	#      help 2142
	#      help var_chipmunk # preset

	# convert digits to LADSPA label

	if ($id !~ /\D/){ $id = $fx_cache->{ladspa_id_to_label}->{$id} or $no_match++ } 

	# convert ladspa_label to el:ladspa_label
	# convert preset_name  to pn:preset_name
	
	if ($fx_cache->{full_label_to_index}->{$id}){} # we are ready

	elsif ( $fx_cache->{partial_label_to_full}->{$id} ) { $id = $fx_cache->{partial_label_to_full}->{$id} }
	else { $no_match++ }

	# one-line help for Ecasound and chain operators, controllers and presets
	
	if ($id !~ /^(lv2|el):/) {
		push @output, grep{ /$id/  } @{$fx_cache->{user_help}};
	}

	# full help for LADSPA/LV2 plugins
	
	elsif ( $id =~ /el:/  ) { @output = $fx_cache->{ladspa_help}->{$id} }
	elsif ( $id =~ /elv2:/) { @output = $fx_cache->{lv2_help}->{$id}    }

	if( $no_match ){ throw("No effects were found matching: $input\n\n"); }
	else { Audio::Nama::pager(@output) }
}

sub find_effect {
	my @keys = @_;
	#print "keys: @keys\n";
	#my @output;
	my @matches = grep{ 
		my $_help = $_; 
		my $didnt_match;
		map{ $_help =~ /\Q$_\E/i or $didnt_match++ }  @keys;
		! $didnt_match; # select if no cases of non-matching
	} grep{$_} @{$fx_cache->{user_help}};
	if ( @matches ){
	Audio::Nama::pager( $text->{wrap}->paragraphs(@matches) , "\n" );
	} else { throw(join " ", "No effects were found matching:",@keys,"\n\n") }
}

sub parse_midi_help {
	my $h = get_data_section("midi_help");
	my @lines = split $/, $h;
	my $j;
	my $cmd;
	my %acc;
	for (@lines)
	{
	 /(^\w+)/ 
		? ($cmd = $1, $acc{$cmd} = [], $j++)
		: (push @{$acc{$cmd}}, $_ );
	}
	$help->{midish} = \%acc;
	return
}

## Initialization


@{ $help->{arr_topic} } = qw(
project
track_basics
track_status
wav_versions
transport
track_fader
effect_info
effect_manipulation
marks
time_shifting
track_io
inserts
fades
group
bus
mixdown
prompt
normalization
track_caching
effect_chains
effect_profiles
advanced_transport
version_control
diagnostics
edits
advanced
                ) ;
my $i;
my @display_index = map{ $help->{index}->{++$i} = $_;  # integer => topic key
                            s/_/ /g; 
                            my $name = ucfirst $_; 
                            $help->{title}->[$i] = $name;
                            $name = join " ",$i, $name;
                            $help->{display}->[$i] = $name;
                            } @{ $help->{arr_topic} };
sub pad {
    my ($text, $len) = @_;
    my $pad = ' ' x ( $len - length $text);
    $text.$pad
}
my @twocolumn = map{ pad($display_index[$_], 22).$display_index[$_+13].$/ } 0..12;


%{ $help->{topic} }  = (

help => <<HELP,
   help <command>       - show help for <command>
   help <fragment>      - show help for commands matching /<fragment>/
   help <ladspa_id>     - info on a LADSPA id
   help <topic_number>  - list commands under <topic_number> 
HELP

project => <<'PROJECT',
   load-project, load      - load an existing project, e.g 'load <project-name>'
   create-project, create  - create a new project (usually under $HOME/nama/project-name/)
   list-projects, lp       - list all projects
   undo                    - go back in time to the state before the last command
   redo                    - reapply the step rolled back by undo
   exit, quit              - exit program, saving state 


PROJECT

track_basics => <<'TRACKBASICS',
   add-track, add          - Create a new track

      Example: add sax     - Add a new track 'sax', mono by default.
                           - Sax is selected, and receives next commands.
               source 3    - Use soundcard channel 3 as input
               rec         - Arm for recording an audio file (e.g. sax_1.wav)
               start       - Start engine, begin recording
               stop        - Stop engine, close file and queue for playback
     
               <SPACE> can be used at the prompt to start and stop engine
   
      Example: add piano; source synth; stereo; rec
   
      This line of commands prepares to record track 'piano' in stereo 
      width from JACK client 'synth'. Use of semicolons allow several 
      commands in one line of input.

   import-audio, import    - Import a .wav file, resampling if necessary
   remove-track            - Remove effects, parameters and GUI for current track
TRACKBASICS

track_status => <<'TRACKSTATUS',

Prepare conditions for next engine run

   rec              -  REC: record and monitor audio source
   mon              -  MON: monitor audio source
   play             -  PLAY: queue .wav file for playback
   off              -  OFF: omit track from audio network
   show-tracks,show - show status, all tracks
   show-track,sh    - show status of current track, including effects, versions, etc.
   chains           - show the audio network configuration
TRACKSTATUS


wav_versions => <<'WAV_VERSIONS',
   list-version, lver       - list version numbers of audio files in the current track
                            - (this information also appears in the show-track listing)
   set-version, version, n  - select a version number for the current track

A track can record multiple audio files ('takes'). The audio filenames
follow the trackname so that recording a track named 'piano' will
produce files with names with names like piano_1.wav, piano_2.wav.
Audio files recorded by Nama are considered immutable resources and
stored outside of version control.

One version can be selected as streaming source when when the track is
set to PLAY. The version number is zero by default, which means
select the most recent (highest numbered) take. The bus-version command
will set default version number for all tracks belonging to the current 
bus.
WAV_VERSIONS

transport => <<TRANSPORT,
   start, t, SPACE    -  Start processing. SPACE must be at beginning of command line.
   stop, s, SPACE     -  Stop processing. SPACE must be at beginning of command line.
   rewind, rw         -  Rewind  some number of seconds, i.e. rw 15
   forward, fw        -  Forward some number of seconds, i.e. fw 75
   setpos, sp         -  Set the playback head position, i.e. setpos 49.2
   getpos, gp         -  Get the current head position 
   jump-to-start, beg   - set playback head to beginning of audio file(s)
   jump-to-end, end     - set playback head to end
TRANSPORT
track_fader => <<'TRACKFADER',
   Track volume/pan fader can be used to change settings for the current track.

   pan, p                   -  get/set pan position
   pan-back, pb             -  restore pan after pr/pl/pc  
   pan-center, pc           -  set pan center    
   pan-left, pl             -  pan track fully left    
   pan-right, pr            -  pan track fully right    
   volume, vol              -  set or adjust track volume (in dB)
       Examples:
       vol 0   (set level to 0 dB or unity gain)
       vol -20 (set level to -20 dB)
       vol - 3 (reduce vol by 3 dB) 
                                      
   unity                    -  set volume gain to unity
   mute, c, cut             -  mute track volume 
   unmute, nomute, uncut, C -  restore muted volume
   solo                     -  mute all tracks but current track
   all, nosolo              -  return to pre-solo status
TRACKFADER
effect_info => <<'EFFECT_INFO',
   ladspa-register, lrg     - list LADSPA effects
   preset-register, prg     - list Ecasound presets
   ctrl-register, crg       - list Ecasound controllers 
   find-effect, fe          - list available effects matching arguments
                              example: find-effect reverb
   help-effect, he          - full information about an effect 
                              example: help-effect 1209 
                                (information about LADSPA plugin 1209)
                              example: help-effect valve
                                (information about LADSPA plugin valve)
EFFECT_INFO
effect_manipulation => <<'EFFECT_DO',
   add-effect,     afx           - add an effect to the current track
                                   Example: afx ea 50
   add-controller, acl           - add an Ecasound controller to the parameter
                                   of an effect  
   insert-effect,  ifx           - insert an effect before another effect
   modify-effect,  mfx           - set, increment or decrement effect parameter
   remove-effect,  rfx           - remove an effect or controller
   append-effect,  apfx          - add effect to the end of current track effect list 
   bypass-effects, bypass, bye   - suspend current track effects except vol/pan
   restore-effects, restore, ref - restore track effects
EFFECT_DO

marks => <<MARKS,
   new-mark,      mark, k     - drop mark at current position, with optional name
   list-marks,    lmk,  lm    - list marks showing index, time, name
   next-mark,     nmk,  nm    - jump to next mark 
   previous-mark, pmk,  pm    - jump to previous mark 
   name-mark,           nom   - give a name to current mark 
   to-mark,       tmk,  tom   - jump to a mark by name or index
   remove-mark,   rmk,  rom   - remove current mark
   modify-mark, move-mark, 
    mmk, mm                   - change the time setting of current mark

Marks belong to the overall timeline, not to a particular track.
They do not move when a track is time-shifted.  Many commands
that can take time positions as as arguments can also take mark
names. This has the advantage that the time of effect will
change when the mark is adjusted.  
MARKS

time_shifting => <<'TIME_SHIFTING',
   Regions and time shifting

   set-region,    srg      - specify a track region using times or mark names
   add-region,    arg      - define a region creating an auxiliary track
   remove-region, rrg      - remove auxiliary track or region definition
   shift-track,   shift    - set playback delay for track/region
   unshift-track, unshift  - eliminate playback delay for track/region
TIME_SHIFTING

track_io => <<'TRACKIO',
   Track inputs and outputs are set by source and send commands, 
   which take similar arguments. 

   source, src, r            -  set track source
                             -  with no arguments returns current signal source

    ----------------------------------------------------------
    for this input              use this command
    ----------------------------------------------------------

     * soundcard channel 3      source 3 

     * soundcard channels 3,4   source 3; stereo

     * JACK client              source fluidsynth
     
     * JACK port                source fluidsynth:left
  
     * JACK port with spaces    source "MPlayer [20120]:out_0"
 
     * unconnected JACK port    source manual
     
       note: the port for mono track 'piano' would be ecasound:piano_in_1

     * A list of JACK ports     source drum.ports (ports list from file drums.ports)
                                source ports (ports list from file <trackname>.ports)

     * from another track (after effects processing)
                                source track Strings
     * from a bus (raw output)  source bus Strings
     
     * from another track (before effects processing)
                                source loop sax_in

    -----------------------------------------------------------

   send, out, m, aux         -  Create an auxiliary send
                                Same arguments as 'source'.
                                One send is allowed per track.

   Sends are not necessary to set up as most tracks are part
   of a bus that routes the audio output. 
TRACKIO
inserts => <<'INSERTS',

Use inserts to pass an audio stream through an external effect
such as a JACK client or an analog fx box hooked to
your soundcard. 

   add-insert,         ain    - add an insert to current track
   remove-insert,      rin    - remove an insert from current track
   set-insert-wetness, wet    - set/query insert wetness 
                                example: wet 99 (99% wet, 1% dry)
INSERTS
fades => <<FADES,
   add-fade,         afd, fade  - add fade (in or out) to current track
                                  examples: 
                                      fade in song-start 0.2
                                  (fades in at mark 'song-start' over 0.2 s)
                                      fade out 0.5 song-start
                                  (fades out over 0.5 s ending at 'song-start')
                                  
   remove-fade,      rfd        - remove fade (by index)
   list-fade         lfd        - list all fades
FADES

group => <<GROUP,
Group control
   new-bunch, bunch, nb       - name a bunch of tracks
                                e.g. bunch strings violins cello bass
                                e.g. bunch 3 4 6 7 (track indexes)
   list-bunches,     lb       - list groups of tracks (bunches)
   remove-bunches,   rb       - remove bunch definitions

   for                   - execute commands on several tracks 
                           by name, or by specifying a group or bunch
                           example: for strings; vol +10
                           example: for drumkit congas; mute
                           example: for 3 5; vol * 1.5
                           example: for Main; version 5;; show
                            (operates on all tracks in bus Main,
                            commands following ';;' execute only once)
                           example: for bus; version 5
                            (operates on tracks in current bus)
                           example: for rec; off
                            (operates on tracks in current bus set to 'rec')
                           example: for OFF; off
                            (operates on tracks in current bus w/status OFF)
GROUP

bus => <<BUS,
   add-bus, abs         - create a sub-bus feeding a regular user track
                          of the same name
                          example: add-bus Strings 
                                   add-tracks violin cello bass
                                   for cello violin bass; move-to-bus Strings
   list-buses, lbs      - list bus data
   remove-bus           - remove a bus
   bus-version          - select default .wav version for all tracks on bus
   bus-off              - set all tracks belonging to bus to OFF
   bus-on               - restore bus tracks to status at previous bus-off
BUS

mixdown => <<MIXDOWN,
   mixdown,    mxd             - enable mixdown 
   mixoff,     mxo             - disable mixdown 
   mixplay,    mxp             - playback a recorded mix 
   automix                     - normalize track vol levels, then mixdown
   master-on,  mr              - enter mastering mode
   master-off, mro             - leave mastering mode
MIXDOWN

prompt => <<PROMPT,
   The prompt displays the name of the project and currently selected track and
   bus (if other than Main.)

   nama allegro violin / Strings > 

   At the command prompt, you can enter several types
   of commands:

   Type                        Example
   ------------------------------------------------------------
   Nama commands               load somesong
   Ecasound commands           cs-is-valid
   Shell expressions           ! ls
   Perl code                   eval 2*3     # prints '6'

   Many commands in Nama operate on the currently selected track or 'current track'. 
   track name or number to a command sets the current track before the command
   executes.  For example, to mute the volume for a track called 'sax', you could
   say 'sax mute', or even something like '4 mute'. Using the track number
   can be convenient when executing commands on multiple tracks as 'for 4 5 6; unmute'

PROMPT

normalization => <<'NORMAL',
Normalization

   ecanormalize, normalize, norm 
                           - run ecanormalize on current track version
   ecafixdc, fixdc         - run ecafixdc on current track version
   autofix-tracks, autofix - fixdc and normalize selected versions of all PLAY
NORMAL

track_caching => <<'CACHING',
Track caching (freezing) - render effects to a new .wav file to fix a result and save cpu

   cache                       - cache the output of a track or bus as a .wav file
   uncache                     - restore effects and settings prior to cache operation
CACHING

effect_chains => <<'EFFECT_CHAINS',

Effect chains are presets that can consist of multiple effects. They are a
convenient way to save by name sequences of effects with the parameters that
you commonly use. You make an effect chain by saving effects from the current
track. 

   find-effect-chains,     fec   - find all effect chains (filtering on key/value pairs, if supplied)
   find-user-effect-chains,fuec  - find all user-defined effect chains, filtering as above
   new-effect-chain,       nec   - define a new effect chain
   overwrite-effect-chain, oec   - as above, but overwite existing definition
   add-effect-chain,       aec   - add an effect chain to the current track
   delete-effect-chain,    dec   - delete an effect chain definition
EFFECT_CHAINS

effect_profiles => <<'EFFECT_PROFILES',
Effect profiles (effect chains for a group of tracks)

An effect profile is a group of effect chains, saved with the tracks that
configure them. It is a convenient way to share parts of a project among other
projects. 

   new-effect-profile, nep       - define a new effect profile
   apply-effect-profile, aep     - apply an effect profile
                                   (current effects are bypassed)
   overlay-effect-profile, oep   - apply an effect profile,
                                   adding to current effects
   delete-effect-profile, dep    - delete an effect profile definition
EFFECT_PROFILES

advanced_transport => <<'ADVANCED_TRANSPORT',
   loop-enable, loop  -  loop playback between two points
                         example: loop 5.0 200.0 (positions in seconds)
                         example: loop start end (mark names or numbers)
   loop-disable, noloop, nl
                      -  disable looping

   preview            -  start engine with WAV recording disabled
                         (for mic check, etc.) Release with 'arm'.

   doodle             -  Like preview, with WAV playback also disabled
                         Release with 'arm'.
ADVANCED_TRANSPORT

version_control => <<'VCS',
** Version control 

Nama uses git to save project state as a series of commits, a new commit after
each command. It is easy to tag a commit as a way of documenting
developments in a projects. 

   save <tagname>            - label current snapshot as <tagname>
   get <tagname>             - checkout project state tagged with <tagname>
   branch <tagname>          - switch to branch and load state
   list-branches, lbr        - list branches and tags
   new-branch, nbr           - create a new branch starting at the current 
                               commit or a specified commit, e.g. 'nbr <tagname>'
   tag                       - tag current commit with a name and optional message

   ** note that <tagname> can be a branch, tag, commit id.  
VCS
diagnostics => <<DIAGNOSTICS,

   dump-all,   dumpall,   dumpa - dump most internal state
   dump-track, dumpt,     dump  - dump current track data
   dump-group, dumpgroup, dumpg - dump group settings for user tracks
   show-io,    showio           - show chain inputs and outputs
   engine-status, egs           - display ecasound audio processing engine
                                   status
DIAGNOSTICS

edits => <<EDITS,

-  general

   list-edits,       led        - list edits
   new-edit,         ned        - create new edit for current track and version
   select-edit,      sed        - choose an edit to modify, becomes current edit
   end-edit-mode,    eem        - track plays full length
   disable-edits,    ded        - disable edits for current track
   destroy-edit                 - remove all WAV files and data for current edit
   
-  edit marks

   set-edit-points,  sep        - mark play start, rec start and rec end 

   play-start-mark,  psm        - select and move to play start mark
   rec-start-mark,   rsm        - select and move to rec start mark
   red-end-mark,     rem        - select and move to rec end mark

   set-play-start-mark, spsm    - set mark to current position
   set-rec-start-mark,  srsm    - set mark to current position
   set-rec-end-mark,    srem    - set mark to current position

-  preview edit segment

   preview-edit-in   pei        - preview track with edit segment removed
   preview-edit-out  peo        - preview edit segment to be removed

-  record/play edit

   record-edit       red        - record a WAV file for current edit
   play-edit         ped        - play a completed edit

-  select edit related tracks

   edit-track,       et         - set edit track as current track
   edit-track,       et         - set edit track as current track
   host-track,       ht         - set host track alias as current track
   host-track-alias, hta        - set host track alias as current track
   version-mix-track,vmt        - set version mix track as current track 
EDITS


advanced => <<'ADVANCED',

   set-track               - directly set current track parameters

   destroy-current-wav     - unlink current track's selected WAV version.
ADVANCED

   
);
# print values %{$help->{topic}};

$help->{screen} = <<HELP.

Welcome to Nama help

The help command ('help', 'h') can take several arguments.

help <command>          - show help for <command>
help <fragment>         - show help for all commands matching /<fragment>/
help <topic_number>     - list commands under topic <topic_number> below
help yml                - browse the YAML command source

help is available for the following topics:

HELP
join '',@twocolumn;


1;