package SPVM::UV::Callback::Idle;



1;

=encoding utf8

=head1 Name

SPVM::UV::Callback::Idle - Callback for Idle Handle

=head1 Description

C<UV::Callback::Idle> in L<SPVM> is the interface for the callback passed to L<uv_idle_start|https://docs.libuv.org/en/v1.x/idle.html#c.uv_idle_start>.

=head1 Usage

  use UV::Callback::Idle;

=head1 Interface Methods

=head2 Anonymous method

C<required method : void ($uv_idle : L<UV::Handle::Idle|SPVM::UV::Handle::Idle>);>

The callback method called when the idle handle is active.

See L<UV::Handle::Idle#start|SPVM::UV::Handle::Idle/"start"> method for usage.

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
