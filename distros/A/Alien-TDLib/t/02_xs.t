use strict;
use warnings;
use Test::More;
use Test::Alien;
use Alien::TDLib;

alien_ok 'Alien::TDLib';

my %xs = (xs => do { local $/; <DATA> });
if (Alien::TDLib->install_type eq 'share') {
    # the rpath baked into libs names the final install prefix; under blib the
    # share dir is elsewhere, so also add an rpath for the copy under test
    $xs{cbuilder_link} = { extra_linker_flags =>
        ['-Wl,-rpath,' . Alien::TDLib->dist_dir . '/lib'] };
}

xs_ok \%xs, with_subtest {
    my ($module) = @_;
    my $json = $module->tdlib_version_request;
    like $json, qr/\@type/, 'td_execute returned a JSON object';
    unlike $json, qr/"\@type"\s*:\s*"error"/, 'not an error object';
};

done_testing;

__DATA__
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <td/telegram/td_json_client.h>

MODULE = TA_MODULE PACKAGE = TA_MODULE

SV *
tdlib_version_request(klass)
    SV *klass
  PREINIT:
    const char *res;
  CODE:
    PERL_UNUSED_VAR(klass);
    res = td_execute("{\"@type\":\"getTextEntities\",\"text\":\"@ok\"}");
    RETVAL = res ? newSVpv(res, 0) : &PL_sv_undef;
  OUTPUT:
    RETVAL
