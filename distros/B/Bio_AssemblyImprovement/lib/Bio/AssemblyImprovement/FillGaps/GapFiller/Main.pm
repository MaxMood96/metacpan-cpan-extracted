package Bio::AssemblyImprovement::FillGaps::GapFiller::Main;
# ABSTRACT: Run a single iteration of gapfiller


use Moose;
use Cwd;
use File::Copy;
use Bio::AssemblyImprovement::FillGaps::GapFiller::Config;
with 'Bio::AssemblyImprovement::Scaffold::SSpace::OutputFilenameRole';
with 'Bio::AssemblyImprovement::Scaffold::SSpace::TempDirectoryRole';

has 'input_files'     => ( is => 'ro', isa => 'ArrayRef', required => 1     );
has 'insert_size'     => ( is => 'ro', isa => 'Int',      required => 1     );
has 'mapper'          => ( is => 'ro', isa => 'Str',      default  => 'bwa' );
has 'merge_size'      => ( is => 'ro', isa => 'Int',      default  => 10    );
has 'threads'		  => ( is => 'ro', isa => 'Int',      default  => 1     );
has 'gap_filler_exec' => ( is => 'rw', isa => 'Str',      required => 1     );
has 'debug'           => ( is => 'ro', isa => 'Bool',     default  => 0     );
has 'num_iterations'  => ( is => 'ro', isa => 'Int',      default  => 20    );

has '_config_file_obj' => ( is => 'ro', isa => 'Bio::AssemblyImprovement::FillGaps::GapFiller::Config', lazy => 1, builder => '_build__config_file_obj' );

sub _build__config_file_obj {
    my ($self) = @_;
    Bio::AssemblyImprovement::FillGaps::GapFiller::Config->new(
        input_files     => $self->input_files,
        insert_size     => $self->insert_size,
        output_filename => join( '/', ( $self->_temp_directory, '_gap_filler.config' ) ),
        mapper          => $self->mapper
    )->create_config_file();
}

sub _intermediate_file_name {
    my ($self) = @_;
    $self->_output_prefix.'/'.$self->_output_prefix . '.gapfilled.final.fa';
}

sub run {
    my ($self) = @_;
    my $original_cwd = getcwd();
    chdir( $self->_temp_directory );
    
    my $stdout_of_program = '';
    $stdout_of_program =  "> /dev/null 2>&1"  if($self->debug == 0);

    system(
        join(
            ' ',
            (
                'perl', $self->gap_filler_exec, 
                '-l', $self->_config_file_obj->output_filename,
                '-s', $self->input_assembly, 
                '-i', $self->num_iterations,
                '-m', $self->merge_size,
                '-T', $self->threads,
                '-b', $self->_output_prefix,
                $stdout_of_program
            )
        )
    );
    move( $self->_intermediate_file_name, $self->output_filename );
    chdir($original_cwd);
    return $self;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Bio::AssemblyImprovement::FillGaps::GapFiller::Main - Run a single iteration of gapfiller

=head1 VERSION

version 1.160490

=head1 SYNOPSIS

Run a single iteration of gapfiller.

   use Bio::AssemblyImprovement::FillGaps::GapFiller::Main;

   my $config_file_obj = Bio::AssemblyImprovement::Scaffold::SSpace::Main->new(
     input_files => ['abc_1.fastq', 'abc_2.fastq'],
     input_assembly => 'contigs.fa'
     insert_size => 250,
     merge_size => 5,
     threads => 2,
     gap_filler_exec => '/path/to/SSPACE.pl',

     _output_prefix => 'gapfilled'
   )->run;

=head1 METHODS

=head2 run

Iteratively run gapfiller.

=head1 SEE ALSO

=for :list * L<Bio::AssemblyImprovement::FillGaps::GapFiller::Config>
* L<Bio::AssemblyImprovement::FillGaps::GapFiller::Iterative>

=head1 AUTHOR

Andrew J. Page <ap13@sanger.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Wellcome Trust Sanger Institute.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
