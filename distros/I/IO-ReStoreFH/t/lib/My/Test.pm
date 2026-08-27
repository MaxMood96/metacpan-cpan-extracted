use Test2::V0;

use v5.10;
use File::Temp;
use File::Slurper;
use FileHandle::Fmode ();

sub read_text {
    my ( $filename ) = shift;
    File::Slurper::read_text( $filename, undef, 'auto' );
}

sub mode_flags {
    my ( $fh ) = @_;

    return [ map { FileHandle::Fmode->can( $_ )->( $fh ) } qw( is_RO is_WO is_R is_W is_A ) ];
}

sub test_wfh {
    my ( $desc, $mode, $sub ) = @_;

    subtest $desc, sub {
        my $tmp1 = File::Temp->new;

        open my $fh, $mode, $tmp1
          or die "error creating fh $tmp1";

        my $tmp2 = File::Temp->new;

        {
            my $s   = $sub->( $fh );
            my $dup = $s->{dups}[0]{dup};

            is( mode_flags( $dup ), mode_flags( $fh ), 'dup fh preserves mode flags', );

            open( $fh, '>', $tmp2->filename )
              or die( "error creating $tmp2\n" );

            $dup->print( "during\n" );

            $fh->print( "dup\n" );
            $fh->flush;
        }

        is( read_text( $tmp1->filename ), "during\n", 'redirect fh to file; write to original during dup' );

        is( read_text( $tmp2->filename ), "dup\n", 'redirect fh to file; write to dup' );

        $fh->print( "after\n" );
        close( $fh )
          or die "error closing fh $tmp1";

        is( read_text( $tmp1->filename ),
            "during\nafter\n", 'redirect fh to file; write to original post dup' );
    };
}

1;
