# NAME

IO::ReStoreFH - store/restore file handles

# VERSION

version 0.13

# SYNOPSIS

        use IO::ReStoreFH;

        {
           my $fhstore = IO::ReStoreFH->new( *STDOUT );

           open( STDOUT, '>', 'file' );
        } # STDOUT will be restored when $fhstore is destroyed

        # or, one at-a-time
        {
           my $fhstore = IO::ReStoreFH->new;
           $store->store( *STDOUT );
           $store->store( $myfh );

           open( STDOUT, '>', 'file' );
           open( $myfh, '>', 'another file' );
        } # STDOUT and $myfh will be restored when $fhstore is destroyed

# DESCRIPTION

Redirecting and restoring I/O streams is straightforward but a chore,
and can lead to strangely silent errors if you forget to restore
STDOUT or STDERR.

**IO::ReStoreFH** helps keep track of the present state of filehandles and
low-level file descriptors and restores them either explicitly or when
the **IO::ReStoreFH** object goes out of scope.

It uses the standard Perl filehandle duplication methods (via **open**)
for filehandles, and uses **POSIX::dup** and **POSIX::dup2** for file
descriptors.

File handles and descriptors are restored in the reverse order that
they are stored.

# INTERNALS

# INTERFACE

- new

            my $fhstore = IO::ReStoreFH->new;
            my $fhstore = IO::ReStoreFH->new( $fh1, $fh2, $fd, ... );

    Create a new object and an optional list of Perl filehandles or
    integer file descriptors.

    The passed handles and descriptors will be duplicated to be restored
    when the object is destroyed or the **restore** method is called.

- store

            $fhstore->store( $fh );

            $fhstore->store( $fd );

    The passed handles and descriptors will be duplicated to be restored
    when the object is destroyed or the **restore** method is called.

- restore

        $fhstore->restore;

    Restore the stored file handles and descriptors, in the reverse order
    that they were stored.  This is automatically called when the object
    is destroyed.

# DIAGNOSTICS

- `$fh is not an open filehandle`

    The passed filehandle failed a check to ensure that it was an open
    filehandle.  Make sure it's a) a real filehandle; b) it's open.

- `inexplicable error: unable to determine mode for $fh`

    **IO::ReStoreFH** was unable to get the access mode for the passed file
    handle.  Are you sure that it's really a filehandle object?

- `error fdopening %s: %s`

    Perl **open()** was unable to duplicate the passed filehandle for the
    specified reason.

- `error dup'ing file descriptor %s: %s`

    **POSIX::dup()** was unable to duplicate the passed file descriptor for the
    specified reason.

- `$fh must be opened Perl filehandle or object or integer file descriptor`

    The passed `$fh` argument wasn't recognized as a Perl filehandle or a
    file descriptor.  Please try again.

- `error restoring file descriptor %d: %s`

    Attempting to restore the file descriptor failed for the specified reason.

- `error restoring file handle %s: %s`

    Attempting to restore the Perl file handle failed for the specified reason.

# SUPPORT

## Bugs

Please report any bugs or feature requests to bug-io-restorefh@rt.cpan.org  or through the web interface at: [https://rt.cpan.org/Public/Dist/Display.html?Name=IO-ReStoreFH](https://rt.cpan.org/Public/Dist/Display.html?Name=IO-ReStoreFH)

## Source

Source is available at

    https://codeberg.org/djerius/p5-IO-ReStoreFH

and may be cloned from

    https://codeberg.org/djerius/p5-IO-ReStoreFH.git

# AUTHOR

Diab Jerius <djerius@cfa.harvard.edu>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

    The GNU General Public License, Version 3, June 2007
