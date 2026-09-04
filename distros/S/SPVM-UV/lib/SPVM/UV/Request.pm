package SPVM::UV::Request;



1;

=encoding utf8

=head1 Name

SPVM::UV::Request - Base Request for libuv

=head1 Description

C<UV::Request> in L<SPVM> represents the base request for L<libuv|https://libuv.org/>, corresponding to the C<uv_req_t> structure.

=head1 Usage

  use UV::Request;

=head1 Well Known Child Classes

=over 2

=item * L<UV::Request::Write|SPVM::UV::Request::Write>

=back

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
