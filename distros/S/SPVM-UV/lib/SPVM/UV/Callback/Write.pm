package SPVM::UV::Callback::Write;



1;

=encoding utf8

=head1 Name

SPVM::UV::Callback::Write - Callback for Write Request

=head1 Description

C<UV::Callback::Write> in L<SPVM> is the interface for the callback passed to L<uv_write|https://docs.libuv.org/en/v1.x/stream.html#c.uv_write>.

=head1 Usage

  use UV::Callback::Write;

=head1 Interface Methods

=head2 Anonymous method

C<required method : void ($uv_req_write : L<UV::Request::Write|SPVM::UV::Request::Write>, $status : int);>

The callback method called when the write request has completed.

See L<UV::Request::Write#write|SPVM::UV::Request::Write/"write"> method for usage.

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
