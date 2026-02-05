requires 'perl', '5.008001';

requires 'Plack', '1.0000';
requires 'Plack::Middleware';
requires 'Plack::Request';
requires 'Plack::Response';
requires 'Digest::SHA';
requires 'MIME::Base64';
requires 'File::ShareDir', '1.00';
requires 'File::Spec';
requires 'parent';

on 'configure' => sub {
    requires 'ExtUtils::MakeMaker', '6.64';
    requires 'File::ShareDir::Install', '0.06';
};

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'HTTP::Request::Common';
    requires 'Plack::Test';
};

on 'develop' => sub {
    requires 'Test::Pod', '1.41';
    requires 'Test::Pod::Coverage', '1.08';
};
