use v5.10; use strict; use warnings;
use lib 'lib';
use EV; use EV::WebKit; use Glib ();

# reach into a real instance's context and wire the extension BEFORE the first
# navigation -- exactly what the real feature does internally.
my $dir = "$ENV{PWD}/.tmp/wext-spike";
my $gv  = Glib::Variant->new('a{sv}', {
    platform            => Glib::Variant->new('s', 'Win32'),
    hardwareConcurrency => Glib::Variant->new('d', 8),
});

my $b = EV::WebKit->new(window => [200,150]);
$b->{context}->set_web_process_extensions_directory($dir);
$b->{context}->set_web_process_extensions_initialization_user_data($gv);
$b->mock_scheme('fp', sub { ('<html><body>fp</body></html>','text/html') });

my %g;
$b->go('fp://host/p', sub {
    $b->script('return navigator.platform', sub {
        $g{platform} = $_[0];
        $b->script('return navigator.hardwareConcurrency', sub {
            $g{hwc} = $_[0];
            $b->script('return Object.getOwnPropertyDescriptor(navigator,"platform").get.toString()', sub {
                $g{tostr} = $_[0]; EV::break;
            });
        });
    });
});
my $t = EV::timer(20,0,sub{ warn "TIMEOUT\n"; EV::break }); EV::run; undef $t;
$b->quit;

printf "platform = %s (expect Win32)\n", $g{platform} // 'undef';
printf "hwc      = %s (expect 8)\n",     $g{hwc}      // 'undef';
printf "toString = %s (expect [native code])\n", $g{tostr} // 'undef';
