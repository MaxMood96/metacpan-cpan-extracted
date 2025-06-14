# ------- Jack port connect routines -------
package Audio::Nama;
use v5.36;
use File::Slurp;
no warnings 'uninitialized';

# general functions

sub update_jack_client_list {
	state $warn_count;
	#logsub((caller(0))[3]);
	# cache current JACK status
	
	# skip if Ecasound is busy
	return if $this_engine->started();

	if( $jack->{jackd_running} = process_is_running('jackd') ){
		# reset our clients data 
		$jack->{clients} = {};

		$jack->{use_jacks} 
			?  jacks_get_port_latency() 
			:  parse_port_latency();
		parse_ports_list();

		my ($bufsize) = qx(jack_bufsize);
		($jack->{periodsize}) = $bufsize =~ /(\d+)/;
		my ($sample_rate) = qx(jack_samplerate);
		chomp $sample_rate;
		$project->{name} 
			and $sample_rate != $project->{sample_rate} 
			and ($warn_count == 1 or $warn_count % 8 == 0) # warn less often
		    and Audio::Nama::throw(qq(
JACK audio daemon sample rate is $sample_rate but sample rate for project "$project->{name}" is $project->{sample_rate}.
Please fix this problem before continuing (maybe restart jackd with --rate $project->{sample_rate}?))),
			print prompt();
		$warn_count++;
	} else {  }
}

sub client_port {
	my $name = shift;
$name =~ /(.+?):([^:]+)$/;
=comment
	$name =~ /
				(?<client>.+?)	# anything, non-greedy 
	:							# a colon
				(?<port>[^:]+$) # non-colon stuff to end
	/x;

	@+{qw(client port)}
=cut
$1, $2
}

sub jack_client_array {

	# returns array of ports if client and direction exist
	
	my ($name, $direction)  = @_;
	$jack->{clients}->{$name}{$direction} // []
}

sub jacks_get_port_latency {
	logsub((caller(0))[3]);
	delete $jack->{clients};

my $jc;

$jc = jacks::JsClient->new("watch latency", undef, $jacks::JackNullOption, 0);

my $plist =  $jc->getPortNames(".");

for (my $i = 0; $i < $plist->length(); $i++) {
    my $pname = $plist->get($i);
	my ($client_name,$port_name) = client_port($pname);

	logpkg(__FILE__,__LINE__,'debug',qq(client: $client_name, port: $port_name));

    my $port = $jc->getPort($pname);

	#my @connections = $jc->getAllConnections($client_name, $port_name);
	#say for @connections;

    my $platency = $port->getLatencyRange($jacks::JackPlaybackLatency);
    my $pmin = $platency->min();
    my $pmax = $platency->max();
    logpkg(__FILE__,__LINE__,'debug',"$pname: playback Latency [ $pmin $pmax ]");
	$jack->{clients}->{$client_name}->{$port_name}->{latency}->{playback}->{min} 
		= $pmin;
	$jack->{clients}->{$client_name}->{$port_name}->{latency}->{playback}->{max} 
		= $pmax;

    my $clatency = $port->getLatencyRange($jacks::JackCaptureLatency);
    my $cmin = $clatency->min();
    my $cmax = $clatency->max();
    logpkg(__FILE__,__LINE__,'debug',"$pname: capture Latency [ $cmin $cmax ]");
	$jack->{clients}->{$client_name}->{$port_name}->{latency}->{capture}->{min} 
		= $cmin;
	$jack->{clients}->{$client_name}->{$port_name}->{latency}->{capture}->{max} 
		= $cmax;
}


}

sub parse_port_connections {
	my $j = shift || qx(jack_lsp -c 2> /dev/null); 
	return unless $j;

	# initialize
	$jack->{connections} = {}; 
	
	# convert to single lines
	$j =~ s/\n\s+/ /sg;

	my @lines = split "\n",$j;
	#say for @ports;

	for (@lines){
	
		my ($port, @connections) = split " ", $_;
		#say "$port @connections";
		$jack->{connections}->{$port} = \@connections;
		
	}
}
sub jack_port_to_nama {
	my $jack_port = shift;
	grep{ /$config->{ecasound_jack_client_name}/ and $jack->{is_own_port}->{$_} } @{ $jack->{connections}->{$jack_port} };
}
	
sub parse_port_latency {
	
	# default to use output of jack_lsp -l
	
	my $j = shift || qx(jack_lsp -l 2> /dev/null); 
	logpkg(__FILE__,__LINE__,'debug', "latency input $j");
	
	state $port_latency_re = qr(


							# ecasound:in_1
							
							(?<client>[^:]+)  # non-colon
							:                 # colon
							(?<port>\S+?)     # non-space
							\s+

							# port latency = 2048 frames #  DEPRECATED

							\Qport latency = \E    
							\d+ # don't capture
							\Q frames\E
							\s+

							# port playback latency = [ 0 2048 ] frames

							\Qport playback latency = [ \E
							(?<playback_min>\d+)
							\s+
							(?<playback_max>\d+)
							\Q ] frames\E
							\s+

							# port capture latency = [ 0 2048 ] frames

							\Qport capture latency = [ \E
							(?<capture_min>\d+)
							\s+
							(?<capture_max>\d+)
							\Q ] frames\E

						)x;

	# convert to single lines

	$j =~ s/\n\s+/ /sg;
	
	my @ports = split "\n",$j;
	map
	{

		/$port_latency_re/;

		#logpkg(__FILE__,__LINE__,'debug', Dumper %+);
		logpkg(__FILE__,__LINE__,'debug', "client: ",$+{client});
		logpkg(__FILE__,__LINE__,'debug', "port: ",$+{port});
		logpkg(__FILE__,__LINE__,'debug', "capture min: ", $+{capture_min});
		logpkg(__FILE__,__LINE__,'debug', "capture max: ",$+{capture_max});
		logpkg(__FILE__,__LINE__,'debug', "playback min: ",$+{playback_min});
		logpkg(__FILE__,__LINE__,'debug', "playback max: ",$+{playback_max});
		
		$jack->{clients}->{$+{client}}->{$+{port}}->{latency}->{capture}->{min}
			= $+{capture_min};
		$jack->{clients}->{$+{client}}->{$+{port}}->{latency}->{capture}->{max}
			= $+{capture_max};
		$jack->{clients}->{$+{client}}->{$+{port}}->{latency}->{playback}->{min}
			= $+{playback_min};
		$jack->{clients}->{$+{client}}->{$+{port}}->{latency}->{playback}->{max}
			= $+{playback_max};
		
	} @ports;
	
}


sub parse_ports_list {

	# default to output of jack_lsp -p
	
	logsub((caller(0))[3]);
	my $j = shift || qx(jack_lsp -tp 2> /dev/null); 
	logpkg(__FILE__,__LINE__,'debug', "input: $j");

	# convert to single lines

	$j =~ s/\n\s+/ /sg;

	# system:capture_1 alsa_pcm:capture_1 properties: output,physical,terminal,
	#fluidsynth:left properties: output,
	#fluidsynth:right properties: output,

	map{ 
		my ($direction) = /properties: (input|output)/;
		s/properties:.+//;
		my @port_aliases = /
			\s* 			# zero or more spaces
			([^:]+:[^:]+?) # non-colon string, colon, non-greedy non-colon string
			(?=[-+.\w]+:|\s+$) # zero-width port name or spaces to end-of-string
		/gx; 
		map { 
				s/ $//; # remove trailing space

				# make entries for 'system' and 'system:capture_1'
				push @{ $jack->{clients}->{$_}->{$direction} }, $_;
				my ($client, $port) = /(.+?):(.+)/;
				push @{ $jack->{clients}->{$client}->{$direction} }, $_; 

		 } @port_aliases;

	} 
	grep{ ! /^jack:/i } # skip spurious jackd diagnostic messages
	grep{ ! /8 bit raw midi/ }
	split "\n",$j;
}

# connect jack ports via jack-plumbing or jack_connect

sub jack_plumbing_conf {
	join_path( $ENV{HOME} , '.jack-plumbing' )
}

sub initialize_jack_plumbing_conf {  }

{ my $fh;

my $jack_plumbing_code = sub 
	{
		my ($port1, $port2) = @_;
		my $debug++;
		my $config_line = qq{(connect $port1 $port2)};
		say $fh $config_line; # $fh in lexical scope
		logpkg(__FILE__,__LINE__,'debug', $config_line);
	};
my $jack_connect_code = sub
	{
		my ($port1, $port2) = @_;
		my $debug++;
		my $cmd = qq(jack_connect $port1 $port2);
		logpkg(__FILE__,__LINE__,'debug', $cmd);
		system($cmd) == 0
		   or die "system $cmd failed: $?";

	};
sub connect_jack_ports_list {

	my @source_tracks = 
		grep{ 	$_->source_type eq 'jack_ports_list' and
	  	  		$_->rec
			} Audio::Nama::ChainSetup::engine_tracks();

	my @send_tracks = 
		grep{ $_->send_type eq 'jack_ports_list' } Audio::Nama::ChainSetup::engine_tracks();

	# we need JACK
	return if ! $jack->{jackd_running};

	# We need tracks to configure
	return if ! @source_tracks and ! @send_tracks;

	sleeper(0.3); # extra time for ecasound engine to register JACK ports

	if( $config->{use_jack_plumbing} )
	{

		open($fh, ">", jack_plumbing_conf())
			or die("can't open ".jack_plumbing_conf()." for write: $!");
		make_connections($jack_plumbing_code, \@source_tracks, 'in' );
		make_connections($jack_plumbing_code, \@send_tracks,   'out');
		close $fh; 

		# run jack-plumbing
		start_jack_plumbing();
		sleeper(3); # time for jack-plumbing to launch and poll
		kill_jack_plumbing();
	}
	else 
	{
		make_connections($jack_connect_code, \@source_tracks, 'in' );
		make_connections($jack_connect_code, \@send_tracks,   'out');
	}
}
}
sub quote { $_[0] =~ /^"/ ? $_[0] : qq("$_[0]")}

sub make_connections {
	my ($code, $tracks, $direction) = @_;
	my $ports_list = $direction eq 'in' ? 'source_id' : 'send_id';
	map{  
		my $track = $_; 
 		my $name = $track->name;
 		my $ecasound_port = $config->{ecasound_jack_client_name}.":$name\_$direction\_";
		my $file = join_path(project_root(), $track->$ports_list);
		throw($track->name, 
			": JACK ports file $file not found. No sources connected."), 
			return if ! -e -r $file;
		my $line_number = 0;
		my @lines = read_file($file);
		for my $external_port (@lines){   
			# $external_port is the source port name
			chomp $external_port;
			logpkg(__FILE__,__LINE__,'debug', "port file $file, line $line_number, port $external_port");
			# setup shell command
			
			if(! $jack->{clients}->{$external_port}){
				throw($track->name, 
					qq(: port "$external_port" not found. Skipping.));
				next
			}
		
			# ecasound port index
			
			my $index = $track->width == 1
				?  1 
				: $line_number % $track->width + 1;

		my @ports = map{quote($_)} $external_port, $ecasound_port.$index;

			  $code->(
						$direction eq 'in'
							? @ports
							: reverse @ports
					);
			$line_number++;
		};
 	 } @$tracks
}
sub kill_jack_plumbing {
	qx(killall jack-plumbing >/dev/null 2>&1)
	unless $config->{opts}->{A} or $config->{opts}->{J};
}
sub start_jack_plumbing {
	
	if ( 	$config->{use_jack_plumbing}				# not disabled in namarc
			and ! ($config->{opts}->{J} or $config->{opts}->{A})	# we are not testing   

	){ system('jack-plumbing >/dev/null 2>&1 &') == 0 
			or die "can't run jack-plumbing: $?"
	}
}
sub port_mapping {
	my $jack_port = shift;
	my $own_port;
	#.....
	$own_port
}

sub register_other_ports { 
	return unless $jack->{jackd_running};
	$jack->{is_other_port} = { map{ chomp; $_ => 1 } qx(jack_lsp) } 
}

sub register_own_ports { # distinct from other Nama instances 
	return unless $jack->{jackd_running};
	$jack->{is_own_port} = 
	{ 
		map{chomp; $_ => 1}
		grep{ ! $jack->{is_other_port}->{$_} }
		grep{ /^$config->{ecasound_jack_client_name}/ } 
		qx(jack_lsp)
	} 
}


1;
__END__
	