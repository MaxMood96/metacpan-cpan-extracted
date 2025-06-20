# ---------------------- Bunch -----------------
#
# operate on a list of tracks 

package Audio::Nama;
use v5.36;

sub is_bunch {
	my $name = shift;
	$bn{$name} or $project->{bunch}->{$name}
}

{
my %set_stat = ( 
				 (map{ $_ => 'rw' } qw(rec play mon off) ), 
				 map{ $_ => 'rec_status' } qw(REC PLAY MON OFF )
				 );

sub bunch {
	my ($bunchname, @tracks) = @_;
	if (! $bunchname){
		Audio::Nama::pager(json_out( $project->{bunch} ));
	} elsif (! @tracks){
		$project->{bunch}->{$bunchname} 
			and pager("bunch $bunchname: @{$project->{bunch}->{$bunchname}}\n") 
			or  throw("bunch $bunchname: does not exist.\n");
	} elsif (my @mispelled = grep { ! $tn{$_} and ! $ti{$_}} @tracks){
		Audio::Nama::throw("@mispelled: mispelled track(s), skipping.\n");
	} else {
	$project->{bunch}->{$bunchname} = [ @tracks ];
	}
}
sub add_to_bunch {}

sub bunch_tracks {
	my $bunchy = shift;
	my @tracks;
	if ( my $bus = $bn{$bunchy}){
		@tracks = $bus->tracks;
	} elsif ( $bunchy eq 'bus' ){
		logpkg(__FILE__,__LINE__,'debug', "special bunch: bus");
		@tracks = grep{ ! $bn{$_} } $bn{$this_bus}->tracks;
	} elsif ($bunchy =~ /\s/  # multiple identifiers
		or $tn{$bunchy} 
		or $bunchy !~ /\D/ and $ti{$bunchy}){ 
			logpkg(__FILE__,__LINE__,'debug', "multiple tracks found");
			# verify all tracks are correctly named
			my @track_ids = split " ", $bunchy;
			my @illegal = grep{ ! track_from_name_or_index($_) } @track_ids;
			if ( @illegal ){
				throw("Invalid track ids: @illegal.  Skipping.");
			} else { @tracks = map{ $_->name} 
							   map{ track_from_name_or_index($_)} @track_ids; }

	} elsif ( my $method = $set_stat{$bunchy} ){
		logpkg(__FILE__,__LINE__,'debug', "special bunch: $bunchy, method: $method");
		$bunchy = uc $bunchy;
		@tracks = grep{$tn{$_}->$method eq $bunchy} 
				$bn{$this_bus}->tracks
	} elsif ( $project->{bunch}->{$bunchy} and @tracks = @{$project->{bunch}->{$bunchy}}  ) {
		logpkg(__FILE__,__LINE__,'debug', "bunch tracks: @tracks");
	} else { throw("$bunchy: no matching bunch identifier found") }
	@tracks;
}
}
sub track_from_name_or_index { /\D/ ? $tn{$_[0]} : $ti{$_[0]}  }
1;