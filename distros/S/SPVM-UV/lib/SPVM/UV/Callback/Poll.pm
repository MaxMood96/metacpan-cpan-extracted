package SPVM::UV::Callback::Poll;



1;

=encoding utf8

=head1 Name

SPVM::UV::Callback::Poll - Callback for Poll Handle

=head1 Description

C<UV::Callback::Poll> in L<SPVM> is the interface for the callback passed to L<uv_poll_start|https://docs.libuv.org/en/v1.x/poll.html#c.uv_poll_start>.

=head1 Usage

  use UV::Callback::Poll;

=head1 Interface Methods

=head2 Anonymous method

C<required method : void ($uv_poll : L<UV::Handle::Poll|SPVM::UV::Handle::Poll>, $status : int, $events : int);>

The callback method called when the poll handle detects events or an error occurs.

See L<UV::Handle::Poll#start|SPVM::UV::Handle::Poll/"start"> method for usage.

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
