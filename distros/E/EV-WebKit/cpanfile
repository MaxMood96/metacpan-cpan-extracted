requires 'perl', '5.010';
requires 'EV';
requires 'EV::Glib';
requires 'Glib';
requires 'Glib::Object::Introspection';
requires 'Glib::IO';
requires 'Cpanel::JSON::XS';
requires 'File::ShareDir';

recommends 'Proxy::Impersonate', '0.01';

on configure => sub { requires 'File::ShareDir::Install'; };
on test      => sub { requires 'Test::More'; };
