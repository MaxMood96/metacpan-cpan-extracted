load_extension('Dist::Build::Core');
auto_PL();

load_extension('Dist::Build::XS');
load_extension('Dist::Build::XS::Conf');

try_compile_run(source => <<'EOF', define => 'HAS_WRITE_UNIX_MAX_OPT', quiet => 1);
#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/stat.h>

void main() {
	struct statx stat_struct;
	stat_struct.stx_atomic_write_unit_max_opt = 42;
}
EOF

auto_xs();
