use v5.40;
use experimental 'class';

# Ensure the base class is loaded
use Alien::Xrepo::Base;

class Alien::Zstandard : isa(Alien::Xrepo::Base) {
    method package_name {'zstd'}

    method install_opts {
        return (
            kind => 'shared',

            #configs => { legacy => 1 }
        );
    }
}

#~ # Quick Test
#~ my $zstd = Alien::Zstandard->new;
#~ say "Package: " . $zstd->package_name;
#~ say "Version: " . $zstd->version;
#~ say "CFlags:  " . $zstd->cflags;
