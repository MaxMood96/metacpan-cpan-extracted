package Daje::Tools::Datasections;
use Mojo::Base -base, -signatures;


use Mojo::Loader qw {data_section load_class};

# Daje::Tools::Datasections - Load and store data sections in memory from a named *.pm
#
#
# Abstract
# ========
#
# Get and store data sections from perl classes
#
#
# Synopsis
# =========
#
#  use GenerateSQL::Tools::Datasections
#
#  my $data = GenerateSQL::Tools::Datasections->new(
#
#       data_sections => ['c1','c2','c3'],
#
#       source => 'Class::Containing::Datasections
#
#   )->load_data_sections();
#
# METHODS
# =======
# Get one section of loaded data
#
#  my $c1 = $data->get_data_section('c1');
#
# Add a section of data
#
#  $data->set_data_section('new_section', 'section data');
#
# Set a new source
#
#  $data->set_source('New::Source');
#
# Add a new section to load
#
#  $data->add_data_section('test');
#
#
# LICENSE
# =======
# Generate::Tools::Datasections  (the distribution) is licensed under the same terms as Perl.
#
# AUTHOR
# ======
# Jan Eskilsson
#
# COPYRIGHT
# =========
# Copyright (C) 2024 Jan Eskilsson.
#

our $VERSION = '0.11';

has 'data_sec';
has 'data_sections';
has 'source';
has 'error';

# Load all data_sections
sub load_data_sections($self) {

    eval {
        my $data_sec = {};
        $self->data_sec($data_sec);
        my $class = $self->source();
        my $c = load_class($class);
        my @data_sec = split(',', $self->data_sections) ;
        my $length = scalar @data_sec;
        for(my $i = 0; $i < $length; $i++){
            my $section = $data_sec[$i];
            if (!exists($self->data_sec->{$section})) {
                my $sec = data_section($class, $section);
                $self->set_data_section($section, $sec);
            }
        }
    };
    $self->error($@) if $@;

    return 1;
}
# Get one section
sub get_data_section($self, $section) {
    return $self->data_sec->{$section};
}
# Set a section
sub set_data_section($self, $key, $templ) {
    $self->data_sec->{$key} = $templ;
}
# Set Source
sub set_source($self, $source_class) {
    $self->source = $source_class;
}
# Add a section to the data sections_array to be loaded
sub add_data_section($self, $section) {
    $self->data_sections .','. $section;
}
1;

__END__






#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

Daje::Tools::Datasections


=head1 DESCRIPTION

Daje::Tools::Datasections - Load and store data sections in memory from a named *.pm




=head1 REQUIRES

L<Mojo::Loader> 

L<Mojo::Base> 


=head1 METHODS

Get one section of loaded data

 my $c1 = $data->get_data_section('c1');

Add a section of data

 $data->set_data_section('new_section', 'section data');

Set a new source

 $data->set_source('New::Source');

Add a new section to load

 $data->add_data_section('test');




=head1 Synopsis


 use GenerateSQL::Tools::Datasections

 my $data = GenerateSQL::Tools::Datasections->new(

      data_sections => ['c1','c2','c3'],

      source => 'Class::Containing::Datasections

  )->load_data_sections();



=head1 Abstract


Get and store data sections from perl classes




=head1 AUTHOR

Jan Eskilsson



=head1 COPYRIGHT

Copyright (C) 2024 Jan Eskilsson.



=head1 LICENSE

Generate::Tools::Datasections  (the distribution) is licensed under the same terms as Perl.



=cut

