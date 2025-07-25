package Dist::Build::Serializer;
$Dist::Build::Serializer::VERSION = '0.020';
use strict;
use warnings;

use parent 'ExtUtils::Builder::Serializer';

use List::Util 1.33 'any';

use ExtUtils::Builder::Action::Function;
use Dist::Build::Core;

sub serialize_action {
	my ($self, $action, %args) = @_;

	if ($action->isa('ExtUtils::Builder::Action::Function')) {
		if ($action->module eq 'Dist::Build::Core') {
			return [ $action->function, $action->arguments ];
		} elsif ($action->module eq 'File::Path') {
			if ($action->function eq 'make_path') {
				return [ 'mkdir', $action->arguments ];
			} elsif ($action->function eq 'remove_tree') {
				return [ 'rm_r', $action->arguments ];
			}
		}
	}

	return $self->SUPER::serialize_action($action);
}

sub deserialize_action {
	my ($self, $serialized, %options) = @_;
	my ($command, @args) = @{$serialized};

	my $message = join ' ', @{$serialized};
	if ($command eq 'tap_harness') {
		my %args = @args;
		$args{verbose} = $options{verbose} if defined $options{verbose};
		$args{jobs} = $options{jobs} if defined $options{jobs};
		return make_function('tap_harness', 'prove', %args);
	} elsif ($command eq 'copy') {
		my ($source, $destination, %args) = @args;
		$args{verbose} = $options{verbose} if defined $options{verbose};
		$message = sprintf("cp %s %s", $source, $destination);
		return make_function('copy', "cp $source $destination", $source, $destination, %args);
	} elsif ($command eq 'mkdir') {
		my ($destination, %args) = @args;
		$args{verbose} = $options{verbose} if defined $options{verbose};
		return ExtUtils::Builder::Action::Function->new(
			function  => 'make_path',
			module    => 'File::Path',
			arguments => [ $destination, %args ],
			exports   => 'explicit',
			message   => "mkdir $destination",
		);
	} elsif ($command eq 'rm_r') {
		my (@files) = @args;
		return ExtUtils::Builder::Action::Function->new(
			function  => 'remove_tree',
			module    => 'File::Path',
			arguments => \@files,
			exports   => 'explicit',
			message   => "rm_r @files",
		);
	} elsif ($command eq 'install') {
		my %args = @args;
		$args{verbose} = $options{verbose} if defined $options{verbose};
		$args{uninst} = $options{uninst} if defined $options{uninst};
		$args{dry_run} = $options{dry_run} if defined $options{dry_run};
		$args{install_map} = $options{install_paths}->install_map;
		return make_function('install', $message, %args);
	} elsif (any { $command eq $_ } @Dist::Build::Core::EXPORT_OK) {
		return make_function($command, $message, @args);
	} else {
		$self->SUPER::deserialize_action($serialized, %options);
	}
}

sub make_function {
	my ($command, $message, @args) = @_;
	ExtUtils::Builder::Action::Function->new(
		function  => $command,
		module    => 'Dist::Build::Core',
		arguments => \@args,
		exports   => 'explicit',
		message   => $message,
	);
}

1;

# ABSTRACT: A Serializer for a Dist::Build plan

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Build::Serializer - A Serializer for a Dist::Build plan

=head1 VERSION

version 0.020

=head1 DESCRIPTION

This is a subclass of L<ExtUtils::Builder::Serializer|ExtUtils::Builder::Serializer> that optimizes the serialization of C<Dist::Build> actions such as those in L<Dist::Build::Core>.

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
