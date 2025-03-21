# NAME

Zing::Store::Sqlite - Sqlite Storage

# ABSTRACT

Sqlite Storage Abstraction

# SYNOPSIS

    use Test::DB::Sqlite;
    use Zing::Encoder::Dump;
    use Zing::Store::Sqlite;

    my $testdb = Test::DB::Sqlite->new;
    my $store = Zing::Store::Sqlite->new(
      client => $testdb->create->dbh,
      encoder => Zing::Encoder::Dump->new
    );

    # $store->drop;

# DESCRIPTION

This package provides a SQLite-specific storage adapter for use with data
persistence abstractions. The ["client"](#client) attribute accepts a [DBI](https://metacpan.org/pod/DBI) object
configured to connect to a [DBD::SQLite](https://metacpan.org/pod/DBD::SQLite) backend. The `ZING_DBNAME`
environment variable can be used to specify the database name (defaults to
"zing.db"). The `ZING_DBZONE` environment variable can be used to specify the
database table name (defaults to "entities").

# INHERITS

This package inherits behaviors from:

[Zing::Store](https://metacpan.org/pod/Zing::Store)

# LIBRARIES

This package uses type constraints from:

[Zing::Types](https://metacpan.org/pod/Zing::Types)

# ATTRIBUTES

This package has the following attributes:

## client

    client(InstanceOf["DBI::db"])

This attribute is read-only, accepts `(InstanceOf["DBI::db"])` values, and is optional.

# METHODS

This package implements the following methods:

## decode

    decode(Str $data) : HashRef

The decode method decodes the JSON data provided and returns the data as a hashref.

- decode example #1

        # given: synopsis

        $store->decode('{"status"=>"ok"}');

## drop

    drop(Str $key) : Int

The drop method removes (drops) the item from the datastore.

- drop example #1

        # given: synopsis

        $store->drop('zing:main:global:model:temp');

## encode

    encode(HashRef $data) : Str

The encode method encodes and returns the data provided as JSON.

- encode example #1

        # given: synopsis

        $store->encode({ status => 'ok' });

## keys

    keys(Str @keys) : ArrayRef[Str]

The keys method returns a list of keys under the namespace of the datastore or
provided key.

- keys example #1

        # given: synopsis

        my $keys = $store->keys('zing:main:global:model:temp');

- keys example #2

        # given: synopsis

        $store->send('zing:main:global:model:temp', { status => 'ok' });

        my $keys = $store->keys('zing:main:global:model:temp');

## lpull

    lpull(Str $key) : Maybe[HashRef]

The lpull method pops data off of the top of a list in the datastore.

- lpull example #1

        # given: synopsis

        $store->lpull('zing:main:global:model:items');

- lpull example #2

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

        $store->lpull('zing:main:global:model:items');

## lpush

    lpush(Str $key, HashRef $val) : Int

The lpush method pushed data onto the top of a list in the datastore.

- lpush example #1

        # given: synopsis

        $store->lpush('zing:main:global:model:items', { status => '1' });

- lpush example #2

        # given: synopsis

        $store->lpush('zing:main:global:model:items', { status => '0' });

        $store->lpush('zing:main:global:model:items', { status => '0' });

## recv

    recv(Str $key) : Maybe[HashRef]

The recv method fetches and returns data from the datastore by its key.

- recv example #1

        # given: synopsis

        $store->recv('zing:main:global:model:temp');

- recv example #2

        # given: synopsis

        $store->send('zing:main:global:model:temp', { status => 'ok' });

        $store->recv('zing:main:global:model:temp');

## rpull

    rpull(Str $key) : Maybe[HashRef]

The rpull method pops data off of the bottom of a list in the datastore.

- rpull example #1

        # given: synopsis

        $store->rpull('zing:main:global:model:items');

- rpull example #2

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 1 });
        $store->rpush('zing:main:global:model:items', { status => 2 });

        $store->rpull('zing:main:global:model:items');

## rpush

    rpush(Str $key, HashRef $val) : Int

The rpush method pushed data onto the bottom of a list in the datastore.

- rpush example #1

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

- rpush example #2

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

## send

    send(Str $key, HashRef $val) : Str

The send method commits data to the datastore with its key and returns truthy.

- send example #1

        # given: synopsis

        $store->send('zing:main:global:model:temp', { status => 'ok' });

## size

    size(Str $key) : Int

The size method returns the size of a list in the datastore.

- size example #1

        # given: synopsis

        my $size = $store->size('zing:main:global:model:items');

- size example #2

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

        my $size = $store->size('zing:main:global:model:items');

## slot

    slot(Str $key, Int $pos) : Maybe[HashRef]

The slot method returns the data from a list in the datastore by its index.

- slot example #1

        # given: synopsis

        my $model = $store->slot('zing:main:global:model:items', 0);

- slot example #2

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

        my $model = $store->slot('zing:main:global:model:items', 0);

## test

    test(Str $key) : Int

The test method returns truthy if the specific key (or datastore) exists.

- test example #1

        # given: synopsis

        $store->rpush('zing:main:global:model:items', { status => 'ok' });

        $store->test('zing:main:global:model:items');

- test example #2

        # given: synopsis

        $store->drop('zing:main:global:model:items');

        $store->test('zing:main:global:model:items');

# AUTHOR

Al Newkirk, `awncorp@cpan.org`

# LICENSE

Copyright (C) 2011-2019, Al Newkirk, et al.

This is free software; you can redistribute it and/or modify it under the terms
of the The Apache License, Version 2.0, as elucidated in the ["license
file"](https://github.com/iamalnewkirk/zing-store-redis/blob/master/LICENSE).

# PROJECT

[Wiki](https://github.com/iamalnewkirk/zing-store-redis/wiki)

[Project](https://github.com/iamalnewkirk/zing-store-redis)

[Initiatives](https://github.com/iamalnewkirk/zing-store-redis/projects)

[Milestones](https://github.com/iamalnewkirk/zing-store-redis/milestones)

[Contributing](https://github.com/iamalnewkirk/zing-store-redis/blob/master/CONTRIBUTE.md)

[Issues](https://github.com/iamalnewkirk/zing-store-redis/issues)
