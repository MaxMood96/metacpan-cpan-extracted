package SPVM::UV::Handle;



1;

=encoding utf8

=head1 Name

SPVM::UV::Handle - Base Handle for libuv

=head1 Description

C<UV::Handle> in L<SPVM> represents the base handle for L<libuv|https://libuv.org/>, corresponding to the C<uv_handle_t> structure.

=head1 Usage

  use UV::Handle;

=head1 Fields

=head2 close_cb

C<has close_cb : rw L<UV::Callback::Close|SPVM::UV::Callback::Close>;>

The callback called when the handle has been closed.

=head2 loop

C<has loop : ro L<UV::Loop|SPVM::UV::Loop>;>

The event loop associated with the handle.

=head1 Instance Methods

=head2 close_safe

C<method close_safe : void ($close_cb : L<UV::Callback::Close|SPVM::UV::Callback::Close> = undef);>

Request the handle to be closed safely. If the handle is not already closed, it checks whether it is closing using the L<uv_is_closing|https://docs.libuv.org/en/v1.x/handle.html#c.uv_is_closing> function, and if not, calls the L<uv_close|https://docs.libuv.org/en/v1.x/handle.html#c.uv_close> function.

The callback $close_cb is invoked when the handle has been closed. 

The callback $close_cb is stored in L</"close_cb"> field.

Exceptions:

If uv_close fails, an exception is thrown.

=head2 get_type

C<method get_type : int ();>

Returns the handle type.

This method calls the L<uv_handle_get_type|https://docs.libuv.org/en/v1.x/handle.html#c.uv_handle_get_type> function.

=head1 Well Known Child Classes

=over 2

=item * L<UV::Handle::Async|SPVM::UV::Handle::Async>

=item * L<UV::Handle::Idle|SPVM::UV::Handle::Idle>

=item * L<UV::Handle::Pipe|SPVM::UV::Handle::Pipe>

=item * L<UV::Handle::Poll|SPVM::UV::Handle::Poll>

=item * L<UV::Handle::Stream|SPVM::UV::Handle::Stream>

=item * L<UV::Handle::Timer|SPVM::UV::Handle::Timer>

=back

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
