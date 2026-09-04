package SPVM::UV::Callback::Timer;



1;

=encoding utf8

=head1 Name

SPVM::UV::Callback::Timer - Callback for Timer Handle

=head1 Description

C<UV::Callback::Timer> in L<SPVM> is the interface for the callback passed to L<uv_timer_start|https://docs.libuv.org/en/v1.x/timer.html#c.uv_timer_start>.

=head1 Usage

  use UV::Callback::Timer;

=head1 Interface Methods

=head2 Anonymous method

C<required method : void ($uv_timer : L<UV::Handle::Timer|SPVM::UV::Handle::Timer>);>

The callback method called when the timer has timed out.

See L<UV::Handle::Timer#start|SPVM::UV::Handle::Timer/"start"> method for usage.

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
