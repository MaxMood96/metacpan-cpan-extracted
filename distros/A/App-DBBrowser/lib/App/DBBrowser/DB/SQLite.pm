package # hide from PAUSE
App::DBBrowser::DB::SQLite;

use warnings;
use strict;
use 5.016;

use Encode                qw( encode decode );
use File::Find            qw( find );
use File::Spec::Functions qw( catfile );

use DBD::SQLite 1.74;    # sqlite 3.42.0
use DBD::SQLite::Constants ':dbd_sqlite_string_mode';
use DBI            qw();
use Encode::Locale qw();

use Term::Choose       qw();
use Term::Choose::Util qw();

use App::DBBrowser::Auxil;
use App::DBBrowser::Opt::DBGet;


sub new {
    my ( $class, $info, $opt ) = @_;
    my $sf = {
        i => $info,
        o => $opt
    };
    bless $sf, $class;
}


sub get_db_driver {
    my ( $sf ) = @_;
    return 'SQLite';
}


sub read_attributes {
    my ( $sf ) = @_;
    return [
        { name => 'sqlite_busy_timeout', default => 30000 },
    ];
}


sub set_attributes {
    my ( $sf ) = @_;
    my $values = [
        DBD_SQLITE_STRING_MODE_PV               . ' DBD_SQLITE_STRING_MODE_PV',               # 0
        DBD_SQLITE_STRING_MODE_BYTES            . ' DBD_SQLITE_STRING_MODE_BYTES',            # 1
        DBD_SQLITE_STRING_MODE_UNICODE_NAIVE    . ' DBD_SQLITE_STRING_MODE_UNICODE_NAIVE',    # 4
        DBD_SQLITE_STRING_MODE_UNICODE_FALLBACK . ' DBD_SQLITE_STRING_MODE_UNICODE_FALLBACK', # 5
        DBD_SQLITE_STRING_MODE_UNICODE_STRICT   . ' DBD_SQLITE_STRING_MODE_UNICODE_STRICT',   # 6
    ];
    return [
        { name => 'sqlite_string_mode',         default => 3, values => $values }, # $values->[3] == DBD_SQLITE_STRING_MODE_UNICODE_FALLBACK (5)
        { name => 'sqlite_see_if_its_a_number', default => 1, values => [ 0, 1 ] },
        { name => 'ChopBlanks',                 default => 0, values => [ 0, 1 ] },
    ];
}


sub get_db_handle {
    my ( $sf, $db ) = @_;
    my $db_opt_get = App::DBBrowser::Opt::DBGet->new( $sf->{i}, $sf->{o} );
    my $db_opt = $db_opt_get->read_db_config_files();
    my $read_attributes = $db_opt_get->get_read_attributes( $db, $db_opt );
    my $set_attributes = $db_opt_get->get_set_attributes( $db, $db_opt );
    my $dsn = "dbi:$sf->{i}{driver}:dbname=$db";
    my $dbh = DBI->connect( $dsn, '', '', {
        PrintError => 0,
        RaiseError => 1,
        AutoCommit => 1,
        ShowErrorStatement => 1,
        %$set_attributes,
    } );
    if ( DBI::looks_like_number( $read_attributes->{sqlite_busy_timeout} ) ) {
        $dbh->sqlite_busy_timeout( 0 + $read_attributes->{sqlite_busy_timeout} );
    }
    return $dbh;
}


sub get_databases {
    my ( $sf ) = @_;
    return \@ARGV if @ARGV;
    my $cache_sqlite_files = catfile $sf->{i}{app_dir}, 'cache_SQLite_files.json';
    my $ax = App::DBBrowser::Auxil->new( {}, {}, {} );
    my $tc = Term::Choose->new( $sf->{i}{tc_default} );
    my $db_cache = $ax->read_json( $cache_sqlite_files ) // {};
    my $dirs = $db_cache->{directories} // [ $sf->{i}{home_dir} ];
    my $databases = $db_cache->{databases} // [];
    if ( ! $sf->{i}{search} && @$databases ) {
        return $databases;
    }
    while ( 1 ) {
        my ( $ok, $change ) = ( '- Confirm', '- Change' );
        # Choose
        my $choice = $tc->choose(
            [ undef, $ok, $change ],
            { %{$sf->{i}{lyt_v}}, prompt => 'Search databases in: ' . join( ', ', @$dirs ), info => 'SQLite' }
        );
        if ( ! defined $choice ) {
            return $databases;
        }
        elsif ( $choice eq $change ) {
            my $tu = Term::Choose::Util->new( $sf->{i}{tcu_default} );
            #my $info = 'Curr: ' . join( ', ', @$dirs ); #
            my $new_dirs = $tu->choose_directories( { confirm => $sf->{i}{_confirm}, back => $sf->{i}{_back} } );
            if ( ! @{$new_dirs//[]} ) {
                next;
            }
            $dirs = $new_dirs;
        }
        else {
            last;
        }
    }
    $databases = [];
    local $| = 1;
    print 'Searching ... ';
    my $encoding = Encode::find_encoding( 'locale_fs' );
    if ( $sf->{o}{G}{file_find_warnings} ) {
        my $file;
        for my $dir ( @$dirs ) {
            File::Find::find( {
                wanted => sub {
                    #my $file_fs = $_;
                    return if ! -f $_;
                    $file = $encoding->decode( $_ );
                    print "$file\n";
                    if ( ! eval {
                        open my $fh, '<:raw', $_ or die "$file: $!";
                        defined( read $fh, my $string, 13 ) or die "$file: $!";
                        close $fh;
                        push @$databases, $file if $string eq 'SQLite format';
                        1 }
                    ) {
                        utf8::decode( $@ );
                        print $@;
                    }
                },
                no_chdir => 1,
            },
            $encoding->encode( $dir ) );
        }
        $tc->choose(
            [ 'Press ENTER to continue' ],
            { prompt => 'Search finished.' }
        );
    }
    else {
        no warnings qw( File::Find );
        my $file;
        for my $dir ( @$dirs ) {
            File::Find::find( {
                wanted => sub {
                    #my $file_fs = $_;
                    return if ! -f $_;
                    $file = $encoding->decode( $_ );
                    print "$file\n";
                    eval {
                        open my $fh, '<:raw', $_ or die "$file: $!";
                        defined( read $fh, my $string, 13 ) or die "$file: $!";
                        close $fh;
                        push @$databases, $file if $string eq 'SQLite format';
                    };
                },
                no_chdir => 1,
            },
            $encoding->encode( $dir ) );
        }
    }
    print 'Ended searching' . "\n";
    $db_cache->{directories} = $dirs;
    $databases = [ sort { $a cmp $b } @$databases ];
    $db_cache->{databases} = $databases;
    $ax->write_json( $cache_sqlite_files, $db_cache );
    return $databases;
}








1;


__END__
