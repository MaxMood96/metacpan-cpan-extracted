# NAME

Plack::Middleware::DirListing - Display a listing of a directory in html

# SYNOPSIS

```perl
use Plack::Builder;
use Plack::App::File;

my $app = Plack::App::File->new({ root => '.' })->to_app;

builder {
      enable "DirListing", root => '.';
      $app;
}
```

# DESCRIPTION

This Plack middleware provides the same functionality as [Plack::App::Directory](https://metacpan.org/pod/Plack%3A%3AApp%3A%3ADirectory), but \*only\* serves the directory listing if the URL points to a directory. It does not try to serve any files.

It also strives to have a cleaner UI that more closely matches a prettified version of the Apache web server's output.

This modules does not attempt to find a default html file for the directory. If desired, include [Plack::Middleware::DirIndex::Htaccess](https://metacpan.org/pod/Plack%3A%3AMiddleware%3A%3ADirIndex%3A%3AHtaccess) or [Plack::Middleware::DirIndex](https://metacpan.org/pod/Plack%3A%3AMiddleware%3A%3ADirIndex) before this module.

# CONFIGURATION

- root

    Document root directory. Defaults to the current directory.

# AUTHOR

Keith Carangelo <kcaran@gmail.com>
