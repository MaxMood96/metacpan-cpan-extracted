package Sim::Agent::Hook;

use strict;
use warnings;


sub load 
{

    my ($file) = @_;

    open my $fh, '<', $file
        or die "Cannot open hook file: $file";

    local $/;
    my $code = <$fh>;
    close $fh;

    my $pkg = "Sim::Agent::Hook::Run::" . int(rand(1_000_000));

    my $wrapped = "package $pkg;\n$code";

    my $sub = eval $wrapped;

    if ($@) 
    {
        die "Hook compile error in $file:\n$@";
    }

    die "Hook file $file did not return coderef"
        unless ref($sub) eq 'CODE';

    return $sub;
}


sub invoke 
{

    my ($coderef, @args) = @_;

    my $result = eval 
    {
        $coderef->(@args);
    };

    if ($@) 
    {
        die "Hook runtime error:\n$@";
    }

    return $result;
}





1;

#my $hook = Sim::Agent::Hook::load($file);
#my $result = Sim::Agent::Hook::invoke($hook, $context, $agent, $runner);


=pod

=head1 NAME

Sim::Agent::Hook - Loads and invokes hook files that return coderefs

=head1 DESCRIPTION

Loads a Perl file, evaluates it in an isolated package, verifies it returns a coderef, and invokes it with structured context.

See L<Sim::Agent> for hook contracts.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut


