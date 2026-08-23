#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif
#include <spawn.h>

int
main(void)
{
    posix_spawn_file_actions_t actions;
    int error = posix_spawn_file_actions_init(&actions);
    if (!error) {
        error = posix_spawn_file_actions_addchdir_np(&actions, ".");
        posix_spawn_file_actions_destroy(&actions);
    }
    return error != 0;
}
