use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::CheckBreaks 0.020

use Test::More tests => 3;
use Term::ANSIColor 'colored';

SKIP: {
    eval { +require Module::Runtime::Conflicts; Module::Runtime::Conflicts->check_conflicts };
    skip('no Module::Runtime::Conflicts module found', 1) if not $INC{'Module/Runtime/Conflicts.pm'};

    diag $@ if $@;
    pass 'conflicts checked via Module::Runtime::Conflicts';
}

SKIP: {
    eval { +require Moose::Conflicts; Moose::Conflicts->check_conflicts };
    skip('no Moose::Conflicts module found', 1) if not $INC{'Moose/Conflicts.pm'};

    diag $@ if $@;
    pass 'conflicts checked via Moose::Conflicts';
}

# this data duplicates x_breaks in META.json
my $breaks = {
  "Catalyst" => "<= 5.90049999",
  "Config::MVP" => "<= 2.200004",
  "Devel::REPL" => "<= 1.003020",
  "Dist::Zilla" => "<= 5.043",
  "Dist::Zilla::Plugin::Git" => "<= 2.016",
  "Fey" => "<= 0.36",
  "Fey::ORM" => "<= 0.42",
  "File::ChangeNotify" => "<= 0.15",
  "HTTP::Throwable" => "<= 0.017",
  "KiokuDB" => "<= 0.51",
  "Markdent" => "<= 0.16",
  "Mason" => "<= 2.18",
  "Moose::Autobox" => "<= 0.15",
  "MooseX::ABC" => "<= 0.05",
  "MooseX::Aliases" => "<= 0.08",
  "MooseX::AlwaysCoerce" => "<= 0.13",
  "MooseX::App" => "<= 1.22",
  "MooseX::Attribute::Deflator" => "<= 2.1.7",
  "MooseX::Attribute::Dependent" => "<= 1.1.3",
  "MooseX::Attribute::Prototype" => "<= 0.10",
  "MooseX::AttributeHelpers" => "<= 0.22",
  "MooseX::AttributeIndexes" => "<= 1.0.0",
  "MooseX::AttributeInflate" => "<= 0.02",
  "MooseX::CascadeClearing" => "<= 0.03",
  "MooseX::ClassAttribute" => "<= 0.26",
  "MooseX::Constructor::AllErrors" => "<= 0.021",
  "MooseX::Declare" => "<= 0.35",
  "MooseX::FollowPBP" => "<= 0.02",
  "MooseX::Getopt" => "<= 0.56",
  "MooseX::InstanceTracking" => "<= 0.04",
  "MooseX::LazyRequire" => "<= 0.06",
  "MooseX::Meta::Attribute::Index" => "<= 0.04",
  "MooseX::Meta::Attribute::Lvalue" => "<= 0.05",
  "MooseX::Method::Signatures" => "<= 0.44",
  "MooseX::MethodAttributes" => "<= 0.22",
  "MooseX::NonMoose" => "<= 0.24",
  "MooseX::Object::Pluggable" => "<= 0.0011",
  "MooseX::POE" => "<= 0.214",
  "MooseX::Params::Validate" => "<= 0.05",
  "MooseX::PrivateSetters" => "<= 0.03",
  "MooseX::Role::Cmd" => "<= 0.06",
  "MooseX::Role::Parameterized" => "<= 1.00",
  "MooseX::Role::WithOverloading" => "<= 0.14",
  "MooseX::Runnable" => "<= 0.03",
  "MooseX::Scaffold" => "<= 0.05",
  "MooseX::SemiAffordanceAccessor" => "<= 0.05",
  "MooseX::SetOnce" => "<= 0.100473",
  "MooseX::Singleton" => "<= 0.25",
  "MooseX::SlurpyConstructor" => "<= 1.1",
  "MooseX::Storage" => "<= 0.42",
  "MooseX::StrictConstructor" => "<= 0.12",
  "MooseX::Traits" => "<= 0.11",
  "MooseX::Types" => "<= 0.19",
  "MooseX::Types::Parameterizable" => "<= 0.05",
  "MooseX::Types::Set::Object" => "<= 0.03",
  "MooseX::Types::Signal" => "<= 1.101930",
  "MooseX::UndefTolerant" => "<= 0.11",
  "Net::Twitter" => "<= 4.01041",
  "PRANG" => "<= 0.14",
  "Pod::Elemental" => "<= 0.093280",
  "Pod::Weaver" => "<= 3.101638",
  "Reaction" => "<= 0.002003",
  "Test::Able" => "<= 0.10",
  "Test::CleanNamespaces" => "<= 0.03",
  "Test::Moose::More" => "<= 0.022",
  "Test::TempDir" => "<= 0.05",
  "Throwable" => "<= 0.102080",
  "namespace::autoclean" => "<= 0.08"
};

use CPAN::Meta::Requirements;
use CPAN::Meta::Check 0.011;

my $reqs = CPAN::Meta::Requirements->new;
$reqs->add_string_requirement($_, $breaks->{$_}) foreach keys %$breaks;

our $result = CPAN::Meta::Check::check_requirements($reqs, 'conflicts');

if (my @breaks = grep defined $result->{$_}, keys %$result) {
    diag colored('Breakages found with Moose:', 'yellow');
    diag colored("$result->{$_}", 'yellow') for sort @breaks;
    diag "\n", colored('You should now update these modules!', 'yellow');
}

pass 'checked x_breaks data';
