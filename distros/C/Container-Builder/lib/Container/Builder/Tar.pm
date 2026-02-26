package Container::Builder::Tar;

use v5.40;
use feature 'class';
no warnings 'experimental::class';

# Our own implementation for creating directories because Archive::Tar doesn't allow us to do this.
# It supports adding data via "add_data()" but this doesn't set the correct options in Archive::Tar::File
# since it's instantiated as a file with data Archive::Tar::File->new(data => $filename, $data, $options)
# which in that class does not check the options because we're passing data...
# 
# So here we are making TAR files from scratch...
class Container::Builder::Tar {
	field $full_tar = '';

	method get_tar() {
		my $str = $full_tar;
		$str .= "\x00" x 1024; # 2 empty blocks at the end
		return $str;
	}

	method add_dir($path, $mode, $uid, $gid) {
		$path = '.' . $path if $path =~ /^\//;
		die "Path is longer than 98 chars" if length($path) > 98;
		die "Mode is too long" if length(sprintf("%07o", int($mode))) > 7;
		die "Uid is too long" if length(sprintf("%07o", int($uid))) > 7;
		die "Gid is too long" if length(sprintf("%07o", int($gid))) > 7;
		my $tar = $path . "\x00" x (100-length($path)); #  char name[100];               /*   0 */
		$tar .= sprintf("%07o", int($mode)) . "\x00"; #  char mode[8];                 /* 100 */
		$tar .= sprintf("%07o", int($uid)) . "\x00"; #  char uid[8];                  /* 108 */ -> not sure why we use 6 bytes but that's how other tars do it
		$tar .= sprintf("%07o", int($gid)) . "\x00"; #  char gid[8];                  /* 116 */ -> not sure why we use 6 bytes but that's how other tars do it
		$tar .= sprintf("%011o", 0) . "\x00"; #  char size[12];                /* 124 */ -> dir size is always 0...
		$tar .= sprintf("%011o", 566833020) . "\x00"; #  char mtime[12];               /* 136 */
		$tar .= "\x20" x 8; #  char chksum[8];               /* 148 */ -> we'll do this later
		$tar .= "5"; #  char typeflag;                /* 156 */ --> A dir is 5
		$tar .= "\x00" x 100; #  char linkname[100];           /* 157 */
		$tar .= "ustar\x00"; #  char magic[6];                /* 257 */
		$tar .= "00"; #  char version[2];              /* 263 */
		#$tar .= "ustar\x20\x20\x00";
		$tar .= "\x00" x 32; #  char uname[32];               /* 265 */
		$tar .= "\x00" x 32; #  char gname[32];               /* 297 */
		$tar .= "\x00" x 8; #  char devmajor[8];             /* 329 */
		$tar .= "\x00" x 8; #  char devminor[8];             /* 337 */
		$tar .= "\x00" x 155; #  char prefix[155];             /* 345 */

		my $checksum = 0;
		map { $checksum += ord($_) } split //, $tar;
		# NOT LIKE THE SPEC!
		# I don't know why but all tar archives that I look at only use 6 bytes for the checksum instead of 7 + null byte.
		# When I followed the spec to a tee, it gave errors. When I do the same and make a 6 byte number (no zeroes in front) + null byte + left over space (\x20), it works...
		# Don't ask me why...
		my $checksum_str = sprintf("%6o", $checksum);
		$tar =~ s/^(.{148}).{7}/$1.$checksum_str."\x00"/e; # Overwrite checksum bytes

		$tar .= "\x00" x 12; # create a block of 512, the header is 500 bytes.

		$full_tar .= $tar;
	}

	method add_file($filepath, $data, $mode, $uid, $gid) {
		$filepath = '.' . $filepath if $filepath =~ /^\//; # When given an absolute path, we actually need to make it ./
		die "Path is longer than 98 chars" if length($filepath) > 98;
		die "Mode is too long" if length(sprintf("%07o", int($mode))) > 7;
		die "Uid is too long" if length(sprintf("%07o", int($uid))) > 7;
		die "Gid is too long" if length(sprintf("%07o", int($gid))) > 7;
		my $tar = $filepath . "\x00" x (100-length($filepath)); #  char name[100];               /*   0 */
		$tar .= sprintf("%07o", int($mode)) . "\x00"; #  char mode[8];                 /* 100 */
		$tar .= sprintf("%07o", int($uid)) . "\x00"; #  char uid[8];                  /* 108 */
		$tar .= sprintf("%07o", int($gid)) . "\x00"; #  char gid[8];                  /* 116 */ 
		$tar .= sprintf("%011o", length($data)) . "\x00"; #  char size[12];                /* 124 */ 
		$tar .= sprintf("%011o", 566833020) . "\x00"; #  char mtime[12];               /* 136 */
		$tar .= "\x20" x 8; #  char chksum[8];               /* 148 */ -> we'll do this later
		$tar .= "0"; #  char typeflag;                /* 156 */ --> A regular file is 0
		$tar .= "\x00" x 100; #  char linkname[100];           /* 157 */
		$tar .= "ustar\x00"; #  char magic[6];                /* 257 */
		$tar .= "00"; #  char version[2];              /* 263 */
		$tar .= "\x00" x 32; #  char uname[32];               /* 265 */
		$tar .= "\x00" x 32; #  char gname[32];               /* 297 */
		$tar .= "\x00" x 8; #  char devmajor[8];             /* 329 */
		$tar .= "\x00" x 8; #  char devminor[8];             /* 337 */
		$tar .= "\x00" x 155; #  char prefix[155];             /* 345 */

		my $checksum = 0;
		map { $checksum += ord($_) } split //, $tar;
		# NOT LIKE THE SPEC!
		# I don't know why but all tar archives that I look at only use 6 bytes for the checksum instead of 7 + null byte.
		# When I followed the spec to a tee, it gave errors. When I do the same and make a 6 byte number (no zeroes in front) + null byte + left over space (\x20), it works...
		# Don't ask me why...
		my $checksum_str = sprintf("%6o", $checksum);
		$tar =~ s/^(.{148}).{7}/$1.$checksum_str."\x00"/e; # Overwrite checksum bytes

		$tar .= "\x00" x 12; # create a block of 512, the header is 500 bytes.

		$tar .= $data;
		my $remainder = length($data) % 512;
		$tar .= "\x00" x (512 - $remainder) if $remainder > 0;

		$full_tar .= $tar;
	}

	method extract_file($tar, $filepath) {
		my $blocks_read = 0;
		my $filename = $self->_get_filename($tar, $blocks_read);
		my $filesize = $self->_get_filesize($tar, $blocks_read);
		while($filename ne $filepath && $filename && length($tar) > $blocks_read * 512) {
			$blocks_read++; # skip header block
			# jump the amount of blocks to the next header.
			my $block_count = int($filesize / 512); 
			$block_count++ if $filesize % 512; # the remainder is another block unless there's no remainder bytes (file neatly fits a block, no remainder)
			$blocks_read += $block_count;
			# read header
			$filename = $self->_get_filename($tar, $blocks_read);
			$filesize = $self->_get_filesize($tar, $blocks_read);
		}
		# extract data from our file and return
		if($filename eq $filepath) {
			if($filesize == 0) { # probably a directory... Only return the header
				my $header = substr($tar, $blocks_read*512, 512);
				return $header;
			} else {
				my $bytes_to_read = 512; # header size
				$bytes_to_read += 512 * int($filesize / 512);
				$bytes_to_read += 512 if $filesize % 512;
				my $file = substr($tar, $blocks_read*512, $bytes_to_read); 
				return $file;
			}
		} else {
			return '';
		}
	}

	method extract_wildcard_files($tar, $filepath) {
		chop($filepath); # remove wildcard *
		my $prefix_length = length($filepath);
		my $blocks_read = 0;
		my $filename = $self->_get_filename($tar, $blocks_read);
		my $filesize = $self->_get_filesize($tar, $blocks_read);
		my $tarfile = '';
		while($filename && length($tar) > $blocks_read * 512) {
			$blocks_read++; # skip header block
			if(substr($filename, 0, $prefix_length) eq $filepath && $filesize > 0 && substr($filename, $prefix_length) !~ /\//) {
				my $bytes_to_read = 512; # header size
				$bytes_to_read += 512 * int($filesize / 512);
				$bytes_to_read += 512 if $filesize % 512;
				my $file = substr($tar, ($blocks_read-1)*512, $bytes_to_read); 
				$tarfile .= $file;
			}
			# jump the amount of blocks to the next header.
			my $block_count = int($filesize / 512); 
			$block_count++ if $filesize % 512; # the remainder is another block unless there's no remainder bytes (file neatly fits a block, no remainder)
			$blocks_read += $block_count;
			# read header
			$filename = $self->_get_filename($tar, $blocks_read);
			$filesize = $self->_get_filesize($tar, $blocks_read);
		}
		return $tarfile;
	}

	method _get_filesize($tar, $blocks_read) {
		my $header = substr($tar, $blocks_read * 512, 512);
		my @header_bytes = split //, $header;
		my @size = splice(@header_bytes, 124, 11);
		my $size_str = join('', @size);
		my $actual_size = oct($size_str);
		return $actual_size;
	}

	method _get_filename($tar, $blocks_read) {
		my $header = substr($tar, $blocks_read * 512, 512);
		my $filename = '';
		my @header_bytes = split //, $header;
		my $i = 0;
		while($header_bytes[$i] ne "\x00") {
			$filename .= $header_bytes[$i++];
		}
		return $filename;
	}
}

1;
__END__

=encoding utf-8

=pod

=head1 NAME

Container::Builder::Tar - Class for creating Tar archives from scratch.

=head1 DESCRIPTION

Container::Builder::Tar provides several methods to create a TAR archive. It was created because the methods of L<Archive::Tar> didn't allow fine-grained control over permissions and owning users.

=head1 METHODS

=over 1

=item new()

Create an empty C<Container::Builder::Tar> object. 

=item get_tar()

Return a valid TAR file as a scalar string that is the concatenation of all the directories and files.

=item add_dir($path, $mode, $uid, $gid)

Add a directory to the TAR archive. Absolute directories will be prefixed with a '.'.

=item add_file($filepath, $data, $mode, $uid, $gid)

Add a file to the TAR archive. Absolute paths will be prefixed with a '.'.

=item extract_file($tar, $filepath)

Pass a valid TAR file as a scalar string and a filepath, and this method will return the header + data blocks of the file (or only the header when it's a directory).

=item extract_wildcard_files($tar, $filepath)

Does the same as C<extract_file()> but allows appending a wildcard (an asterisk) to the path to get all the files matching in the directory. Note that this does not recursively find all files, it will only match the files in the directory of the wildcard.

=back

=head1 AUTHOR

Adriaan Dens E<lt>adri@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2026- Adriaan Dens

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over

=item Part of the L<Container::Builder> module.

=item L<GNU TAR format|https://www.gnu.org/software/tar/manual/html_node/Standard.html>

=back

=cut

