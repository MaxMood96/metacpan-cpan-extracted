use v5.40;
use feature 'class';
no warnings 'experimental::class';


class Daje::Generate::Input::Sql::ConfigManager {
    use Daje::Generate::Database::SqlLite;
    use Daje::Generate::Database::Operations;
    use Daje::Generate::Tools::FileChanged;

    use Mojo::File;
    use Mojo::JSON qw{from_json};

    field $source_path :param :reader = "";
    field $files :reader = {};
    field $filetype :param :reader = "";
    field $changed_files :reader;
    field $change;

    method save_new_hash($file) {
        my $path = Mojo::File->new($file);
        my $new_hash = $change->load_new_hash($path);
        my $dbh = Daje::Generate::Database::SqlLite->new(path => $path)->get_dbh();
        my $operations = Daje::Generate::Database::Operations->new(dbh => $dbh);
        $operations->save_hash($path->dirname . '/' . $path->basename, $new_hash);

        return 1;
    }

    method load_json($file) {
        my $context;
        try {
            $context =  Mojo::File->new($file)->slurp;
        } catch ($e) {
            die "load_json failed '$e";
        };

        return from_json($context);
    }

    method load_changed_files () {
        my ($dbh, $operations, $path) = $self->_load_objects();
        try {
            $files = $path->list();
        } catch ($e) {
            die "Files could not be loaded: $e";
        };

        my $length = scalar @{$files};
        for (my $i = 0; $i < $length; $i++) {
            my $old_hash = $operations->load_hash(@{$files}[$i]->dirname . '/' . @{$files}[$i]->basename);
            if ($change->is_file_changed( @{$files}[$i], $old_hash)) {
                push @{$changed_files}, @{$files}[$i]->dirname . '/' . @{$files}[$i]->basename;
            }
        }
        return;
    }

    method _load_objects() {
        my $path = Mojo::File->new($source_path);
        $change = Daje::Generate::Tools::FileChanged->new();
        my $dbh = Daje::Generate::Database::SqlLite->new(path => $path)->get_dbh();
        my $operations = Daje::Generate::Database::Operations->new(dbh => $dbh);

        return ($dbh, $operations, $path);
    }

};


1;



#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

lib::Daje::Generate::Input::Sql::ConfigManager - lib::Daje::Generate::Input::Sql::ConfigManager


=head1 DESCRIPTION

pod generated by Pod::Autopod - keep this line to make pod updates possible ####################


=head1 REQUIRES

L<Mojo::JSON> 

L<Mojo::File> 

L<Daje::Generate::Tools::FileChanged> 

L<Daje::Generate::Database::Operations> 

L<Daje::Generate::Database::SqlLite> 

L<feature> 

L<v5.40> 


=head1 METHODS


=cut

