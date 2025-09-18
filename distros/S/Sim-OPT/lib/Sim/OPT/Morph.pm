#package Sim::OPT::Morph;
# Copyright (C) 2008-2025 by Gian Luca Brunetti and Politecnico di Milano.
# This is the module Sim::OPT::Morph of Sim::OPT.
# This is free software.  You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

# use v5.14;
use Exporter;
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
use Math::Trig;
use Math::Round;
use List::Util qw[ min max reduce shuffle];
use List::MoreUtils qw(uniq);
use List::AllUtils qw(sum);
use Statistics::Basic qw(:all);
use Set::Intersection;
use List::Compare;
use IO::Tee;
use Storable qw(dclone);
use File::Copy qw( move copy );
use Data::Dumper;


use Sim::OPT;
use Sim::OPT::Sim;
use Sim::OPT::Report;
use Sim::OPT::Descend;
use Sim::OPT::Takechance;

use Data::Dump qw(dump);
use feature 'say';

no strict;
no warnings;
@ISA = qw( Exporter );


our @EXPORT = qw(
morph translate translate_surfaces_simple translate_surfaces rotate_surface translate_vertices shift_vertices rotate
rotatez make_generic_change reassign_construction change_thickness
recalculateish daylightcalc daylightcalc_other change_config checkfile change_climate recalculatenet apply_constraints
reshape_windows warp use_modish export_toenergyplus genchange genprop change_groundreflectance constrain_geometry
read_geometry read_geo_constraints apply_geo_constraints vary_controls
calc_newctl checkfile constrain_controls read_controls read_control_constraints apply_loopcontrol_changes
apply_flowcontrol_changes constrain_obstructions read_obstructions read_obs_constraints apply_obs_constraints
vary_net read_net apply_node_changes readobsfile obs_modify
decreasearray deg2rad_ rad2deg_ purifyarray replace_nth rotate2dabs rotate2d rotate3d fixlength purifydata
gatherseparators supercleanarray modish $max_processes @weighttransforms rebuildconstr
); # our @EXPORT = qw( );

$VERSION = '0.165'; # our $VERSION = '';
$ABSTRACT = 'Sim::OPT::Morph is a morphing program for performing parametric variations on model for simulation programs.';

################################################# MORPH


sub getnear
{
	my ( $missing, $carrier_r, $countcase ) = @_;

	my %carrier = %{ $carrier_r };
	my ( @indices, @numfrom, @numto );
	my @missings = split( "_|-", $missing );

	foreach my $key (sort {$a <=> $b} (keys %carrier ) )
	{
	  push( @indices, $key );
		push( @numfrom, $carrier{$key} );
	}

	$c = 0;
	foreach my $el ( @missings )
	{
		if ( Sim::OPT::odd( $c ) )
		{
			push ( @numto, $el );
		}
		$c++;
	}

	my ( @numchanges, @diffchanges );
	my $c = 0;
	foreach my $el ( @numto )
	{
		if ( not ( $el eq "$numfrom[$c]" ) )
		{
			push ( @numchanges,  $el );
		}
		elsif ( $el eq "$numfrom[$c]" )
		{
			push ( @numchanges, "x" );
		}
		$c++;
	}

	my ( @nummix, @countvrs, @countsteps );
	my $c = 0;
  foreach my $el ( @numchanges )
	{
		unless ( $el eq "x" )
		{
			my $cn = 0;
			foreach ( @numfrom )
			{
				splice ( @numfrom, $c, 1, $el );
			}
      push ( @countsteps, $el );
			push ( @nummix, [ @numfrom ] );
			push ( @countvrs, $indices[$c] );
      $cn++
		}
		$c++
	}

	my ( @box );
	foreach my $elt_r ( @nummix )
	{
		my $line = "";
		my @elts = @{ $elt_r };
		my $count = 0;
		foreach my $elt ( @elts )
		{
      $line = $line . $indices[$count] . "-" . $elt . "_";
			$count++;
		}
		chop $line;
    push ( @box, $line );
	}

	return( \@box, \@countvrs, \@countsteps );
}


sub cleaninst
{
	my %inst = @_;
	my %pure;
	foreach my $key ( keys %inst )
	{
		unless ( $key eq "" )
		{

		}
	}
}


sub giveback
{
  my %mids = %{ $_[0] };

  my $string;
  foreach my $key ( sort { $a <=> $b } ( keys %mids ) )
  {

    $string = $string . $key . "-" . $mids{$key} . "_";
  }
  $string =~ s/_$// ;
  return( $string );
}


sub setpickedinsts
{
	my ( $instances_ref, $inst_ref, $dirfiles_ref ) = @_;
	my @instances = @{ $instances_ref };
	my %inst = %{ $inst_ref };
	my %dirfiles = %{ $dirfiles_ref };

	my @newinstances;


	my $countinst = 0;
	foreach my $instance ( @instances )
	{
		my %d = %{ $instance };
		my $countcase = $d{countcase};
		my $countblock = $d{countblock};
		my @miditers = @{ $d{miditers} };
		my $countvar = $d{countvar};
		my $countstep = $d{countstep};
		my @sweeps = @{ $d{sweeps} };
		my @sourcesweeps = @{ $d{sourcesweeps} };
		my @blockelts = @{ $d{blockelts} };
		my @blocks = @{ $d{blocks} };
		my $origin = $d{origin};
		my %to = %{ $d{to} };
		my %orig = %{ $d{orig} };
		my $from = $origin;
		my %varnums = %{ $d{varnums} };
		my %mids = %{ $d{mids} };
		my %carrier = %{ $d{carrier} };
		my $varnumber = $countvar;
		my $stepsvar = $varnums{$countvar};
		my $is;
		my @addinsts;

		my $missing = $origin;
		my ( $box_ref, $countvrs_ref, $countsteps_ref  ) = getnear( $missing, \%mids, $countcase );
		my @addinsts = @{ $box_ref };
		my @countvrs = @{ $countvrs_ref };
		my @countsteps = @{ $countsteps_ref };

		if ( scalar( @addinsts ) > 0 )
		{
			my $cn = 0;
			foreach $addinst ( @addinsts )
			{
				my $countvar = $countvrs[$cn];
				my $countstep = $countsteps[$cn];
				$is = $addinst;
				my %to = %{ Sim::OPT::extractcase( \%inst, \%dowhat, $is, \%carrier, $file, \@blockelts, $mypath ) };

				my ( %orig, @whatto );

				if ( $cn == 0 )
				{
					$origin = giveback ( \%mids );
					%orig = %{ Sim::OPT::extractcase( \%inst, \%dowhat, $origin, \%carrier, $file, \@blockelts, $mypath, "" ) };

					push ( @whatto, "begin" );
				}

				if ( $cn > 0 )
				{
					push ( @whatto, "transition" );
					$origin = $addinsts[$cn-1];
					%orig = %{ Sim::OPT::extractcase( \%inst, \%dowhat, $origin, \%carrier, $file, \@blockelts, $mypath, "" ) };
				}

				if ( $cn == $#addinsts )
				{
					push ( @whatto, "end" );
					%orig = %{ Sim::OPT::extractcase( \%inst, \%dowhat, $origin, \%carrier, $file, \@blockelts, $mypath, "" ) };
				}

				my %i = %{ $inst_ref };
				my %inst = $i{inst};
				my %to = %{ $inst{to} };
				my %orig = %{ $inst{orig} };

				#my $crypto = int( ( scalar( keys %inst ) ) / 5 * 6 );
				#my $cryptor = $crypto + 1;

				my $crypto = Sim::OPT::encrypt1( $is ); say RELATE "in setpickinst \$crypto " .dump ( \$crypto );
		    my $cryptor = Sim::OPT::encrypt1( $origin ); say RELATE "in setpickinst \$cryptor " .dump ( \$cryptor );

		    $to{to} = "$mypath/$file" . "_" . "$is";  say RELATE "A in setpickinst \$to{to} " .dump ( $to{to} );
		    $to{cleanto} = "$is"; say RELATE "B in setpickinst \$to{cleanto} " .dump ( $to{cleanto} );
		    $orig{to} = "$mypath/$file" . "_" . "$origin"; say RELATE "C in setpickinst \$orig{to} " .dump ( $orig{to} );
		    $orig{cleanto} = "$origin"; say RELATE "D in setpickinst \$orig{cleanto} " .dump ( $orig{cleanto} );

		    if ( $dowhat{names} eq "long" )
		    {
		      $to{crypto} = "$mypath/$file" . "_" . "$crypto";  ###DDD!!! FINISH THIS.
		      $to{cleancrypto} = $crypto;  ###DDD!!! FINISH THIS.
		      $orig{crypto} = "$mypath/$file" . "_" . "$cryptor";  ###DDD!!! FINISH THIS.
		      $orig{cleancrypto} = $cryptor; ###DDD!!! FINISH THIS.
		    }

		    if ( $dowhat{names} eq "short" )
		    {

		      $to{crypto} = $to{to};  ### TAKE CARE!!! REASSIGNIMENT!!!
		      $to{cleancrypto} = $to{cleanto}; ### TAKE CARE!!! REASSIGNIMENT!!!
		      $orig{crypto} = $orig{to}; ### TAKE CARE!!! REASSIGNIMENT!!!
		      $orig{cleancrypto} = $orig{cleanto}; ### TAKE CARE!!! REASSIGNIMENT!!!
		    }

				#say $tee "HERE : \$countinst: $countinst, \$cn $cn, \$addinst: $addinst, \$origin: $origin, \$is: $is, \%to: " . dump( \%to ) . "\%orig: " . dump( \%orig );
				push( @newinstances,
				{
					countcase => $countcase, countblock => $countblock,
					miditers => \@miditers,  winneritems => \@winneritems, c => $c, from => $from,
					to => \%to, countvar => $countvar, countstep => $countstep,
					sweeps => \@sweeps, dowhat => \%dowhat, orig => \%orig,
					sourcesweeps => \@sourcesweeps, datastruc => \%datastruc,
					varnumbers => \@varnumbers, blocks => \@blocks,
					blockelts => \@blockelts, mids => \%mids, varnums => \%varnums,
					countinstance => $count, carrier => \%carrier, origin => $origin,
					instn => $instn, is => $is, vehicles => \%vehicles,
					mypath => $mypath, file => $file, whatto => \@whatto,
				} );

				$cn++;
			}
		}
		else
		{
			push( @newinstances, $instance );
		}
	}
	#say $tee "IN MORPH PRINT NEWINSTANCES scalar " . scalar( @newinstances ) . dump ( @newinstances );

	@instances = @newinstances; # REASSIGNMENT!!!!!!
	#say $tee "GOING TO GIVE INSTANCES: " .dump( @instances );
	#say $tee "AND HAD INST: " .dump( \%inst );
	my (  $newinstnames_r, $newinst_r ) = Sim::OPT::filterinsts_winsts( \@instances, \%inst );
	%inst = %{ $newinst_r }; # REASSIGNMENT!!!!!!
	my @newinstnames = @{ $newinstnames_r };
	push( @{ $dirfiles{dones} }, @newinstnames );
	@{ $dirfiles{dones} } = uniq ( @{ $dirfiles{dones} } );

	#say $tee "NEWINST: " . dump( %inst );
	#say $tee "IN MORPH PRINT INSTANCES AFTER " . scalar( @instances ) . dump ( @instances );

	$countinst++;

	return( \@instances, \%inst, \%dirfiles );
}


sub setpickinst
{
  my ( $missing, $mids_r, $countcase, $baseinsts_r, $dowhat_r ) = @_;
  my %mids = %{ $mids_r };
  my @baseinsts = @{ $baseinsts_r }; say RELATE "IN setpickinst baseinsts " .dump ( @baseinsts );
	my $ins_r = pop( @baseinsts );
	my %b = %{ $ins_r };

	my %dowhat = %{ $dowhat_r }; #say "IN setpickinst \%dowhat " .dump ( %dowhat );

  #my %b = %{ $baseinsts[0] }; say RELATE "IN setpickinst baseinsts " .dump ( \%b );
  my $countblock = $b{countblock};
  my @miditers = @{ $b{miditers} }; say RELATE "IN setpickinst \@miditers " .dump ( @miditers );
  my @sweeps = @{ $b{sweeps} };
  my @sourcesweeps = @{ $b{sourcesweeps} };
  my @varnumbers = @{ $b{varnumbers} };
  my @blocks = @{ $b{blocks} };  say RELATE "IN setpickinst \@blocks " .dump ( @blocks );
  my @blockelts = @{ $b{blockelts} }; say RELATE "IN setpickinst \@blockelts " .dump ( @blockelts );
  my %varnums = %{ $b{varnums} };
  my %carrier = %{ $b{carrier} };
  my $stamp = Sim::OPT::encrypt1( $missing );

  $mypath = $dowhat{mypath}; say RELATE "IN setpickinst \$mypath " .dump ( \$mypath ); say "IN setpickinst \$mypath " .dump ( $mypath );
  $file = $dowhat{file}; say RELATE "IN setpickinst \$file " .dump ( \$file );

	say RELATE "\nMISSING: $missing";
	say RELATE "\%mids: " . dump( \%mids );

	my ( $box_ref, $countvrs_ref, $countsteps_ref  ) = getnear( $missing, \%mids );
	my @addinsts = @{ $box_ref }; say RELATE "in setpickinst PRODUCING \@addinsts" . dump( @addinsts );
	my @countvrs = @{ $countvrs_ref }; say RELATE "in setpickinst PRODUCING \@countvrs" . dump( @countvrs );
	my @countsteps = @{ $countsteps_ref }; say RELATE "in setpickinst PRODUCING \@countsteps" . dump( @countsteps );
  my $countvar;
  my $countstep;


	if ( scalar( @addinsts ) > 0 )
	{
		my $cn = 0;
		foreach $addinst ( @addinsts )
		{
			$countvar = $countvrs[$cn];
			$countstep = $countsteps[$cn];
      my ( $is, %origin, %to, %orig);
			$is = $addinst;

      $to{to} = "$mypath/$file" . "_" . "$is";  say RELATE "A in setpickinst \$to{to} " .dump ( $to{to} );
      $to{cleanto} = "$is"; say RELATE "B in setpickinst \$to{cleanto} " .dump ( $to{cleanto} );

			my ( @whatto );

			if ( $cn == 0 )
			{
				$origin = Sim::OPT::Morph::giveback ( \%mids );
				push ( @whatto, "begin" );
			}

			if ( $cn > 0 )
			{
				push ( @whatto, "transition" );
				$origin = $addinsts[$cn-1];
			}

			if ( $cn == $#addinsts )
			{
				push ( @whatto, "end" );
        $origin = $addinsts[$cn-1];
			}

      $orig{to} = "$mypath/$file" . "_" . "$origin"; say RELATE "C in setpickinst \$orig{to} " .dump ( $orig{to} );
      $orig{cleanto} = "$origin"; say RELATE "D in setpickinst \$orig{cleanto} " .dump ( $orig{cleanto} );

			say RELATE "in setpickinst : \$countinst: $countinst, \$cn $cn, \$addinst: $addinst, \$origin: $origin, \$is: $is, \%to: " . dump( \%to ) . "\%orig: " . dump( \%orig );

			my $crypto = Sim::OPT::encrypt1( $is ); say RELATE "in setpickinst \$crypto " .dump ( \$crypto );
	    my $cryptor = Sim::OPT::encrypt1( $origin ); say RELATE "in setpickinst \$cryptor " .dump ( \$cryptor );


	    if ( $dowhat{names} eq "long" )
	    {
	      $to{crypto} = "$mypath/$file" . "_" . "$crypto";  ###DDD!!! FINISH THIS.
	      $to{cleancrypto} = $crypto;  ###DDD!!! FINISH THIS.
	      $orig{crypto} = "$mypath/$file" . "_" . "$cryptor";  ###DDD!!! FINISH THIS.
	      $orig{cleancrypto} = $cryptor; ###DDD!!! FINISH THIS.
	    }

	    if ( $dowhat{names} eq "short" )
	    {

	      $to{crypto} = $to{to};  ### TAKE CARE!!! REASSIGNIMENT!!!
	      $to{cleancrypto} = $to{cleanto}; ### TAKE CARE!!! REASSIGNIMENT!!!
	      $orig{crypto} = $orig{to}; ### TAKE CARE!!! REASSIGNIMENT!!!
	      $orig{cleancrypto} = $orig{cleanto}; ### TAKE CARE!!! REASSIGNIMENT!!!
	    }

      if ( $cn < $#addinsts )
      {
				push( @newinstances,
  			{
  				countcase => $countcase, countblock => $countblock,
  				miditers => \@miditers,  winneritems => \@winneritems, c => $c, from => $from,
  				to => \%to, countvar => $countvar, countstep => $countstep,
  				sweeps => \@sweeps, orig => \%orig,
  				sourcesweeps => \@sourcesweeps, datastruc => \%datastruc,
  				varnumbers => \@varnumbers, blocks => \@blocks,
  				blockelts => \@blockelts, mids => \%mids, varnums => \%varnums,
  				countinstance => $cn, carrier => \%mids, origin => $origin,
  				instn => $cn, is => $is, vehicles => \%vehicles,
  				mypath => $mypath, file => $file, whatto => \@whatto,
          fire => "no", from => $origin, gaproc => "yes", stamp => $stamp,
  			} );
      }
      else
      {
				push( @newinstances,
        {
  				countcase => $countcase, countblock => $countblock,
  				miditers => \@miditers,  winneritems => \@winneritems, c => $c, from => $from,
  				to => \%to, countvar => $countvar, countstep => $countstep,
  				sweeps => \@sweeps, orig => \%orig,
  				sourcesweeps => \@sourcesweeps, datastruc => \%datastruc,
  				varnumbers => \@varnumbers, blocks => \@blocks,
  				blockelts => \@blockelts, mids => \%mids, varnums => \%varnums,
  				countinstance => $cn, carrier => \%mids, origin => $origin,
  				instn => $cn, is => $is, vehicles => \%vehicles,
  				mypath => $mypath, file => $file, whatto => \@whatto,
          fire => "yes", from => $origin, gaproc => "yes", stamp => $stamp,
				} );
      }
			$cn++;
		}
	}
  else
	{
		$countvar = $countvrs[$cn];
		$countstep = $countsteps[$cn];
		$is = $addinst;

		my ( %orig, @whatto );
		$origin = Sim::OPT::Morph::giveback ( \%mids );
    push ( @whatto, "end" );

		say RELATE "in setpickother : \$countinst: $countinst, \$cn $cn, \$addinst: $addinst, \$origin: $origin, \$is: $is, \%to: " . dump( \%to ) . "\%orig: " . dump( \%orig );

    my $crypto = Sim::OPT::encrypt1( $is ); say RELATE "in setpickinst \$crypto " .dump ( \$crypto );
    my $cryptor = Sim::OPT::encrypt1( $origin ); say RELATE "in setpickinst \$cryptor " .dump ( \$cryptor );

    $to{to} = "$mypath/$file" . "_" . "$is";  say RELATE "A in setpickinst \$to{to} " .dump ( $to{to} );
    $to{cleanto} = "$is"; say RELATE "B in setpickinst \$to{cleanto} " .dump ( $to{cleanto} );
    $orig{to} = "$mypath/$file" . "_" . "$origin"; say RELATE "C in setpickinst \$orig{to} " .dump ( $orig{to} );
    $orig{cleanto} = "$origin"; say RELATE "D in setpickinst \$orig{cleanto} " .dump ( $orig{cleanto} );

    if ( $dowhat{names} eq "long" )
    {
      $to{crypto} = "$mypath/$file" . "_" . "$crypto";  ###DDD!!! FINISH THIS.
      $to{cleancrypto} = $crypto;  ###DDD!!! FINISH THIS.
      $orig{crypto} = "$mypath/$file" . "_" . "$cryptor";  ###DDD!!! FINISH THIS.
      $orig{cleancrypto} = $cryptor; ###DDD!!! FINISH THIS.
    }

    if ( $dowhat{names} eq "short" )
    {

      $to{crypto} = $to{to};  ### TAKE CARE!!! REASSIGNIMENT!!!
      $to{cleancrypto} = $to{cleanto}; ### TAKE CARE!!! REASSIGNIMENT!!!
      $orig{crypto} = $orig{to}; ### TAKE CARE!!! REASSIGNIMENT!!!
      $orig{cleancrypto} = $orig{cleanto}; ### TAKE CARE!!! REASSIGNIMENT!!!
    }
    push( @newinstances,
    {
			countcase => $countcase, countblock => $countblock,
			miditers => \@miditers,  winneritems => \@winneritems, c => $c, from => $from,
			to => \%to, countvar => $countvar, countstep => $countstep,
			sweeps => \@sweeps, dowhat => \%dowhat, orig => \%orig,
			sourcesweeps => \@sourcesweeps, datastruc => \%datastruc,
			varnumbers => \@varnumbers, blocks => \@blocks,
			blockelts => \@blockelts, mids => \%mids, varnums => \%varnums,
			countinstance => $cn, carrier => \%mids, origin => $origin,
			instn => $instn, is => $to{cleanto}, vehicles => \%vehicles,
			mypath => $mypath, file => $file, whatto => \@whatto,
      fire => "yes", from => $origin, gaproc => "yes", stamp => $stamp,
		} );
	}
	return ( \@newinstances );
}


sub reconstruct
{
	my ( $string ) = @_;
	my %mids = split( "_|-", $string );
  return( \%mids );
}


sub morph
{
	my ( $configfile, $instances_r, $dirfiles_r, $dowhat_r, $vehicles_r, $inst_r, $precedents_r ) = @_;

	my @instances = @{ $instances_r };

	my %dirfiles = %{ $dirfiles_r };
	my %dowhat = %{ $dowhat_r };
	my %vehicles = %{ $vehicles_r };
	my %inst = %{ $inst_r };
	my @precedents = @{ $precedents_r };

	my $mypath = $main::mypath;
	my $exeonfiles = $main::exeonfiles;
	my $generatechance = $main::generatechance;
	my $file = $main::file;
	my $preventsim = $main::preventsim;
	my $fileconfig = $main::fileconfig;
	my $outfile = $main::outfile;
	my $tofile = $main::tofile;
	my $simnetwork = $main::simnetwork;
  my $max_processes = $main::max_processes;

	my %simtitles = %main::simtitles;
	my %retrievedata = %main::retrievedata;
	my @keepcolumns = @main::keepcolumns;
	my @weights = @main::weights;
  my @weighttransforms = @main::weighttransforms;
	my @weightsaim = @main::weightsaim;
	my @varthemes_report = @main::varthemes_report;
	my @varthemes_variations = @main::varthemes_variations;
	my @varthemes_steps = @main::varthemes_steps;
	my @rankcolumn = @main::rankcolumn;
	my %reportdata = %main::reportdata;
	my @files_to_filter = @main::files_to_filter;
	my @filter_reports = @main::filter_reports;
	my @base_columns = @main::base_columns;
	my @maketabledata = @main::maketabledata;
	my @filter_columns = @main::filter_columns;
	my %vals = %main::vals;

  say  "RECEIVED NOW INSTANCES" . dump ( @instances );

	if ( $tofile eq "" )
	{
		$tofile = "./report.txt";
	}

	$tee = new IO::Tee( \*STDOUT, ">>$tofile" ); # GLOBAL ZZZ

	say $tee "\n# Now in Sim::OPT::Morph.\n";

	if ( not ( $exeonfiles ) ) { $exeonfiles = "y"; }
	if ( not ( $preventsim ) ) { $preventsim = "n"; }
	if ( not ( $report ) ) { $report = "$mypath/$file-report.txt"; }

	my @simcases = @{ $dirfiles{simcases} };
	my @simstruct = @{ $dirfiles{simstruct} };
	my @morphcases = @{ $dirfiles{morphcases} };
	my @morphstruct = @{ $dirfiles{morphstruct} };
	my @retcases = @{ $dirfiles{retcases} };
	my @retstruct = @{ $dirfiles{retstruct} };
	my @repcases = @{ $dirfiles{repcases} };
	my @repstruct = @{ $dirfiles{repstruct} };
	my @mergecases = @{ $dirfiles{mergecases} };
	my @mergestruct = @{ $dirfiles{mergestruct} };
	my @descendcases = @{ $dirfiles{descendcases} };
	my @descendstruct = @{ $dirfiles{descendstruct} };

	my $morphlist = $dirfiles{morphlist};
	my $morphblock = $dirfiles{morphblock};
	my $simlist = $dirfiles{simlist};
	my $simblock = $dirfiles{simblock};
	my $retlist = $dirfiles{retlist};
	my $retblock = $dirfiles{retblock};
	my $replist = $dirfiles{replist};
	my $repblock = $dirfiles{repblock};
	my $descendlist = $dirfiles{descendlist};
	my $descendblock = $dirfiles{descendblock};

	my $skipfile = $vals{skipfile};
	my $skipsim = $vals{skipsim};
	my $skipreport = $vals{skipreport};

	my ( %numvertmenu, %vertnummenu );

	if ( ( $dowhat{menus} eq "shortb" ) or ( not ( defined ( $dowhat{menus} ) ) ) )
	{
		%numvertmenu = ( 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f", 7 => "g",
		8 => "h", 9 => "i", 10 => "j", 11 => "k", 12 => "l",
		13 => "m", 14 => "n", 15 => "o", 16 => "p", 17 => "0\nq", 18 => "0\nr", 19 => "0\ns",
		20 => "0\nt", 		21 => "0\nu", 22 => "0\nv", 23 => "0\nw", 24 => "0\nx", 25 => "0\ny",
		26 => "0\nz", 27 => "0\na", 28 => "0\nb", 29 => "0\nc", 30 => "0\nd", 31 => "0\ne",
		32 => "0\n0\nb\nf", 33 => "0\n0\nb\ng", 34 => "0\n0\nb\nh", 35 => "0\n0\nb\ni", 36 => "0\n0\nb\nj",
		37 => "0\n0\nb\nk", 38 => "0\n0\nb\nl", 39 => "0\n0\nb\nm", 40 => "0\n0\nb\nn", 41 => "0\n0\nb\no",
		42 => "0\n0\nb\np", 43 => "0\n0\nb\nq", 44 => "0\n0\nb\nr", 45 => "0\n0\nb\ns", 46 => "0\n0\nb\nt",
		47 => "0\n0\nb\n0\nb\nu", 48 => "0\n0\nb\n0\nb\nv", 49 => "0\n0\nb\n0\nb\nw", 50 => "0\n0\nb\n0\nb\nx",
		51 => "0\n0\nb\n0\nb\ny", 52 => "0\n0\nb\n0\nb\nz",
		53 => "0\n0\nb\n0\nb\na", 54 => "0\n0\nb\n0\nb\nb", 55 => "0\n0\nb\n0\nb\nc", 56 => "0\n0\nb\n0\nb\nd",
		57 => "0\n0\nb\n0\nb\ne", 58 => "0\n0\nb\n0\nb\nf",
		59 => "0\n0\nb\n0\nb\ng", 60 => "0\n0\nb\n0\nb\nh", 61 => "0\n0\nb\n0\nb\ni",
		62 => "0\n0\nb\n0\nb\n0\nb\nj", 63 => "0\n0\nb\n0\nb\n0\nb\nk", 64 => "0\n0\nb\n0\nb\n0\nb\nl",
		65 => "0\n0\nb\n0\nb\n0\nb\nm", 66 => "0\n0\nb\n0\nb\n0\nb\nn",
		67 => "0\n0\nb\n0\nb\n0\nb\no", 68 => "0\n0\nb\n0\nb\n0\nb\np", 69 => "0\n0\nb\n0\nb\n0\nb\nq",
		70 => "0\n0\nb\n0\nb\n0\nb\nr", 71 => "0\n0\nb\n0\nb\n0\nb\ns",
		72 => "0\n0\nb\n0\nb\n0\nb\nt", 73 => "0\n0\nb\n0\nb\n0\nb\nu", 74 => "0\n0\nb\n0\nb\n0\nb\nv",
		75 => "0\n0\nb\n0\nb\n0\nb\nw", 76 => "0\n0\nb\n0\nb\n0\nb\nx",
		77 => "0\n0\nb\n0\nb\n0\nb\n0\nb\ny", 78 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nz", 79 => "0\n0\nb\n0\nb\n0\nb\n0\nb\na",
		80 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nb", 81 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nc", 82 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nd",
		83 => "0\n0\nb\n0\nb\n0\nb\n0\nb\ne", 84 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nf", 85 => "0\n0\nb\n0\nb\n0\nb\n0\nb\ng",
		86 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nh", 87 => "0\n0\nb\n0\nb\n0\nb\n0\nb\ni", 88 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nj",
		89 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nk", 90 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nl", 91 => "0\n0\nb\n0\nb\n0\nb\n0\nb\nm",
		92 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nn", 93 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\no",
		94 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\np", 95 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nq",
		96 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nr", 97 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\ns",
		98 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nt", 99 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nu",
		100 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nv", 101 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nw",
		102 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nx", 103 => "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\ny", );

		%vertnummenu = ( "a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6, "g" => 7, "h" => 8, "i" => 9, "j" => 10, "k" => 11, "l" => 12,
	"m" => 13, "n" => 14, "o" => 15, "p" => 16,
	"0\nq" => 17, "0\nr" => 18, "0\ns" => 19, "0\nt" => 20, "0\nu" => 21, "0\nv" => 22, "0\nw" => 23, "0\nx" => 24, "0\ny" => 25, "0\nz" => 26,
	"0\na" => 27, "0\nb" => 28, "0\nc" => 29, "0\nd" => 30, "0\ne" => 31,
	"0\n0\nb\nf" => 32, "0\n0\nb\ng" => 33, "0\n0\nb\nh" => 34, "0\n0\nb\ni" => 35, "0\n0\nb\nj" => 36, "0\n0\nb\nk" => 37, "0\n0\nb\nl" => 38,
	"0\n0\nb\nm" => 39, "0\n0\nb\nn" => 40, "0\n0\nb\no" => 41, "0\n0\nb\np" => 42, "0\n0\nb\nq" => 43, "0\n0\nb\nr" => 44, "0\n0\nb\ns" => 45,
	"0\n0\nb\nt" => 46,
	"0\n0\nb\n0\nb\nu" => 47, "0\n0\nb\n0\nb\nv" => 48, "0\n0\nb\n0\nb\nw" => 49, "0\n0\nb\n0\nb\nx" => 50, "0\n0\nb\n0\nb\ny" => 51, "0\n0\nb0\nb\nz" => 52,
	"0\n0\nb\n0\nb\na" => 53, "0\n0\nb\n0\nb\nb" => 54, "0\n0\nb\n0\nb\nc" => 55, "0\n0\nb\n0\nb\nd" => 56, "0\n0\nb\n0\nb\ne" => 57, "0\n0\nb0\nb\nf" => 58,
	"0\n0\nb\n0\nb\ng" => 59, "0\n0\nb\n0\nb\nh" => 60, "0\n0\nb\n0\nb\ni" => 61,
	"0\n0\nb\n0\nb\n0\nb\nj" => 62, "0\n0\nb\n0\nb\n0\nb\nk" => 63, "0\n0\nb\n0\nb\n0\nb\nl" => 64, "0\n0\nb\n0\nb\n0\nb\nm" => 65, "0\n0\nb\n0\nb\n0\nb\nn" => 66,
	"0\n0\nb\n0\nb\n0\nb\no" => 67, "0\n0\nb\n0\nb\n0\nb\np" => 68, "0\n0\nb\n0\nb\n0\nb\nq" => 69, "0\n0\nb\n0\nb\n0\nb\nr" => 70, "0\n0\nb\n0\nb\n0\nb\ns" => 71,
	"0\n0\nb\n0\nb\n0\nb\nt" => 72, "0\n0\nb\n0\nb\n0\nb\nu" => 73, "0\n0\nb\n0\nb\n0\nb\nv" => 74, "0\n0\nb\n0\nb\n0\nb\nw" => 75, "0\n0\nb\n0\nb\n0\nb\nx" => 76,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\ny" => 77, "0\n0\nb\n0\nb\n0\nb\n0\nb\nz" => 78, "0\n0\nb\n0\nb\n0\nb\n0\nb\na" => 79, "0\n0\nb\n0\nb\n0\nb\n0\nb\nb" => 80,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\nc" => 81, "0\n0\nb\n0\nb\n0\nb\n0\nb\nd" => 82, "0\n0\nb\n0\nb\n0\nb\n0\nb\ne" => 83, "0\n0\nb\n0\nb\n0\nb\n0\nb\nf" => 84,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\ng" => 85, "0\n0\nb\n0\nb\n0\nb\n0\nb\nh" => 86, "0\n0\nb\n0\nb\n0\nb\n0\nb\ni" => 87, "0\n0\nb\n0\nb\n0\nb\n0\nb\nj" => 88,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\nk" => 89, "0\n0\nb\n0\nb\n0\nb\n0\nb\nl" => 90, "0\n0\nb\n0\nb\n0\nb\n0\nb\nm" => 91,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nn" => 92, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\no" => 93, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\np" => 94, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nq" => 95,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nr" => 96, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\ns" => 97, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nt" => 98, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nu" => 99,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nv" => 100, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nw" => 101, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nx" => 102, "0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\ny" => 103,
	"0\n0\nb\n0\nb\n0\nb\n0\nb\n0\nb\nz" => 104 );
	}
	elsif ( $dowhat{menus} eq "shortc" )
	{
		%numvertmenu = ( 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f", 7 => "g",
		8 => "h", 9 => "i", 10 => "j", 11 => "k", 12 => "l",
		13 => "m", 14 => "n", 15 => "o", 16 => "p", 17 => "0\nq", 18 => "0\nr", 19 => "0\ns",
		20 => "0\nt", 		21 => "0\nu", 22 => "0\nv", 23 => "0\nw", 24 => "0\nx", 25 => "0\ny",
		26 => "0\nz", 27 => "0\na", 28 => "0\nb", 29 => "0\nc", 30 => "0\nd", 31 => "0\ne",
		32 => "0\n0\nc\nf", 33 => "0\n0\nc\ng", 34 => "0\n0\nc\nh", 35 => "0\n0\nc\ni", 36 => "0\n0\nc\nj",
		37 => "0\n0\nc\nk", 38 => "0\n0\nc\nl", 39 => "0\n0\nc\nm", 40 => "0\n0\nc\nn", 41 => "0\n0\nc\no",
		42 => "0\n0\nc\np", 43 => "0\n0\nc\nq", 44 => "0\n0\nc\nr", 45 => "0\n0\nc\ns", 46 => "0\n0\nc\nt",
		47 => "0\n0\nc\n0\nc\nu", 48 => "0\n0\nc\n0\nc\nv", 49 => "0\n0\nc\n0\nc\nw", 50 => "0\n0\nc\n0\nc\nx",
		51 => "0\n0\nc\n0\nc\ny", 52 => "0\n0\nc\n0\nc\nz",
		53 => "0\n0\nc\n0\nc\na", 54 => "0\n0\nc\n0\nc\nb", 55 => "0\n0\nc\n0\nc\nc", 56 => "0\n0\nc\n0\nc\nd",
		57 => "0\n0\nc\n0\nc\ne", 58 => "0\n0\nc\n0\nc\nf",
		59 => "0\n0\nc\n0\nc\ng", 60 => "0\n0\nc\n0\nc\nh", 61 => "0\n0\nc\n0\nc\ni",
		62 => "0\n0\nc\n0\nc\n0\nc\nj", 63 => "0\n0\nc\n0\nc\n0\nc\nk", 64 => "0\n0\nc\n0\nc\n0\nc\nl",
		65 => "0\n0\nc\n0\nc\n0\nc\nm", 66 => "0\n0\nc\n0\nc\n0\nc\nn",
		67 => "0\n0\nc\n0\nc\n0\nc\no", 68 => "0\n0\nc\n0\nc\n0\nc\np", 69 => "0\n0\nc\n0\nc\n0\nc\nq",
		70 => "0\n0\nc\n0\nc\n0\nc\nr", 71 => "0\n0\nc\n0\nc\n0\nc\ns",
		72 => "0\n0\nc\n0\nc\n0\nc\nt", 73 => "0\n0\nc\n0\nc\n0\nc\nu", 74 => "0\n0\nc\n0\nc\n0\nc\nv",
		75 => "0\n0\nc\n0\nc\n0\nc\nw", 76 => "0\n0\nc\n0\nc\n0\nc\nx",
		77 => "0\n0\nc\n0\nc\n0\nc\n0\nc\ny", 78 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nz", 79 => "0\n0\nc\n0\nc\n0\nc\n0\nc\na",
		80 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nb", 81 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nc", 82 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nd",
		83 => "0\n0\nc\n0\nc\n0\nc\n0\nc\ne", 84 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nf", 85 => "0\n0\nc\n0\nc\n0\nc\n0\nc\ng",
		86 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nh", 87 => "0\n0\nc\n0\nc\n0\nc\n0\nc\ni", 88 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nj",
		89 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nk", 90 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nl", 91 => "0\n0\nc\n0\nc\n0\nc\n0\nc\nm",
		92 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nn", 93 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\no",
		94 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\np", 95 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nq",
		96 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nr", 97 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\ns",
		98 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nt", 99 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nu",
		100 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nv", 101 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nw",
		102 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nx", 103 => "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\ny", );

		%vertnummenu = ( "a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6, "g" => 7, "h" => 8, "i" => 9, "j" => 10, "k" => 11, "l" => 12,
			"m" => 13, "n" => 14, "o" => 15, "p" => 16,
		"0\nq" => 17, "0\nr" => 18, "0\ns" => 19, "0\nt" => 20, "0\nu" => 21, "0\nv" => 22, "0\nw" => 23, "0\nx" => 24, "0\ny" => 25, "0\nz" => 26,
		"0\na" => 27, "0\nb" => 28, "0\nc" => 29, "0\nd" => 30, "0\ne" => 31,
		"0\n0\nc\nf" => 32, "0\n0\nc\ng" => 33, "0\n0\nc\nh" => 34, "0\n0\nc\ni" => 35, "0\n0\nc\nj" => 36, "0\n0\nc\nk" => 37, "0\n0\nc\nl" => 38,
		"0\n0\nc\nm" => 39, "0\n0\nc\nn" => 40, "0\n0\nc\no" => 41, "0\n0\nc\np" => 42, "0\n0\nc\nq" => 43, "0\n0\nc\nr" => 44, "0\n0\nc\ns" => 45,
		"0\n0\nc\nt" => 46,
		"0\n0\nc\n0\nc\nu" => 47, "0\n0\nc\n0\nc\nv" => 48, "0\n0\nc\n0\nc\nw" => 49, "0\n0\nc\n0\nc\nx" => 50, "0\n0\nc\n0\nc\ny" => 51, "0\n0\nc0\nc\nz" => 52,
		"0\n0\nc\n0\nc\na" => 53, "0\n0\nc\n0\nc\nb" => 54, "0\n0\nc\n0\nc\nc" => 55, "0\n0\nc\n0\nc\nd" => 56, "0\n0\nc\n0\nc\ne" => 57, "0\n0\nc0\nc\nf" => 58,
		"0\n0\nc\n0\nc\ng" => 59, "0\n0\nc\n0\nc\nh" => 60, "0\n0\nc\n0\nc\ni" => 61,
		"0\n0\nc\n0\nc\n0\nc\nj" => 62, "0\n0\nc\n0\nc\n0\nc\nk" => 63, "0\n0\nc\n0\nc\n0\nc\nl" => 64, "0\n0\nc\n0\nc\n0\nc\nm" => 65, "0\n0\nc\n0\nc\n0\nc\nn" => 66,
		"0\n0\nc\n0\nc\n0\nc\no" => 67, "0\n0\nc\n0\nc\n0\nc\np" => 68, "0\n0\nc\n0\nc\n0\nc\nq" => 69, "0\n0\nc\n0\nc\n0\nc\nr" => 70, "0\n0\nc\n0\nc\n0\nc\ns" => 71,
		"0\n0\nc\n0\nc\n0\nc\nt" => 72, "0\n0\nc\n0\nc\n0\nc\nu" => 73, "0\n0\nc\n0\nc\n0\nc\nv" => 74, "0\n0\nc\n0\nc\n0\nc\nw" => 75, "0\n0\nc\n0\nc\n0\nc\nx" => 76,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\ny" => 77, "0\n0\nc\n0\nc\n0\nc\n0\nc\nz" => 78, "0\n0\nc\n0\nc\n0\nc\n0\nc\na" => 79, "0\n0\nc\n0\nc\n0\nc\n0\nc\nb" => 80,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\nc" => 81, "0\n0\nc\n0\nc\n0\nc\n0\nc\nd" => 82, "0\n0\nc\n0\nc\n0\nc\n0\nc\ne" => 83, "0\n0\nc\n0\nc\n0\nc\n0\nc\nf" => 84,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\ng" => 85, "0\n0\nc\n0\nc\n0\nc\n0\nc\nh" => 86, "0\n0\nc\n0\nc\n0\nc\n0\nc\ni" => 87, "0\n0\nc\n0\nc\n0\nc\n0\nc\nj" => 88,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\nk" => 89, "0\n0\nc\n0\nc\n0\nc\n0\nc\nl" => 90, "0\n0\nc\n0\nc\n0\nc\n0\nc\nm" => 91,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nn" => 92, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\no" => 93, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\np" => 94, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nq" => 95,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nr" => 96, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\ns" => 97, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nt" => 98, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nu" => 99,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nv" => 100, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nw" => 101, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nx" => 102, "0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\ny" => 103,
		"0\n0\nc\n0\nc\n0\nc\n0\nc\n0\nc\nz" => 104 );
	}
	elsif ( $dowhat{menus} eq "long" )
	{
		%numvertmenu = ( 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f", 7 => "g",
		8 => "h", 9 => "i", 10 => "j", 11 => "k", 12 => "l",
		13 => "m", 14 => "n", 15 => "o", 16 => "p", 17 => "q", 18 => "r", 19 => "s",
		20 => "t", 		21 => "u", 22 => "v", 23 => "w", 24 => "x", 25 => "0\ny",
		26 => "0\nz", 27 => "0\na", 28 => "0\nb", 29 => "0\nc", 30 => "0\nd", 31 => "0\ne",
		32 => "0\nf", 33 => "0\ng", 34 => "0\nh", 35 => "0\ni", 36 => "0\nj",
		37 => "0\nk", 38 => "0\nl", 39 => "0\nm", 40 => "0\nn", 41 => "0\no",
		42 => "0\np", 43 => "0\nq", 44 => "0\nr", 45 => "0\ns", 46 => "0\nt",
		47 => "0\nu", 48 => "0\n0\nc\nv", 49 => "0\n0\nc\nw", 50 => "0\n0\nc\nx",
		51 => "0\n0\nc\ny", 52 => "0\n0\nc\nz",
		53 => "0\n0\nc\na", 54 => "0\n0\nc\nb", 55 => "0\n0\nc\nc", 56 => "0\n0\nc\nd",
		57 => "0\n0\nc\ne", 58 => "0\n0\nc\nf",
		59 => "0\n0\nc\ng", 60 => "0\n0\ncnh", 61 => "0\n0\nc\ni",
		62 => "0\n0\nc\nj", 63 => "0\n0\nc\nk", 64 => "0\n0\nc\nl",
		65 => "0\n0\nc\nm", 66 => "0\n0\nc\nn",
		67 => "0\n0\nc\no", 68 => "0\n0\nc\np", 69 => "0\n0\nc\nq",
		70 => "0\n0\nc\nr", 71 => "0\n0\nc\ns",
		72 => "0\n0\nc\nt", 73 => "0\n0\nc\nu", 74 => "0\n0\nc\nv",
		75 => "0\n0\nc\nw", 76 => "0\n0\nc\nx",
		77 => "0\n0\nc\ny", 78 => "0\n0\nc\nz", 79 => "0\n0\nc\na",
		80 => "0\n0\nc\nb", 81 => "0\n0\nc\nc", 82 => "0\n0\nc\nd",
		83 => "0\n0\nc\ne", 84 => "0\n0\nc\nf", 85 => "0\n0\nc\n0\nc\ng",
		86 => "0\n0\nc\n0\nc\nh", 87 => "0\n0\nc\n0\nc\ni", 88 => "0\n0\nc\n0\nc\nj",
		89 => "0\n0\nc\n0\nc\nk", 90 => "0\n0\nc\n0\nc\nl", 91 => "0\n0\nc\n0\nc\nm",
		92 => "0\n0\nc\n0\nc\nn", 93 => "0\n0\nc\n0\nc\no",
		94 => "0\n0\nc\n0\nc\np", 95 => "0\n0\nc\n0\nc\nq",
		96 => "0\n0\nc\n0\nc\nr", 97 => "0\n0\nc\n0\nc\ns",
		98 => "0\n0\nc\n0\nc\nt", 99 => "0\n0\nc\n0\nc\nu",
		100 => "0\n0\nc\n0\nc\nv", 101 => "0\n0\nc\n0\nc\nw",
		102 => "0\n0\nc\n0\nc\nx", 103 => "0\n0\nc\n0\nc\ny", );

		%vertnummenu = ( "a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6, "g" => 7,
		"h" => 8, "i" => 9, "j" => 10, "k" => 11, "l" => 12,
		"m" => 13, "n" => 14, "o" => 15, "p" => 16, "q" => 17, "r" => 18, "s" => 19,
		"t" => 20, "u" => 21, "v" => 22, "w" => 23, "x" => 24, "0\ny" => 25,
		"0\nz" => 26, "0\na" => 27, "0\nb" => 28, "0\nc" => 29, "0\nd" => 30, "0\ne" => 31,
		"0\nf" => 32, "0\ng" => 33, "0\nh" => 34, "0\ni" => 35, "0\nj" => 36,
		"0\nk" => 37, "0\nl" => 38, "0\nm" => 39, "0\nn" => 40, "0\no" => 41,
		"0\np" => 42, "0\nq" => 43, "0\nr" => 44, "0\ns" => 45, "0\nt" => 46,
		"0\nu" => 47, "0\n0\nc\nv" => 48, "0\n0\nc\nw" => 49, "0\n0\nc\nx" => 50,
		"0\n0\nc\ny" => 51, "0\n0\nc\nz" => 52,
		"0\n0\nc\na" => 53, "0\n0\nc\nb" => 54, "0\n0\nc\nc" => 55, "0\n0\nc\nd" => 56,
		"0\n0\nc\ne" => 57, "0\n0\nc\nf" => 58,
		"0\n0\nc\ng" => 59, "0\n0\ncnh" => 60, "0\n0\nc\ni" => 61,
		"0\n0\nc\nj" => 62, "0\n0\nc\nk" => 63, "0\n0\nc\nl" => 64,
		"0\n0\nc\nm" => 65, "0\n0\nc\nn" => 66,
		"0\n0\nc\no" => 67, "0\n0\nc\np" => 68, "0\n0\nc\nq" => 69,
		"0\n0\nc\nr" => 70, "0\n0\nc\ns" => 71,
		"0\n0\nc\nt" => 72, "0\n0\nc\nu" => 73, "0\n0\nc\nv" => 74,
		"0\n0\nc\nw" => 75, "0\n0\nc\nx" => 76,
		"0\n0\nc\ny" => 77, "0\n0\nc\nz" => 78, "0\n0\nc\na" => 79,
		"0\n0\nc\nb" => 80, "0\n0\nc\nc" => 81, "0\n0\nc\nd" => 82,
		"0\n0\nc\ne" => 83, "0\n0\nc\nf" => 84, "0\n0\nc\n0\nc\ng" => 85,
		"0\n0\nc\n0\nc\nh" => 86, "0\n0\nc\n0\nc\ni" => 87, "0\n0\nc\n0\nc\nj" => 88,
		"0\n0\nc\n0\nc\nk" => 89, "0\n0\nc\n0\nc\nl" => 90, "0\n0\nc\n0\nc\nm" => 91,
		"0\n0\nc\n0\nc\nn" => 92, "0\n0\nc\n0\nc\no" => 93,
		"0\n0\nc\n0\nc\np" => 94, "0\n0\nc\n0\nc\nq" => 95,
		"0\n0\nc\n0\nc\nr" => 96, "0\n0\nc\n0\nc\ns" => 97,
		"0\n0\nc\n0\nc\nt" => 98, "0\n0\nc\n0\nc\nu" => 99,
		"0\n0\nc\n0\nc\nv" => 100, "0\n0\nc\n0\nc\nw" => 101,
		"0\n0\nc\n0\nc\nx" => 102, "0\n0\nc\n0\nc\ny" => 103, );
	};

	my @menus = ( \%numvertmenu, \%vertnummenu );

	my $numberof_morphings = scalar ( keys %{ $dowhat{simtools} } );
	my ( @done_instances, @done_tos );



	if ( ( $dirfiles{randompick} eq "yes" ) or ( $dirfiles{latinhypercube} eq "yes" ) )
	{
		my ( $instances_ref, $inst_ref, $dirfiles_ref ) = setpickedinsts( \@instances, \%inst, \%dirfiles );
	  @instances = @{ $instances_ref };
		%inst = %{ $inst_ref };
		%dirfiles = %{ $dirfiles_ref };
	}

  my @collect;
	foreach $instance_r ( @instances )
	{
		%d = %{ $instance_r };
		push( @collect, $d{is} );
	}
	say $tee "NOW COLLECTED INSTANCES " . dump( @collect );

  my $counti = 0;
	foreach my $instance ( @instances )
	{
		my %d = %{ $instance };
		my $instance_after = $instances[ $counti + 1];
		my %d_after = %{ $instance_after };

		my $countcase = $d{countcase};
		my $countblock = $d{countblock};
		my %datastruc = %{ $d{datastruc} };
		my @rescontainer = @{ $d{rescontainer} };
		my @miditers = @{ $d{miditers} };
		my @winneritems = @{ $d{winneritems} };
		my $countvar = $d{countvar};

		if ( $d{treated} eq "treated" )
		{
			#print $tee "TREATED!: $d{treated}";
		};
		#say $tee "ARRIVED IN MORPH 1";

		my @countvars;
		push( @countvars, $countvar );
		my $countvar_after = $d_after{countvar};
		my $countstep = $d{countstep};
		my $countinstance = ( $d{instn} );

		my @uplift = @{ $d{uplift} };
		my @backvalues = @{ $d{backvalues} };
		my @sweeps = @{ $d{sweeps} };
		my @sourcesweeps = @{ $d{sourcesweeps} };
		my @blockelts = @{ $d{blockelts} };
		my @blocks = @{ $d{blocks} };

		my $origin = $d{origin};
		my %to = %{ $d{to} };
		my %orig = %{ $d{orig} };
		my $fire = $d{fire};
		my $gaproc = $d{gaproc};

		my $from = $origin;
		my $is = $d{is};
		my @whatto = @{ $d{whatto} };
		my $stamp = $d{stamp};

		my %varnums = %{ $d{varnums} };
		my %mids = %{ $d{mids} };
		my $rootname = Sim::OPT::getrootname( \@rootnames, $countcase );

		my $varnumber = $countvar;
		my $stepsvar = $varnums{$countvar};
		my $countcaseplus1 = ( $countcase + 1 );
		my $countblockplus1 = ( $countblock + 1 );

		my $countmorphing = 1;
		my $numberof_morphings = scalar( keys %{ $dowhat{simtools} } );

		my ( $orig, $target );

		my $i == 0;
		foreach my $countvar ( @countvars )
		{
			while ( $countmorphing <= $numberof_morphings )
			{
				if ( not (defined ( $vals{$countmorphing}{$countvar}{general_variables} ) ) )
				{
					$vals{$countmorphing}{$countvar}{general_variables} =
									[
									"y", # $generate(n) eq "n" # (if the models deriving from this runs will not be generating new models) or y (if they will be generating new models).
									"n" #if $sequencer eq "y", or "last" (of a sequence) iteration between non-continuous cases wanted.  The first gets appended to the middle(s) and to he last. Otherwise, "n".
									];
				}

				if ( $dowhat{actonmodels} eq "" )
				{
					$dowhat{actonmodels} = "y";
				}

				my @applytype = @{ $vals{$countmorphing}{$countvar}{applytype} };
				my $general_variables = $vals{$countmorphing}{$countvar}{general_variables};
				my @generic_change = @{$vals{$countmorphing}{$countvar}{generic_change} };
				my $rotate = $vals{$countmorphing}{$countvar}{rotate};
				my $rotatez = $vals{$countmorphing}{$countvar}{rotatez};
				my $translate = $vals{$countmorphing}{$countvar}{translate};
				my $translate_surface = $vals{$countmorphing}{$countvar}{translate_surface};
				my $keep_obstructions = $vals{$countmorphing}{$countvar}{keep_obstructions};
				my $shift_vertices = $vals{$countmorphing}{$countvar}{shift_vertices};
				my $reassign_construction = $vals{$countmorphing}{$countvar}{reassign_construction};
				my $change_thickness = $vals{$countmorphing}{$countvar}{change_thickness};
				my $recalculateish = $vals{$countmorphing}{$countvar}{recalculateish};
				my $rebuildconstr = $vals{$countmorphing}{$countvar}{rebuildconstr};
				my @recalculatenet = @{ $vals{$countmorphing}{$countvar}{recalculatenet} };
				my $obs_modify = $vals{$countmorphing}{$countvar}{obs_modify};
				my $netcomponentchange = $vals{$countmorphing}{$countvar}{netcomponentchange};
				my $changecontrol = $vals{$countmorphing}{$countvar}{changecontrol};
				my @apply_constraints = @{ $vals{$countmorphing}{$countvar}{apply_constraints} };
				my $rotate_surface = $vals{$countmorphing}{$countvar}{rotate_surface};
				my @reshape_windows = @{ $vals{$countmorphing}{$countvar}{reshape_windows} };
				my @apply_netconstraints = @{ $vals{$countmorphing}{$countvar}{apply_netconstraints} };
				my @apply_windowconstraints = @{ $vals{$countmorphing}{$countvar}{apply_windowconstraints} };
				my @translate_vertices = @{ $vals{$countmorphing}{$countvar}{translate_vertices} };
				my $warp = $vals{$countmorphing}{$countvar}{warp};
				my @daylightcalc = @{ $vals{$countmorphing}{$countvar}{daylightcalc} };
				my @change_config = @{ $vals{$countmorphing}{$countvar}{change_config} };
				my @vary_controls = @{ $vals{$countmorphing}{$countvar}{vary_controls} };
				my @constrain_controls =  @{ $vals{$countmorphing}{$countvar}{constrain_controls} };
				my $checkfile = $vals{$countmorphing}{$countvar}{checkfile};
				my @change_climate = @{ $vals{$countmorphing}{$countvar}{change_climate} };
				my $pin_obstructions = $vals{$countmorphing}{$countvar}{pin_obstructions};
				my $use_modish = $vals{$countmorphing}{$countvar}{use_modish};
				my $export_toradiance = $vals{$countmorphing}{$countvar}{export_toradiance};
				my $genchange = $vals{$countmorphing}{$countvar}{genchange};
				my $genprop = $vals{$countmorphing}{$countvar}{genprop};
				my $change_groundreflectance = $vals{$countmorphing}{$countvar}{change_groundreflectance};
				my $export_toenergyplus = $vals{$countmorphing}{$countvar}{export_toenergyplus};
				my $skipop = $vals{$countmorphing}{$countvar}{skipop};
				my $todos = $vals{$countmorphing}{$countvar}{todos};
				# genchange
				my ( @cases_to_sim, @files_to_convert );
				my ( @obs, @node, @component, @loopcontrol, @flowcontrol, @new_loopcontrol, @new_flowcontrol ); # THINGS GLOBAL AS REGARDS TO COUNTER ZONE CYCLES
				my ( @myobs, @mynode, @mycomponent, @myloopcontrol, @myflowcontrol); # THINGS LOCAL AS REGARDS TO COUNTER ZONE CYCLES
				my ( @tempv, @tempobs, @tempnode, @tempcomponent, @temploopcontrol, @tempflowcontrol); # THINGS LOCAL AS REGARDS TO COUNTER ZONE CYCLES
				my ( @v, @v_, @obs_, @donode, @docomponent, @doloopcontrol, @doflowcontrol); # THINGS LOCAL AS REGARDS TO COUNTER ZONE CYCLES
				my ( %names, %newcontents, @filecontents, @newfilecontents );

				my $generate  = $$general_variables[0];
				my $sequencer = $$general_variables[1];
				my $dffile = "df-$file.txt";

				#my $semph = 0;
				#unless ( ( $exeonfiles eq "n" ) or ( $semph > 0 ) )
				#{
				#	my $starttarget = giveback( \%mids );
				#	$starttarget = "$mypath/$file" . "_" . "$starttarget"; say $tee "\$starttarget $starttarget";
				#	if ( not ( -e $starttarget ) )
				#	{
				#		`cp -R $mypath/$file $starttarget`;
				#		say $tee "LEVEL 0a: cp -R $mypath/$file $starttarget\n";
				#	}
				#	$semph++;
				#}
        my $target = $to{crypto};
				my $orig = $orig{crypto};

				my $starttarget = giveback( \%mids );  #say $tee "STARTTARGET $starttarget";

				#if ( ( ( ( $countblock > 0 ) and ( $countstep > 1 ) ) and ( not ( ( $dirfiles{randompick} eq "yes" ) and ( $dirfiles{ga} eq "yes" ) ) ) )
				#  or ( ( ( $dirfiles{randompick} eq "yes" ) or ( $dirfiles{ga} eq "yes" ) ) ) )
				{
					unless ( $gaproc eq "yes" )
					{
						open( MORPHBLOCK, ">>$morphblock") or die( "$!" );# or die;
					}
					push ( @{ $morphstruct[$countcase][$countblock] }, $to{cleanto} );

					#	if ( ( not ( grep { $_ eq $to } @morphcases ) ) or ( $dowhat{actonmodels} eq "y" ) )
					if ( ( $dowhat{actonmodels} eq "y" ) and ( not ( $dowhat{inactivatemorph} eq "y" ) ) )
					{ say $tee "HERE 2 COUNTBLOCK: $countblock, \$countstep: $countstep, \$origin: $origin, \$is: $is \$from: $from, \$to{cleanto}: $to{cleanto}, \$to{thisto}: $to{thisto},  ";
						push ( @morphcases, $is );

						print MORPHLIST "$to{cleanto}\n";

						unless ($exeonfiles eq "n")
						{
							if ( ( $dirfiles{randompick} eq "yes" ) or ( $dirfiles{latinhypercube} eq "yes" ) or ( $dirfiles{ga} eq "yes" ) )
							{
								if ( ( grep { $_ eq "begin" } @whatto ) and ( not ( grep { $_ eq "end" } @whatto ) ) and ( $dowhat{jumpinst} eq "yes" ) )
								{
									$orig = "$mypath/$file";
									$target = "$to{crypto}" . "-trans-$stamp" ;
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`cp -R $orig $target`;
										print $tee "LEVEL 1a: cp -R $orig $target\n\n";
									}
								}
								elsif ( ( grep { $_ eq "begin" } @whatto )  and ( not ( grep { $_ eq "end" } @whatto ) ) and ( not ( $dowhat{jumpinst} eq "yes" ) ) )
								{
									$orig = "$mypath/$file";
									$target = "$to{crypto}";
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`cp -R $orig $target`;
										print $tee "LEVEL 1b: cp -R $orig $target\n\n";
										print "LEVEL 1b: cp -R $orig $target\n\n";
									}
								}

								if ( ( grep { $_ eq "transition" } @whatto ) and ( not ( grep { $_ eq "begin" } @whatto) ) and
								            ( not ( grep { $_ eq "end" } @whatto) ) and ( $dowhat{jumpinst} eq "yes" ) )
								{
									$orig = "$orig{crypto}" . "-trans-$stamp";
									$target = "$to{crypto}" . "-trans-$stamp" ;
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`mv -f $orig $target`;
										print $tee "LEVEL 1c: cp -R $orig $target\n\n";
										print  "LEVEL 1c: cp -R $orig $target\n\n";
									}
								}
								elsif ( ( grep { $_ eq "transition" } @whatto ) and ( not ( grep { $_ eq "begin" } @whatto) ) and
								            ( not ( grep { $_ eq "end" } @whatto) ) and ( not ( $dowhat{jumpinst} eq "yes" ) ) )
								{
									$orig = "$orig{crypto}";
									$target = "$to{crypto}";
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`cp -R $orig $target`;
										print $tee "LEVEL 1d: cp -R $orig $target\n\n";
										print  "LEVEL 1d: cp -R $orig $target\n\n";
									}
								}

								if ( ( grep { $_ eq "end" } @whatto ) and ( $dowhat{jumpinst} eq "yes" ) )
								{
	                $orig = "$orig{crypto}" . "-trans-$stamp";
									$target = "$to{crypto}";
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`mv -f $orig $target`;
										print $tee "LEVEL 1e1: cp -R $orig $target\n\n";
										print  "LEVEL 1e1: cp -R $orig $target\n\n";
									}
								}
                elsif ( ( grep { $_ eq "end" } @whatto ) and ( not ( $dowhat{jumpinst} eq "yes" ) ) )
								{
	                $orig = "$orig{crypto}";
									$target = "$to{crypto}";
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`cp -R $orig $target`;
										print $tee "LEVEL 1e2: cp -R $orig $target\n\n";
										print  "LEVEL 1e2: cp -R $orig $target\n\n";
									}
								}

								if ( "IMPOSSIBLE" eq "SOMETHING" )
								{
	                $orig = "$orig{crypto}";
									$target = "$to{crypto}";
									if ( ( not ( -e $orig ) ) and ( $origin eq $starttarget ) )
									{
										$orig = "$mypath/$file";
									}
									if ( not ( -e $target ) )
									{
										`cp -R $orig $target`;
										print $tee "LEVEL 1e2: cp -R $orig $target\n\n";
										print  "LEVEL 1e2: cp -R $orig $target\n\n";
									}
								}

							}

							if ( ( not ( $dirfiles{randompick} eq "yes" ) ) and ( not ( $dirfiles{latinhypercube} eq "yes" ) )
							 and ( not ( $dirfiles{ga} eq "yes" ) ) )
							{
								$orig;
								$target = "$to{crypto}";

								if ( ( not ( -e $origin ) ) and ( $origin eq $starttarget ) )
								{
									$orig = "$mypath/$file";
								}
								else
								{
									$orig = "$orig{crypto}";
								}

								if ( not ( -e $target ) )
								{
									`cp -R $orig $target`;
									#say $tee "HERE 3 COUNTBLOCK: $countblock, \$countstep: $countstep, \$orig: $orig, \$target: $target, \$to{cleanto}: $to{cleanto}, \$to{thisto}: $to{thisto},  ";
									print $tee "LEVEL 1g: cp -R $orig $target \n\n";
									#print  "LEVEL 1g: cp -R $orig $target \n\n";
                }
							}
						}

						my $to = $target; #say $tee "\$to: $to!!!"; ### TAKE CARE!!! REASSIGNIMENT!!!
						my $from = $orig; #say $tee "\$from: $from!!!"; ### TAKE CARE!!! REASSIGNIMENT!!!

						if ( $dowhat{actonmodels} eq "y" )
						{ #if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 6";
							my $countop = 0; # "$countop" IS THE COUNTER OF THE OPERATIONS
							foreach my $op ( @applytype )
							{ #if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 7 ";

								my $skip = $skipop->[ $countop ]	;
								my $modification_type = $applytype[$countop][0];
								if ( ( $applytype[$countop][1] ne $applytype[$countop][2] ) and ( $modification_type ne "changeconfig" ) )
								{

									unless ($exeonfiles eq "n")
									{
											say $tee `cp -f $to/zones/$applytype[$countop][1] $to/zones/$applytype[$countop][2]\n`;

											say $tee `cp -f $to/cfg/$applytype[$countop][1] $to/cfg/$applytype[$countop][2]\n`;
									}
									#if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 8 "; print $tee "LEVEL 2:cp -f $to/zones/$applytype[$countop][1] $to/zones/$applytype[$countop][2]\n\n";
									print $tee "LEVEL 2: cp -f $to/cfg/$applytype[$countop][1] $to/cfg/$applytype[$countop][2]\n";
								}

								if ( ( $applytype[$countop][1] ne $applytype[$countop][2] ) and ( $modification_type eq "changeconfig" ) )
								{
									unless ($exeonfiles eq "n")
									{
										say $tee `cp -f $to/cfg/$applytype[$countop][1] $to/cfg/$applytype[$countop][2]\n`;
									}
									print $tee "LEVEL 2b: cp -f $to/cfg/$applytype[$countop][1] $to/cfg/$applytype[$countop][2]\n";
								}

								`cd $to`;
								say $tee "cd $to\n";
                #if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 9 ";
								my $launchline = "cd $to/cfg/ \n prj -file $fileconfig -mode script"; say $tee "SO, LAUNCHLINE! " . dump( $launchline );

								if ( ( $stepsvar > 1 ) and ( not ( eval ( $skip ) ) ) )
								{

									##########################################
									my @mods;
									if ( not( ref( $modification_type ) ) )
									{
										push( @mods, $modification_type );
									}
									else
									{
										push( @mods, @{ $modification_type } );
									}
									#########################################
                  #if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 10 ";
									foreach my $modtype ( @mods )
									{
										if ( $modtype eq "change_groundreflectance" )#
										{
											change_groundreflectance
											( $to, $stepsvar, $countop, $countstep,
												\@applytype, $change_groundreflectance, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "genchange" )
										{
											( $names_ref, $nums_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref ) = genchange
											( $to, $stepsvar, $countop, $countstep,
												\@applytype, $genchange, $countvar, $fileconfig, $mypath, $file,
												$countmorphing, "vary", $names_ref, $nums_ref,
												$newcontents_ref, $filecontents_ref, $newfilecontents_ref, $launchline, \@menus );
											%names = %$names_ref;
											%nums = %$nums_ref;
											%newcontents = %$newcontents_ref;
											@newfilecontents = @$newfilecontents_ref;
										} #
										elsif ( $modtype eq "generic_change" )#
										{
											make_generic_change( $to, $stepsvar, $countop, $countstep, \@applytype, $generic_change, $countvar, $fileconfig, $countmorphing, $launchline, \@menus, $countinstance );
										} #
										elsif ( $modtype eq "translate_surface" )
										{
											translate_surfaces($to, $stepsvar, $countop, $countstep, \@applytype, $translate_surface, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "rotate_surface" )              #
										{
											rotate_surface($to, $stepsvar, $countop, $countstep, \@applytype, $rotate_surface, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "shift_vertices" )
										{
											shift_vertices( $to, $stepsvar, $countop, $countstep, \@applytype, $shift_vertices, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "translate_vertices" )
										{
											translate_vertices( $to, $stepsvar, $countop, $countstep, \@applytype, \@translate_vertices, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "reassign_construction" )
										{
											reassign_construction( $to, $stepsvar, $countop, $countstep, \@applytype, $reassign_construction, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "rotate" )
										{
											rotate( $to, $stepsvar, $countop, $countstep, \@applytype, $rotate, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "translate" )
										{

											translate( $to, $stepsvar, $countop, $countstep, \@applytype, $translate, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "pin_obstructions" )
										{

											pin_obstructions( $to, $stepsvar, $countop, $countstep, \@applytype, $pin_obstructions, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "apply_constraints" )
										{

											apply_constraints( $to, $stepsvar, $countop, $countstep, \@applytype, \@apply_constraints, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "change_thickness" )
										{
											change_thickness( $to, $stepsvar, $countop, $countstep, \@applytype, $change_thickness, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "rotatez" )
										{
											rotatez($to, $stepsvar, $countop, $countstep, \@applytype, $rotatez, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "change_config" )
										{
											change_config( $to, $stepsvar, $countop, $countstep, \@applytype, \@change_config, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "reshape_windows" )
										{
											reshape_windows($to, $stepsvar, $countop, $countstep, \@applytype, \@reshape_windows, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "obs_modify" )
										{
											obs_modify( $to, $stepsvar, $countop, $countstep, \@applytype, $obs_modify, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );

										}
										elsif ( $modtype eq "warping" )
										{
											warp( $to, $stepsvar, $countop, $countstep, \@applytype, $warp, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "vary_controls" )
										{
											vary_controls( $to, $stepsvar, $countop, $countstep, \@applytype, \@vary_controls, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "vary_net" )
										{
											vary_net( $to, $stepsvar, $countop, $countstep, \@applytype, \@vary_net, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
										}
										elsif ( $modtype eq "change_climate" )
										{
											change_climate( $to, $stepsvar, $countop, $countstep, \@applytype, \@change_climate, $countvar, $fileconfig, $mypath, $file, $countmorphing, $countmorphing, $launchline, \@menus, $countinstance );
										}
										else
										{
											say $tee "Can't recognize the modification type. So quitting.";
											die( "$!" );
										}
									}
                  #if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 11 ";


									push ( @{ $done_instances[ $countvar ] }, $instance );
									push ( @{ $done_tos[ $countvar ] }, $to );



									my @todolist = @{ $todos->[ $countop ] };
									my ( @expectedinsts, @expectedtos );
									foreach my $todo ( @todolist )
									{
										my @listtodo = @{ $todo->{actions} };
										foreach my $action ( @listtodo )
										{

											if ( not ( eval ( $skip ) ) )
											{

												if ( ( defined( $constrain_geometry[$countop] ) ) and ( ( $action eq "read_geo" ) or ( $action eq "write_geo" ) ) )
												{

													my ( $v_ref ) = constrain_geometry
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, \@constrain_geometry, $countvar, $fileconfig, \@v_, $countmorphing, $exeonfiles, \@v_, $action, $launchline, \@menus, $countinstance );
													@v = @$v_ref;
													@v_ = @$v__ref;
												}

												if ( ( defined( $genprop[$countop] ) ) and ( ( $action eq "read_gen" ) or ( $action eq "write_gen" ) ) )
												{
													( $names_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref ) =
														genprop ( $to, $stepsvar, $countop, $countstep,
															\@applytype, $genchange, $countvar, $fileconfig, $mypath, $file, $countmorphing, $action,
															$names_ref, $nums_ref, $newcontents_ref, $filecontents_ref,
															$newfilecontents_ref, $launchline, \@menus, $countinstance );
															%nums = %$nums_ref;
															%names = %$names_ref;
															%newcontents = %$newcontents_ref;
															@filecontents = @$filecontents_ref;
															@newfilecontents = @$newfilecontents_ref;
												}

												if ( defined ( $constrain_obstructions[$countop] ) and ( ( $action eq "read_obs" ) or ( $action eq "write_obs" ) ) )
												{
													my ( $obs_ref, $obs__ref ) = constrain_obstructions
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, \@constrain_obstructions, $countvar, $fileconfig, $countmorphing, $exeonfiles, $obs_ref, $obs__ref, $action, $launchline, \@menus, $countinstance );
														@obs = @$obs_ref;
														@obs_ = @$obs__ref;
												}

												if ( defined( $constrain_net[$countop] ) and ( ( $action eq "read_net" ) or ( $action eq "write_net" ) ) )
												{
													my ( $node_ref, $component_ref, $donode_ref, $docomponent_ref ) = constrain_net( $to, $stepsvar, $countop,
														$countstep, \@applytype, \@constrain_net, $countvar, $fileconfig, $countmorphing, $exeonfiles, $action,
														$node_ref, $component_ref, $donode_ref, $docomponent_ref, $launchline, \@menus, $countinstance );
														@node = @$node_ref;
														@component = @$component_ref;
														@donode = @$donode_ref;
														@docomponent = @$docomponent_ref;
												}

												if ( defined( $constrain_controls[$countop] ) and ( ( $action eq "read_ctl" ) or ( $action eq "write_ctl" ) ) )
												{
													my ( $loopcontrol_ref, $flowcontrol_ref, $new_loopcontrol_ref, $new_flowcontrol_ref ) = constrain_controls
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, \@constrain_controls, $countvar, $fileconfig, $countmorphing, $exeonfiles, $action,
														$loopcontrol_ref, $flowcontrol_ref, $new_loopcontrol_ref, $new_flowcontrol_ref, $launchline, \@menus, $countinstance );
														@loopcontrol = @$loopcontrol_ref;
														@flowcontrol = @$flowcontrol_ref;
														@new_loopcontrol = @$new_loopcontrol_ref;
														@new_flowcontrol = @$new_flowcontrol_ref;
												}

												if ( defined( $apply_constraints[$countop] ) and ( $action eq "apply_constraints" ) )
												{
													apply_constraints
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, \@apply_constraints, $countvar, $fileconfig, $countmorphing, $launchline, \@menus, $countinstance );
												}

												if ( defined( $pin_obstructions->[ $countop ] ) and ( $action eq "pin_obstructions" ) )
												{
													pin_obstructions
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, $pin_obstructions, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
												}

												if ( defined( $recalculatenet[$countop] ) and ( $action eq "recalculatenet" ) )
												{
													recalculatenet
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, \@recalculatenet, $countvar, $fileconfig, $countmorphing, $launchline, \@menus, $countinstance );
												}

												if ( defined( $recalculateish->[$countop] ) and ( $action eq "recalculateish" ) )
												{
													recalculateish
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, $recalculateish, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
												}

												if ( defined( $rebuildconstr->[$countop] ) and ( $action eq "rebuildconstr" ) )
												{
													rebuildconstr
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, $rebuildconstr, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
												}

												if ( defined( $daylightcalc->[$countop] )  and ( $action eq "daylightcalc" ) )
												{
													daylightcalc
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, $filedf, \@daylightcalc, $countvar, $fileconfig, $countmorphing, $launchline, \@menus, $countinstance );
												}
												if ( defined( $use_modish->[$countop] )  and ( $action eq "use_modish" ) )
												{
													use_modish
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, $use_modish, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
												}
												if ( defined( $export_toenergyplus->[$countop] )  and ( $action eq "export_toenergyplus" ) )
												{
													export_toenergyplus
													( $to, $stepsvar, $countop,
														$countstep, \@applytype, $export_toenergyplus, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, \@menus, $countinstance );
												}
											}
										}
									}
                  #if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 12 ";

									if ( ( $countvar_after > $countvar )
										or ( defined( $countvar ) and ( not ( defined( $countvar_after ) ) ) and ( not( scalar( @todolist ) == 0 ) ) ) )
									{
										my ( @expected_instances, @expected_tos );

										foreach my $todo ( @todolist )
										{
											my @listtodo = @{ $todo->{actions} };
											my @parameters =  @{ $todo->{parameters} };
											foreach my $parameter ( @parameters )
											{
												foreach my $inst ( @instances )
												{
													my %d = %{ $inst };
													my $countcase_ = $d{countcase};
													my $countblock_ = $d{countblock};
													my $countvar_ = $d{countvar};
													my $countstep_ = $d{countstep};
													my $to_ = $d{to}{crypto};

													if ( $parameter == $countvar )
													{
														push ( @expected_instances, $inst );
														push ( @expected_tos, $to_ );
													}
												}
											}


											my ( @nondone_tos, @nondone_instances );
											my $countinst = 0;
											foreach ( @expected_tos )
											{
												my $expected_instance = $expected_instances[ $countinst ];
												my $expected_to = $expected_tos[ $countinst ];


												if ( not ( grep { $_ eq $expected_to } @{ $done_tos[ $countvar ] } ) )
												{
													push ( @nondone_tos, $expected_to );
													push ( @nondone_instances, $expected_instance );
												}
												$countinst++;
											}
											@nondone_tos = uniq( @nondone_tos );
											@nondone_instances = uniq( @nondone_instances );

											my $numberof = scalar( @nondone_instances );
											my $cou = 0;
											my $countt = 1;
											foreach my $inst ( @nondone_instances )
											{

												$countt++;
												my $numberdone = ( $cou + 1 );
												my %d = %{ $inst };
												my $countcase = $d{countcase};
												my $countblock = $d{countblock};
												my @miditers = @{ $d{miditers} };
												my @winneritems = @{ $d{winneritems} };
												my $countvar = $d{countvar};
												my $countstep = $d{countstep};

												my $stepsvar = Sim::OPT::getstepsvar( $countvar, $countcase, \@varinumbers );

												foreach my $todo ( @todolist )
												{
													my @listtodo = @{ $todo->{actions} };
													foreach my $action ( @listtodo )
													{
														if ( not ( eval ( $skip ) ) )
														{
															my $newlaunchline;
															unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
															{
																$newlaunchline = " -file $to/cfg/$fileconfig -mode script";
															}
															else
															{
																$newlaunchline = " -file $to\\cfg\\$fileconfig -mode script";
															}


															if ( ( defined( $constrain_geometry[ $countop ] ) ) and ( ( $action eq "read_geo" ) or ( $action_ eq "write_geo" ) ) )
															{

																my ( $v_ref ) = constrain_geometry
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, \@constrain_geometry, $countvar, $fileconfig, \@v_, $countmorphing, $exeonfiles, \@v_, $action, $newlaunchline, \@menus, $countinstance );
																@v = @$v_ref;
																@v_ = @$v__ref;
															}

															if ( ( defined( $genprop[$countop] ) ) and ( ( $action eq "read_gen" ) or ( $action eq "write_gen" ) ) )
															{

																say $tee "WORKING EX-POST ON NON-YET-UPDATED INSTANCES AFTER LAST MORPHED INSTANCE. NOw INSTANCE $numberdone OF $numberof.";
																( $names_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref ) =
																	genprop ( $to_, $stepsvar_, $countop, $countstep_,
																		\@applytype, $genchange, $countvar_, $fileconfig, $mypath, $file, $countmorphing, $action_,
																		$names_ref, $nums_ref, $newcontents_ref, $filecontents_ref,
																		$newfilecontents_ref, $newlaunchline, \@menus, $countinstance );
																		%nums = %$nums_ref;
																		%names = %$names_ref;
																		%newcontents = %$newcontents_ref;
																		@filecontents = @$filecontents_ref;
																		@newfilecontents = @$newfilecontents_ref;
															}

															if ( defined ( $constrain_obstructions[$countop] ) and ( ( $action eq "read_obs" ) or ( $action eq "write_obs" ) ) )
															{
																my ( $obs_ref, $obs__ref ) = constrain_obstructions
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, \@constrain_obstructions, $countvar, $fileconfig, $countmorphing, $exeonfiles, $obs_ref, $obs__ref, $action, $newlaunchline, \@menus, $countinstance );
																	@obs = @$obs_ref;
																	@obs_ = @$obs__ref;
															}

															if ( defined( $constrain_net[$countop] ) and ( ( $action eq "read_net" ) or ( $action eq "write_net" ) ) )
															{
																my ( $node_ref, $component_ref, $donode_ref, $docomponent_ref ) = constrain_net( $to, $stepsvar, $countop,
																	$countstep, \@applytype, \@constrain_net, $countvar, $fileconfig, $countmorphing, $exeonfiles, $action,
																	$node_ref, $component_ref, $donode_ref, $docomponent_ref, $newlaunchline, \@menus, $countinstance );
																	@node = @$node_ref;
																	@component = @$component_ref;
																	@donode = @$donode_ref;
																	@docomponent = @$docomponent_ref;
															}

															if ( defined( $constrain_controls[$countop] ) and ( ( $action eq "read_ctl" ) or ( $action eq "write_ctl" ) ) )
															{
																my ( $loopcontrol_ref, $flowcontrol_ref, $new_loopcontrol_ref, $new_flowcontrol_ref ) = constrain_controls
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, \@constrain_controls, $countvar, $fileconfig, $countmorphing, $exeonfiles, $action,
																	$loopcontrol_ref, $flowcontrol_ref, $new_loopcontrol_ref, $new_flowcontrol_ref, $newlaunchline, \@menus, $countinstance  );
																	@loopcontrol = @$loopcontrol_ref;
																	@flowcontrol = @$flowcontrol_ref;
																	@new_loopcontrol = @$new_loopcontrol_ref;
																	@new_flowcontrol = @$new_flowcontrol_ref;
															}

															if ( defined( $apply_constraints[$countop] ) and ( $action eq "apply_constraints" ) )
															{
																apply_constraints
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, \@apply_constraints, $countvar, $fileconfig, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}

															if ( defined( $pin_obstructions->[ $countop ] ) and ( $action eq "pin_obstructions" ) )
															{
																pin_obstructions
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, $pin_obstructions, $countvar, $fileconfig, $mypath, $file, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}

															if ( defined( $recalculatenet[$countop] ) and ( $action eq "recalculatenet" ) )
															{
																recalculatenet
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, \@recalculatenet, $countvar, $fileconfig, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}

															if ( defined( $recalculateish->[$countop] ) and ( $action eq "recalculateish" ) )
															{   say $tee "FOR $to CALLED \$recalculateish EX-POST " . dump( $recalculateish );
																recalculateish
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, $recalculateish, $countvar, $fileconfig, $mypath, $file, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}

															if ( defined( $rebuildconstr->[$countop] ) and ( $action eq "rebuildconstr" ) )
															{   say $tee "FOR $to CALLED \$rebuildconstr EX-POST " . dump( $rebuildconstr );
																rebuildconstr
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, $rebuildconstr, $countvar, $fileconfig, $mypath, $file, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}

															if ( defined( $daylightcalc->[$countop] )  and ( $action eq "daylightcalc" ) )
															{
																daylightcalc
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, $filedf, \@daylightcalc, $countvar, $fileconfig, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}


															if ( defined( $use_modish->[$countop] )  and ( $action eq "use_modish" ) )
															{   say $tee "FOR $to CALLED \$use_modish EX-POST " . dump( $use_modish );
																use_modish
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, $use_modish, $countvar, $fileconfig, $mypath, $file, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}
															if ( defined( $export_toenergyplus->[$countop] )  and ( $action eq "export_toenergyplus" ) )
															{
																export_toenergyplus
																( $to, $stepsvar, $countop,
																	$countstep, \@applytype, $export_toenergyplus, $countvar, $fileconfig, $mypath, $file, $countmorphing, $newlaunchline, \@menus, $countinstance );
															}

														}
													}
												}
												$cou++;
											}
										}
									}
								}
								$countop++;
								print `cd $mypath`;
								#print $tee "cd $mypath\n\n";
							}
						}
					}
				}
				#if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 13, EXECUTING ";
				$countmorphing++;
			} #########

		}########
		close MORPHLIST;
		close MORPHBLOCK;
		$counti++;
	}
	close TOFILE;
	close OUTFILE;
	#if ( $d{treated} eq "treated" ){ print $tee "TREATED: $d{treated} "; }; say $tee "ARRIVED IN MORPH 14, EXITING ";
	#return ( \@morphcases, \@morphsruct, \%inst );
	return ( \@morphcases, \@morphsruct );
}    # END SUB morph


############################################ GENERAL FUNCTIONS


sub decreasearray
{
	my @arr = @_;
	my @newarr;
	foreach ( @arr )
	{
		push ( @newarr, ( $_ - 1 ) );
	}
	return ( @newarr );
}

sub deg2rad_
{
	my $degrees = shift;
	return ( ( $degrees / 180 ) * 3.14159265358979 );
}

sub rad2deg_
{
	my $radians = shift;
	return ( ( $radians / 3.14159265358979 ) * 180 );
}


sub purifyarray
{
	my @elts = @_;
	my @cleanarr;
	foreach my $elt ( @elts )
	{
		if ( not ( $elt eq "" ) )
		{
			push ( @cleanarr, $elt );
		}
	}
	return ( @cleanarr );
}

sub supercleanarray
{
	my @elts = @_;
	my @cleanarr;
	foreach my $elt ( @elts )
	{
		if ( ( not ( $elt eq "" ) ) and ( not ( $elt eq " " ) ) )
		{
			push ( @cleanarr, $elt );
		}
	}
	return ( @cleanarr );
}

sub replace_nth
{
	my ( $row, $nposition, $string, $newstring ) = @_;
	$row =~ s/((?:$string.*?){$nposition})$string/${1}$newstring/;
	return ( $row );
}

sub rotate2dabs # CHECK! ZZZ
{
		my ( $x, $y, $angle ) = @_;
		$angle = deg2rad_( $angle );
		my $x_new = cos($angle)*$x - sin($angle)*$y;
		my $y_new = sin($angle)*$x + cos($angle)*$y;
	return ( $x_new, $y_new);
}

sub rotate2d {
		my ( $x, $y, $angle, $centrex, $centrey ) = @_;
		$angle = deg2rad_( $angle );
		my $tempx = ( $x - $centrex );
		my $tempy = ( $y - $centrey );
		my $x_temp_new = cos($angle)*$tempx - sin($angle)*$tempy;
		my $y_temp_new = sin($angle)*$tempx + cos($angle)*$tempy;
		my $x_new = ( $x_temp_new + $centrex );
		my $y_new = ( $y_temp_new + $centrey );
	return ( $x_new, $y_new);
}

sub rotate3d # CHECK! ZZZ
{
	my ( $vertices_ref, $angle, $centre_ref, $plantype, $flatten ) = @_;
	my @vertices = @$vertices_ref; #print $tee  "\@vertices: " . Dumper( @vertices ) . "\n";
	my @centreverts = @$centre_ref; #print $tee "centreverts; @centreverts \n";
	my ( $centre_x, $centre_y, $centre_z ) = @centreverts;
	print "centre_x; $centre_x \n"; #print $tee "centre_y; $centre_y \n"; print "centre_z; $centre_z \n";

	my @newbag;

	foreach $vertex_ref ( @vertices )
	{
		( $x, $y, $z ) = ( $vertex_ref->[0], $vertex_ref->[1], $vertex_ref->[2]); #$print $tee "x; $x \n"; print "y; $y \n"; print "z; $z \n";
		if ( $plantype eq "xy" )
		{
			my ( $newx, $newy ) = rotate2d( $x, $y, $angle, $centre_x, $centre_y );
			$newx = sprintf( "%.3f", $newx );
			$newy = sprintf( "%.3f", $newy );
			if ( $flatten eq "" )
			{
				push ( @newbag, [ $newx, $newy, $z ] );
			}
			elsif ( $flatten eq "x")
			{
				push ( @newbag, [ $x, $newy, $z ] );
			}
			elsif ( $flatten eq "y")
			{
				push ( @newbag, [ $newx, $y, $z ] );
			}
		}
		elsif ( $plantype eq "xz" )
		{
			my ( $newx, $newz ) = rotate2d( $x, $z, $angle, $centre_x, $centre_z );
			$newx = sprintf( "%.3f", $newx );
			$newz = sprintf( "%.3f", $newz );
			if ( $flatten eq "" )
			{
				push ( @newbag, [ $newx, $y, $newz ] );
			}
			elsif ( $flatten eq "z")
			{
				push ( @newbag, [ $newx, $y, $z ] );
			}
			elsif ( $flatten eq "x")
			{
				push ( @newbag, [ $x, $y, $newz ] );
			}
		}
		elsif ( $plantype eq "yz" )
		{
			my ( $newy, $newz ) = rotate2d( $y, $z, $angle, $centre_y, $centre_z );
			$newy = sprintf( "%.3f", $newy );
			$newz = sprintf( "%.3f", $newz );
			if ( $flatten eq "" )
			{
				push ( @newbag, [ $x, $newy, $newz ] );
			}
			elsif ( $flatten eq "z")
			{
				push ( @newbag, [ $x, $newy, $z  ] );
			}
			elsif ( $flatten eq "y")
			{
				push ( @newbag, [ $x, $y, $newz  ] );
			}
		}
	}
	return ( \@newbag );
}



sub fixlength
{
	my ( $el, $newel, $adjustanswer ) = @_;

	my $length = length( $el );

	my $truenewel;
	if ( ( $el < 0 ) and ( $adjustanswer eq "y" ) )
	{
		if ( not ( $el =~ /\./ ) )
		{

			my $thisel = "$el" . ".000";
		}
		else
		{
			$truenewel = substr( $newel, 0, $length );
		}
	}
	elsif ( ( $el >= 0 ) and ( $newel < 0 ) and ( $adjustanswer eq "y" ) )
	{
		my $adjustedlengt;
		if ( not ( $el =~ /\./ ) )
		{
			my $thisel = "$el" . ".000";
			$adjustedlength = length( $thisel );
			$truenewel = substr( $newel, 0, $adjustedlength);
		}
		$truenewel = " " . "$truenewel";
	}
	elsif ( ( $el >= 0 ) and ( $newel < 0 ) and ( $adjustanswer eq "y" ) )
	{
		if ( $el =~ /\./ )
		{
			my $thisel = "$el" . "000";
			$adjustedlength = length( $thisel );
			$truenewel = substr( $newel, 0, $adjustedlength);
		}
	}
	elsif ( ( $el >= 0 ) and ( $newel >= 0 ) and ( $adjustanswer eq "y" ) )
	{
		my $adjustedlength ;
		if ( not ( $el =~ /\./ ) )
		{
			my $thisel = "$el" . ".000";
			$adjustedlength = length( $thisel );
			$truenewel = substr( $newel, 0, $adjustedlength);
		}
		$truenewel = " " . "$truenewel";
	}

	$truenewel = sprintf( "%.3f", $truenewel );

	if ( ( $el >= 0 ) and ( $newel => 0 ) and ( $adjustanswer eq "n" ) )
	{
		if ( $el =~ /\./ )
		{
			$newel = $newel . "000";
		}
		$truenewel = substr( $newel, 0, $length);
	}

	return ( "$el", "$truenewel" );
}

sub purifydata
{  # IT BRINGS ALL THE NUMBERS IN A LIST OF LIST (LIKE: VERTEXES) IN A FILE AT THE SAME LENGTH OF ANOTHER SPECIFIED LIST
	my ( $modelarr_ref, $newarr_ref ) = @_;
	@modelarr = @$modelarr_ref;
	@newarr = @$newarr_ref;

	my $countout = 0;
	foreach my $row ( @modelarr )
	{
		my $rownew = $newarr[ $countout ];
		my $countin = 0;
		foreach my $elt ( @$row )
		{
			my $newelt = $rownew->[ $countin ] ;
			if ( ( $newelt ne $elt ) or ( $newelt =! $elt ) )
			{
				$newarr_ref->[ $countout ][ $countin ] = fixlength( "$elt", "$newelt" );
			}
			$countin++;
		}
		$countout++;
	}
	return( $newarr_ref );
}

sub gatherseparators
{
	my ( $string ) = @_;

	my @chars = split( "", $string );

	my @bag;
	foreach my $char ( @chars )
	{

		if ( $char =~ /(,|;)/ )
		{
			push ( @bag, $char );
		}
	}
	return ( @bag );
}


############################################ END OF GENERAL FUNCTIONS


sub translate
{
	my ( $to, $stepsvar, $countop, $countstep, $swap, $translate, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;
	my @applytype = @$swap;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Translating zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	if ( $stepsvar > 1 )
	{
		my $yes_or_no_translate_obstructions = "$$translate[$countop][0]";
		my $yes_or_no_update_radiation =  $$translate[$countop][2];

		if ( $yes_or_no_update_radiation eq "y" )
		{
			$yes_or_no_update_radiation = "a";
		}
		else
		{
			$yes_or_no_update_radiation = "c";
		}

		my @coordinates_for_movement = @{ $$translate[$countop][1] };
		my ( $x_begin, $y_begin, $z_begin, $x_end, $y_end, $z_end, $x_swing, $y_swing, $z_swing, $x_value, $y_value, $z_value );
		my ( @coord2, @coord1 );

		if ( ref( $coordinates_for_movement[0] ) )
		{
			@coord1 = @{ $coordinates_for_movement[0] };
			@coord2 = @{ $coordinates_for_movement[1] };
			( $x_begin, $y_begin, $z_begin ) = @coord1;
			( $x_end, $y_end, $z_end ) = @coord2;

			$x_swing = ( $x_end - $x_begin );
			$y_swing = ( $y_end - $y_begin );
			$z_swing = ( $z_end - $z_begin );

			$x_pace = ( $x_swing / ( $stepsvar - 1 ) );
			$y_pace = ( $y_swing / ( $stepsvar - 1 ) );
			$z_pace = ( $z_swing / ( $stepsvar - 1 ) );

			$x_value = ( $x_begin + ( $x_pace * ( $countstep - 1) ) );
			$y_value = ( $y_begin + ( $y_pace * ( $countstep - 1) ) );
			$z_value = ( $z_begin + ( $z_pace * ( $countstep - 1) ) );

		}
		else
		{
			$x_end = $coordinates_for_movement[0];
			$x_swing = ( 2 * $x_end );
			$x_base = $base[0];

			$y_end = $coordinates_for_movement[1];
			$y_swing = ( 2 * $y_end );
			$y_base = $base[1];

			$z_end = $coordinates_for_movement[2];
			$z_swing = ( 2 * $z_end );
			$z_base = $base[2];

			$x_pace = ( $x_swing / ( $stepsvar - 1 ) );
			$x_value = ($x_base + ( $x_end - ( $x_pace * ( $countstep - 1 ) ) ));
			$y_pace = ( $y_swing / ( $stepsvar - 1 ) );
			$y_value = ($y_base + ( $y_end - ( $y_pace * ( $countstep - 1 ) ) ));
			$z_pace = ( $z_swing / ( $stepsvar - 1 ) );
			$z_value = ($z_base + ( $z_end - ( $z_pace * ( $countstep - 1 ) ) ));
		}

		$x_value = sprintf( "%.3f", $x_value );
		$y_value = sprintf( "%.3f", $y_value );
		$z_value = sprintf( "%.3f", $z_value );

my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
i
e
$x_value $y_value $z_value
y
$yes_or_no_translate_obstructions
-
y
c
-
-
-
-
-
-
-
-
-
YYY
";

		unless ($exeonfiles eq "n")
		{
			print `$printthis`; say $tee "$printthis"
		}

		my $pinobs =  $$translate[$countop][3];
		if ( defined( $pinobs ) and ref( $pinobs ) )
		{
			my @infos = @{ $pinobs };
			my $sourcefile = shift( @infos );
		  my $sourcepath = "$mypath/$file/zones/$sourcefile";
			my %keeplines ;
			my @newlines;
			open ( SOURCEFILE, $sourcepath ) or die( "$!" );
			my @sourcelines = <SOURCEFILE>;
			close SOURCEFILE;

			foreach my $obs ( @infos )
			{
				foreach my $line ( @sourcelines )
				{
					if  ( ( $line =~ /^\*obs/ ) and ( $line =~ / $obs$/ ) )
					{
						$keeplines{$obs} = $line ;
					}
				}
			}
			my $targetpath = "$to/zones/$sourcefile";
			my $oldfile = $targetpath . ".old";


			`mv -f $targetpath $oldfile`;
			#print $tee "mv -f $targetpath $oldfile\n";

			open( OLDFILE, $oldfile ) or die( "$!" );
			my @oldlines = <OLDFILE>;
			close OLDFILE;
			open ( NEWFILE, ">$targetpath" ) or die( "$!" );

			foreach my $line ( @oldlines )
			{
				if ( $line =~ /^\*obs/ )
				{
					foreach my $obs ( keys %keeplines )
					{
						if  ( $line =~ / $obs$/ )
						{
							$line = $keeplines{$obs};
						}
					}
				}
				print NEWFILE $line;
			}
			close NEWFILE;
		}

		print $tee "#Translating zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.\" $printthis";
	}
} # end sub translate


sub translate_surfaces
{
	my ( $to, $stepsvar, $countop, $countstep, $swap, $translate_surface, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;


	my @applytype = @$swap;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Translating surfaces for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $transform_type = $$translate_surface[$countop][0];
	my @surfs_to_transl = @{ $translate_surface->[$countop][1] };
	my @ends_movs = @{ $translate_surface->[$countop][2] };
	my $yes_or_no_update_radiation = $$translate_surface[$countop][3];
	my @transform_coordinates = @{ $translate_surface->[$countop][2] };
	my $countsurface = 0;
	my ( $end_mov, $mov_surf, $pace, $movement, $surface_letter_constrainedarea, $movement_constrainedarea, $pace, $swing_surf, $movement, $base );

	foreach my $surface_letter (@surfs_to_transl)
	{

		if ( $stepsvar > 1 )
		{

			if ($transform_type eq "a")
			{
				$end_mov = $ends_movs[$countsurface];
				if ( ref ( $end_mov ) )
				{
					my $min = $end_mov->[0];
					my $max = $end_mov->[1];
					$swing_surf = ( $max - $min );
					$base = $min;
				}
				else
				{
					$swing_surf = ( $end_mov * 2 );
					$base = - ( $swing_surf / 2 );
				}

				$pace = ( $swing_surf / ( $stepsvar - 1 ) );
				$movement = ( $base + ( $pace * ( $countstep - 1) ) );



				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
e
>
$surface_letter
$transform_type
$movement
y
-
-
y
c
-
-
-
-
-
-
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				print $tee "#Translating surfaces for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance
				$printthis";

				$countsurface++;
				$countcycles_transl_surfs++;
			}
			elsif ($transform_type eq "b")
			{
				my @coordinates_for_movement = @{ $transform_coordinates[$countsurface] };
				my ( $x_begin, $y_begin, $z_begin, $x_end, $y_end, $z_end, $x_swing, $y_swing, $z_swing, $x_value, $y_value, $z_value );
				my ( @coord2, @coord1 );

				if ( ref( $coordinates_for_movement[0] ) )
				{
					@coord1 = @{ $coordinates_for_movement[0] };
					@coord2 = @{ $coordinates_for_movement[1] };
					( $x_begin, $y_begin, $z_begin ) = @coord1;
					( $x_end, $y_end, $z_end ) = @coord2;

					$x_swing = ( $x_end - $x_begin );
					$y_swing = ( $y_end - $y_begin );
					$z_swing = ( $z_end - $z_begin );

					$x_pace = ( $x_swing / ( $stepsvar - 1 ) );
					$y_pace = ( $y_swing / ( $stepsvar - 1 ) );
					$z_pace = ( $z_swing / ( $stepsvar - 1 ) );

					$x_value = ( $x_begin + ( $x_pace * ( $countstep - 1) ) );
					$y_value = ( $y_begin + ( $y_pace * ( $countstep - 1) ) );
					$z_value = ( $z_begin + ( $z_pace * ( $countstep - 1) ) );

				}
				else
				{
					$x_end = $coordinates_for_movement[0];
					$x_swing = ( 2 * $x_end );
					$x_base = $base[0];

					$y_end = $coordinates_for_movement[1];
					$y_swing = ( 2 * $y_end );
					$y_base = $base[1];

					$z_end = $coordinates_for_movement[2];
					$z_swing = ( 2 * $z_end );
					$z_base = $base[2];

					$x_pace = ( $x_swing / ( $stepsvar - 1 ) );
					$x_value = ($x_base + ( $x_end - ( $x_pace * ( $countstep - 1 ) ) ));
					$y_pace = ( $y_swing / ( $stepsvar - 1 ) );
					$y_value = ($y_base + ( $y_end - ( $y_pace * ( $countstep - 1 ) ) ));
					$z_pace = ( $z_swing / ( $stepsvar - 1 ) );
					$z_value = ($z_base + ( $z_end - ( $z_pace * ( $countstep - 1 ) ) ));
				}

				$x_value = sprintf( "%.3f", $x_value );
				$y_value = sprintf( "%.3f", $y_value );
				$z_value = sprintf( "%.3f", $z_value );

				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
e
>
$surface_letter
$transform_type
$x_value $y_value $z_value
y
-
-
y
c
-
-
-
-
-
-
-
-
YYY
";

				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}

				print $tee "#Translating surfaces for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance
$printthis";

				$countsurface++;
				$countcycles_transl_surfs++;
			}
		}
	}
}    # END SUB translate_surfaces


sub rotate_surface
{
	my ( $to, $stepsvar, $countop, $countstep, $applytyperef, $rotate_surface, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytyperef;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Rotating surfaces for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @surfs_to_rotate =  @{ $rotate_surface->[$countop][0] };
	my @vertices_numbers =  @{ $rotate_surface->[$countop][1] };
	my @swingrotations = @{ $rotate_surface->[$countop][2] };
	my @yes_or_no_apply_to_others = @{ $rotate_surface->[$countop][3] };
	my $configfile = $$rotate_surface[$countop][4];
	my ( $base, $swingrotate, $pacerotate, $rotation_degrees, $vertex_number, $yes_or_no_apply );

	my $countrotate = 0;
	foreach my $surface_letter (@surfs_to_rotate)
	{
		$swingrotate = $swingrotations[$countrotate];

		if ( ref ( $swingrotate ) )
		{
			my $min = $swingrotate->[0];
			my $max = $swingrotate->[1];
			$swingrotate = ( $max - $min );
			$base = $min;
		}
		else
		{
			$swingrotate = ( 2 * $swingrotate );
			$base = - ( $swingrotate / 2 );
		}

		$pacerotate = ( $swingrotate / ( $stepsvar - 1 ) );
		$rotation_degrees = $base + ( $pacerotate * ( $countstep - 1 ) ) ;
		$vertex_number = $vertices_numbers[$countrotate];
		$yes_or_no_apply = $yes_or_no_apply_to_others[$countrotate];

		if ( $rotation_degrees < -100 )
		{
			$rotation_degrees = ( $rotation_degrees + 360 );
		}

		if (  ( $swingrotate != 0 ) and ( $stepsvar > 1 ) )
		{
			my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
e
>
$surface_letter
c
$vertex_number
$rotation_degrees
$yes_or_no_apply
-
-
y
c
-
-
-
-
-
-
-
-
YYY
";
			unless ($exeonfiles eq "n")
			{
				print `$printthis`;
			}

			print  $tee "
Rotating surfaces for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance
$printthis";
		}
		$countrotate++;
	}
} # END SUB rotate_surface


sub translate_vertices
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $translate_vertices_ref,
		$countvar, $fileconfig , $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my @translate_vertices = @$translate_vertices_ref;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] }; #say $tee "IN MORPH VERTS_TO_TRANSL: \%numvertmenu" . dump( %numvertmenu );
	my %vertnummenu = %{ $menus[1] }; #say $tee "IN MORPH VERTS_TO_TRANSL: \%vertnummenu" . dump( %vertnummenu );

	say $tee "Translating vertices for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @v;
	my @verts_to_transl = @{ $translate_vertices[$countop][0] }; #say $tee "IN MORPH VERTS_TO_TRANSL: " . dump( @verts_to_transl );
	my @transform_coordinates = @{ $translate_vertices[$countop][1] };
	my @sourcefiles = @{ $translate_vertices[$countop][2] };

	my $sourcefile = $sourcefiles[0]; #say $tee "HERE \sourcefile: $sourcefile";
	my $sourceaddress = "$to$sourcefile"; #say $tee "HERE \sourceaddress: $sourceaddress";
	# my $zone_letter = $sourcefiles[1];
	my $zone_letter = $applytype[$countop][3]; #say $tee "HERE ZONE_LETTER: $zone_letter";

	open( SOURCEFILE, $sourceaddress ) or die "Can't open $sourceaddress 2: $!\n";
	my @lines = <SOURCEFILE>;
	close SOURCEFILE;

	my %verts = %numvertmenu; #say $tee "HERE \%verts: " . dump( \%verts );

	foreach my $vert ( @verts_to_transl )
	{
		my $vertnum = $vertnummenu{$vert};
		foreach my $line ( @lines )
		{
			$line =~ s/^\s+//;
			my @rowelts = split(/\s+|,/, $line);
			if   ($rowelts[0] eq "*vertex" )
			{
				if ( $rowelts[5] eq $vertnum )
				{
					push (@v, [ $rowelts[1], $rowelts[2], $rowelts[3], $vertnum ] ); #say $tee "\@v: " . dump( \@v );
				}
			}
		}
	}

	my $countvertex = 0;
	foreach my $base_coordinates_ref ( @transform_coordinates )
	{
		#my $vertex_letter = $verts{ $verts_to_transl[ $countvertex ] }; say $tee "\$vertex_letter: $vertex_letter";
		my $vertex_letter = $verts_to_transl[$countvertex]; #say $tee "\$vertex_letter: $vertex_letter";

		my @basevs = @{ $v[ $countvertex ] };
		my ( $x_base, $y_base, $z_base, $vertex_number ) = ( $basevs[0], $basevs[1], $basevs[2], $basevs[3] ); #say $tee "\$vertex_number: $vertex_number";

		my @base_coordinates = @{ $base_coordinates_ref };

		my $x_end = $base_coordinates[0];
		if ( ref ( $x_end ) )
		{
			my $min = $base_coordinates[0][0];
			my $max = $base_coordinates[1][0];
			$x_swing = ( $max - $min );
			$x_base = $x_base - $min;
		}
		else
		{
			$x_swing = ( 2 * $x_end );
			$x_base = $x_base - ( $x_swing / 2 );
		}

		my $y_end = $base_coordinates[1];
		if ( ref ( $y_end ) )
		{
			my $min = $base_coordinates[0][1];
			my $max = $base_coordinates[1][1];
			$y_swing = ( $max - $min );
			$y_base = $y_base - $min;
		}
		else
		{
			$y_swing = ( 2 * $y_end );
			$y_base = $y_base - ( $y_swing / 2 );
		}

		my $z_end = $base_coordinates[2];
		if ( ref ( $z_end ) )
		{
			my $min = $base_coordinates[0][2];
			my $max = $base_coordinates[1][2];
			$z_swing = ( $max - $min );
			$z_base = $z_base - $min;
		}
		else
		{
			$z_swing = ( 2 * $z_end );
			$z_base = $z_base - ( $z_swing / 2 );
		}

		my $x_pace = ( $x_swing / ( $stepsvar - 1 ) );
		my $x_new = ( $x_base + ( $x_pace * ( $countstep - 1 ) ) );

		my $y_pace = ( $y_swing / ( $stepsvar - 1 ) );
		my $y_new = ( $y_base + ( $y_pace * ( $countstep - 1 ) ) );

		my $z_pace = ( $z_swing / ( $stepsvar - 1 ) );
		my $z_new = ( $z_base + ( $z_pace * ( $countstep - 1 ) ) );

		$x_new = sprintf( "%.3f", $x_new );
		$y_new = sprintf( "%.3f", $y_new );
		$z_new = sprintf( "%.3f", $z_new );

		my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
d
$vertex_letter
$x_new $y_new $z_new
-
-
y
c
-
-
-
-
-
-
YYY
";
		unless ($exeonfiles eq "n")
		{
			print `$printthis`;
		}

		print $tee "#Translating vertices for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
		$countvertex++;
	}
} # END SUB translate_vertices


sub shift_vertices
{
	my ( $to, $stepsvar, $countop, $countstep, $swap, $shift_vertices, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$swap;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Shifting vertices for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my ( $pace, $movement );
	my $movementtype = $$shift_vertices[$countop][0];
	my @pairs_of_vertices = @{ $$shift_vertices[$countop][1] };
	my @shift_swings = @{ $$shift_vertices[$countop][2] };
	my $yes_or_no_radiation_update = $$shift_vertices[$countop][3];
	my $configfile = $$shift_vertices[$countop][4];
	my ( $base );

	if ( $stepsvar > 1 )
	{
		my $countthis = 0;
		if ($movementtype eq "j")
		{
		foreach my $shift_swing (@shift_swings)
			{

				if ( ref ( $shift_swing ) )
				{
					my $min = $shift_swing->[0];
					my $max = $shift_swing->[1];
					$base = $min;
					$shift_swing = ( $max - $min );
				}
				else
				{
					$shift_swing = ( $shift_swing * 2 );
					$base = - ( $shift_swing / 2 );
				}

				$pace = ( $shift_swing / ( $stepsvar - 1 ) );
				$movement_or_vertex = ( $base + ( $pace * ( $countstep - 1 ) ) );
				$vertex1 = ( $pairs_of_vertices[ 0 + ( 2 * $countthis ) ] );
				$vertex2 = ( $pairs_of_vertices[ 1 + ( 2 * $countthis ) ] );

				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
d
^
$movementtype
$vertex1
$vertex2
-
$movement_or_vertex
y
-
y
-
y
-
-
-
-
-
-
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				print $tee "#Shifting vertices for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";

				$countthis++;
			}
		}
		elsif ($movementtype eq "h")
		{
			foreach my $shift_swing (@shift_swings)
			{
				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
d
^
$movementtype
$vertex1
$vertex2
-
$movement_or_vertex
-
y
n
n
n
-
y
-
y
-
-
-
-
-
-
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				print $tee "#Shifting vertices for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
			}
		}
	}
}    # END SUB shift_vertices


sub rotate    # generic zone rotation
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $rotate, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Rotating zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my ( $rotation_degrees, $pacerotate, $base );
	my $swingrotate = $$rotate[$countop][1];
	my $yes_or_no_rotate_obstructions = $$rotate[$countop][0];
	my $yes_or_no_update_radiation = $$rotate[$countop][2];
	my $base_vertex = $$rotate[$countop][3];


	if ( ref ( $swingrotate ) )
	{
		my $begin = $swingrotate->[0];
		my $end = $swingrotate->[1];
		$swingrotate = ( $end - $begin );
		$base = $begin;
	}
	else
	{
		$swingrotate = ( $swingrotate * 2 );
		$base = - ( $swingrotate / 2 );
	}

	$pacerotate = ( $swingrotate / ( $stepsvar - 1 ) );
	$rotation_degrees = ( $base + ( $pacerotate * ( $countstep - 1 ) ) );

	my $count_rotate = 0;

	if ( $rotation_degrees < -100 )
	{
		$rotation_degrees = ( $rotation_degrees + 360 );
	}

	if ( ( $swingrotate != 0 ) and ( $stepsvar > 1 ) )
	{

		my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
i
b
$rotation_degrees
$base_vertex
-
$yes_or_no_rotate_obstructions
-
y
c
-
y
-
-
-
-
-
-
-
-
YYY
";

		unless ($exeonfiles eq "n")
		{
			print `$printthis`; say $tee "$printthis";
		}


		my $pinobs =  $$rotate[$countop][4];
		if ( defined( $pinobs ) and ref( $pinobs ) )
		{
			my @infos = @{ $pinobs };
			my $sourcefile = shift( @infos );
			my $sourcepath = "$mypath/$file/zones/$sourcefile";
			my %keeplines ;
			my @newlines;
			open ( SOURCEFILE, $sourcepath ) or die( "$!" );
			my @sourcelines = <SOURCEFILE>;
			close SOURCEFILE;

			foreach my $obs ( @infos )
			{
				foreach my $line ( @sourcelines )
				{
					if  ( ( $line =~ /^\*obs/ ) and ( $line =~ / $obs$/ ) )
					{
						$keeplines{$obs} = $line ;
					}
				}
			}
			my $targetpath = "$to/zones/$sourcefile";
			my $oldfile = $targetpath . ".old";


			`mv -f $targetpath $oldfile`;
			#print $tee "mv -f $targetpath $oldfile\n";

			open( OLDFILE, $oldfile ) or die( "$!" );
			my @oldlines = <OLDFILE>;
			close OLDFILE;
			open ( NEWFILE, ">$targetpath" ) or die( "$!" );

			foreach my $line ( @oldlines )
			{
				if ( $line =~ /^\*obs/ )
				{
					foreach my $obs ( keys %keeplines )
					{
						if  ( $line =~ / $obs$/ )
						{
							$line = $keeplines{$obs};
						}
					}
				}
				print NEWFILE $line;
			}
			close NEWFILE;
		}




		#print $tee		"#Rotating zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.$printthis";
	}
} # END SUB rotate


sub rotatez # PUT THE ROTATION POINT AT POINT 0, 0, 0. I HAVE NOT YET MADE THE FUNCTION GENERIC ENOUGH.
{
	my ( $to, $stepsvar, $countop, $countstep, $swap, $rotatez, $countvar, $fileconfig, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$swap;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Rotating zones on the vertical plane for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @centerpoints = @{$$rotatez[0]};
	my $centerpointsx = $centerpoints[0];
	my $centerpointsy = $centerpoints[1];
	my $centerpointsz = $centerpoints[2];
	my $plane_of_rotation = "$$rotatez[1]";
	 my $infile = "$to/zones/$applytype[$countop][2]";
	my $infile2 = "$to/cfg/$applytype[$countop][2]";
	my $outfilemorph = "erase";
	my $outfile2 = "$to/zones/$applytype[$countop][2]eraseobtained";
	open( INFILE,  "$infile" )   or die "Can't open infile $infile: $!\n";
	open( $_outfile_2, ">>$outfile2" ) or die "Can't open outfile2 $outfile2: $!\n";
	my @lines = <INFILE>;
	close(INFILE);
	my $countline = 0;
	my $countcases = 0;
	my @vertices;
	my $swingrotate = $$rotatez[2];
	my $alreadyrotation = $$rotatez[3];
	my $rotatexy = $$rotatez[4];
	my $swingrotatexy = $$rotatez[5];

	if ( ref ( $swingrotate ) )
	{
		my $min = $swingrotate->[0];
		my $max = $swingrotate->[1];
		$swingrotatexy = ( $max - $min );
	}

	if ( ref ( $swingrotate ) )
	{
		my $min = $swingrotate->[0];
		my $max = $swingrotate->[1];
		$swingrotatexy = ( $max - $min );
	}

	my ( $pacerotate, $linenew, $linenew2 );
	my $count_rotate = 0;
	my ( @rowprovv, @rowprovv2, @row, @row2 );
	if ( $stepsvar > 1 )
	{
		foreach my $line (@lines)
		{#
			{
				$linenew = $line;
				$linenew =~ s/\:\s/\:/g ;
				@rowprovv = split(/\s+/, $linenew);
				$rowprovv[0] =~ s/\:\,/\:/g ;
				@row = split(/\,/, $rowprovv[0]);
				if ($row[0] eq "*vertex")
				{ push (@vertices, [$row[1], $row[2], $row[3]] ) }
			}
			$countline = $countline +1;
		}

		foreach $vertex (@vertices)
		{
			print $_outfile_ "vanilla ${$vertex}[0], ${$vertex}[1], ${$vertex}[2]\n";
		}
		foreach $vertex (@vertices)
		{
			${$vertex}[0] = (${$vertex}[0] - $centerpointsx);
			${$vertex}[0] = sprintf("%.5f", ${$vertex}[0]);
			${$vertex}[1] = (${$vertex}[1] - $centerpointsy);
			${$vertex}[1] = sprintf("%.5f", ${$vertex}[1]);
			${$vertex}[2] = (${$vertex}[2] - $centerpointsz);
			${$vertex}[2] = sprintf("%.5f", ${$vertex}[2]);
			print $_outfile_ "aftersum ${$vertex}[0], ${$vertex}[1], ${$vertex}[2]\n";
		}

		my $anglealready = deg2rad_(-$alreadyrotation);
		foreach $vertex (@vertices)
		{
			my $x_new = cos($anglealready)*${$vertex}[0] - sin($anglealready)*${$vertex}[1];
			my $y_new = sin($anglealready)*${$vertex}[0] + cos($anglealready)*${$vertex}[1];
			${$vertex}[0] = $x_new; ${$vertex}[0] = sprintf("%.5f", ${$vertex}[0]);
			${$vertex}[1] = $y_new; ${$vertex}[1] = sprintf("%.5f", ${$vertex}[1]);
			print $_outfile_ "afterfirstrotation ${$vertex}[0], ${$vertex}[1], ${$vertex}[2]\n";
		}

		$pacerotate = ( $swingrotate / ( $stepsvar - 1) );
		$rotation_degrees = - ( ($swingrotate / 2) - ($pacerotate * ($countstep -1) ) );
		my $angle = deg2rad_($rotation_degrees);
		foreach $vertex (@vertices)
		{
			my $y_new = cos($angle)*${$vertex}[1] - sin($angle)*${$vertex}[2];
			my $z_new = sin($angle)*${$vertex}[1] + cos($angle)*${$vertex}[2];
			${$vertex}[1] = $y_new; ${$vertex}[1] = sprintf("%.5f", ${$vertex}[1]);
			${$vertex}[2] = $z_new; ${$vertex}[2] = sprintf("%.5f", ${$vertex}[2]);
			${$vertex}[0] = sprintf("%.5f", ${$vertex}[0]);
			print $_outfile_ "aftersincos ${$vertex}[0], ${$vertex}[1], ${$vertex}[2]\n";
		}

		my $angleback = deg2rad_($alreadyrotation);
		foreach $vertex (@vertices)
			{
			my $x_new = cos($angleback)*${$vertex}[0] - sin($angleback)*${$vertex}[1];
			my $y_new = sin($angleback)*${$vertex}[0] + cos($angleback)*${$vertex}[1];
			${$vertex}[0] = $x_new; ${$vertex}[0] = sprintf("%.5f", ${$vertex}[0]);
			${$vertex}[1] = $y_new; ${$vertex}[1] = sprintf("%.5f", ${$vertex}[1]);
			print $_outfile_ "afterrotationback ${$vertex}[0], ${$vertex}[1], ${$vertex}[2]\n";ctl type
		}

		foreach $vertex (@vertices)
		{
			${$vertex}[0] = ${$vertex}[0] + $centerpointsx; ${$vertex}[0] = sprintf("%.5f", ${$vertex}[0]);
			${$vertex}[1] = ${$vertex}[1] + $centerpointsy; ${$vertex}[1] = sprintf("%.5f", ${$vertex}[1]);
			${$vertex}[2] = ${$vertex}[2] + $centerpointsz; ${$vertex}[2] = sprintf("%.5f", ${$vertex}[2]);
			print $_outfile_ "after final substraction ${$vertex}[0], ${$vertex}[1], ${$vertex}[2]\n";
		}

		my $countwrite = -1;
		my $countwriteand1;
		foreach $line (@lines)
		{#

				$linenew2 = $line;
				$linenew2 =~ s/\:\s/\:/g ;
				my @rowprovv2 = split(/\s+/, $linenew2);
				$rowprovv2[0] =~ s/\:\,/\:/g ;
				@row2 = split(/\,/, $rowprovv2[0]);
				$countwriteright = ($countwrite - 5);
				$countwriteand1 = ($countwrite + 1);
				if ($row2[0] eq "*vertex")
				{
					if ( $countwrite == - 1) { $countwrite = 0 }
					print $_outfile_2
					"*vertex"."\,"."${$vertices[$countwrite]}[0]"."\,"."${$vertices[$countwrite]}[1]"."\,"."${$vertices[$countwrite]}[2]"."  #   "."$countwriteand1\n";
				}
				else
				{
					print $_outfile_2 "$line";
				}
				if ( $countwrite > ( - 1 ) ) { $countwrite++; }
		}

		close($_outfile_);
		unless ($exeonfiles eq "n") { print `chmod 777 $infile`; }
		print $tee "chmod -R 777 $infile\n";
		unless ($exeonfiles eq "n") { print `chmod 777 $infile2`; }
		print $tee "chmod -R 777 $infile2\n";
		unless ($exeonfiles eq "n") { print `rm $infile`; }
		print $tee "rm $infile\n";
		unless ($exeonfiles eq "n") { print `chmod 777 $outfile2`; }
		print $tee "chmod 777 $outfile2\n";
		unless ($exeonfiles eq "n") { print `cp $outfile2 $infile`; }
		print $tee "cp $outfile2 $infile\n";
		unless ($exeonfiles eq "n") { print `cp $outfile2 $infile2`; }
		print $tee "cp $outfile2 $infile2\n";
	}
} # END SUB rotatez


sub reassign_construction
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $reassign_construction, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

        say $tee "AAA \$to $to"  ;
        say $tee "AAA \$stepsvar $stepsvar" ;
        say $tee "AAA \$countop $countop"  ;
        say $tee "AAA \$countstep $countstep" ;
	my @applytype = @{ $applytype_ref };
	my $zone_letter = $applytype[$countop][3];

	my @menus = @{ $menus_ref };
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Reassign construction solutions for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @surfaces_to_reassign = @{ $reassign_construction->[$countop][0] };
	my @groups_to_choose = @{ $reassign_construction->[$countop][1] };

	my $count = 0;
	foreach $surface_to_reassign ( @surfaces_to_reassign )
	{
		my $construction =  $groups_to_choose[$count]->[$countstep-1];
		my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
f
$surface_to_reassign
e
n
y
$construction
-
-
-
-
y
y
a
a
-
-
-
-
-
-
-
-
YYY
";
		unless ($exeonfiles eq "n")
		{
			`$printthis`;
		}
		print $tee "#Reassign construction solutions for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
		$count++;
	}
} # END SUB reassign_construction


sub change_thickness
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $thickness_change, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;
	my @applytype = @$applytype_ref;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Changing thicknesses in construction layer for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @entries_to_change = @{ $$thickness_change[$countop][0] };
	my @groups_of_strata_to_change = @{ $$thickness_change[$countop][1] };
	my @groups_of_couples_of_min_max_values = @{ $$thickness_change[$countop][2] };

	my $thiscount = 0;
	my ( $entry_to_change, $countstrata, $stratum_to_change, $min, $max, $change_stratum, $enter_change_entry, $swing, $pace, $thickness );
	my ( @strata_to_change, @min_max_values , @change_strata, @change_entries, @change_entries_with_thicknesses );
	if ( $stepsvar > 1 )
	{
		foreach my $entrypair_to_change ( @entries_to_change )
		{

			if ( not( ref( $entrypair_to_change ) ) )
			{
				$entry_to_change = $entrypair_to_change;
			}
			else
			{
				my $group_to_change = $entrypair_to_change->[0];
				my $entry_to_change = $entrypair_to_change->[1];
			}

			@strata_to_change = @{ $groups_of_strata_to_change[$thiscount] };
			$countstrata = 0;
			foreach $stratum_to_change ( @strata_to_change )
			{
				my @min_max_values = @{ $groups_of_couples_of_min_max_values[$thiscount][$countstrata] };
				my $min   = $min_max_values[0];
				my $max   = $min_max_values[1];
				my $swing = $max - $min;
				my $pace  = ( $swing / ( $stepsvar - 1 ) );
				my $thickness = $min + ( $pace * ( $countstep - 1 ) );
				my $layers = ( i => 1, j => 2, k => 3, l => 4, m => 5, n => 6, o => 7, p => 8, q => 9, r => 10, s => 11, t => 12, u => 13, v => 14, w => 15 );


        my $printthis;

				if ( not( ref( $entrypair_to_change ) ) )
				{
                                 $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
b
e
a
$entry_to_change
$stratum_to_change
n
$thickness
-
>
a
y
-
-
-
y

y
b
-
YYY
";
		    }
				else
				{
					$printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
b
e
a
$group_to_change
$entry_to_change
$stratum_to_change
n
$thickness
-
>
a
y
-
-
-
y

y
b
-
YYY
";
				}

				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				print $tee "#Changing thicknesses in construction layer for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
				$countstrata++;
			}
			$thiscount++;
		}
		$" = " ";
		unless ($exeonfiles eq "n") { print `$enter_esp$go_to_construction_database@change_entries_with_thicknesses$exit_construction_database_and_esp`; }
		print $tee "$enter_esp$go_to_construction_database@change_entries_with_thicknesses$exit_construction_database_and_esp\n";
	}
} # END sub change_thickness


sub readobsfile
{    # THIS READS A GEO FILE TO GET THE DATA OF THE REQUESTED OBSTRUCTIONS
	my ( $fullgeopath ) = @_; say $tee "\$fullgeopath: $fullgeopath";

	open( GEOF, "$fullgeopath" ) or die;
	my @lines = <GEOF>;
	close GEOF;

	my $countelt = 0;
	my %obs_letter = ( 1 => "e", 2 => "f", 3 => "g", 4 => "h", 5 => "i", 6 => "j", 7 => "k", 8 => "l", 9 => "m", 10 => "n", 11 => "o" ); # RE-CHECK

	my %obsts;
	foreach my $line (@lines)
	{
		chomp $line;
		if ( $line =~ m/^\*obs/ )
		{
			my @elts = split( /\s+|,/, $line );
			my $obsnum = $elts[15];
			my $obsletter = $obs_letter{$obsnum};
			$obsts{$obsletter}{denomination} = $elts[0];
			$obsts{$obsnum}{denomination} = $elts[0];

			$obsts{$obsletter}{obsnum} = $obsnum;
			$obsts{$obsnum}{obsnum} = $obsnum;

			$obsts{$obsletter}{origin} = [ @elts[ 1..3 ] ];
			$obsts{$obsnum}{origin} = [ @elts[ 1..3 ] ];

			$obsts{$obsletter}{dimensions} = [ @elts[ 4..6 ] ];
			$obsts{$obsnum}{dimensions} = [ @elts[ 4..6 ] ];

			$obsts{$obsletter}{z_rotation} = $elts[7];
			$obsts{$obsnum}{z_rotation} = $elts[7];

			$obsts{$obsletter}{y_rotation} = $elts[8];
			$obsts{$obsnum}{y_rotation} = $elts[8];

			$obsts{$obsletter}{x_rotation} = $elts[9];
			$obsts{$obsnum}{x_rotation} = $elts[9];

			$obsts{$obsletter}{opacity} = $elts[10];
			$obsts{$obsnum}{opacity} = $elts[10];

			$obsts{$obsletter}{name} = $elts[11];
			$obsts{$obsnum}{name} = $elts[11];

			$obsts{$obsletter}{construction} = $elts[12];
			$obsts{$obsnum}{construction} = $elts[12];

			$obsts{$obsletter}{num} = $elts[15];
			$obsts{$obsletter}{num} = $elts[15];
		}
	}
	return( %obsts );
}


sub obs_modify
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $obs_modify_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;
	my @applytype = @$applytype_ref;
	my $geofile = $applytype[$countop][2];
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	my %obsn = ( "e" => 1, "f" => 2, "g" => 3, "h" => 4, "i" => 5, "j" => 6, "k" => 7, "l" => 8, "m" => 9 , "n" => 10, "o"  => 11); # RE-CHECK

	say $tee "Modifying obstructions for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";
	my $case_cycle_ref = $obs_modify_ref->[$countop];
	my $configfile = $geofile;
	my $fullgeopath = "$to/zones/$geofile";
	my @obsrefs = @{ $case_cycle_ref };

	my %obsts = readobsfile( $fullgeopath );

	open( OBSFILE, "$fullgeopath" ) or die;
	my @obslines = <OBSFILE>;
	close OBSFILE;
	`cp -f $fullgeopath $fullgeopath.old`;
	say $tee "mv -f $fullgeopath $fullgeopath.old";

	open( NEWOBSFILE, ">$fullgeopath" ) or die;

	my ( @obsbag );

	$semaphore = 0;
	my $countl = 1;
	foreach my $obsline ( @obslines )
	{
		chomp $obsline;
		my @elts = split( /\s+|,/, $obsline );

		if ( $semaphore == 0 )
		{
			if ( $obsline =~ /\*obs = obstructions/ )
			{
				$semaphore = 1;
			}
			say NEWOBSFILE $obsline;
			say $tee $obsline;
		}
		elsif ( $semaphore == 1 )
		{
			unless ( $obsline =~ /\*block_start/ )
			{
				foreach my $obs ( @obsrefs )
				{
					my @obsletters = @{ $obs->[0] };

					foreach $o ( @obsletters )
					{
						my $onum = $obsn{$o};
						push ( @obsbag, $onum );
					}

					my $modification_type = $obs->[1];
					my $values_ref = $obs->[2];

					my $countobs = 0;
					foreach my $obsletter ( @obsletters )
					{
						my $obsnumber = $obsn{$obsletter};

						if ( $elts[15] eq $obsnumber )
						{

							my ( $value, $basevalue, $swing, $low, $high );
							my ( $x_end, $y_end, $z_end, $zory_end, $x_base, $base, $y_base, $z_base, $end_value, $base_value, $swing, $x_swing,
							$y_swing, $z_swing, $pace, $value, $x_pace, $x_value, $y_pace, $y_value, $z_pace, $z_value,
							$x_begin, $y_begin, $z_begin, $x_newbase, $y_newbase, $z_newbase );
							my ( @base, @values, @coord1, @coord2 );

							my $nofspaces = ( $stepsvar - 1 );

							if ( $modification_type eq "a" )
							{
								@base = @{ $obsts{$obsletter}{origin} };
							}
							elsif ( $modification_type eq "b" )
							{
								@base = @{ $obsts{$obsletter}{dimensions} };
							}
							elsif ( $modification_type eq "c" )
							{
								@base = ( $obsts{$obsletter}{z_rotation} );
							}
							elsif ( $modification_type eq "d" )
							{
								@base = ( $obsts{$obsletter}{y_rotation} );
							}
							elsif ( $modification_type eq "f" )
							{
								@base = ( $obsts{$obsletter}{name} );
							}
							elsif ( $modification_type eq "g" )
							{
								@base = ( $obsts{$obsletter}{construction} );
							}
							elsif ( $modification_type eq "h" )
							{
								@base = ( $obsts{$obsletter}{opacity} );
							}

							if ( ( $modification_type eq "a" ) or ( $modification_type eq "b" ) )
							{
								my ( $x_base, $y_base, $z_base ) = @base;

								if ( ref( $values_ref->[0] ) )
								{

									@coord1 = @{ $values_ref->[0] };
									@coord2 = @{ $values_ref->[1] };
									( $x_begin, $y_begin, $z_begin ) = @coord1;
									( $x_end, $y_end, $z_end ) = @coord2;

									$x_swing = ( $x_end - $x_begin );
									$y_swing = ( $y_end - $y_begin );
									$z_swing = ( $z_end - $z_begin );

									$x_newbase = ( $x_base + $x_begin );
									$y_newbase = ( $y_base + $y_begin );
									$z_newbase = ( $z_base + $z_begin );

									$x_pace = ( $x_swing / $nofspaces );
									$y_pace = ( $y_swing / $nofspaces );
									$z_pace = ( $z_swing / $nofspaces );

									$x_value = ( $x_newbase + ( $x_pace * ( $countstep - 1) ) );
									$y_value = ( $y_newbase + ( $y_pace * ( $countstep - 1) ) );
									$z_value = ( $z_newbase + ( $z_pace * ( $countstep - 1) ) );

								}
								else
								{
									$values = $values_ref;
									$x_end = $values->[0];
									$x_swing = ( 2 * $x_end );
									$x_base = $base[0];

									$y_end = $values->[1];
									$y_swing = ( 2 * $y_end );
									$y_base = $base[1];

									$z_end = $values->[2];
									$z_swing = ( 2 * $z_end );
									$z_base = $base[2];

									$x_pace = ( $x_swing / $nofspaces );
									$x_value = ($x_base + ( $x_end - ( $x_pace * ( $countstep - 1 ) ) ));
									$y_pace = ( $y_swing / $nofspaces );
									$y_value = ($y_base + ( $y_end - ( $y_pace * ( $countstep - 1 ) ) ));
									$z_pace = ( $z_swing / $nofspaces );
									$z_value = ($z_base + ( $z_end - ( $z_pace * ( $countstep - 1 ) ) ));
								}

								$x_value = sprintf( "%.4f", $x_value );
								$y_value = sprintf( "%.4f", $y_value );
								$z_value = sprintf( "%.4f", $z_value );

								if ( $modification_type eq "a" )
							       {
									$obsts{$obsletter}{origin} = [ ( $x_value, $y_value, $z_value ) ];
							                $obsts{$obsnumber}{origin} = [ ( $x_value, $y_value, $z_value ) ];
							       }
							       elsif ( $modification_type eq "b" )
							       {
									$obsts{$obsletter}{dimensions} = [ ( $x_value, $y_value, $z_value ) ];
							                $obsts{$obsnumber}{dimensions} = [ ( $x_value, $y_value, $z_value ) ];
							       }
						       }


							if ( ($modification_type eq "c") or ($modification_type eq "d") or ($modification_type eq "h") )
							{
								my $base = $base[0];
								$zory_end = $value;

								if ( ref ( $zory_end ) )
								{
									my $min = $zory_end->[0];
									my $max = $zory_end->[1];
									$swingtranslate = ( $max - $min );
								}
								else
								{
									$swingtranslate = ( 2 * $zory_end );
								}

								my $zory_base = $base;
								my $zory_pace = ( $swingtranslate / ( $stepsvar - 1 ) );
								my $zory_value = ($zory_base + ( $zory_end - ( $zory_pace * ( $countstep - 1 ) ) ));
								$zory_value = sprintf( "%.4f", $zory_value );

								if ( $modification_type eq "c" )
							       {
									$obsts{$obsletter}{z_rotation} = $zory_value;
									$obsts{$obsnumber}{z_rotation} = $zory_value;
							       }
							       elsif ( $modification_type eq "d" )
							       {
									$obsts{$obsletter}{y_rotation} = $zory_value;
									$obsts{$obsnumber}{y_rotation} = $zory_value;
							       }
							       elsif ( $modification_type eq "h" )
							       {
									$obsts{$obsletter}{opacity} = $zory_value;
									$obsts{$obsnumber}{opacity} = $zory_value;
							       }
							}

							if ($modification_type eq "g")
							{
								my $base = $base[0];
								my @constrs = @{ $values_ref };
								my $constr = $constrs[ $countstep - 1 ];

								$obsts{$obsletter}{construction} = $elts[10];
								$obsts{$obsnumber}{construction} = $elts[10];
							}
						}
					}
					$countobs++;
				}
			}

			@obsbag = uniq( @obsbag );
			my $obsnum = $elts[15];

			if ( ( $obsline =~ /\*end_block/ ) or ( $obsline =~ /block_start/ ) )
			{
				say NEWOBSFILE $obsline;
				#say $tee $obsline;
			}
			elsif (  grep { $_ eq $obsnum } @obsbag )
			{
				say NEWOBSFILE "$obsts{$obsnum}{denomination},$obsts{$obsnum}{origin}->[0],$obsts{$obsnum}{origin}->[1],$obsts{$obsnum}{origin}->[2],$obsts{$obsnum}{dimensions}->[0],$obsts{$obsnum}{dimensions}->[1],$obsts{$obsnum}{dimensions}->[2],$obsts{$obsnum}{z_rotation},$obsts{$obsnum}{y_rotation},$obsts{$obsnum}{x_rotation},$obsts{$obsnum}{opacity},$obsts{$obsnum}{name}, $obsts{$obsnum}{construction},  # block  $obsts{$obsnum}{obsnum}" ;
				say $tee "$obsts{$obsnum}{denomination},$obsts{$obsnum}{origin}->[0],$obsts{$obsnum}{origin}->[1],$obsts{$obsnum}{origin}->[2],$obsts{$obsnum}{dimensions}->[0],$obsts{$obsnum}{dimensions}->[1],$obsts{$obsnum}{dimensions}->[2],$obsts{$obsnum}{z_rotation},$obsts{$obsnum}{y_rotation},$obsts{$obsnum}{x_rotation},$obsts{$obsnum}{opacity},$obsts{$obsnum}{name}, $obsts{$obsnum}{construction},  # block  $obsts{$obsnum}{obsnum}" ;
			}
			else
			{
				say NEWOBSFILE "$obsline";
				#say $tee "$obsline";
			}
			$countl++;
		}
	}
} # END SUB obs_modify.


sub recalculateish
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $recalculateish_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];
	my $recalculateish = $recalculateish_ref->[ $countop ];
	my @things = @$recalculateish;
	my $whatto = shift( @things );

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	$launchline = " -file $to/cfg/$fileconfig -mode script";

	say $tee "Updating the insolation calculations for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $printthis;
	if ( $whatto eq "y" )
	{
	  $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
f
c
*
b
a
-
-
-
-
-
-
YYY
";
	}
	elsif ( $whatto eq "noins" )
	{
	  foreach my $el ( @things )
	  {
		$printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
f
c
$el

y
f
b
g
b


-
y
-
-
-
-
-
YYY
";

	  }
	}


	unless ($exeonfiles eq "n")
	{
      print `$printthis`;
	}

	print $tee "#Updating the insolation calculations for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
} #END SUB RECALCULATEISH



sub rebuildconstr
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $rebuildconstr_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;	my $zone_letter = $applytype[$countop][3];
	my $rebuildconstr = $rebuildconstr_ref->[ $countop ];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };
	my @zone_letters = @{ $rebuildconstr }; say $tee "ZONE LETTERS: " . dump( @zone_letters ) ;

	$launchline = " -file $to/cfg/$fileconfig -mode script";

	say $tee "Updating the construction solutions for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	foreach my $zone_letter ( @zone_letters )
  {
	  my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
b
$zone_letter
b
a
>
a
y
y

-
-
-
-
-
YYY
";
	  unless ($exeonfiles eq "n")
	  {
      print `$printthis`;
	  }
	}


	print $tee "#Updating the construction solutions for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
} #END SUB REBUILDCONSTR


sub ifempty
{
		my ( $dir, $d ) = @_;
		opendir($d, $dir) or die( "$!" );
		return ( scalar( grep{ $_ ne "." and $_ ne ".." } readdir($d)) == 0 );
}


sub daylightcalc # IT WORKS ONLY IF THE "RAD" DIRECTORY IS EMPTY
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $filedf, $swap2, $countvar, $fileconfig, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];
	my @daylightcalc = @$swap2;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Performing daylight calculations through Radiance for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $zone = $daylightcalc[0];
	my $surface = $daylightcalc[1];
	my $where = $daylightcalc[2];
	my $edge = $daylightcalc[3];
	my $distance = $daylightcalc[4];
	my $density = $daylightcalc[5];
	my $accuracy = $daylightcalc[6];
	my $filedf = $daylightcalc[7];

	my $pathdf;
	unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
	{
		$pathdf = "$to/rad/$filedf";
	}
	else
	{
		$pathdf = "$to\\rad\\$filedf";
	}

	my $printthis;
	unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
	{

		if ( ifempty ( "$to/rad/" ) )
		{
			$launchline =~ s/\/cfg\/ \\n prj /\/cfg\/ \\n e2r / ;
			$printthis =
"cd $to/cfg/
e2r -file $fileconfig -mode script<<YYY
a

d

g
-
e
d



y
-
g
y
$zone
-
$surface
$distance
$where
$edge
-
$density

i
$accuracy
y
a
a
-
-
YYY
\n\n
cd $mypath
";
		}

		else
		{
			$printthis =
"cd $to/cfg/
e2r -file $fileconfig -mode script<<YYY

a

a
d
$zone
-
$surface
$distance
$where
$edge
-
$density
y
$accuracy
a
-
-
-
-
-
YYY
\n\n
cd $mypath
";
		}
	}
	else
	{
		if ( ifempty ( "$to\\rad\\" ) )
		{
			$printthis =
"cd $to/cfg/
e2r -file $fileconfig -mode script<<YYY
a

d

g
-
e
d



y
-
g
y
$zone
-
$surface
$distance
$where
$edge
-
$density

i
$accuracy
y
a
a
-
-
YYY
\n\n
cd $mypath
";
		}

		else
		{
			$printthis =
"cd $to/cfg/
e2r -file $fileconfig -mode script<<YYY

a

a
d
$zone
-
$surface
$distance
$where
$edge
-
$density
y
$accuracy
a
-
-
-
-
-
YYY
\n\n
cd $mypath
";
		}
	}


	unless ($exeonfiles eq "n")
	{
		print `$printthis`;
	}

	print $tee "#Performing daylight calculations through Radiance for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";

	open( RADFILE, $pathdf) or die "Can't open $pathdf: $!\n";
	my @linesrad = <RADFILE>;
	close RADFILE;
	my @dfs;
	my $dfaverage;
	my $sum = 0;
	foreach my $linerad (@linesrad)
	{
		$linerad =~ s/^\s+//;
		my @rowelements = split(/\s+|,/, $linerad);
		push (@dfs, $rowelements[-1]);
	}
	foreach my $df (@dfs)
	{
		$sum = ($sum + $df);
	}
	$dfaverage = ( $sum / scalar(@dfs) );

	open( DFFILE,  ">>$dffile" )   or die "Can't open $dffile: $!";
	print DFFILE "$dfaverage\n";
	close DFFILE;

} # END SUB daylightcalc


sub change_config
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $change_config_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];
	my @change_config = @$change_config_ref;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Substituting a configuration file for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @change_conf = @{$change_config[ $countop ]};
	my @original_configfiles = @{$change_conf[ 0 ]};
	my @new_configfiles = @{$change_conf[ 1 ]};
	my $countconfig = 0;
	my $original_configfile = $original_configfiles[ $countstep - 1 ];
	my $new_configfile = $new_configfiles[ $countstep - 1 ];
	if (  $new_configfile ne $original_configfile )
	{
		unless ($exeonfiles eq "n")
		{

			`cp -f $to/$new_configfile $to/$original_configfile\n`;
			print $tee "cp -f $to/$new_configfile $to/$original_configfile\n";

		}
	}
$countconfig++;
} # END SUB copy_config


sub checkfile # THIS CHECKS IF A SOURCE FILE MUST BE SUBSTITUTED BY ANOTHER ONE.
{
	my ( $sourceaddress, $targetaddress ) = @_;

	unless ( ( $sourceaddress eq "" ) or ( $targetaddress eq "" ) or ( ( $sourceaddress eq $targetaddress ) ) )
	{
		#print $tee "TARGETFILE IN FUNCTION: $targetaddress\n";
		if ( $sourceaddress ne $targetaddress )
		{
			unless ($exeonfiles eq "n")
			{
				`cp -f $sourceaddress $targetaddress\n`;
				print $tee "cp -f $sourceaddress $targetaddress\n";
			}
		}
	}
} # END SUB checkfile


sub change_climate ### THIS SIMPLE SCRIPT HAS TO BE DEBUGGED. WHY DOES IT BLOCK ITSELF IF PRINTED TO THE SHELL?
{  # THIS FUNCTION CHANGES THE CLIMATE FILES.
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $change_climate_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;



	my @applytype = @{ $applytype_ref };
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	my @change_climates = @{ $change_climate_ref };


	say $tee "Substituting climate database for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @climates = @{ $change_climates[ $countop ] };
	my $newclimate = $climates[ $countstep - 1 ];

	my $myfile;
	unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
	{
		$myfile = $to . "/cfg/" . $fileconfig;
	}
	else
	{
		$myfile = $to . "\\cfg\\" . $fileconfig;
	}

	open( FILECONFIG, $myfile ) or die( "$!" );

	my @lines = <FILECONFIG>;

	my $tempfileconfig = $myfile . ".temp";
	open( TEMPFILECONFIG, ">$tempfileconfig" ) or die( "$!" );

	my ( $oldfile, $climatefolder );
	foreach my $line ( @lines )
	{
		if ( $line =~ /^\*clm/ )
		{
			my @row = split ( /\s+/ , $line );
			$climatefile = $row[1];
			$line =~ s/$climatefile/$newclimate/;
			print TEMPFILECONFIG $line;
		}
		else
		{
			print TEMPFILECONFIG $line;
		}
	}
	close FILECONFIG;
	close TEMPFILECONFIG;
	unless ( $exeonfiles eq "n" )
	{
		`cp -R -f $tempfileconfig $myfile` ;
		#print $tee "cp -R -f $tempfileconfig $myfile" ;
	}

	#print $tee "#Substituting a configuration file with climate updated for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance. $printthis";
}


sub recalculatenet # THIS FUNCTION HAS BEEN OUTDATED BY THOSE FOR CONSTRAINING THE NETS, BELOW, BUT WORKS AND IS SIMPLER
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $recalculatenet_ref, $countvar, $fileconfig, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];
	my @recalculatenet = @{ $recalculatenet_ref->[ $countop ] };

	 my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Adequating the ventilation network for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $filenet = $recalculatenet[0];

	my $infilenet;
	unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
	{
		$infilenet = "$mypath/$file/nets/$filenet";
	}
	else
	{
		$infilenet = "$mypath\\$file\\nets\\$filenet";
	}

	my @nodezone_data_tot = @{$recalculatenet[1]}; ################
	my @nodesdata_tot = @{$recalculatenet[2]}; ###############
	my $geosourcefilesref = $recalculatenet[3]; ###################
	my $configaddress = $recalculatenet[4]; # FILE FOR PROPAGATION OF CONSTRAINTS
	my $y_or_n_reassign_cp = $recalculatenet[5];
	my $y_or_n_detect_obs = $recalculatenet[6];
	my @crackwidths = @{$recalculatenet[8]};

	my @geosourcefiles = @$geosourcefilesref; ##################

	my ( @geos, @genobs, @genobspoints );

	my $countgeo = 0;
	foreach my $nodezone_dataref ( @nodezone_data_tot )
	{

		my ( @obstaclesdata, @differences, @ratios );
		my $countlines = 0;
		my $countnode = 0;
		my $geosourcefile = $geosourcefiles->[ $countgeo ];
		my $sourceaddress = "$to$geosourcefile";
		open( SOURCEFILE, $sourceaddress ) or die "Can't open $geosourcefile 2: $!\n";
		my @linesgeo = <SOURCEFILE>;
		close SOURCEFILE;
		my $countvert = 0;
		my $countobs = 0;
		my ( $zone, $line, $xlenght, $ylenght, $truedistance, $heightdifference );
		my ( @rowelements, @node, @component, @v, @obs, @obspoints, @obstructionpoint );

		foreach my $line (@linesgeo)
		{
			$line =~ s/^\s+//;

			my @rowelements = split(/\s+|,/, $line);
			if   ($rowelements[0] eq "*vertex" )
			{
				if ($countvert == 0)
				{
					push (@v, [ "vertices_of_$sourceaddress" ]);
					push (@v, [ $rowelements[1], $rowelements[2], $rowelements[3] ] );
				}

				if ($countvert > 0)
				{
					push (@v, [ $rowelements[1], $rowelements[2], $rowelements[3] ] );
				}
				$countvert++;
			}
			elsif   ($rowelements[0] eq "*obs" )
			{
				push (@obs, [ $rowelements[1], $rowelements[2], $rowelements[3], $rowelements[4],
				$rowelements[5], $rowelements[6], $rowelements[7], $rowelements[8], $rowelements[9], $rowelements[10] ] );
				$countobs++;
			}
			$countlines++;
		}

		#if ( $y_or_n_detect_obs eq "y") ### THIS HAS YET TO BE DONE AND WORK.
		#{
		#  foreach my $ob (@obs)
		#  {
		#    push (@obspoints , [ $$ob[0], $$ob[1],$$ob[5] ] );
		#    push (@obspoints , [ ($$ob[0] + ( $$ob[3] / 2) ), ( $$ob[1] + ( $$ob[4] / 2 ) ) , $$ob[5] ] );
		#    push (@obspoints , [ ($$ob[0] + $$ob[3]), ( $$ob[1] + $$ob[4] ) , $$ob[5] ] );
		#  }
		#}
		#else
		#{
			@obspoints = @{$recalculatenet[7]};
		#}
		push ( @geos, [ @v ] );
		push ( @genobs, [ @obs ] );
		push ( @genobspoints, [ @genobs ] );
		$countgeo++;
	}

	my ( @winpoints, @windowpoints, @windimsfront, @windimseast, @windimsback, @windimswest, @windsims, @windareas, @jointlenghts );
	my ( $jointfront, $jointeast, $jointback, $jointwest, $windimxfront, $windimyfront,
		$windimxback, $windimyback, $windimxeast, $windimyeast, $windimxwest, $windimywest );

	if ($constrain) { eval ($constrain); } # HERE THE INSTRUCTION WRITTEN IN THE OPT CONFIGURATION FILE CAN BE SPEFICIED
	# FOR PROPAGATION OF CONSTRAINTS

	if ($y_or_n_reassign_cp == "y")
	{
		eval `cat $configaddress`; # HERE AN EXTERNAL FILE FOR PROPAGATION OF CONSTRAINTS
		# IS EVALUATED, AND HERE BELOW CONSTRAINTS ARE PROPAGATED.
		# vertices CAN BE CALLED BY NAME with $geo[ $zonenumber ][ ]
		#  x, y or z CAN BE CALLED WITH THE NUMBERS 0, 1 or 2: EXAMPLE: $genobs[ $zonenumber ][ $vertexnumber ][ 0, 1 or 2 ]
		# ZONENUMBER DERIVES FROM $countop.
		# OBSTRUCTION CAN BE CALLED WITH $genobs[ $zonenumber ][ $obstruction_number ]
		# REMEMBER TO ASSIGN THE $height IN THE CONFIGURATION FILE.
		# UNLESS, ESP-r WILL ASSIGN THAT FOR YOU AND THIS IS NOT ALWAYS WHAT YOU WANT.
	}


	open( INFILENET, $infilenet ) or die "Can't open $infilenet 2: $!\n";
	my @linesnet = <INFILENET>;
	close INFILENET;

	my @letters = (
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r",
	"0\nr", "0\ns", "0\nt", "0\nu", "0\nv", "0\nw", "0\nx", "0\ny", "0\nz", "0\nz", "0\na", "0\nb", "0\nc", "0\nd", "0\ne", "0\nf",  "0\ng", "0\nh",
	"0\n0\nc\nh", "0\n0\nc\ni", "0\n0\nc\nj", "0\n0\nc\nk", "0\n0\nc\nl", "0\n0\nc\nm", "0\n0\nc\nn", "0\n0\nc\no", "0\n0\nc\np", "0\n0\nc\nq", "0\n0\nc\nr",
	"0\n0\nc\ns", "0\n0\nc\nt", "0\n0\nc\nu", "0\n0\nc\nv", "0\n0\nc\nw", "0\n0\nc\nx", "0\n0\nc\ny",
	"0\n0\nc\n0\nc\ny", "0\n0\nc\n0\nc\nz", "0\n0\nc\n0\nc\na", "0\n0\nc\n0\nc\nb", "0\n0\nc\n0\nc\nc", "0\n0\nc\n0\nc\nd", "0\n0\nc\n0\nc\ne", "0\n0\nc\n0\nc\nf", "0\n0\nc\n0\nc\ng", "0\n0\nc\n0\nc\nh", "0\n0\nc\n0\nc\ni", "0\n0\nc\n0\nc\nj",
	"0\n0\nc\n0\nc\nk", "0\n0\nc\n0\nc\nl", "0\n0\nc\n0\nc\nm", "0\n0\nc\n0\nc\nn", "0\n0\nc\n0\nc\no", "0\n0\nc\n0\nc\np",
	"0\n0\nc\n0\nc\n0\nc\np", "0\n0\nc\n0\nc\n0\nc\nq", "0\n0\nc\n0\nc\n0\nc\nr", "0\n0\nc\n0\nc\n0\nc\ns", "0\n0\nc\n0\nc\n0\nc\nt", "0\n0\nc\n0\nc\n0\nc\nu", "0\n0\nc\n0\nc\n0\nc\nv", "0\n0\nc\n0\nc\n0\nc\nw", "0\n0\nc\n0\nc\n0\nc\nx", "0\n0\nc\n0\nc\n0\nc\ny", "0\n0\nc\n0\nc\n0\nc\nz", "0\n0\nc\n0\nc\n0\nc\na", "0\n0\nc\n0\nc\n0\nc\nb",
	"0\n0\nc\n0\nc\n0\nc\nc", "0\n0\nc\n0\nc\n0\nc\nd", "0\n0\nc\n0\nc\n0\nc\ne", "0\n0\nc\n0\nc\n0\nc\nf", "0\n0\nc\n0\nc\n0\nc\ng"
	); # RE-CHECK

	my $countnode = 0;
	my ( $interfaceletter, $calcpressurecoefficient, $nodetype, $nodeletter, $mode );
	my $countlines = 0;
	my $countopening = 0;
	my $countcrack = 0;
	my $countthing = 0;
	my $countjoint = 0;
	foreach my $line (@linesnet)
	{
		$line =~ s/^\s+//;
		@rowelements = split(/\s+/, $line);

		if ($rowelements[0] eq "Node") { $mode = "nodemode"; }
		if ($rowelements[0] eq "Component") { $mode = "componentmode"; }
		if ( ( $mode eq "nodemode" ) and ($countlines > 1) and ($countlines < (2 + scalar(@nodesdata) ) ) )
		{
			$countnode = ($countlines - 2);
			$zone = $nodesdata[$countnode][0];
			$interfaceletter = $nodesdata[$countnode][1];
			$calcpressurecoefficient = $nodesdata[$countnode][2];
			$nodetype = $rowelements[2];
			$nodeletter = $letters[$countnode];

			if ( $nodetype eq "0")
			{
				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
e
c

n
c
$nodeletter

a
a
y
$zone

$height
a

-
-
y

y
-
-
-
-
-
-
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}

				print $tee "#Adequating the ventilation network for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
				$countnode++;
			}
			elsif ( $nodetype eq "3")
			{
				if ($y_or_n_reassign_cp == "y")
				{
					my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
e
c

n
c
$nodeletter

a
e
$zone
$interfaceletter
$calcpressurecoefficient
y

$height
-
-
y

y
-
-
-
-
-
-
-
-
YYY
";
					unless ($exeonfiles eq "n")
					{
						print `printthis`;
					}

					print $tee "#Adequating the ventilation network for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
					$countnode++;
				}
			}
		}

		my @node_letters = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
		"q", "r", "s", "t", "u", "v", "w", "x", "y", "z");
		if ( ($mode eq "componentmode") and ( $line =~ "opening"))
		{
			my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
e
c

n
d
$node_letters[$countthing]

k
-
$windareas[$countopening]
-
-
y

y
-
-
-
-
-
-
-
YYY
";
			unless ($exeonfiles eq "n")
			{
				print `$printthis`;
			}

			print $tee "#Adequating the ventilation network for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";

			$countopening++;
			$countthing++;
		}
		elsif ( ($mode eq "componentmode") and ( $line =~ "crack "))
		{
			my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
e
c

n
d
$node_letters[$countthing]

l
-
$crackwidths[$countjoint] $jointlenghts[$countjoint]
-
-
y

y
-
-
-
-
-
-
-
YYY
";
			unless ($exeonfiles eq "n")
			{
				print `$printthis`;
			}

			say $tee "$printthis";

			$countcrack++;
			$countthing++;
			$countjoint++;
		}
		$countlines++;
	}
} # END SUB recalculatenet



sub pin_obstructions
{
	#use strict; use warnings;
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $pin_obstructions_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;
	my @applytype = @$applytype_ref;  #say $tee "\APPLYTYPE: " . dump( @applytype );
	my $zone_letter = $applytype[$countop][3];
        #say $tee "\$pin_obstructions_ref: " . dump( $pin_obstructions_ref );
	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	my @pin_obstructions = @{ $pin_obstructions_ref->[ $countop ] }; #say $tee "\@pin_obstructions: " . dump( @pin_obstructions );
	my $sourcefile = shift( @pin_obstructions ); #say $tee "\sourcefile: $sourcefile"; say $tee "\@pin_obstructions: " . dump( @pin_obstructions );
	my $sourcepath = $mypath . "/" . $file . $sourcefile; #say $tee "\$sourcepath: $sourcepath";
	my %keeplines ;
	my @newlines;
	open ( SOURCEFILE, $sourcepath ) or die( "$!" );
	my @sourcelines = <SOURCEFILE>; #say $tee "\@sourcelines: " . dump( @sourcelines );
	close SOURCEFILE;

	foreach my $obs ( @pin_obstructions )
	{
		foreach my $line ( @sourcelines )
		{
			if  ( ( $line =~ /^\*obs/ ) and ( $line =~ /$obs$/ ) )
			{
				$keeplines{$obs} = $line ;
			}
		}
	} say $tee "\%keeplines: " . dump( \%keeplines );
	my $targetpath = $to . $sourcefile; #say $tee "\$targetpath: $targetpath";

	my $oldfile = $targetpath . ".old";

	`mv -f $targetpath $oldfile`;
	print $tee "mv -f $targetpath $oldfile\n";

	open( OLDFILE, $oldfile ) or die( "$!" );
	my @oldlines = <OLDFILE>;
	close OLDFILE;

	open ( NEWFILE, ">$targetpath" ) or die( "$!" );

	foreach my $line ( @oldlines )
	{
		if ( $line =~ /^\*obs/ )
		{
			foreach my $obs ( keys %keeplines )
			{
				if  ( $line =~ /$obs$/ )
				{
					$line = $keeplines{$obs};

				}
			}
		}

		print NEWFILE $line;

	}
	close NEWFILE;
} # END SUB pin_obstructions


sub apply_constraints
{
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $apply_constraints_ref, $countvar, $fileconfig , $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my @apply_constraints = @ {$apply_constraints_ref };

	my @menus = @ { $menus_ref };
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Applying constraints for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @sourcefiles = @{ $apply_constraints[$countop][0] };
	my @numberfiles = @{ $apply_constraints[$countop][1] };
	my @configfiles = @{ $apply_constraints[$countop][2] };
	my @incrs = @{ $apply_constraints[$countop][3] };
  my @filestoedit = @{ $apply_constraints[$countop][4] };
	my $separator = $apply_constraints[$countop][5];

	my ( %ver, %obs, %nod, %comp );
	my %verts = %numvertmenu;

	my %zones = ( 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f", 7 => "g",
		8 => "h", 9 => "i", 10 => "j", 11 => "k", 12 => "l",
	13 => "m", 14 => "n", 15 => "o", 16 => "p",
	17 => "q", 18 => "r", 19 => "0\ns", 20 => "0\nt", 21 => "0\nu", 22 => "0\nv",
	23 => "0\nw", 24 => "0\nx", 25 => "0\ny", 26 => "0\nz",
	27 => "0\na", 28 => "0\nb", 29 => "0\nc", 30 => "0\nd", 31 => "0\ne",
	32 => "0\nf", 33 => "0\ng", 34 => "0\nh", 35 => "0\ni", 36 => "0\n0\ncj",
	37 => "0\n0\nck", 38 => "0\n0\ncl", 39 => "0\n0\ncm", 40 => "0\n0\ncn", 41 => "0\n0\nco",
	42 => "0\n0\ncp", 43 => "0\n0\ncq", 44 => "0\n0\ncr", 45 => "0\n0\ncs", 46 => "0\n0\nct",
	47 => "0\n0\nc0\ncu", 48 => "0\n0\nc0\ncv", 49 => "0\n0\nc0\ncw", 50 => "0\n0\nc0\ncx" );


	my %obss = ( 1 => "e", 2 => "f", 3 => "g", 4 => "h", 5 => "i", 6 => "j", 7 => "k",
	8 => "l", 9 => "m", 10 => "n", 11 => "o", 12 => "0\no", 13 => "0\np",
	14 => "0\nq", 15 => "0\nr", 16 => "0\ns",
	17 => "0\nt", 18 => "0\nu", 19 => "0\nv", 20 => "0\nw", 21 => "0\nx", 22 => "0\ny",
	23 => "0\n0\nc\ny", 24 => "0\n0\nc\nz", 25 => "0\n0\nc\na", 26 => "0\n0\nc\nb",
	27 => "0\n0\nc\nc", 28 => "0\n0\nc\nd", 29 => "0\n0\nc\ne", 30 => "0\n0\nc\nf",
	31 => "0\n0\nc\ng", 32 => "0\n0\nc\nh", 33 => "0\n0\nc\ni",
	34 => "0\n0\nc\n0\nc\ni", 35 => "0\n0\nc\n0\nc\nj", 36 => "0\n0\nc\n0\nc\nk",
	37 => "0\n0\nc\n0\nc\nl", 38 => "0\n0\nc\n0\nc\nm", 39 => "0\n0\nc\n0\nc\nn",
	40 => "0\n0\nc\n0\nc\no", 41 => "0\n0\nc\n0\nc\np", 42 => "0\n0\nc\n0\nc\nq",
	43 => "0\n0\nc\n0\nc\nr", 44 => "0\n0\nc\n0\nc\ns",
	45 => "0\n0\nc\n0\nc\n0\nc\ns", 46 => "0\n0\nc\n0\nc\n0\nc\nt", 47 => "0\n0\nc\n0\nc\n0\nc\nu",
	48 => "0\n0\nc\n0\nc\n0\nc\nvs", 49 => "0\n0\nc\n0\nc\n0\nc\nw", 50 => "0\n0\nc\n0\nc\n0\nc\nx",
	51 => "0\n0\nc\n0\nc\n0\nc\ny", 52 => "0\n0\nc\n0\nc\n0\nc\nz", 53 => "0\n0\nc\n0\nc\n0\nc\na",
	54 => "0\n0\nc\n0\nc\n0\nc\nb", 55 => "0\n0\nc\n0\nc\n0\nc\nc" );

	my %nodes = ( 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f", 7 => "g",
	8 => "h", 9 => "i", 10 => "j", 11 => "k", 12 => "l",
	13 => "m", 14 => "n", 15 => "o", 16 => "p", 17 => "q", 18 => "r", 19 => "0\ns",
	20 => "0\nt", 		21 => "0\nu", 22 => "0\nv", 23 => "0\nw", 24 => "0\nx", 25 => "0\ny",
	26 => "0\nz", 27 => "0\na", 28 => "0\nb", 29 => "0\nc", 30 => "0\nd", 31 => "0\ne",
	32 => "0\nf", 33 => "0\ng", 34 => "0\nh", 35 => "0\ni", 36 => "0\n0\ncj",
	37 => "0\n0\nck", 38 => "0\n0\ncl", 39 => "0\n0\ncm", 40 => "0\n0\ncn", 41 => "0\n0\nco",
	42 => "0\n0\ncp", 43 => "0\n0\ncq", 44 => "0\n0\ncr", 45 => "0\n0\ncs", 46 => "0\n0\nct",
	47 => "0\n0\ncu", 48 => "0\n0\ncv", 49 => "0\n0\ncw", 50 => "0\n0\ncx",
	51 => "0\n0\nc0\ncy", 52 => "0\n0\nc0\ncz",
	53 => "0\n0\nca", 54 => "0\n0\ncb", 55 => "0\n0\nc0\ncc", 56 => "0\n0\nc0\ncd",
	57 => "0\n0\nc0\nce", 58 => "0\n0\nc0\ncf",
	59 => "0\n0\nc0\ncg", 60 => "0\n0\nc0\nch", 61 => "0\n0\nc0\nci",
	62 => "0\n0\nc0\nc0\ncj", 63 => 63, 64 => "0\n0\nc0\nc0\ncl",
	65 => "0\n0\nc0\nc0\ncm", 66 => "0\n0\nc0\nc0\ncn",
	67 => "0\n0\nc0\nc0\nco", 68 => "0\n0\nc0\nc0\ncp", 69 => "0\n0\nc0\nc0\ncq",
	70 => "0\n0\nc0\nc0\ncr", 71 => "0\n0\nc0\nc0\ncs",
	72 => "0\n0\nc0\nc0\nct", 73 => "0\n0\nc0\nc0\ncu", 74 => "0\n0\nc0\nc0\ncv",
	75 => "0\n0\nc0\nc0\ncw", 76 => "0\n0\nc0\nc0\ncx" );

	my %components = ( 1 => "a", 2 => "b", 3 => "c", 4 => "d", 5 => "e", 6 => "f", 7 => "g",
	8 => "h", 9 => "i", 10 => "j", 11 => "k", 12 => "l",
	13 => "m", 14 => "n", 15 => "o", 16 => "p", 17 => "q", 18 => "r", 19 => "0\ns",
	20 => "0\nt", 		21 => "0\nu", 22 => "0\nv", 23 => "0\nw", 24 => "0\nx", 25 => "0\ny",
	26 => "0\nz", 27 => "0\na", 28 => "0\nb", 29 => "0\nc", 30 => "0\nd", 31 => "0\ne",
	32 => "0\nf", 33 => "0\ng", 34 => "0\nh", 35 => "0\ni", 36 => "0\n0\ncj",
	37 => "0\n0\nck", 38 => "0\n0\ncl", 39 => "0\n0\ncm", 40 => "0\n0\ncn", 41 => "0\n0\nco",
	42 => "0\n0\ncp", 43 => "0\n0\ncq", 44 => "0\n0\ncr", 45 => "0\n0\ncs", 46 => "0\n0\nct",
	47 => "0\n0\ncu", 48 => "0\n0\ncv", 49 => "0\n0\ncw", 50 => "0\n0\ncx",
	51 => "0\n0\nc0\ncy", 52 => "0\n0\nc0\ncz",
	53 => "0\n0\nca", 54 => "0\n0\ncb", 55 => "0\n0\nc0\ncc", 56 => "0\n0\nc0\ncd",
	57 => "0\n0\nc0\nce", 58 => "0\n0\nc0\ncf",
	59 => "0\n0\nc0\ncg", 60 => "0\n0\nc0\nch", 61 => "0\n0\nc0\nci",
	62 => "0\n0\nc0\nc0\ncj", 63 => 63, 64 => "0\n0\nc0\nc0\ncl",
	65 => "0\n0\nc0\nc0\ncm", 66 => "0\n0\nc0\nc0\ncn",
	67 => "0\n0\nc0\nc0\nco", 68 => "0\n0\nc0\nc0\ncp", 69 => "0\n0\nc0\nc0\ncq",
	70 => "0\n0\nc0\nc0\ncr", 71 => "0\n0\nc0\nc0\ncs",
	72 => "0\n0\nc0\nc0\nct", 73 => "0\n0\nc0\nc0\ncu", 74 => "0\n0\nc0\nc0\ncv",
	75 => "0\n0\nc0\nc0\ncw", 76 => "0\n0\nc0\nc0\ncx" );

  my $countfile = 0;
	foreach my $sourcefile ( @sourcefiles )
  {

	my $sourceaddress = "$to$sourcefile";  #say $tee "\$sourceaddress: " . dump( $sourceaddress );

	open( SOURCEFILE, $sourceaddress ) or die "Can't open $sourceaddress: $!\n";
	my @lines = <SOURCEFILE>;
	close SOURCEFILE;

	my $countlines = 0;
	foreach my $line ( @lines )
	{
		$line =~ s/^\s+//;
		my @rowelts = split(/\s+|,/, $line);
		if ( $sourcefile =~ /\.geo$/ )
		{
			if   ($rowelts[0] eq "*vertex" )
			{
				my $vertnum = $rowelts[5];
				@{ $ver{$numberfiles[$countfile]}{$vertnum} } = ( $rowelts[1], $rowelts[2], $rowelts[3] );
			}
	    if   ($rowelts[0] eq "*obs" )
			{
				my $obsnum = $rowelts[13];
				@{ $obs{$numberfiles[$countfile]}{$obsnum} } = ( $rowelts[1], $rowelts[2], $rowelts[3],
	          $rowelts[4], $rowelts[5], $rowelts[6], $rowelts[7], $rowelts[8], $rowelts[9], $rowelts[10] ) ;
			}
		}
		elsif ( $sourcefile =~ /\.afn$/ )
		{
			my $countlines = 0;
			my $countnode = -1;
			my $countcomponent = -1;
			my $countcomp = 0;
			my $semaphore_node = "no";
			my $semaphore_component = "no";
			my $semaphore_connection = "no";
			my ($component_letter, $type, $data_1, $data_2, $data_3, $data_4);
			foreach my $line (@lines)
			{
				if ( $line =~ m/Fld. Type/ )
				{
					$semaphore_node eq "yes";
				}
				if ( $semaphore_node eq "yes" )
				{
					$countnode++;
				}
				if ( $line =~ m/Type C\+ L\+/ )
				{
					$semaphore_component eq "yes";
					$semaphore_node = "no";
				}

				if ( ($semaphore_node eq "yes") and ( $semaphore_component eq "no" ) and ( $countnode >= 0))
				{
					my $node_letter = $nodes[$countnode];
					my $fluid = $row[1];
					my $type = $row[2];
					my $height = $row[3];
					my $data_2 = $row[6]; # volume or azimuth
					my $data_1 = $row[5]; #surface
					@{ $nod{$countnode} } = ( $node_letter, $fluid, $type, $height, $data_2, $data_1 ); # PLURAL
				}

				if ( $semaphore_component eq "yes" )
				{
					$countcomponent++;
				}

				if ( $line =~ m/\+Node/ )
				{
					$semaphore_connection eq "yes";
					$semaphore_component = "no";
					$semaphore_node = "no";
				}

				if ( ($semaphore_component eq "yes") and ( $semaphore_connection eq "no" ) and ( $countcomponent > 0))
				{
					if ($countcomponent % 2 == 1) # $number is odd
					{
						$component_letter = $components[$countnode];
						$fluid = $row[0];
						$type = $row[1];
						if ($type eq "110") { $type = "k"; }
						if ($type eq "120") { $type = "l"; }
						if ($type eq "130") { $type = "m"; }
						$countcomp++;
					}
					else # $number is even
					{
						$data_1 = $row[1];
						$data_2 = $row[2];
						$data_3 = $row[3];
						$data_4 = $row[4];
						@{ $comp{$countcomp} } = ( $component_letter, $fluid, $type, $data_1, $data_2, $data_3, $data_4 ); # PLURAL
					}
				 }
			 $countlines++;
			 }
		 }
	  }
	  $countfile++;
  }

 	my ( $swing, $base, $pace, $val );
 	my $count = 0;
  foreach $incr ( @incrs )
  {
	  if ( ref ( $incr ) )
	  {
		  my $min = $incr->[0];
		  my $max = $incr->[1];
		  $swing->[$count] = ( $max - $min );
		  $base->[$count] = ( 0 - $min );
	  }
	  else
	  {
		  $swing->[$count] = ( 2 * $incr );
		  $base->[$count] = ( 0 - $incr );
	  }

	  $pace->[$count] = ( $swing->[$count] / ( $stepsvar - 1 ) );
	  $val->[$count] = ( $base->[$count] + ( $pace->[$count] * ( $countstep - 1 ) ) ); # THIS IS WHAT YOU WANT TO USE IN THE INSTRUCTIONS FOR PROPAGATING CONSTRAINTS
	  $count++;
  }

	my %eds;
	my @eeds;
	foreach my $file ( @filestoedit )
	{
    my $myfile = "$to$file";
		open( FILE, $myfile ) or die "Can't open $myfile: $!\n";
		my @lines = <FILE>;
		close FILE;

		my $cn = 0;
		foreach my $line ( @lines )
		{
			chomp $line;
			if ( $line =~ /#&&/ )
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+/ /;
				my @transitional = split(/#&&/, $line);
				my $leftpart = $transitional[0]; #say $tee "AAAPPLY_CONSTRAINTS \$leftpart: " . dump( $leftpart );
				my @elts = split(/\s+|,/, $leftpart); #say $tee "AAAPPLY_CONSTRAINTS \@elts: " . dump( @elts );

				my $rightpart = $transitional[1]; #say $tee "AAAPPLY_CONSTRAINTS \$rightpartA: " . dump( $rightpart );
				$rightpart =~ s/^\s+//; #say $tee "AAAPPLY_CONSTRAINTS \$rightpartB: " . dump( $rightpart );
				$rightpart =~ s/\s+$//; #say $tee "AAAPPLY_CONSTRAINTS \$rightpartC: " . dump( $rightpart );
				$rightpart =~ s/\s+/ /; #say $tee "AAAPPLY_CONSTRAINTS \$rightpartD: " . dump( $rightpart );
				my @ins = split(/\s+|,/, $rightpart); #say $tee "AAAPPLY_CONSTRAINTS \@ins: " . dump( @ins );

				foreach my $in ( @ins )
				{
					unless ( ( $in eq undef ) or ( $leftpart eq undef ) or ( $rightpart eq undef ) )
					{
						my @elements = split(/-/, $in); #say $tee "AAAPPLY_CONSTRAINTS \@elements: " . dump( @elements );
						my $name = $elements[0];
						my $position = $elements[1];
						$eds{$name}{file} = $file; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{file}: " . dump( $eds{$name}{file} );
						$eds{$name}{line} = $cn; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{line}: " . dump( $eds{$name}{line} );
						$eds{$name}{position} = $position; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{position}: " . dump( $eds{$name}{position} );
						$eds{$name}{value} = $elts[$position];  #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{value}: " . dump( $eds{$name}{value} );
						my $length = length($in); #say $tee "AAAPPLY_CONSTRAINTS \$length: " . dump( $length );
						$eds{$name}{length} = $length; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{length}: " . dump( $eds{$name}{length} );
						my $beginning = index($line, $in);
						$eds{$name}{beginning} = $beginning; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{beginning}: " . dump( $eds{$name}{beginning} );
						my $end = $beginning + $length;
						$eds{$name}{end} = $end; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{end}: " . dump( $eds{$name}{end} );
						$eds{$name}{rightpart} = $rightpart; #say $tee "AAAPPLY_CONSTRAINTS \$eds{\$name}{rightpart}: " . dump( $eds{$name}{rightpart} );
						push ( @eeds, $name ); #say $tee "AAAPPLY_CONSTRAINTS \@eeds: " . dump( @eeds );


					}
				}
			}
			$cn++;
		}
	}

  my @tooutputs;
  foreach my $configfile ( @configfiles )
  {
    my $configaddress = "$to$configfile";
	   if ( defined ( $configaddress ) )
		 {
			 if ( -e $configaddress )
			 {
				 eval `cat $configaddress`; # HERE AN EXTERNAL FILE FOR PROPAGATION OF CONSTRAINTS IS EVALUATED.

				 #open( CONFIGFILE, $configaddress ) or die;
				 #my @readlines = <CONFIGFILE>;
				 #close(CONFIGFILE);
         #foreach my $readline ( @readlines )
         #{
	       #    if ( $readline =~ /^(.+)=/ )
	       #    {
	       #    	$1 =~ s/my// ;
	       #    	$tooutput = $tooutput . " $1, ";
	       #    }
	       #}
	       #$tooutput = $tooutput . " )";
			  }
			  else
			  {
				  say $tee "\$configaddress does not exist. Exiting." and die;
			  }
		  }
	  }

	  foreach my $file (@filestoedit)
	  {
		  my $myfile = "$to$file";
		  open( FILE, $myfile ) or die "Can't open $myfile: $!\n";
		  my @lines = <FILE>;
		  close FILE;

		  `mv -f $myfile $myfile.old`;
		  open( OFILE, ">$myfile" ) or die "Ah! Can't open $myfile: $!\n";

		  my $cnt = 0;
		  foreach my $line ( @lines )
		  {
			  if ( $line =~ /#&&/ )
			  { say $tee "APPPLY_CONSTRAINTS \$line: " . dump( $line );
				  $line =~ s/ +/ /;
				  my @splits = split( "$separator", $line ); say $tee "APPPLY_CONSTRAINTS \@splits: " . dump( @splits );

				  my @transitional = split( /#&&/, $line );
				  my $rightpart = $transitional[1];
				  $rightpart =~ s/^ +//;
					$rightpart =~ s/ +/ /; say $tee "APPPLY_CONSTRAINTS \$rightpart: " . dump( $rightpart );
				  my @elms = split( / /, $rightpart ); say $tee "APPPLY_CONSTRAINTS \@elms: " . dump( @elms );

		      foreach my $elm ( @elms )
				  {
						chomp $elm;
					  my ( $name, $number ) = split( "-", $elm );

						say $tee "APPPLY_CONSTRAINTS \$name: " . dump( $name );
					  if ( $eds{$name}{file} eq $file )
					  {
						  #if ( $eds{$name}{line} eq $cnt )
						  #{
                $splits[$eds{$name}{position}] = $eds{$name}{newvalue};

                #$line = ( substr( $line, 0, $eds{$name}{beginning} ) ) . ( substr( $line, $eds{$name}{end} ) ); say $tee "APPPLY_CONSTRAINTS \$line!: " . dump( $line );
							  #substr( $line, $eds{$name}{beginning}, 0) = $eds{$name}{newvalue}; say $tee "APPPLY_CONSTRAINTS \$line!: " . dump( $line );

							  #unless ( $line =~ /#&&/ )
							  #{
							  #	$line . " $rightpart";
							  #}
						  #}
					  }
				  }

					my $novelline;
					foreach my $split ( @splits )
					{
						$split = $split . "$separator";
            $novelline = $novelline . $split;
					}
					$line = $novelline . "\n";
			  }
			  $line =~ s/\\00//g ;
			  print OFILE $line;
			  $cnt++;
	    }
		  close OFILE;
	  }

    foreach my $output ( @tooutputs )
    {
      if ( $output =~ /^ver/ )
      {
        $output =~ /^ver\{(\d+)\}\{(\d+)\}/;
        my $zone_number = $1;
        my $zone_letter = $zones{$zone_number};
        my $vnum = $2;
        my $vertex_letter = $verts{$vnum};
        my ( $x, $y, $z ) = ( $ver{$zone_number}{$vnum}->[0], $ver{$zone_number}{$vnum}->[1], $ver{$zone_number}{$vnum}->[2] ); ###THIS!

			  my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
d
$vertex_letter
$x $y $z
-
-
y
c
-
-
-
-
-
-
-
-
-
YYY
";
			  unless ($exeonfiles eq "n")
			  {
				  print `$printthis`;
			  }
			  say $tee "$printthis";
		  }
		  elsif ( $output =~ /^obs/ )
      {
        $output =~ /\$obs\{(.+)\}\{(.+)\}/;
        my $zone_number = $1;
        my $obs_letter = $zones{$zone_number};
        my $obsnum = $2;
        my $obs_letter = $obss{$obsnum};

    	  my @ob = @{ $obs{$zone_number}{$obsnum} };###THIS!
    		my $x = $ob_->[1];
			  my $y = $ob_->[2];
			  my $z = $ob_->[3];
			  my $width = $ob_->[4];
			  my $depth = $ob_->[5];
			  my $height = $ob_->[6];
			  my $y_rotation = $ob_->[7];
			  my $tilt = $ob_->[8];
			  my $opacity = $ob_->[9];
			  my $name = $ob_->[10];
			  my $material = $ob_->[11];

			  my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
h
a
$obs_letter
a
a
$x $y $z
b
$width $depth $height
c
$y_rotation
d
$tilt
e
h
$opacity
-
-
c
-
c
-
-
-
-
YYY

cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
h
a
$obs_letter
g
$material
-
-
-
c
-
c
-
-
-
-
YYY
";
			    unless ($exeonfiles eq "n")
			    {
				    print `$printthis`;
			    }
			    say $tee "$printthis";
		    }
		    elsif ( $output =~ /^nod/ )
               {
			  $output =~ /nod\{(.+)\}/;
			  my $nodnum = $2;
			  my $node_letter = $nodes{$nodnum};
			  my @nods = @{ $nod{$nodnum} }; ###THIS!

			  my $new_node_letter = $nods[0];
			  my $new_fluid = $nods[1];
			  my $new_type = $nods[2];
			  my $new_zone = $nods[3];
			  my $new_height = $nods[4];
			  my $new_data_2 = $nods[5];
			  my $new_surface = $nods[6];
			  my $new_cp = $node_[7];

			  if ($new_type eq "a" ) # IF NODES ARE INTERNAL
			  { ############ THIS CODE IS STALE. REDO
				  my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
f
c

n
c
$new_node_letter
y
$new_fluid
$new_type
y
$new_zone
$new_data_2
$new_height
a

-
-
y

y
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				say $tee "$printthis";
			}

			if ($new_type eq "e" ) # IF NODES ARE BOUNDARY ONES, WIND-INDUCED
			{ ############ THIS CODE IS STALE. REDO
				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
f
c

n
c
$new_node_letter
y
$new_fluid
$new_type
$new_zone
$new_surface
$new_cp
y
$new_data_2
$new_height
-
-
y

y
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				say $tee "$printthis";
			}
    }

    elsif ( $output =~ /^comp/ )
    {
      $output =~ /comp\{(.+)\}/;
      my $compnum = $2;
      my $comp_letter = $components{$compnum};
      my @comps = @{ $comp{$compnum} };

      my $new_component_letter = $comps[0];
			my $new_fluid = $comps[1];
			my $new_type = $comps[2];
			my $new_data_1 = $comps[3];
			my $new_data_2 = $comps[4];
			my $new_data_3 = $comps[5];
			my $new_data_4 = $comps[6];

			if ($new_type eq "k" ) # IF THE COMPONENT IS A GENERIC OPENING
			{ ############ THIS CODE IS STALE. REDO
				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
e
c

n
d
$new_component_letter
$new_fluid
$new_type
-
$new_data_1
-
-
y

y
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				say $tee "$printthis";
			}

			if ($new_type eq "l" ) # IF THE COMPONENT IS A CRACK
			{ ############ THIS CODE IS STALE. REDO
				my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
e
c

n
d
$new_component_letter
$new_fluid
$new_type
-
$new_data_1 $new_data_2
-
-
y

y
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				say $tee "$printthis";
			}

			if ($new_type eq "m" ) # IF THE COMPONENT IS A DOOR
			{ ############ THIS CODE IS STALE. REDO
				my $printthis =
"prj $launchline<<YYY
m
e
c

n
d
$new_component_letter
$new_fluid
$new_type
-
$new_data_1 $new_data_2 $new_data_3 $new_data_4
-
-
y

y
-
-
YYY
";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`;
				}
				say $tee "$printthis";
			}
		}

		### XXX

		say $tee "#Propagating constraints " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
	}
} # END SUB APPLY_CONSTRAINTS



sub reshape_windows # IT APPLIES CONSTRAINTS
{
	my ( $to, $stepsvar, $countop, $countstep, $swap, $swap2, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$swap;
	my $zone_letter = $applytype[$countop][3];
	my @reshape_windows = @$swap2;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Reshaping windows for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my ( @work_letters, @v );

	foreach my $group_operations ( @{$reshape_windows[$countop]} )
	{
		my @group = @{$group_operations};
		my @sourcefiles = @{$group[0]};
		my @targetfiles = @{$group[1]};
		my @configfiles = @{$group[2]};
		my @basevalues = @{$group[3]};
		my @swingvalues = @{$group[4]};
		my @work_letters = @{$group[5]};

		my $countops = 0;
		foreach $sourcefile ( @sourcefiles )
		{
			my $basevalue = $basevalues[$countops];
			my $sourcefile = $sourcefiles[$countops];
			my $targetfile = $targetfiles[$countops];
			my $configfile = $configfiles[$countops];
			my $swingvalue = $swingvalues[$countops];
			my $sourceaddress = "$to$sourcefile";
			my $targetaddress = "$to$targetfile";

			my $configaddress;
			unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
			{
				$configaddress = "$to/opts/$configfile";
			}
			else
			{
				$configaddress = "$to\\opts\\$configfile";
			}

			my $totalswing;
			unless ( ref ( $swingvalue ) )
			{
				$totalswing = ( 2 * $swingvalue );
			}

			if ( ref ( $swingvalue ) )
			{
				my $min = $swingvalue->[0];
				my $max = $swingvalue->[1];
				$totalswing = ( $max - $min );
			}

			my $pace = ( $totalswing / ( $stepsvar - 1 ) );
			checkfile($sourceaddress, $targetaddress);

			open( SOURCEFILE, $sourceaddress ) or die "Can't open $sourcefile 2: $!\n";
			my @lines = <SOURCEFILE>;
			close SOURCEFILE;

			my $countlines = 0;
			my $countvert = 0;
			foreach my $line (@lines)
			{
				$line =~ s/^\s+//;

				my @rowelements = split(/\s+|,/, $line);
				if   ($rowelements[0] eq "*vertex" )
				{
					if ($countvert == 0)
					{
						push (@v, [ "vertices of  $sourceaddress", [], [] ]);
						push (@v, [ $rowelements[1], $rowelements[2], $rowelements[3] ] );
					}

					if ($countvert > 0)
					{
						push (@v, [ $rowelements[1], $rowelements[2], $rowelements[3] ] );
					}

					$countvert++;
				}
				$countlines++;
			}

			my @vertexletters = (
			"a",   "b",   "c",   "d",   "e",   "f",   "g",   "h",   "i",   "j",   "k",   "l",   "m",   "n",   "o",   "p",
			"0\np", "0\nq", "0\nr", "0\ns", "0\nt", "0\nu", "0\nv", "0\nw", "0\nx", "0\ny", "0\nz", "0\na", "0\nb",  "0\nc",  "0\nd",  "0\ne",
			"0\n0\nc\ne", "0\n0\nc\nf", "0\n0\nc\ng", "0\n0\nc\nh", "0\n0\nc\ni", "0\n0\nc\nj", "0\n0\nc\nk", "0\n0\nc\nl",
			"0\n0\nc\nm", "0\n0\nc\nn", "0\n0\nc\no", "0\n0\nc\np", "0\n0\nc\nq", "0\n0\nc\nr", "0\n0\nc\ns", "0\n0\nc\nt",
			"0\n0\nc\n0\nc\nt", "0\n0\nc\n0\nc\nu", "0\n0\nc\n0\nc\nv", "0\n0\nc\n0\nc\nw", "0\n0\nc\n0\nc\nx", "0\n0\nc\n0\nc\ny", "0\n0\nc\n0\nc\nz", "0\n0\nc\n0\nc\na",
			"0\n0\nc\n0\nc\nb", "0\n0\nc\n0\nc\nc", "0\n0\nc\n0\nc\nd", "0\n0\nc\n0\nc\ne", "0\n0\nc\n0\nc\nf", "0\n0\nc\n0\nc\ng", "0\n0\nc\n0\nc\nh", "0\n0\nc\n0\nc\ni",
			"0\n0\nc\n0\nc\n0\nc\ni", "0\n0\nc\n0\nc\n0\nc\nj", "0\n0\nc\n0\nc\n0\nc\nk", "0\n0\nc\n0\nc\n0\nc\nl", "0\n0\nc\n0\nc\n0\nc\nm", "0\n0\nc\n0\nc\n0\nc\nn", "0\n0\nc\n0\nc\n0\nc\no", "0\n0\nc\n0\nc\n0\nc\np",
			"0\n0\nc\n0\nc\n0\nc\nq", "0\n0\nc\n0\nc\n0\nc\nr", "0\n0\nc\n0\nc\n0\nc\ns", "0\n0\nc\n0\nc\n0\nc\nt", "0\n0\nc\n0\nc\n0\nc\nu", "0\n0\nc\n0\nc\n0\nc\nv", "0\n0\nc\n0\nc\n0\nc\nw", "0\n0\nc\n0\nc\n0\nc\nx"
			);

			$value_reshape_window =  ( ( $basevalue - $swingvalue) + ( $pace * ( $countstep - 1 )) );

			if (-e $configaddress)
			{

				eval `cat $configaddress`;  # HERE AN EXTERNAL FILE FOR PROPAGATION OF CONSTRAINTS
				# IS EVALUATED, AND HERE BELOW CONSTRAINTS ARE PROPAGATED.

				if (-e $constrain) { eval ($constrain); } # HERE THE INSTRUCTION WRITTEN IN THE OPT CONFIGURATION FILE CAN BE SPEFICIED
				# FOR PROPAGATION OF CONSTRAINTS

				my $countvertex = 0;

				foreach (@v)
				{
					if ($countvertex > 0)
					{
						my $vertexletter = $vertexletters[$countvertex];
						if (grep { $_ eq $vertexletter } @work_letters)
						{
							my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
d
$vertexletter
$v[$countvertex+1][0] $v[$countvertex+1][1] $v[$countvertex+1][2]
-
y
-
y
c
-
-
-
-
-
-
-
-
-
YYY
";
							unless ($exeonfiles eq "n")
							{
								print `$printthis`;
							}

							say $tee "#Reshaping windows for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
						}
					}
					$countvertex++;
				}
			}
			$countops++;
		}

	}
} # END SUB reshape_windows


sub warp #
{
	my ( $to, $stepsvar, $countop, $countstep, $swap, $warp, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$swap;
	my $zone_letter = $applytype[$countop][3];

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Warping zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @surfs_to_warp =  @{ $warp->[$countop][0] };
	my @vertices_numbers =  @{ $warp->[$countop][1] };
	my @swingrotations = @{ $warp->[$countop][2] };
	my @yes_or_no_apply_to_others = @{ $warp->[$countop][3] };
	my $configfilename = $$warp[$countop][4];

	my $configfile;
	unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
	{
		$configfile = $to."/opts/".$configfilename;
	}
	else
	{
		$configfile = $to."\\opts\\".$configfilename;
	}

	my @pairs_of_vertices = @{ $warp->[$countop][5] }; # @pairs_of_vertices defining axes
	my @windows_to_reallign = @{ $warp->[$countop][6] };
	my $sourcefilename = $$warp[$countop][7];
	my $sourcefile = $to.$sourcefilename;
	my $countrotate = 0;
	foreach my $surface_letter (@surfs_to_warp)
	{
		$swingrotate = $swingrotations[$countrotate];

		if ( ref ( $swingrotate ) )
		{
			my $min = $swingrotate->[0];
			my $max = $swingrotate->[1];
			$swingrotate = ( $max - $min );
		}

		$pacerotate = ( $swingrotate / ( $stepsvar - 1 ) );
		$rotation_degrees = ( ( $swingrotate / 2 ) - ( $pacerotate * ( $countstep - 1 ) )) ;
		$vertex_number = $vertices_numbers[$countrotate];
		$yes_or_no_apply = $yes_or_no_apply_to_others[$countrotate];
		if (  ( $swingrotate != 0 ) and ( $stepsvar > 1 ) and ( $yes_or_no_warp eq "y" ) )
		{
			my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
e
>
$surface_letter
c
$vertex_number
$rotation_degrees
$yes_or_no_apply
-
-
y
c
-
-
-
-
-
-
-
-
YYY
";
			unless ($exeonfiles eq "n")
			{
				print `$printthis`;
			}
			print  $tee "
#Warping zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
		}
		$countrotate++;
	}

	# THIS SECTION READS THE CONFIG FILE FOR DIMENSIONS
	open( SOURCEFILE, $sourcefile ) or die "Can't open $sourcefile: $!\n";
	my @lines = <SOURCEFILE>;
	close SOURCEFILE;
	my $countlines = 0;
	my $countvert = 0;
	foreach my $line (@lines)
	{
		$line =~ s/^\s+//;

		my @rowelements = split(/\s+|,/, $line);
		if   ($rowelements[0] eq "*vertex" )
		{
			if ($countvert == 0)
			{
				push (@v, [ "vertices of  $sourceaddress" ]);
				push (@v, [ $rowelements[1], $rowelements[2], $rowelements[3] ] );
			}

			if ($countvert > 0)
			{
				push (@v, [ $rowelements[1], $rowelements[2], $rowelements[3] ] );
			}
			$countvert++;
		}
		$countlines++;
	}


	my @vertexletters = (
	"a",   "b",   "c",   "d",   "e",   "f",   "g",   "h",   "i",   "j",   "k",   "l",   "m",   "n",   "o",   "p",
	"0\np", "0\nq", "0\nr", "0\ns", "0\nt", "0\nu", "0\nv", "0\nw", "0\nx", "0\ny", "0\nz", "0\na", "0\nb",  "0\nc",  "0\nd",  "0\ne",
	"0\n0\nc\ne", "0\n0\nc\nf", "0\n0\nc\ng", "0\n0\nc\nh", "0\n0\nc\ni", "0\n0\nc\nj", "0\n0\nc\nk", "0\n0\nc\nl",
	"0\n0\nc\nm", "0\n0\nc\nn", "0\n0\nc\no", "0\n0\nc\np", "0\n0\nc\nq", "0\n0\nc\nr", "0\n0\nc\ns", "0\n0\nc\nt",
	"0\n0\nc\n0\nc\nt", "0\n0\nc\n0\nc\nu", "0\n0\nc\n0\nc\nv", "0\n0\nc\n0\nc\nw", "0\n0\nc\n0\nc\nx", "0\n0\nc\n0\nc\ny", "0\n0\nc\n0\nc\nz", "0\n0\nc\n0\nc\na",
	"0\n0\nc\n0\nc\nb", "0\n0\nc\n0\nc\nc", "0\n0\nc\n0\nc\nd", "0\n0\nc\n0\nc\ne", "0\n0\nc\n0\nc\nf", "0\n0\nc\n0\nc\ng", "0\n0\nc\n0\nc\nh", "0\n0\nc\n0\nc\ni",
	"0\n0\nc\n0\nc\n0\nc\ni", "0\n0\nc\n0\nc\n0\nc\nj", "0\n0\nc\n0\nc\n0\nc\nk", "0\n0\nc\n0\nc\n0\nc\nl", "0\n0\nc\n0\nc\n0\nc\nm", "0\n0\nc\n0\nc\n0\nc\nn", "0\n0\nc\n0\nc\n0\nc\no", "0\n0\nc\n0\nc\n0\nc\np",
	"0\n0\nc\n0\nc\n0\nc\nq", "0\n0\nc\n0\nc\n0\nc\nr", "0\n0\nc\n0\nc\n0\nc\ns", "0\n0\nc\n0\nc\n0\nc\nt", "0\n0\nc\n0\nc\n0\nc\nu", "0\n0\nc\n0\nc\n0\nc\nv", "0\n0\nc\n0\nc\n0\nc\nw", "0\n0\nc\n0\nc\n0\nc\nx"
	);

	if (-e $configfile)
	{
		eval `cat $configfile`; # HERE AN EXTERNAL FILE FOR PROPAGATION OF CONSTRAINTS IS EVALUATED
		# AND PROPAGATED.

		if (-e $constrain) { eval ($constrain); } # HERE THE INSTRUCTION WRITTEN IN THE OPT CONFIGURATION FILE CAN BE SPEFICIED
		# FOR PROPAGATION OF CONSTRAINTS

	}
	# THIS SECTION SHIFTS THE VERTEX TO LET THE BASE SURFACE AREA UNCHANGED AFTER THE WARPING.

	my $countthis = 0;
	$number_of_moves = ( (scalar(@pairs_of_vertices)) /2 ) ;
	foreach my $pair_of_vertices (@pairs_of_vertices)
	{
		if ($countthis < $number_of_moves)
		{
			$vertex1 = $pairs_of_vertices[ 0 + ( 2 * $countthis ) ];
			$vertex2 = $pairs_of_vertices[ 1 + ( 2 * $countthis ) ];

			my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
c
a
$zone_letter
d
^
j
$vertex1
$vertex2
-
$addedlength
y
-
y
-
y
-
-
-
-
-
-
-
-
YYY
";
			unless ($exeonfiles eq "n")
			{
				print `$printthis\n`;
			}
			print $tee "#Warping zones for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.
$printthis";
		}
		$countthis++;
	}
}    # END SUB warp


sub export_toenergyplus
{
				my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $export_toenergyplus_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;



				my @applytype = @{ $applytype_ref->[ $countop ] };
				my @export_toenergypluses = @{ $export_toenergyplus_ref->[ $countop ] };

				my @menus = @$menus_ref;
				my %numvertmenu = %{ $menus[0] };
				my %vertnummenu = %{ $menus[1] };

				shift( @export_toenergypluses );
				my $sim = shift( @export_toenergypluses );
				my $retrieve = shift( @export_toenergypluses );
				my $epw = shift( @export_toenergypluses );

				my $epwfile;
				unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
				{
					$epwfile = $mypath . "/" . $epw;
				}
				else
				{
					$epwfile = $mypath . "\\" . $epw;
				}

				say $tee "Exporting to EnergyPlus for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $file_eplus = "$to.idf";

	my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY

o
g
b
$file_eplus



-
-
YYY
";
	unless ($exeonfiles eq "n")
	{
		`$printthis\n`;
	}
	say $tee "#EXPORTING FILE $file_eplus TO ENERGYPLUS.\n $printthis";
	my $oldfile = $file_eplus;
	$oldfile =~ s/\.idx//;
	$oldfile = $oldfile . ".old.idx";

	unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
	{
		unless ( $exeonfiles eq "n" )
		{
			`mv -f $file_eplus $oldfile`;
		}
		#print $tee "mv -f $file_eplus $oldfile\n";
	}
	else
	{
		unless ( $exeonfiles eq "n" )
		{
			`move /y $file_eplus $oldfile`;
		}
		#print $tee "move /y $file_eplus $oldfile\n";
	}

	open ( OLDFILEEPLUS, $oldfile ) or die( "$!" );
	my @oldlines = <OLDFILEEPLUS>;
	close OLDFILEEPLUS;

	open ( NEWFILEEPLUS, ">$file_eplus" ) or die( "$!" );

	foreach my $line ( @oldlines )
	{
		foreach my $elt ( @export_toenergypluses )
		{
			my $old = $elt->[0];
			my $new = $elt->[1];
			$line =~ s/$old/$new/;
		}
		print NEWFILEEPLUS $line;
	}
	close NEWFILEEPLUS;

	if ( $sim )
	{
		unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
		{
			unless ( $exeonfiles eq "n" )
			{
				`runenergyplus $file_eplus $epwfile`;
			}
			#print $tee "runenergyplus $file_eplus $epwfile\n"; # EPW FILE, FOR INSTANCE: /usr/local/EnergyPlus-7-2-0/WeatherData/USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw
		}
		else
		{
			unless ( $exeonfiles eq "n" )
			{
				`runeplus $file_eplus $epwfile`;
			}
			#print $tee "runeplus $file_eplus $epwfile\n"; # EPW FILE
		}
	}

	if ( $retrieve )
	{
		#retrieveepw( $TO_DO );
	}
}


sub use_modish
{
	#use strict;
	#use warnings;

			my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $use_modish_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;


			my @applytype = @$applytype_ref;
			my @use_modish = @{ $use_modish_ref->[ $countop ] };
			my $pathhere = "$to/cfg/$fileconfig";
			say $tee "Executing modish.pl for calculating the effect of solar reflections on obstructions for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

			my @menus = @$menus_ref;
			my %dowhat = %$dowhat_ref;

			my %numvertmenu = %{ $menus[0] };
			my %vertnummenu = %{ $menus[1] };

			my %numletter = %numvertmenu;

			if ( @use_modish )
			{
				foreach $cycle_ref ( @use_modish )
				{
					my @cycle = @$cycle_ref; say $tee "\@cycle " . dump( @cycle );

					my $shortmodishdefpath;
					if ( ref $cycle[0] )
					{
                        $shortmodishdefpath_ref = shift( @cycle ) ;
					}
					my $modishdefpath = "$to" . "$shortmodishdefpath_ref->[0]" ;

			my $zonenumber = $cycle[0];
			my $shdname = $to . $cycle[1];
			my $shdaname = $shdname . "a";
			my @surfaces = @cycle[ 2..$#cycle ];
			my $oldshdname = $shdname . ".old";
			my $oldshdaname = $shdaname . ".old";
			my $tempname = $shdname;
			my $tempname2 = $tempname;
			$tempname =~ s/.shd//;
			my $modshdaname = $tempname . ".mod.shda";
			my $testshdaname = $tempname2 . "test.shda";
			$" = " ";
			#$" = ",";

			#print $tee "rm -f $to/rad/*\n";
			`rm -f $to/rad/*`;
			#print $tee "perl ./Modish.pm $to/cfg/$fileconfig $zonenumber @surfaces \r\n";
			`perl ./Modish.pm $to/cfg/$fileconfig $zonenumber @surfaces `;

			`cp -f $shdname $oldshdname`;
			#print $tee "cp -f $shdname $oldshdname\n";
			`cp -f $shdaname $oldshdaname`;
			#print $tee "cp -f $shdname $oldshdname\n";
			`cp -f $modshdaname $shdaname`;
			#print $tee "cp -f $modshdaname $shdaname\n";


			$" = " ";
			if ( -e $modshdaname )
			{
				my $printthis =
"ish -file $to/cfg/$fileconfig -mode script -mode script<<YYY

b
$numletter{$zonenumber}
m
b
$modshdaname
m
a
$testshdaname
-
y
-
YYY
";
				#print $tee "SETTING UP THINGS AFTER RUNNING modish.pl.\n $printthis";
				unless ($exeonfiles eq "n")
				{
					print `$printthis`; say $tee "$printthis";
				}
			}
			else
			{
				die "NO .mod.shda FILE HERE. STOPPING.";####################
				;
			}
		}
	}
}


sub genchange
{  # TO DO: POSSIBILITY TO SPECIFY TEXT STRINGS IN PLACE OF ELEMENTS

	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $genchange, $countvar, $fileconfig, $mypath, $file,
	$countmorphing, $todo, $names_ref, $nums_ref, $newcontents_ref,
	$filecontents_ref, $newfilecontents_ref, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Executing genchange for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";
	my $this_cycledata = $genchange->[$countop];
	my @filequestions = @{ $this_cycledata->[1] };
	my ( @plaincontents, @filecontents, @newfilecontents );
        my ( %names, %nums, %newcontents );

        sub read_gen
	{
                my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $genchange, $countvar, $fileconfig, $mypath, $file, $countmorphing, $todo, $names_ref, $nums_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref, $launchline, $fullfilepath, $new_fullfilepath, $filequestions_ref ) = @_;
                my @filequestions = @$filequestions_ref;
                my $countunique = 1;
                my $countfile = 0;

                my @applytype = @$applytype_ref;

                foreach my $filequests ( @filequestions )
		{
			my @truequests = @$filequests;
			my $constrainfiles_ref = shift( @truequest );
			my @constrainfiles = @{ $constrainfiles_ref };
			my $thisfile = shift( @truequests );
			$thisfile =~ /\.(\d+)?/ ;
			$afterdot = $1 ;
			#say $tee "AFTERDOT:\ $afterdot";
			my $fullfilepath = $to . $thisfile ;
			my $new_fullfilepath = $fullfilepath . ".$afterdot" ;

			#say $tee "fullfilepath: $fullfilepath";
			open( FULLFILEPATH, "$fullfilepath" ) or die ( "$!" );
			my @filerows = <FULLFILEPATH>;
			my @passrows = @filerows;
			close FULLFILEPATH;
			@{ $plaincontents[ $countfile ] } = @filerows;

			my $countro = 0;
			foreach my $row ( @filerows )
			{
				my $newrow = "";
				$row =~ s/^\s+//; # CLEAR WHITE SPACES AT THE BEGINNING OF THE LINE
				$row =~ s/\s+/ /g; # MAKE SEQUENCES OF WHITE SPACES ONE SPACE
				#$" = " ";
				my @row_elts = split( /\s+|,|;/, $row );
				my @rowelts = supercleanarray( @row_elts );
				@{ $filecontents[ $countfile ][ $countro ] } = @rowelts ;
				#$plaincontents[ $countfile ][ $countro ] = $row;

				#my $count = 0;
				#foreach my $el ( @rowelts )
				#{
				#  $filecont{$countfile}{$countro}{$count} = $el ;
				#  $count++;
				#}
				$countro++;
			}
			#@newfilecontents = @filecontents;

			$countrow = 0;
			foreach my $row ( @filerows )
			{

				my $countquest = 0;
				my $countcoord = 0;

				foreach my $quest ( @truequests )
				{

					if ( scalar( @{ $quest } ) > 0 )
					{
						my @row_numbers_plus1 = @{ $quest->[0] };
						my @row_numbers = decreasearray( @row_numbers_plus1 );
						my $countrownum = 0;
						foreach my $row_number ( @row_numbers )
						{
							#if ( $row_number == $countrow )
							#{
							#  say $tee "YES HERE \$row_number $row_number eq \$countrow $countrow";
							#}
							my @elts_pos_plus1 = @{ $quest->[1] };
							my @elts_pos = decreasearray( @elts_pos_plus1 );

							my $range = $quest->[2];
							my @nicknames = @{ $quest->[3] };
							#if ( scalar( @nicknames ) == 0 )
							#{
							#  @nicknames = @row_numbers_plus1;
							#}
							my $operation_type = $quest->[4];
							my $separator =  $quest->[5];
							my $precision =  $quest->[6];
							my @centrexyz = @{ $quest->[7] };
							my $centrex = $centrexyz[0];
							my $centrey = $centrexyz[1];
							my $centrez = $centrexyz[2];

							my @rowelts = @{ $filecontents[ $countfile ][ $countrow ] };

							my $countpos = 0;
							foreach $elt_position ( @elts_pos )
							{
								my $countelt = 0;

								foreach my $rowelt ( @rowelts )
								{
									my ( $truerange, $low, $high, $pace, $value, $base, $newvalue, $newangle );

									{

										my @coords;
										if ( ( $row_number == $countrow ) and ( $elt_position == $countelt ) )
										{





											my $next_elt_position = $elts_pos[ $countpos + 1 ];
											my $prev_elt_position = $elts_pos[ $countpos - 1 ];



											if ( defined( $range ) and ( $range ne "" ) )
											{
												if ( not ( defined( $operation_type ) ) )
												{
													$operation_type = "linear"; #LINEAR TRANSFORMATION.
												}

												if ( $operation_type eq "linear" )
												{
													if ( not ( ref( $range ) ) )
													{
														$truerange = ( 2 * $range );
														$base = ( $rowelt - $range );
													}
													else
													{
														( $low, $high ) = ( $range->[0], $range->[1] );
														$truerange = ( $high - $low );
														$base = ( $rowelt + $low );
													}

													$pace = ( $truerange / ( $stepsvar - 1 ) );
													$newvalue = ( $base + ( $pace * ( $countstep - 1 ) ) );
												} # INSERT HERE WHAT HAPPENS IF THE TRANSFORMATION IS NOT LINEAR.

												if ( $operation_type eq "rotation2d" )
												{
													$countcoord++;
													if ( not ( ref( $range ) ) )
													{
														$truerange = ( 2 * $range );
														$base = - $range;
													}
													else
													{
														( $low, $high ) = ( $range->[0], $range->[1] );
														$truerange = ( $high - $low );
														$base = $low;
													}

													$pace = ( $truerange / ( $stepsvar - 1 ) );
													$newangle = ( $base + ( $pace * ( $countstep - 1 ) ) );

													my $next_elt_position = $elts_pos[ $countelt + 1  ];
													my $prev_elt_position = $elts_pos[ $countelt - 1  ] ;

													if ( $countcoord == 1 )
													{

														my @obtained = rotate2d( $rowelt, $rowelts[ $next_elt_position ] , $newangle, $centrex, $centrey );
														$newvalue = $obtained[0];
														#if ( ( $newvalue < 0.00001 ) and ( $newvalue > - 0.00001 ) ){ $newvalue = 0; } ;

													}
													elsif ( $countcoord == 2 )
													{



														#my @obtained = rotate2d ( $filecontents[ $countfile ][ $row_number ][ $prev_elt_position ] , $rowelt, $newangle, $centrex, $centrey );
														my @obtained = rotate2d ( $rowelts[ $prev_elt_position ], $rowelt, $newangle, $centrex, $centrey );
														$newvalue = $obtained[1];
														#if ( ( $newvalue < 0.00001 ) and ( $newvalue > - 0.00001 ) ) { $newvalue = 0; } ;
														$countcoord = 0;
													}
												}

												if ( $operation_type eq "wordchange" )
												{
													my @newwords = @$range;
													$newvalue = $newwords[ $countstep - 1 ];

												}

												if ( $operation_type eq "rotation2d_multiline" ) #TO BE CHECKED
												{
													$countcoord++;
													if ( not ( ref( $range ) ) )
													{
														$truerange = ( 2 * $range );
														$base = - $range;
													}
													else
													{
														( $low, $high ) = ( $range->[0], $range->[1] );
														$truerange = ( $high + $low );
														$base = - $low;
													}

													$pace = ( $truerange / ( $stepsvar - 1 ) );
													$newangle = ( $base + ( $pace * ( $countstep - 1 ) ) );

													if ( $countcoord == 1 )
													{




														#my @obtained = rotate2d( $rowelt, $filecontents[ $countfile ][ $next_row_number ][ $elt_position ]  , $newangle, $centrex, $centrey );
														$newvalue = $obtained[0];
														if ( ( $newvalue < 0.00001 ) and ( $newvalue > - 0.00001 ) ){ $newvalue = 0; } ;
													}
													elsif ( $countcoord == 2 )
													{



														#my @obtained = rotate2d ( $filecontents[ $countfile ][ $prev_row_number ][ $elt_position ] , $rowelt, $newangle, $centrex, $centrey );
														my @obtained = rotate2d ( $filecontents[ $countfile ][ $prev_row_number ][ $elt_position ], $rowelt, $newangle, $centrex, $centrey );
														$newvalue = $obtained[1];
														#if ( ( $newvalue < 0.00001 ) and ( $newvalue > - 0.00001 ) ) { $newvalue = 0; } ;
														$countcoord = 0;
													}
												}

											}
											elsif ( ( $range ne "" ) and ( $operation_type eq "" ) )
											{
												$newvalue = $rowelt;
											}


											my $nickname;
											if ( scalar( @nicknames ) == 0 )
											{
												$nickname = $countvar . "-" . ( $countrow + 1) . "-" . ( $countelt + 1 );
											}

											my $thisline = $passrows[$countrows];
											$names{$nickname} =
											{
												oldvalue => $rowelt,
												countfile => $countfile,
												countrow => $countrow,
												countelt => $countelt,
												newvalue => $newvalue,
												fullfilepath => $fullfilepath,
												countquest => ( $countquest + 1 ),
												nickname => $nickname,
												row => $thisline,
												separator => $separator,
												precision => $precision,
												operation_type => $operation_type,
											};

											$nums{$countunique} =
											{
												oldvalue => $rowelt,
												countfile => $countfile,
												countrow => $countrow,
												countelt => $countelt,
												newvalue => $newvalue,
												fullfilepath => $fullfilepath,
												countquest => ( $countquest + 1 ),
												nickname => $nickname,
												row => $thisline,
												separator => $separator,
												precision => $precision,
												operation_type => $operation_type,
											};
											$countunique++;
										}
									}
									$countelt++;
								}
								$countpos++;
							}
							$countrownum++;
						}
					}
					$countquest++;
				}
				$countrow++;
			}
			$countfile++;
		}
		return (  \%names, \%nums, \%newcontents, \@newfilecontents, \@plaincontents, \@filecontents );
	}

	if ( ( $todo eq "read_gen" ) or ( $todo eq "vary" ) or ( $applytype[$countop][0] eq "genchange" ) )
	{
		( $names_ref, $nums_ref, $newcontents_ref, $newfilecontents_ref, $plaincontents_ref, $filecontents_ref ) =
		read_gen( $to, $stepsvar, $countop, $countstep, $applytype_ref, $genchange, $countvar, $fileconfig, $mypath, $file,
				$countmorphing, $todo,  $names_ref, $nums_ref, $newcontents_ref,
				$filecontents_ref, $newfilecontents_ref, $launchline, , $fullfilepath, $new_fullfilepath, \@filequestions );
		%names = %$names_ref;
		%nums = %$nums_ref;
		%newcontents = %$newcontents_ref;
		@newfilecontents = @$newfilecontents_ref;
		@plaincontents = @$plaincontents_ref;
		@filecontents = @$filecontents_ref;
	}

	sub read_gen_constraints
	{
		my ( $constrainfiles_ref, $names_ref, $newcontents_ref ) = @_;
		my @constrainfiles = @$constrainfiles_ref;
		my %names = %$names_ref;
		my %newcontents = %$newcontents_ref;
		foreach my $constrainfile ( @constrainfiles )
		{
			if ( ( -e $constrainfile ) and ( defined( $constrainfile ) ) )
			{
				eval `cat $constrainfile`;
			}
		}


		foreach my $nickname ( sort {$a <=> $b} ( keys %names ) )
		{
			if ( defined( $nickname ) )
			{
				$newcontents{$names{$nickname}{countfile}}{$names{$nickname}{countrow}}{$names{$nickname}{countquest}}{$names{$nickname}{countelt}} = $names{$nickname}{newvalue} ;
			}
		}
		return ( \%names, \%newcontents );
	}

	if ( ( $todo eq "read_gen" ) or ( $todo eq "vary" ) )
	{
		( $names_ref, $newcontents_ref ) = read_gen_constraints ( \@constrainfiles, \%names, \%newcontents );
		%names = %$names_ref;
		%newcontents = %$newcontents_ref;
	}

	if ( ( $todo eq "read_gen" ) or ( $todo eq "vary" ) )
	{
		foreach my $uniqnum ( sort { $a <=> $b } keys %nums )
		{
			foreach my $nickname ( keys %names )
			{
				if ( ( defined ( $nickname ) ) and ( $nickname ne "" ) )
				{
					if ( $nickname eq $nums{$uniqnum}{nickname} )
					{
						if ( ( $nums{$uniqnum}{newvalue} ne $names{$nickname}{newvalue} ) and ( $nums{$uniqnum}{newvalue} != $names{$nickname}{newvalue} ) )
						{
							$nums{$uniqnum}{newvalue} = $names{$nickname}{newvalue} ;
						}
					}
				}
			}
		}
	}



	sub foreachcontentsref
	{
		my ( $plaincontents_ref, $names_ref, $nums_ref, $filecontents_ref ) = @_;
		my @plaincontents = @$plaincontents_ref;
		my %names = %$names_ref;
		my %nums = %$nums_ref;
		my @filecontents = @$filecontents_ref;
		my $countfile = 0;
		foreach my $fil ( @plaincontents )
		{
			my $countline = 0;


			foreach my $newrow ( @$fil )
			{
				my $thisnewrow;
				foreach my $countunique ( sort { $a <=> $b } keys ( %nums ) )
				{
					my $nickname = $nums{$countunique}{nickname};

					my $el = $nums{$countunique}{oldvalue};
					my $newel = $nums{$countunique}{newvalue};
					my $countrow = $nums{$countunique}{countrow};
					my $countelt = $nums{$countunique}{countelt};
					my $fullfilepath = $nums{$countunique}{fullfilepath};
					my $separator = $nums{$countunique}{separator};
					my $precision = $nums{$countunique}{precision};
					my $operation_type = $nums{$countunique}{operation_type};
					my $counteltminus1 = ( $countelt - 1 );
					if ( defined( $newel ) and ( $newel ne "" ) and  defined( $el ) and ( $el ne "" ) and defined( $el ) and ( $el ne " " ) )
					{
						if ( $countrow == $countline )
						{
							my $alternewrow = $newrow;
							my @seps = gatherseparators( $newrow );
							$alternewrow =~ s/^\s+//; # CLEAR WHITE SPACES AT THE BEGINNING OF THE LINE
							$alternewrow =~ s/\s+//g;
							my @rowelts = split( /\s+|,|;/, $alternewrow );
							#my @rowelts = @{ $filecontents[ $countfile ][ $countline ] };
							#@rowelts = purifyarray( @rowelts );
							my $thiselt = $rowelts[ $countelt ];
							my @previouselts = @rowelts[ 0..$counteltminus1 ];
							my $countscore = 0;
							foreach my $elem ( @previouselts )
							{
								if ( not ( $operation_type eq "wordchange" ) )
								{
									my $elemcomma = "$elem,";
									my $elemcomma = "$thiselt,";
								}
								else
								{
									my $elemcomma = "$elem";
									my $elemcomma = "$thiselt";
								}
								if ( $elemcomma eq $thiselt )
								{
									$countscore++;
								}
							}

							my ( $retel, $truenewel );
							if ( $tooltype eq "esp-r" )
							{
								if ( not ( $operation_type eq "wordchange" ) )
								{
									( $retel, $truenewel ) = fixlength( $thiselt, $newel, "n" ); #ORIGINARY NUMBER, NEW NUMBER, "y" FOR ADJUSTING THE LENGTH DO THAT WHEN NEGATIVE IT OCCUPIES ONE CHARACTER MORE, or nothing
									$newrow = replace_nth( "$newrow", $countscore, "$retel,", "$truenewel," );
								}
								else
								{
									$newrow = replace_nth( "$newrow", $countscore, "$el,", "$newel," );
								}



							}
							else
							{
								#$newel = sprintf( "%.3f", $newel ); say $tee "\$newel " . dump( $newel );
								#$newrow = replace_nth( "$newrow", $countscore, "$thiselt,", "$newel," );
								my $smallpiece;
								if ( not ( $operation_type eq "wordchange" ) )
								{
									$smallpiece = "%." . $precision . "f";
									$newel = sprintf( $smallpiece, $newel );
									$rowelts[ $countelt ] = $newel;
									my $begin = "  ";
									my $count = 0;
									foreach ( @rowelts )
									{
										my $sep = $seps[ $count ];
										$begin = "$begin" . "$_" . "$sep ";
										$count++;
									}
									$newrow = "$begin\n";
								}
								else
								{
									$newrow = replace_nth( "$newrow", $countscore, $el, $newel );
								}
							}
						}
					}
				}
				$newfilecontents[ $countfile ][ $countline ] = $newrow ;
				$countline++;
			}
			$countfile++;
		}
		return ( \@newfilecontents );
	}

	if ( ( $todo eq "read_gen" ) or ( $todo eq "vary" ) )
	{
		$newfilecontents_ref = foreachcontentsref ( \@plaincontents, \%names, \%nums, \@filecontents );

		@newfilecontents = @$newfilecontents_ref;
	}


	sub foreachfilerequest
	{
		my ( $filequestions_ref, $to, $newfilecontents_ref ) = @_;
		my @filequestions = @$filequestions_ref;

		my @newfilecontents = @$newfilecontents_ref;
		my $countfile = 0;
		foreach my $filequests ( @filequestions )
		{
			my @truequests = @$filequests;
			my $constrainfiles_ref = shift( @truequest );
			my @constrainfiles = @{ $constrainfiles_ref };
			my $thisfile = shift( @truequests );
			my $fullfilepath = $to . $thisfile ;
			my $new_fullfilepath = $fullfilepath . ".new" ;

			my $oldfile = $fullfilepath . ".bac";
			my $newfile = $fullfilepath . ".new";
			my $newfile_ = $to . ".idf";

			open( NEWFILECONTENTS, ">$newfile" ) or die( "$!" );

			foreach my $my_row ( @{ $newfilecontents[ $countfile ] } )
			{
				if ( not ( ref( $my_row ) ) )
				{
					print NEWFILECONTENTS $my_row;
				}
			}
			close NEWFILECONTENTS;



			unless ( ( "$^O" eq "MSWin32" ) or ( "$^O" eq "MSWin64" ) )
			{
				say $tee "mv -f $fullfilepath $oldfile";
				`mv -f $fullfilepath $oldfile` ;
				#say $tee "cp -f $newfile $newfile_";
				#`cp -f $newfile $newfile_` ;
				say $tee "mv -f $newfile $fullfilepath";
				`mv -f $newfile $fullfilepath` ;
			}
			else
			{
				say $tee "xcopy  /e /c /r /y $fullfilepath $oldfile";
				`xcopy  /e /c /r /y $fullfilepath $oldfile`  or die ("$!") ;
				say $tee "xcopy  /e /c /r /y $newfile $newfile_";
				`xcopy  /e /c /r /y $newfile $newfile_` or die $! ;
				say $tee "xcopy  /e /c /r /y $newfile $fullfilepath";
				`xcopy  /e /c /r /y $newfile $fullfilepath` or die $! ;

			}
			$countfile++;
		}
	}

	if ( ( $todo eq "write_gen" ) or ( $todo eq "vary" ) )
	{
		foreachfilerequest( \@filequestions, $to, \@newfilecontents  );
	}
	close FULLFILEPATH;
	return ( \%names, \%nums, \%newcontents, \@filecontents, \@newfilecontents );
}


sub genprop
{  # TO DO: POSSIBILITY TO SPECIFY TEXT STRING IN PLACE OF ELEMENT
	my ($to, $stepsvar, $countop, $countstep, $applytype_ref, $genchange, $countvar, $fileconfig, $mypath, $file, $countmorphing, $todo,
		$names_ref, $nums_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref, $launchline, $menus_ref, $countinstance ) = @_;

	( $names_ref, $nums_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref ) = genchange ($to, $stepsvar, $countop, $countstep,
												$applytype_ref, $genchange, $countvar, $fileconfig, $mypath, $file, $countmorphing, $to_do,
												$names_ref, $nums_ref, $newcontents_ref, $filecontents_ref, $newfilecontents_ref,
												$launchline, $countinstance );
	%names = %$names_ref;
	%newcontents = %$newcontents_ref;
	@filecontents = @$filecontents_ref;
	@newfilecontents = @$newfilecontents_ref;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	return ( \%names, \%newcontents, \@filecontents, \@newfilecontents );
}

sub change_groundreflectance
{
	#use strict;
	#use warnings;
	( $to, $stepsvar, $countop, $countstep, $applytype_ref, $change_groundreflectance, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;
	my @applytype = @$applytype_ref;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Changing ground reflectance for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";
	my ( $low, $high, $swing, $pace, $newvalue );

	if ( $change_groundreflectance )
	{
		my @this_cycledata = @{ $change_groundreflectance->[ $countop ] };
		my $basevalue = $this_cycledata[0];
		my $swingcontent = $this_cycledata[1];
		if ( ref( $swingcontent ) )
		{
			$low = $swingcontent->[0];
			$high = $swingcontent->[1];
			$swing = ( $high - $low );
		}
		else
		{
			$swing = ( $swingcontent * 2 );
		}
		$pace = ( $swing / ( $stepsvar - 1 ) );
		$newvalue = ( $basevalue + ( $pace * ( $countstep - 1 ) ) );
	}

	my $printthis =
"cd $to/cfg/
prj -file $fileconfig -mode script<<YYY
m
b
d
a
$newvalue
-
-
-
YYY
";

	unless ($exeonfiles eq "n")
	{
		print `$printthis`;
	}
	say $tee "CHANGING GROUND REFLECTANCE.\n $printthis";
	#no strict;
	#no warnings;
}


sub vary_controls
{    # IT IS CALLED FROM THE MAIN FILE
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $vary_controls_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing, $launchline, $menus_ref, $countinstance ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];
	my @vary_controls = @{ $vary_controls_ref[ $countop ] } ;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Variating controls for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my ( $semaphore_zone, $semaphore_dataloop, $semaphore_massflow, $semaphore_setpoint, $doline );
	my $count_controlmass = -1;
	my $countline = 0;
	my @letters = ("e", "f", "g", "h", "i", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "z"); # CHECK IF THE LAST LETTERS ARE CORRECT
	my @period_letters = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "l", "m", "n", "o", "p", "q", "r", "s"); # CHECK IF THE LAST LETTERS ARE CORRECT
	my $loop_hour = 2; # NOTE: THE FOLLOWING VARIABLE NAMES ARE SHADOWED IN THE FOREACH LOOP BELOW,
	# BUT ARE THE ONES USED IN THE OPT CONSTRAINTS FILES.
	my $max_heating_power = 3;
	my $min_heating_power = 4;
	my $max_cooling_power = 5,
	my $min_cooling_power = 6;
	my $heating_setpoint = 7;
	my $cooling_setpoint = 8;
	my $flow_hour = 2;
	my $flow_setpoint = 3;
	my $flow_onoff = 4;
	my $flow_fraction = 5;
	my $loop_letter;
	my $loopcontrol_letter;

	my @group = @{$vary_controls[$countop]};
	my $sourcefile = $group[0];
	my $targetfile = $group[1];
	my $configfile = $group[2];
	my @buildbulk = @{$group[3]};
	my @flowbulk = @{$group[4]};

	my $countbuild = 0;
	my $countflow = 0;

	my $countcontrol = 0;
	my $sourceaddress = "$to$sourcefile";
	my $targetaddress = "$to$targetfile";
	my $configaddress = "$to$configfile";

	my ( @groupzone_letters, @zone_period_letters, @flow_letters, @fileloopbulk, @fileflowbulk );

	checkfile($sourceaddress, $targetaddress);

	if ($countstep == 1)
	{
		read_controls($sourceaddress, $targetaddress, \@letters, \@period_letters);
	}


	sub calc_newctl
	{
		# THIS COMPUTES CHANGES TO BE MADE TO CONTROLS BEFORE PROPAGATION OF CONSTRAINTS
		my ( $to, $stepsvar, $countop, $countstep, $swap, $swap2, $swap3, $swap4, $countvar, $fileconfig, $countmorphing ) = @_;

		my @buildbulk = @$swap;
		my @flowbulk = @$swap2;
		my @loopcontrol = @$swap3;
		my @flowcontrol = @$swap4;

		my ( @new_loop_hours, @new_max_heating_powers, @new_min_heating_powers, @new_max_cooling_powers, @new_min_cooling_powers, @new_heating_setpoints,
			@new_cooling_setpoints, @new_flow_hours, @new_flow_setpoints, @new_flow_onoffs, @new_flow_fractions );

		# HERE THE MODIFICATIONS TO BE EXECUTED ON EACH PARAMETERS ARE CALCULATED.
		if ($stepsvar == 0) {$stepsvar = 1;}
		if ($stepsvar > 1)
		{
			foreach $each_buildbulk (@buildbulk)
			{
				my @askloop = @{$each_buildbulk};
				my $new_loop_letter = $askloop[0];
				my $new_loopcontrol_letter = $askloop[1];
				my $swing_loop_hour = $askloop[2];
				my $swing_max_heating_power = $askloop[3];
				my $swing_min_heating_power = $askloop[4];
				my $swing_max_cooling_power = $askloop[5];
				my $swing_min_cooling_power = $askloop[6];
				my $swing_heating_setpoint = $askloop[7];
				my $swing_cooling_setpoint = $askloop[8];

				my $countloop = 0; #IT IS FOR THE FOLLOWING FOREACH. LEAVE IT ATTACHED TO IT.
				foreach $each_loop (@loopcontrol) # THIS DISTRIBUTES THIS NESTED DATA STRUCTURES IN A FLAT MODE TO PAIR THE INPUT FILE, USER DEFINED ONE.
				{
					my $countcontrol = 0;
					@thisloop = @{$each_loop};
					foreach $lp (@thisloop)
					{
						my @control = @{$lp};
						$loop_letter = $loopcontrol[$countloop][$countcontrol][0];
						$loopcontrol_letter = $loopcontrol[$countloop][$countcontrol][1];
						if ( ( $new_loop_letter eq $loop_letter ) and ($new_loopcontrol_letter eq $loopcontrol_letter ) )
						{

							$loop_hour__ = $loopcontrol[$countloop][$countcontrol][$loop_hour];
							$max_heating_power__ = $loopcontrol[$countloop][$countcontrol][$max_heating_power];
							$min_heating_power__ = $loopcontrol[$countloop][$countcontrol][$min_heating_power];
							$max_cooling_power__ = $loopcontrol[$countloop][$countcontrol][$max_cooling_power];
							$min_cooling_power__ = $loopcontrol[$countloop][$countcontrol][$min_cooling_power];
							$heating_setpoint__ = $loopcontrol[$countloop][$countcontrol][$heating_setpoint];
							$cooling_setpoint__ = $loopcontrol[$countloop][$countcontrol][$cooling_setpoint];
						}
						$countcontrol++;
					}
					$countloop++;
				}

				my $pace_loop_hour =  ( $swing_loop_hour / ($stepsvar - 1) );
				my $floorvalue_loop_hour = ($loop_hour__ - ($swing_loop_hour / 2) );
				my $new_loop_hour = $floorvalue_loop_hour + ($countstep * $pace_loop_hour);

				my $pace_max_heating_power =  ( $swing_max_heating_power / ($stepsvar - 1) );
				my $floorvalue_max_heating_power = ($max_heating_power__ - ($swing_max_heating_power / 2) );
				my $new_max_heating_power = $floorvalue_max_heating_power + ($countstep * $pace_max_heating_power);

				my $pace_min_heating_power =  ( $swing_min_heating_power / ($stepsvar - 1) );
				my $floorvalue_min_heating_power = ($min_heating_power__ - ($swing_min_heating_power / 2) );
				my $new_min_heating_power = $floorvalue_min_heating_power + ($countstep * $pace_min_heating_power);

				my $pace_max_cooling_power =  ( $swing_max_cooling_power / ($stepsvar - 1) );
				my $floorvalue_max_cooling_power = ($max_cooling_power__ - ($swing_max_cooling_power / 2) );
				my $new_max_cooling_power = $floorvalue_max_cooling_power + ($countstep * $pace_max_cooling_power);

				my $pace_min_cooling_power =  ( $swing_min_cooling_power / ($stepsvar - 1) );
				my $floorvalue_min_cooling_power = ($min_cooling_power__ - ($swing_min_cooling_power / 2) );
				my $new_min_cooling_power = $floorvalue_min_cooling_power + ($countstep * $pace_min_cooling_power);

				my $pace_heating_setpoint =  ( $swing_heating_setpoint / ($stepsvar - 1) );
				my $floorvalue_heating_setpoint = ($heating_setpoint__ - ($swing_heating_setpoint / 2) );
				my $new_heating_setpoint = $floorvalue_heating_setpoint + ($countstep * $pace_heating_setpoint);

				my $pace_cooling_setpoint =  ( $swing_cooling_setpoint / ($stepsvar - 1) );
				my $floorvalue_cooling_setpoint = ($cooling_setpoint__ - ($swing_cooling_setpoint / 2) );
				my $new_cooling_setpoint = $floorvalue_cooling_setpoint + ($countstep * $pace_cooling_setpoint);

				$new_loop_hour = sprintf("%.2f", $new_loop_hour);
				$new_max_heating_power = sprintf("%.2f", $new_max_heating_power);
				$new_min_heating_power = sprintf("%.2f", $new_min_heating_power);
				$new_max_cooling_power = sprintf("%.2f", $new_max_cooling_power);
				$new_min_cooling_power = sprintf("%.2f", $new_min_cooling_power);
				$new_heating_setpoint = sprintf("%.2f", $new_heating_setpoint);
				$new_cooling_setpoint = sprintf("%.2f", $new_cooling_setpoint);

				push(@new_loopcontrols,
				[ $new_loop_letter, $new_loopcontrol_letter, $new_loop_hour,
				$new_max_heating_power, $new_min_heating_power, $new_max_cooling_power,
				$new_min_cooling_power, $new_heating_setpoint, $new_cooling_setpoint ] );
			}

			my $countflow = 0;

			foreach my $elm (@flowbulk)
			{
				my @askflow = @{$elm};
				my $new_flow_letter = $askflow[0];
				my $new_flowcontrol_letter = $askflow[1];
				my $swing_flow_hour = $askflow[2];
				my $swing_flow_setpoint = $askflow[3];
				my $swing_flow_onoff = $askflow[4];
				if ( $swing_flow_onoff eq "ON") { $swing_flow_onoff = 1; }
				elsif ( $swing_flow_onoff eq "OFF") { $swing_flow_onoff = -1; }
				my $swing_flow_fraction = $askflow[5];

				my $countflow = 0; # IT IS FOR THE FOLLOWING FOREACH. LEAVE IT ATTACHED TO IT.
				foreach $each_flow (@flowcontrol) # THIS DISTRIBUTES THOSE NESTED DATA STRUCTURES IN A FLAT MODE TO PAIR THE INPUT FILE, USER DEFINED ONE.
				{
					my $countcontrol = 0;
					@thisflow = @{$each_flow};
					foreach $elm (@thisflow)
					{
						my @control = @{$elm};
						# my $letterfilecontrol = $period_letters[$countcontrol];
						$flow_letter = $flowcontrol[$countflow][$countcontrol][0];
						$flowcontrol_letter = $flowcontrol[$countflow][$countcontrol][1];
						if ( ( $new_flow_letter eq $flow_letter ) and ($new_flowcontrol_letter eq $flowcontrol_letter ) )
						{
							$flow_hour__ = $flowcontrol[$countflow][$countcontrol][$flow_hour];
							$flow_setpoint__ = $flowcontrol[$countflow][$countcontrol][$flow_setpoint];
							$flow_onoff__ = $flowcontrol[$countflow][$countcontrol][$flow_onoff];
							if ( $flow_onoff__ eq "ON") { $flow_onoff__ = 1; }
							elsif ( $flow_onoff__ eq "OFF") { $flow_onoff__ = -1; }
							$flow_fraction__ = $flowcontrol[$countflow][$countcontrol][$flow_fraction];
						}
						$countcontrol++;
					}
					$countflow++;
				}

				my $pace_flow_hour =  ( $swing_flow_hour / ($stepsvar - 1) );
				my $floorvalue_flow_hour = ($flow_hour__ - ($swing_flow_hour / 2) );
				my $new_flow_hour = $floorvalue_flow_hour + ($countstep * $pace_flow_hour);

				my $pace_flow_setpoint =  ( $swing_flow_setpoint / ($stepsvar - 1) );
				my $floorvalue_flow_setpoint = ($flow_setpoint__ - ($swing_flow_setpoint / 2) );
				my $new_flow_setpoint = $floorvalue_flow_setpoint + ($countstep * $pace_flow_setpoint);

				my $pace_flow_onoff =  ( $swing_flow_onoff / ($stepsvar - 1) );
				my $floorvalue_flow_onoff = ($flow_onoff__ - ($swing_flow_onoff / 2) );
				my $new_flow_onoff = $floorvalue_flow_onoff + ($countstep * $pace_flow_onoff);

				my $pace_flow_fraction =  ( $swing_flow_fraction / ($stepsvar - 1) );
				my $floorvalue_flow_fraction = ($flow_fraction__ - ($swing_flow_fraction / 2) );
				my $new_flow_fraction = $floorvalue_flow_fraction + ($countstep * $pace_flow_fraction);

				$new_flow_hour = sprintf("%.2f", $new_flow_hour);
				$new_flow_setpoint = sprintf("%.2f", $new_flow_setpoint);
				$new_flow_onoff = sprintf("%.2f", $new_flow_onoff);
				$new_flow_fraction = sprintf("%.2f", $new_flow_fraction);

				push(@new_flowcontrols,
				[ $new_flow_letter, $new_flowcontrol_letter, $new_flow_hour,  $new_flow_setpoint, $new_flow_onoff, $new_flow_fraction ] );
			}
			# HERE THE MODIFICATIONS TO BE EXECUTED ON EACH PARAMETERS ARE APPLIED TO THE MODELS THROUGH ESP-r.
			# FIRST, HERE THEY ARE APPLIED TO THE ZONE CONTROLS, THEN TO THE FLOW CONTROLS
		}
	} # END SUB calc_newcontrols

	calc_newctl($to, $stepsvar, $countop, $countstep, \@buildbulk,
	\@flowbulk, \@loopcontrol, \@flowcontrol, $countvar, $fileconfig );

	print $_outfile_ "\@new_loopcontrols: " . Dumper(@new_loopcontrols) . "\n\n";

	apply_loopcontrol_changes(\@new_loopcontrols);
	apply_flowcontrol_changes(\@new_flowcontrols);

} # END SUB vary_controls.


##############################################################################
# BEGINNING OF SECTION DEDICATED TO FUNCTIONS FOR CONSTRAINING CONTROLS

sub constrain_controls
{  # IT READS CONTROL USER-IMPOSED CONSTRAINTS
	my ( $to, $filecon, $countop, $countstep, $applytype_ref, $constrain_controls_ref, $countvar, $fileconfig, $countmorphing, $todo,
		$loopcontrol_ref, $flowcontrol_ref, $new_loopcontrol_ref, $new_flowcontrol_ref, $launchline, $menus_ref, $countinstance ) = @_;

	my @menus = @$menus_ref;
	my %numvertmenu = %{ $menus[0] };
	my %vertnummenu = %{ $menus[1] };

	say $tee "Constraining controls for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $zone_letter = $applytype[$countop][3];
	my @applytype = @$applytype_ref;
	my @constrain_controls = @{ $constrain_controls_ref[ $countop ] };
	my @loopcontrol = @$loopcontrol_ref;
	my @flowcontrol = @$flowcontrol_ref;
	my @new_loopcontrol = @$new_loopcontrol_ref;
	my @new_flowcontrol = @$new_flowcontrol_ref;

	my $elm = $constrain_controls[$countop];
	my @group = @{$elm};
	my $sourcefile = $group[0];
	my $targetfile = $group[1];
	my $configfile = $group[2];
	my @sentletters = @{ $group[3] };
	my @sentperiod_letters = @{ $group[4] };

	my $sourceaddress = "$to$sourcefile";
	my $targetaddress = "$to$targetfile";
	my $configaddress = "$to$configfile";
	#@loopcontrol; @flowcontrol; @new_loopcontrols; @new_flowcontrols; # DON'T PUT "my" HERE. THEY ARE globsAL!!!
	my ( $semaphore_zone, $semaphore_dataloop, $semaphore_massflow, $semaphore_setpoint, $doline );
	my $count_controlmass = -1;
	my $countline = 0;

	my @letters;
	if (@sentletters) { @letters = @sentletters; }
	else
	{
		@letters = ("e", "f", "g", "h", "i", "l", "m" ); # RE-CHECK
	}

	my @period_letters;
	if (@sentperiod_letters) { @period_letters = @sentperiod_letters; }
	else
	{
		@period_letters = ( "a", "b", "c", "d", "e", "f", "g", "h", "i", "l", "m", "n", "o", "p", "q", "r", "s" ); # CHECK IF THE LAST LETTERS ARE CORRECT
	}

	my $loop_hour = 2; # NOTE: THE FOLLOWING VARIABLE NAMES ARE SHADOWED IN THE FOREACH LOOP BELOW,
	# BUT ARE THE ONES USED IN THE OPT CONSTRAINTS FILES.
	my $max_heating_power = 3;
	my $min_heating_power = 4;
	my $max_cooling_power = 5,
	my $min_cooling_power = 6;
	my $heating_setpoint = 7;
	my $cooling_setpoint = 8;
	my $flow_hour = 2;
	my $flow_setpoint = 3;
	my $flow_onoff = 4;
	my $flow_fraction = 5;
	my ( $loop_letter, $loopcontrol_letter );
	my $countbuild = 0;
	my $countflow = 0;
	my $countcontrol = 0;
	my ( $new_loopcontrol_ref, $new_flowcontrol_ref );

	my (
	@groupzone_letters, @zone_period_letters, @flow_letters, @fileloopbulk, @fileflowbulk,
	 @temploopcontrol, @tempflowcontrol
	);

	if ($todo eq "read_ctl")
	{
		if ($countstep == 1)
		{
			print $_outfile_ "THIS\n";
			checkfile($sourceaddress, $targetaddress);
			@flowcontrol = read_controls($sourceaddress, $targetaddress, \@letters, \@period_letters);
			$new_loopcontrol_ref, $new_flowcontrol_ref = read_control_constraints( $to, $stepsvar,
			$countop, $countstep, $configaddress, \@loopcontrol, \@flowcontrol, \@temploopcontrol, \@tempflowcontrol, $countvar, $fileconfig );
		}
	}

	@new_loopcontrol = @$new_loopcontrol_ref;
	@new_flowcontrol = @$new_flowcontrol_ref;

	if ($todo eq "write_ctl")
	{
		print $_outfile_ "THAT\n";
		apply_loopcontrol_changes( \@new_loopcontrol, \@temploopcontrol );
		apply_flowcontrol_changes( \@new_flowcontrol, \@tempflowcontrol );
	}
	# return ( \@loopcontrol, \@flowcontrol, \@new_loopcontrol, \@new_flowcontrol );
	return ( \@loopcontrol, \@flowcontrol, \@new_loopcontrol, \@new_flowcontrol );
} # END SUB constrain_controls.


sub read_controls
{  # TO BE CALLED WITH: read_controls($sourceaddress, $targetaddress, \@letters, \@period_letters);
	# THIS MAKES THE CONTROL CONFIGURATION FILE BE READ AND THE NEEDED VALUES ACQUIRED.
	# NOTICE THAT CURRENTLY ONLY THE "basic control law" IS SUPPORTED.

	my ( $sourceaddress, $targetaddress, $swap, $swap2, $countvar ) = @_;
	say $tee "Reading controls for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my @letters = @$swap;
	my @period_letters = @$swap2;

	open( SOURCEFILE, $sourceaddress ) or die "Can't open $sourceaddress: $!\n";
	my @lines = <SOURCEFILE>;
	close SOURCEFILE;
	my $countlines = 0;
	my $countloop = -1;
	my $countflow = -1;
	my $countflowcontrol = -1;
	my ( $countloopcontrol, $semaphore_building, $semaphore_loop, $loop_hour, $semaphore_loopcontrol, $semaphore_massflow,
		$flow_hour, $semaphore_flow, $semaphore_flowcontrol, $loop_letter, $loopcontrol_letter, $flow_letter, $flowcontrol_letter );

	foreach my $line (@lines)
	{
		if ( $line =~ /Control function/ )
		{
			$semaphore_loop eq "yes";
			$countloopcontrol = -1;
			$countloop++;
			$loop_letter = $letters[$countloop];
		}
		if ( ($line =~ /ctl type, law/ ) )
		{
			$countloopcontrol++;
			my @row = split(/\s+/, $line);
			$loop_hour = $row[3];
			$semaphore_loopcontrol eq "yes";
			$loopcontrol_letter = $period_letters[$countloopcontrol];
		}

		if ( ($semaphore_loop eq "yes") and ($semaphore_loopcontrol eq "yes") and ($line =~ /No. of data items/ ) )
		{
			$doline = $countlines + 1;
		}

		if ( ($semaphore_loop eq "yes" ) and ($semaphore_loopcontrol eq "yes") and ($countlines == $doline) )
		{
			my @row = split(/\s+/, $line);
			my $max_heating_power = $row[1];
			my $min_heating_power = $row[2];
			my $max_cooling_power = $row[3];
			my $min_cooling_power = $row[4];
			my $heating_setpoint = $row[5];
			my $cooling_setpoint = $row[6];

			push(@{$loopcontrol[$countloop][$countloopcontrol]},
			$loop_letter, $loopcontrol_letter, $loop_hour,
			$max_heating_power, $min_heating_power, $max_cooling_power,
			$min_cooling_power, $heating_setpoint, $cooling_setpoint );

			$semaphore_loopcontrol = "no";
			$doline = "";
		}

		if ($line =~ /Control mass/ )
		{
			$semaphore_flow eq "yes";
			$countflowcontrol = -1;
			$countflow++;
			$flow_letter = $letters[$countflow];
		}
		if ( ($line =~ /ctl type \(/ ) )
		{
			$countflowcontrol++;
			my @row = split(/\s+/, $line);
			$flow_hour = $row[3];
			$semaphore_flowcontrol eq "yes";
			$flowcontrol_letter = $period_letters[$countflowcontrol];
		}

		if ( ($semaphore_flow eq "yes") and ($semaphore_flowcontrol eq "yes") and ($line =~ /No. of data items/ ) )
		{
			$doline = $countlines + 1;
		}

		if ( ($semaphore_flow eq "yes" ) and ($semaphore_flowcontrol eq "yes") and ($countlines == $doline) )
		{
			my @row = split(/\s+/, $line);
			my $flow_setpoint = $row[1];
			my $flow_onoff = $row[2];
			my $flow_fraction = $row[3];
			push( @{ $flowcontrol[$countflow][$countflowcontrol]}, $flow_letter, $flowcontrol_letter, $flow_hour, $flow_setpoint, $flow_onoff, $flow_fraction );
			$semaphore_flowcontrol = "no";
			$doline = "";
		}
		$countlines++;
	}
	return ( @flowcontrol );
} # END SUB read_controls.


sub read_control_constraints
{
	#  #!/usr/bin/perl
	# THIS FILE CAN CONTAIN USER-IMPOSED CONSTRAINTS FOR CONTROLS TO BE READ BY OPT.
	# THE FOLLOWING VALUES CAN BE ADDRESSED IN THE OPT CONSTRAINTS CONFIGURATION FILE,
	# SET BY THE PRESENT FUNCTION:
	# 1) $loopcontrol[$countop][$countloop][$countloopcontrol][$loop_hour]
	# Where $countloop and  $countloopcontrol has to be set to a specified number in the OPT file for constraints.
	# 2) $loopcontrol[$countop][$countloop][$countloopcontrol][$max_heating_power] # Same as above.
	# 3) $loopcontrol[$countop][$countloop][$countloopcontrol][$min_heating_power] # Same as above.
	# 4) $loopcontrol[$countop][$countloop][$countloopcontrol][$max_cooling_power] # Same as above.
	# 5) $loopcontrol[$countop][$countloop][$countloopcontrol][$min_cooling_power] # Same as above.
	# 6) $loopcontrol[$countop][$countloop][$countloopcontrol][heating_setpoint] # Same as above.
	# 7) $loopcontrol[$countop][$countloop][$countloopcontrol][cooling_setpoint] # Same as above.
	# 8) $flowcontrol[$countop][$countflow][$countflowcontrol][$flow_hour]
	# Where $countflow and  $countflowcontrol has to be set to a specified number in the OPT file for constraints.
	# 9) $flowcontrol[$countop][$countflow][$countflowcontrol][$flow_setpoint] # Same as above.
	# 10) $flowcontrol[$countop][$countflow][$countflowcontrol][$flow_onoff] # Same as above.
	# 11) $flowcontrol[$countop][$countflow][$countflowcontrol][$flow_fraction] # Same as above.
	# EXAMPLE : $flowcontrol[0][1][2][$flow_fraction] = 0.7
	# OTHER EXAMPLE: $flowcontrol[2][1][2][$flow_fraction] = $flowcontrol[0][2][1][$flow_fraction]
	# The $countop that is actuated is always the last, the one which is active.
	# It would have therefore no sense writing $flowcontrol[1][1][2][$flow_fraction] = $flowcontrol[3][2][1][$flow_fraction].
	# Differentent $countops can be referred to the same zone. Different $countops just number mutations in series.
	# ALSO, THIS MAKES AVAILABLE TO THE USER INFORMATIONS ABOUT THE MORPHING STEP OF THE MODELS
	# AND THE STEPS THE MODEL HAS TO FOLLOW.
	# THIS ALLOWS TO IMPOSE EQUALITY CONSTRAINTS TO THESE VARIABLES,
	# WHICH COULD ALSO BE COMBINED WITH THE FOLLOWING ONES:
	# $stepsvar, WHICH TELLS THE PROGRAM HOW MANY ITERATION STEPS IT HAS TO DO IN THE CURRENT MORPHING PHASE.
	# $countop, WHICH TELLS THE PROGRAM WHAT OPERATION IS BEING EXECUTED IN THE CHAIN OF OPERATIONS.
	# THAT MAY BE EXECUTES AT EACH MORPHING PHASE. EACH $countop WILL CONTAIN ONE OR MORE ITERATION STEPS.
	# TYPICALLY, IT WILL BE USED FOR A ZONE, BUT NOTHING PREVENTS THAT SEVERAL OF THEM CHAINED ONE AFTER
	# THE OTHER ARE APPLIED TO THE SAME ZONE. THE NUMBER COUNT STARTS FROM 0.
	# $countstep, WHICH TELLS THE PROGRAM WHAT THE CURRENT ITERATION STEP IS.
	# $countvar, WHICH TELLS THE PROGRAM WHAT NUMBER OF DESIGN PARAMETER THE PROGRAM IS WORKING AT.

	my ( $to, $stepsvar, $countop, $countstep, $swap, $swap2, $swap3, $swap4, $countvar, $fileconfig, $countmorphing ) = @_;
	say $tee "Reading controls constraints for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	@loopcontrol = @$swap;
	@flowcontrol = @$swap2;
	@temploopcontrol = @$swap3;
	@tempflowcontrol = @$swap4;

	if (-e $configaddress) # TEST THIS
	{  # THIS APPLIES CONSTRAINST, THE FLATTEN THE HIERARCHICAL STRUCTURE OF THE RESULTS,
		# TO BE PREPARED THEN FOR BEING APPLIED TO CHANGE PROCEDURES. IT HAS TO BE TESTED.
		push (@loopcontrol, [@myloopcontrol]); #
		push (@flowcontrol, [@myflowcontrol]); #

		eval `cat $configaddress`;  # HERE AN EXTERNAL FILE FOR PROPAGATION OF CONSTRAINTS
		# IS EVALUATED, AND HERE BELOW CONSTRAINTS ARE PROPAGATED.

		if (-e $constrain) { eval ($constrain); } # HERE THE INSTRUCTION WRITTEN IN THE OPT CONFIGURATION FILE CAN BE SPEFICIED
		# FOR PROPAGATION OF CONSTRAINTS

		@doloopcontrol = @{$loopcontrol[$#loopcontrol]}; #
		@doflowcontrol = @{$flowcontrol[$#flowcontrol]}; #

		shift (@doloopcontrol);
		shift (@doflowcontrol);

		sub flatten_loopcontrol_constraints
		{
			my @looptemp = @doloopcontrol;
			@new_loopcontrol = "";
			foreach my $elm (@looptemp)
			{
				my @loop = @{$elm};
				foreach my $elm (@loop)
				{
					my @loop = @{$elm};
					push (@new_loopcontrol, [@loop]);
				}
			}
		}
		flatten_loopcontrol_constraints;

		sub flatten_flowcontrol_constraints
		{
			my @flowtemp = @doflowcontrol;
			@new_flowcontrol = "";
			foreach my $elm (@flowtemp)
			{
				my @flow = @{$elm};
				foreach my $elm (@flow)
				{
					my @loop = @{$elm};
					push (@new_flowcontrol, [@flow]);
				}
			}
		}
		flatten_flowcontrol_constraints;

		shift @new_loopcontrol;
		shift @new_flowcontrol;
	}
	return( \@new_loopcontrol, \@new_flowcontrol );
} # END SUB read_control_constraints


sub apply_loopcontrol_changes
{   # TO BE CALLED WITH: apply_loopcontrol_changes($exeonfiles, \@new_loopcontrol);
	# THIS APPLIES CHANGES TO LOOPS IN CONTROLS (ZONES)
	my ( $swap, $swap2, $countvar ) = @_;

	my @new_loop_ctls = @$swap;
	my @temploopcontrol = @$swap2;

	my $countloop = 0;

	foreach my $elm (@new_loop_ctls)
	{
		my @loop = @{$elm};
		$new_loop_letter = $loop[0];
		$new_loopcontrol_letter = $loop[1];
		$new_loop_hour = $loop[2];
		$new_max_heating_power = $loop[3];
		$new_min_heating_power = $loop[4];
		$new_max_cooling_power = $loop[5];
		$new_min_cooling_power = $loop[6];
		$new_heating_setpoint = $loop[7];
		$new_cooling_setpoint = $loop[8];
		unless ( @{$new_loop_ctls[grep { $_ eq $countloop]} } @{ $temploopcontrol[$countloop] } )
		{
			my $printthis =
"prj -file $to/cfg/$fileconfig -mode script<<YYY
m
j

$new_loop_letter
c
$new_loopcontrol_letter
1
$new_loop_hour
b
$new_max_heating_power
c
$new_min_heating_power
d
$new_max_cooling_power
e
$new_min_cooling_power
f
$new_heating_setpoint
g
$new_cooling_setpoint
-
y
-
-
-
n
d

-
y
y
-
-
YYY
";
			unless ($exeonfiles eq "n")
			{
				print `$printthis`;
			}
			say $tee "$printthis";
		}
		$countloop++;
	}
} # END SUB apply_loopcontrol_changes();


sub apply_flowcontrol_changes
{  # THIS HAS TO BE CALLED WITH: apply_flowcontrol_changes($exeonfiles, \@new_flowcontrols);
	# # THIS APPLIES CHANGES TO NETS IN CONTROLS
	my ( $swap, $swap2, $countvar ) = @_;
	say $tee "Applying changes to flow controls for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $countflow = 0;
	my @new_flowcontrols = @$swap;
	my @tempflowcontrol = @$swap2;

	foreach my $elm (@new_flowcontrols)
	{
		my @flow = @{$elm};
		$flow_letter = $flow[0];
		$flowcontrol_letter = $flow[1];
		$new_flow_hour = $flow[2];
		$new_flow_setpoint = $flow[3];
		$new_flow_onoff = $flow[4];
		$new_flow_fraction = $flow[5];
		unless ( @{$new_flowcontrols[grep { $_ eq $countflow]} } @{ $tempflowcontrol[$countflow] } )
		{
			my $printthis =
"prj -file $to/cfg/$fileconfig -mode script<<YYY
m
l

$flow_letter
c
$flowcontrol_letter
a
$new_flow_hour
$new_flow_setpoint $new_flow_onoff $new_flow_fraction
-
-
-
y
y
-
-
YYY
";
			unless ($exeonfiles eq "n") # unless ($exeonfiles eq "n")
			{
				print `$printthis`;
			}

			say $tee "$printthis";
		}
		$countflow++;
	}
} # END SUB apply_flowcontrol_changes;
# END OF SECTION DEDICATED TO FUNCTIONS FOR CONSTRAINING CONTROLS
##############################################################################


####################################################### BEGINNING OF SECTION DEDICATED TO NET VARIATION
sub vary_net
{    # IT IS CALLED FROM THE MAIN FILE
	my ( $to, $stepsvar, $countop, $countstep, $applytype_ref, $vary_net_ref, $countvar, $fileconfig, $mypath, $file, $countmorphing ) = @_;

	my @applytype = @$applytype_ref;
	my $zone_letter = $applytype[$countop][3];
	my @vary_net = @{ $vary_net_ref[ $countop ] };

	say $tee "Executing variations on networks for case " . ($countcase + 1) . ", block " . ($countblock + 1) . ", parameter $countvar at iteration $countstep. Instance $countinstance.";

	my $activezone = $applytype[$countop][3];
	my ($semaphore_node, $semaphore_component, $node_letter);
	my $count_component = -1;
	my $countline = 0;
	my @node_letters = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "l", "m", "n", "o", "p", "q", "r", "s"); # ZZZ THESE LETTERS HAVE TO BE CHECKED WITH REGARDS TO THE CHANGE OF PAGES!
	my @component_letters = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "l", "m", "n", "o", "p", "q", "r", "s"); # ZZZ THESE LETTERS HAVE TO BE CHECKED WITH REGARDS TO THE CHANGE OF PAGES!
	# NOTE: THE FOLLOWING VARIABLE NAMES ARE SHADOWED IN THE FOREACH LOOP BELOW,
	# BUT ARE THE ONES USED IN THE OPT CONSTRAINTS FILES.

	my @group = @{$vary_net[$countop]};
	my $sourcefile = $group[0];
	my $targetfile = $group[1];
	my $configfile = $group[2];
	my @nodebulk = @{$group[3]};
	my @componentbulk = @{$group[4]};
	my $countnode = 0;
	my $countcomponent = 0;

	my $sourceaddress = "$to$sourcefile";
	my $targetaddress = "$to$targetfile";
	my $configaddress = "$to$configfile";

	#@node; @component; # PLURAL. DON'T PUT "my" HERE!
	#@new_nodes; @new_components; # DON'T PUT "my" HERE.

	my @flow_letters;

	checkfile($sourceaddress, $targetaddress);

	if ($countstep == 1)
	{
		read_net($sourceaddress, $targetaddress, \@node_letters, \@component_letters);
	}

	sub calc_newnet
	{  # TO BE CALLED WITH: calc_newnet($to, $fileconfig, $stepsvar, $countop, $countstep, \@nodebulk, \@componentbulk, \@node_, \@component);
		# THIS COMPUTES CHANGES TO BE MADE TO CONTROLS BEFORE PROPAGATION OF CONSTRAINTS
		my ( $to, $stepsvar, $countop, $countstep, $swap, $swap2, $swap3, $swap4, $countvar, $fileconfig, $countmorphing ) = @_;

		my @nodebulk = @$swap;
		my @componentbulk = @$swap2;
		my @node = @$swap3; # PLURAL
		my @component = @$swap4; # PLURAL

		my ( @new_volumes_or_surfaces, @node_heights_or_cps, @new_azimuths, @boundary_heights );

		# HERE THE MODIFICATIONS TO BE EXECUTED ON EACH PARAMETERS ARE CALCULATED.
		if ($stepsvar == 0) {$stepsvar = 1;}
		if ($stepsvar > 1)
		{
			foreach $each_nodebulk (@nodebulk)
			{
				my @asknode = @{$each_nodebulk};
				my $new_node_letter = $asknode[0];
				my $new_fluid = $asknode[1];
				my $new_type = $asknode[2];
				my $new_zone = $activezone;
				my $swing_height = $asknode[3];
				my $swing_data_2 = $asknode[4];
				my $new_surface = $asknode[5];
				my @askcp = @{$asknode[6]};
				my ($height__, $data_2__, $data_1__, $new_cp);
				my $countnode = 0; #IT IS FOR THE FOLLOWING FOREACH. LEAVE IT ATTACHED TO IT.
				foreach $each_node (@node)
				{
					@node_ = @{$each_node};
					my $node_letter = $node_[0];
					if ( $new_node_letter eq $node_letter )
					{
						$height__ = $node_[3];
						$data_2__ = $node_[4];
						$data_1__ = $node_[5];
						$new_cp = $askcp[$countstep-1];
					}
					$countnode++;
				}
				my $height = ( $swing_height / ($stepsvar - 1) );
				my $floorvalue_height = ($height__ - ($swing_height / 2) );
				my $new_height = $floorvalue_height + ($countstep * $pace_height);
				$new_height = sprintf("%.3f", $height);
				if ($swing_height == 0) { $new_height = ""; }

				my $pace_data_2 =  ( $swing_data_2 / ($stepsvar - 1) );
				my $floorvalue_data_2 = ($data_2__ - ($swing_data_2 / 2) );
				my $new_data_2 = $floorvalue_data_2 + ($countstep * $pace_data_2);
				$new_data_2 = sprintf("%.3f", $new_data_2);
				if ($swing_data_2 == 0) { $new_data_2 = ""; }

				my $pace_data_1 =  ( $swing_data_1 / ($stepsvar - 1) ); # UNUSED
				my $floorvalue_data_1 = ($data_1__ - ($swing_data_1 / 2) );
				my $new_data_1 = $floorvalue_data_1 + ($countstep * $pace_data_1);
				$new_data_1  = sprintf("%.3f", $new_data_1);
				if ($swing_data_1 == 0) { $new_data_1 = ""; }

				push(@new_nodes,
				[ $new_node_letter, $new_fluid, $new_type, $new_zone, $new_height, $new_data_2, $new_surface, $new_cp ] );
			}

			foreach $each_componentbulk (@componentbulk)
			{
				my @askcomponent = @{$each_componentbulk};
				my $new_component_letter = $askcomponent[0];

				my $new_type = $askcomponent[1];
				my $swing_data_1 = $askcomponent[2];
				my $swing_data_2 = $askcomponent[3];
				my $swing_data_3 = $askcomponent[4];
				my $swing_data_4 = $askcomponent[5];
				my $component_letter;
				my $countcomponent = 0;    #IT IS FOR THE FOLLOWING FOREACH.
				my ($new_type, $data_1__, $data_2__, $data_3__, $data_4__ );
				foreach $each_component (@component) # PLURAL
				{
					@component_ = @{$each_component};
					$component_letter = $component_letters[$countcomponent];
					if ( $new_component_letter eq $component_letter )
					{
						$new_component_letter = $component_[0];
						$new_fluid = $component_[1];
						$new_type = $component_[2];
						$data_1__ = $component_[3];
						$data_2__ = $component_[4];
						$data_3__ = $component_[5];
						$data_4__ = $component_[6];
					}
					$countcomponent++;
				}

				my $pace_data_1 =  ( $swing_data_1 / ($stepsvar - 1) );
				my $floorvalue_data_1 = ($data_1__ - ($swing_data_1 / 2) );
				my $new_data_1 = $floorvalue_data_1 + ($countstep * $pace_data_1);
				if ($swing_data_1 == 0) { $new_data_1 = ""; }

				my $pace_data_2 =  ( $swing_data_2 / ($stepsvar - 1) );
				my $floorvalue_data_2 = ($data_2__ - ($swing_data_2 / 2) );
				my $new_data_2 = $floorvalue_data_2 + ($countstep * $pace_data_2);
				if ($swing_data_2 == 0) { $new_data_2 = ""; }

				my $pace_data_3 =  ( $swing_data_3 / ($stepsvar - 1) );
				my $floorvalue_data_3 = ($data_3__ - ($swing_data_3 / 2) );
				my $new_data_3 = $floorvalue_data_3 + ($countstep * $pace_data_3 );
				if ($swing_data_3 == 0) { $new_data_3 = ""; }

				my $pace_data_4 =  ( $swing_data_4 / ($stepsvar - 1) );
				my $floorvalue_data_4 = ($data_4__ - ($swing_data_4 / 2) );
				my $new_data_4 = $floorvalue_data_4 + ($countstep * $pace_data_4 );
				if ($swing_data_4 == 0) { $new_data_4 = ""; }

				$new_data_1 = sprintf("%.3f", $new_data_1);
				$new_data_2 = sprintf("%.3f", $new_data_2);
				$new_data_3 = sprintf("%.3f", $new_data_3);
				$new_data_4 = sprintf("%.3f", $new_data_4);
				$new_data_4 = sprintf("%.3f", $new_data_4);

				push(@new_components, [ $new_component_letter, $new_fluid, $new_type, $new_data_1, $new_data_2, $new_data_3, $new_data_4 ] );
			}
		}
	} # END SUB calc_newnet

	calc_newnet($to, $stepsvar, $countop, $countstep, \@nodebulk, \@componentbulk, \@node, \@component, $countvar, $fileconfig  );  # PLURAL

	apply_node_changes(\@new_nodes);
	apply_component_changes(\@new_components);

} # END SUB vary_net.
######################################################### END OF SECTION DEDICATED TO NET VARIATION

1;


__END__

=head1 NAME

Sim::OPT::Morph.

=head1 SYNOPSIS

	use Sim::OPT;
	opt;

=head1 DESCRIPTION

Sim::OPT::Morph is morphing program for preparing model instances (in text format) to be given to simulation programs, usually in design-aimed explorations. Sim::OPT::Morph is controlled by the Sim::OPT module, which manages the structure of the searches.

Sim::OPT::Morph can manipulate the text files constituting the description of models for simulation programs. The general function dedicated to that aim recognizes variables by position on the page (determined by row number and position of the list element in that row) and modifies them with operations like translations, rotations or text substitution, and possibly with propagation of constraints.

Additionally, Sim::OPT::Morph features several specialized functions which are specific to the ESP-r building performance simulation platform. Those functions can manage the simulation program directly, through the shell, or by manipulating model configuration files. Some of these functionalities involve operations in which the Radiance lighting performance simulation platform is called via ESP-r.

The morphing instructions must be written in a configuration file whose name will be asked at the launch of Sim::OPT. This distribution includes some examples of such files an ESP-r model and an EnergyPlus model.

Propagation of constraints can target the model configuration files and/or, in the case of ESP-r, trigger modification operations performed through the shell and regarding geometry, solar shadings, mass/flow network and controls.

=head2 EXPORT

"morph".

=head1 SEE ALSO

Annotated examples can be found in the "optw.tar.gz" file in "examples" directory in this distribution. They constitute the available documentation.

=head1 AUTHOR

Gian Luca Brunetti, E<lt>gianluca.brunetti@polimi.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2022 by Gian Luca Brunetti and Politecnico di Milano. This is free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.


=cut
