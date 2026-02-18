use v5.40;
use blib;
use Acme::Parataxis;

# Symmetric coroutines (Producer/Consumer)
my ( $producer, $consumer );
$producer = Acme::Parataxis->new(
    code => sub {
        for my $item (qw(Apple Banana Cherry)) {
            say "Producer: Created $item. Transferring to Consumer...";
            $consumer->transfer($item);
            say 'Producer: Consumer gave control back. Moving to next item.';
        }
        say 'Producer: Out of items. Telling consumer to finish.';
        $consumer->transfer(undef);
    }
);
$consumer = Acme::Parataxis->new(
    code => sub {

        # Initial yield to wait for the first item from the Producer
        my $item = Acme::Parataxis->yield();
        while ( defined $item ) {
            say "  Consumer: Received '$item'. Processing...";
            say '  Consumer: Done processing. Transferring back to Producer...';

            # Transfer back to producer and wait for the NEXT item
            $item = $producer->transfer();
        }
        say '  Consumer: Shutting down.';
        Acme::Parataxis->root->transfer();    # Return to main
    }
);
say 'Main: Starting the dance...';

# We need to prime the consumer so it hits its yield()
$consumer->call();

# Now start the producer
$producer->call();
say 'Main: The dance is over.';
