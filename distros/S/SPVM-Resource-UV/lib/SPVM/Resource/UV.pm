package SPVM::Resource::UV;

our $VERSION = "0.001";

1;

=encoding utf8

=head1 Name

SPVM::Resource::UV - libuv Resources

=head1 Description

SPVM::Resource::UV class in L<SPVM> is a L<resource|SPVM::Document::Resource> class for L<libuv|https://github.com/libuv/libuv> library.

=head1 Usage

MyClass.config:
  
  my $config = SPVM::Builder::Config->new_c99;
  
  $config->use_resource('Resource::UV');
  
  my $resource_uv = $config->get_resource('Resource::UV');
  $config->add_define(@{$resource_uv->config->defines});
  $config->add_lib(@{$resource_uv->config->libs});
  
  $config;

MyClass.c:
  
  #include <uv.h>
  
  uv_loop_t* loop = uv_default_loop();
  
  uv_run(loop, UV_RUN_DEFAULT);
  
  uv_loop_close(loop);

=head1 Original Product

L<libuv|https://github.com/libuv/libuv>

=head1 Original Product Version

L<libuv v1.52.1|https://github.com/libuv/libuv/releases/tag/v1.52.1>

=head1 Language

The C language

=head1 Language Standard

C99

=head1 Header Files

=over 2

=item * C<uv.h>

=item * C<uv/errno.h>

=item * C<uv/fos.h>

=item * C<uv/threadpool.h>

=item * C<uv/version.h>

=item * C<uv/unix.h>

=item * C<uv/win.h>

=back

=head1 Source Files

Common:

=over 2

=item * C<fs-poll.c>

=item * C<idna.c>

=item * C<inet.c>

=item * C<random.c>

=item * C<strscpy.c>

=item * C<strtok.c>

=item * C<thread-common.c>

=item * C<threadpool.c>

=item * C<timer.c>

=item * C<uv-common.c>

=item * C<uv-data-getter-setters.c>

=item * C<version.c>

=back

Unix:

=over 2

=item * C<unix/async.c>

=item * C<unix/core.c>

=item * C<unix/dl.c>

=item * C<unix/fs.c>

=item * C<unix/getaddrinfo.c>

=item * C<unix/getnameinfo.c>

=item * C<unix/loop-watcher.c>

=item * C<unix/loop.c>

=item * C<unix/pipe.c>

=item * C<unix/poll.c>

=item * C<unix/process.c>

=item * C<unix/random-devurandom.c>

=item * C<unix/signal.c>

=item * C<unix/stream.c>

=item * C<unix/tcp.c>

=item * C<unix/thread.c>

=item * C<unix/tty.c>

=item * C<unix/udp.c>

=back

Linux:

=over 2

=item * C<unix/linux.c>

=item * C<unix/procfs-exepath.c>

=item * C<unix/random-getrandom.c>

=item * C<unix/random-sysctl-linux.c>

=item * C<unix/proctitle.c>

=back

macOS (Darwin):

=over 2

=item * C<unix/proctitle.c>

=item * C<unix/darwin.c>

=item * C<unix/darwin-proctitle.c>

=item * C<unix/fsevents.c>

=item * C<unix/bsd-ifaddrs.c>

=item * C<unix/kqueue.c>

=item * C<unix/random-getentropy.c>

=back

Windows:

=over 2

=item * C<win/async.c>

=item * C<win/core.c>

=item * C<win/detect-wakeup.c>

=item * C<win/dl.c>

=item * C<win/error.c>

=item * C<win/fs.c>

=item * C<win/fs-event.c>

=item * C<win/getaddrinfo.c>

=item * C<win/getnameinfo.c>

=item * C<win/handle.c>

=item * C<win/loop-watcher.c>

=item * C<win/pipe.c>

=item * C<win/thread.c>

=item * C<win/poll.c>

=item * C<win/process.c>

=item * C<win/process-stdio.c>

=item * C<win/signal.c>

=item * C<win/snprintf.c>

=item * C<win/stream.c>

=item * C<win/tcp.c>

=item * C<win/tty.c>

=item * C<win/udp.c>

=item * C<win/util.c>

=item * C<win/winapi.c>

=item * C<win/winsock.c>

=back

=head1 Compiler Flags & Defines

Unix (Common):

=over 2

=item * C<-D_FILE_OFFSET_BITS=64>

=item * C<-D_LARGEFILE_SOURCE>

=back

Linux:

=over 2

=item * C<-D_GNU_SOURCE>

=item * C<-D_POSIX_C_SOURCE=200112>

=back

macOS (Darwin):

=over 2

=item * C<-D_DARWIN_UNLIMITED_SELECT=1>

=item * C<-D_DARWIN_USE_64_BIT_INODE=1>

=back

Windows:

=over 2

=item * C<-DWIN32_LEAN_AND_MEAN>

=item * C<-D_WIN32_WINNT=0x0A00>

=item * C<-D_CRT_DECLARE_NONSTDC_NAMES=0>

=back

=head1 Libraries

Linux:

=over 2

=item * C<dl>

=item * C<rt>

=back

Windows:

=over 2

=item * C<psapi>

=item * C<user32>

=item * C<advapi32>

=item * C<iphlpapi>

=item * C<userenv>

=item * C<ws2_32>

=item * C<dbghelp>

=item * C<ole32>

=item * C<shell32>

=back

=head1 How to Create Resource

=head2 Download

  mkdir -p .tmp
  git clone https://github.com/libuv/libuv .tmp/libuv
  git -C .tmp/libuv checkout tags/v1.52.1 -b branch_v1.52.1
  git -C .tmp/libuv branch

=head2 Extracting Header Files

The header files of C<libuv> is copied into the C<include> directory by the following command.

  rsync -av --include='*.h' --exclude='*' .tmp/libuv/include/ lib/SPVM/Resource/UV.native/include/

=head2 Extracting Source Files

The source files of C<libuv> are copied into the C<src> directory by the following command.

  rsync -av --exclude='*.h' .tmp/libuv/src/ lib/SPVM/Resource/UV.native/src/

=head1 Repository

L<SPVM::Resource::UV - Github|https://github.com/yuki-kimoto/SPVM-Resource-UV>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License

=cut
