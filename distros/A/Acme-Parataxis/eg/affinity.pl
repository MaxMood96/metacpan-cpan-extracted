use v5.40;
use lib 'lib';
use blib;
use Acme::Parataxis;
$|++;

# Demonstrate Thread Affinity / Core ID
Acme::Parataxis::run(
    sub {
        say 'Main thread (TID: ' . Acme::Parataxis->tid . ')';
        my @futures;
        for ( 1 .. 20 ) {
            push @futures, Acme::Parataxis->spawn(
                sub {
                    my $core_id = Acme::Parataxis->await_core_id();

                    #~ warn 'In core ' . $core_id;
                    return $core_id;
                }
            );
        }
        say 'Main: Tasks spawned, waiting for results...';
        my %distribution;
        for my $f (@futures) {
            my $core = $f->await();
            if ( defined $core ) {
                $distribution{$core}++;
            }
            else {
                warn "Failed to get core ID for a task.\n";
            }
        }
        say 'Background Task Distribution across CPU Cores:';
        for my $core ( sort { $a <=> $b } keys %distribution ) {
            say "  Core $core: " . $distribution{$core} . ' tasks';
        }
        @futures = ();
        Acme::Parataxis::stop();
    }
);
