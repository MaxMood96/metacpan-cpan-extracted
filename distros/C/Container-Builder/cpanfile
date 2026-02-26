requires 'perl', '5.040';

requires 'Archive::Ar';
requires 'Archive::Tar';
requires 'IO::Uncompress::UnXz';
requires 'IO::Compress::Gzip';
requires 'IO::Uncompress::Gunzip';
requires 'Cwd';
requires 'DateTime';
requires 'File::Copy';
requires 'Crypt::Digest::SHA256';
requires 'LWP::Protocol::https';
requires 'LWP::Simple';
requires 'LWP::UserAgent';
requires 'DPKG::Packages::Parser', '0.03'; # Need the new(fh) constructor
requires 'JSON';
requires 'File::Basename';
requires 'Path::Class::Iterator';

on test => sub {
	requires 'Test::More', '0.96';
	requires 'JSON';
	requires 'Archive::Tar';
	requires 'Crypt::Digest::SHA256';
};
