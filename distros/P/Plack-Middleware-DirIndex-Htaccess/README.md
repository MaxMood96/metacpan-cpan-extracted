# NAME

Plack::Middleware::DirIndex::Htaccess - Serve default html files for directory URLS. Includes checking of .htaccess file for DirectoryIndex.

# SYNOPSIS

```perl
use Plack::Builder;
use Plack::App::Directory;

my $app = Plack::App::Directory->new()->to_app;

builder {
    enable "DirIndex::Htaccess", root => '.', dir_index => 'index.html';
    $app;
};
```

# DESCRIPTION

The Apache web server uses the `DirectoryIndex` directive within
`.htaccess` files to automatically serve a default page
(e.g., `about.html` when a user requests a directory URL like `/about/`).

This Plack middleware provides a lightweight simulation of
Apache's DirectoryIndex functionality for your local Plack environment.
By reading the `DirectoryIndex` from your existing `.htaccess` files,
it ensures that requests to directories resolve to the correct default
file, just as they would on the live server.

If there is no c<DirectoryIndex> directive (or `.htaccess` file), the module will append the value of &lt;dir\_index> (defaults to `index.html`) if the file exists, like Plack::Middleware::DirIndex.

# AUTHOR

Keith Carangelo <kcaran@gmail.com>
