## WHAT THIS LIBRARY IS FOR
Primary IPC lock mechanisms via lock files and tokens.
Secondary it allows to transfer references (arrayref/hashref) between processes, but you should separate transfer files and lock files for the sake of the speed. However, never should it be used for huge data transfer, but for small pieces, e.g. the file path where you saved a file containing huge data. Or the identifier within the database table.

## WHAT THIS LIBRARY IS NOT FOR
This is not a fifo, socket, nor TCP pipe implementation.

## UPDATES
With version 2.8 much things were renamed. Tests must be run before finally integrating it. Things will work as before, but using the the old functions will throw warnings.
With version 2.9 the formerly named functions were removed and only the new will be available.
Exception: new() is a synonym for New().

## INSTALLATION
Usually you just have to run these three commands:

```
  perl Makefile.PL
  make
  make install
```

If ran on a systemd based OS you should have `/dev/shm` as main shared memory for IPC, else check the following.
On any else \*NIX based system you should provide a tmpfs, as `/run` or at least as `/tmp` for speed purpoises.
Easy way for e.g. FreeBSD: `mount -t tmpfs tmpfs /run`

## DEPENDENCIES
Perl v5.40.0 or newer.
Any required libraries are usually part of the default Perl installation of version 5.40.0 .

## HOW TO <a name="howto"></a>
[See at GitHub-Wiki.](https://github.com/DomAsProgrammer/perl-IPC-LockTicket/wiki)

## WHY THIS LIBRARY EXISTS
It shall leave the semaphores alone, which are e.g. used by *IPC::Shareable*. I discovered many issues which are no problem of *IPC::Shareable* itself but mor the (not) provided cleaning of semaphores itself. Even when used the clean mechanisms of *IPC::Shareable* extensively it was occasionally happen to need to clean them by hand with system tools. Tough modern technology using tmpfs (RAM based file systems) offerd a more cleaner and simpler opportunity to make use of the speed of RAM as file system especially using the *Storeable* library of Perl which lets us save Perl's data stracture as is as file. This brought me to this idea, using an array containing PIDs to make a stable and token based lock system. This way it is possible to prevent deadlocks because of tokens for interrupted/killed or unclean terminated applications. To clarify: It's not (meant) to prevent programming issues like forgotten unlock (`TokenUnlock()`/`MainUnlock()`) can't be captured this way unless the corresponding process exits itself and therefore the token becomes obsolete. For further details see the manual you can find at the [*HOW TO*](#howto) section.
