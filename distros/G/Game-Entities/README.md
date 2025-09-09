# NAME

Game::Entities - A simple entity registry for ECS designs

# SYNOPSIS

    my $ECS = Game::Entities->new;

    # Create an entity with a possibly empty set of components
    $guid = $ECS->create(
        Collidable->new,
        Drawable->new,
        Consumable->new,
    );

    # CRUD operations on an entity's components
    $ECS->add( $guid => Equipable->new );      # It is now equipable
    $ECS->delete( $guid => 'Consumable' );     # It is no longer consumable
    $item = $ECS->get( $guid => 'Equipable' );

    # A system operates on sets of entities defined by a view
    $view = $ECS->view(qw( Drawable Equipable ));

    # You can iterate over the set with a callback
    # The callback will get the GUID and the components in the order requested
    $view->each( sub ( $guid, $draw, $item ) {
        draw_equipment( $draw, $item );
    });

    # Or you can do the same iterating over the components
    for ( $view->components ) {
        my ( $draw, $item ) = @$_;
        draw_equipment( $draw, $item );
    }

    # Or over the entity GUIDs
    for my $guid ( $view->entities ) {
        my ( $draw, $item ) = $ECS->get( $guid => qw( Drawable Equipable ) );
        draw_equipment( $draw, $item );
    }

    # Or you can iterate over the view directly and get both
    for ( @{ $view } ) {
        my ( $guid, $draw, $item ) = ( $_->[0], @{ $_->[1] } );

        if ( $ECS->get( $guid => 'Consumable' ) ) {
            say 'This is equipment you can eat!';
        }

        ...
    }

    # Delete the entity and all its components
    $ECS->delete($guid);

    # Delete all entities and components
    $ECS->clear;

# DESCRIPTION

Game::Entities is a minimalistic entity manager designed for applications
using an ECS architecture.

If you don't know what this means, Mick West's
[Evolve Your Hierarchy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy)
might be a good place to start.

## On Stability

This distribution is currently **experimental**, and as such, its API might
still change without warning. Any change, breaking or not, will be noted in
the change log, so if you wish to use it, please pin your dependencies and
make sure to check the change log before upgrading.

# CONCEPTS

Throughout this documentation, there are a couple of key concepts that will
be used repeatedly:

## GUID

Entities are represented by an opaque global unique identifier: a GUID. GUIDs
used by Game::Entities are opaque to the user, and represent a particular
version of an entity which will remain valid as long as that entity is not
deleted (with [delete](#delete) or [clear](#clear)).

Each Game::Entities registry supports up to 1,048,575 (2^20 - 1) simultaneous
valid entity GUIDs. As of version 0.005 they are guaranteed to always be truthy
values.

## Valid entities

An entity's GUID is valid from the time it is created with [create](#create)
until the time it is deleted. An entity's GUID can be stored and used as an
identifier anywhere in the program at any point during this time, but must not
be used outside it.

## Components

As far as Game::Entities is concerned, any reference of any type can be used
as a component and added to an entity. This includes blessed and non-blessed
references.

Entities can have any number of components attached to them, but they will
only ever have one component of any one type (as identified by
[ref](https://perldoc.perl.org/functions/ref)).

## Views

A group of components defines a view, which includes all the entities that
have all of that view's components. Given a view for components `A`, `B`,
and `C`, all components in it will have _at least_ those three components,
but could of course have any others as well.

The main purpose of views is to make it possible to iterate as fast as
possible over any group of entities that have a set of common components.

# METHODS

## new

    $ECS = Game::Entities->new;

Creates a new entity registry. The constructor takes the following arguments:

- prefix

    _Since version 0.101_

    If set to a true value, this will be prepended to any component name that
    starts with a single colon (`:`). This will only affect methods that accept
    component names, that is ["check"](#check), ["delete"](#delete), ["view"](#view), and ["get"](#get).

    This can be used to reduce the repetition when using multiple components that
    share a base namespace:

        $ECS = Game::Entities->new( prefix => 'Local' );

        my $guid = $ECS->create( Local::Renderable->new );

        $ECS->check( $guid => 'Renderable' );        # False: no leading colon
        $ECS->check( $guid => 'Local::Renderable' ); # True: uses full name
        $ECS->check( $guid => ':Renderable' );       # True: uses the prefix

    Note that the prefix should not have any trailing colons: these will be added
    automatically.

## create

    $guid = $ECS->create(@components)

Creates a new entity and returns its GUID. If called with a list of components,
these will be added to the entity before returning.

## add

    $ECS = $ECS->add( $guid, @components );

Takes an entity's GUID and a component, and adds that component to the
specified entity. If the entity already had a component of that type, calling
this method will silently overwrite it.

Multiple components can be specified, and they will all be added in the order
they were provided.

Starting from version 0.101 this method returns the invokant, so it supports
chaining.

## get

    $component  = $ECS->get( $guid, $component_name );
    @components = $ECS->get( $guid, @component_names );

Takes an entity's GUID and the name of a component as a string, and retrieves
the component with that name for the specified entity, if it exists. If the
entity has no component by that name, this method returns undefined instead.

Multiple components names can be specified, and they will all be retrieved and
returned in the order they were provided.

When called with a single target component name, this method returns a scalar.
When called with a list of components names, it will return a list.

## delete

    $ECS = $ECS->delete( $guid );
    $ECS = $ECS->delete( $guid, @component_names );

When called with only an entity's GUID, it deletes all components from the
entity, and marks that entity's GUID as invalid.

When called with one or more additional component names,the components by
those names will be removed from the specified entity in the order provided.
Deleting a component from an entity is an idempotent process.

Starting from version 0.101 this method returns the invokant, so it supports
chaining.

## check

    $bool = $ECS->check( $guid => $component_name );

Takes an entity's GUID and a component name and returns a truthy value if the
specified entity has a component by that name, or a falsy value otherwise.

## valid

    $bool = $ECS->valid($guid);

Takes an entity's GUID and returns a truthy value if the specified entity is
valid, or a falsy value otherwise. An entity is valid if it has been created
and not yet deleted.

## created

    $count = $ECS->created;

Returns the number of entities that have been created. Calling [clear](#clear)
resets this number.

## alive

    $count = $ECS->alive;

Returns the number of created entities that are still valid. That is:
entities that have been created and not yet deleted.

## clear

    $ECS = $ECS->clear;

Resets the internal storage of the registry. Calling this method leaves no
trace from the previous state.

Starting from version 0.101 this method returns the invokant, so it supports
chaining.

## sort

    $ECS = $ECS->sort( $component_name => $parent_name );
    $ECS = $ECS->sort( $component_name => sub { $a ... $b } );
    $ECS = $ECS->sort( $component_name => sub ($$) { $_[0] ... $_[1] } );

_Since version 0.006, with support for prototypes since 0.011_

Under normal circumstances, the order in which a particular set of components
is stored is not guaranteed, and will depend entirely on the additions and
deletions of that component type.

However, it will sometimes be useful to impose an order on a component set.
This will be the case for example when renderable components need to be drawn
back to front, etc.

This function accommodates this use case.

Given a single component name, and a code reference to a comparator function,
the specified component will be sorted accordingly. The comparator function
behaves just like the one used for the regular
[sort](https://perldoc.perl.org/functions/sort), accessing the two components
being compared via the `$a` and `$b` variables, or as the first two values
in `@_` if the comparator has the a prototype equal to `$$`.

Alternatively, if given the name of another component (`B`) instead of a
comparator function, the order of the first component (`A`) will follow that
of the `B`. After this, iterating over the entities that have `A` will
return

- all of the entities that also have `B`, according to the order in `B`
- all of the entities that _do not_ have `B`, in no particular order

Sorting a component pool invalidates any cached views that use that component.

The imposed order for this component is guaranteed to be stable as long as no
components of this type are added or removed.

Starting from version 0.101 this method returns the invokant, so it supports
chaining.

## view

    $view = $ECS->view;
    $view = $ECS->view(@component_names);

Takes a set of one or more component names, and returns an internal object
representing a _view_ for that specific set of components. The order of
entities in a view can be set with [sort](#sort) (see above for details). If
no order has been set, then entities in the view are in no specific order.

A view generated with no components will include all entities that were valid
at the moment it was created.

Once a view has been created, it will remain valid as long as none of the
components in the view's set are added or deleted from any entity. Once this
is done, the data returned by the view object is no longer guaranteed to be
accurate. For this reason, it is not recommended to keep hold of view objects
for longer than it takes to run an iteration.

The view object can be used as an array reference to iterate over the pair
of entity GUIDs and component sets. When used in this way, each value will
be an array reference holding the GUID as the first value, and a nested array
reference with the list of components as the second value.

    for my $pair ( $ECS->view(@component_names)->@* ) {
        my ( $guid, @components ) = ( $pair->[0], $pair->[1]->@* );
        # Do something with the data
    }

The pairs returned when used in this way are returned by calling `pairs` in
[List::Util](https://metacpan.org/pod/List%3A%3AUtil#pairs).

Apart from this, the interface for the view object is documented below:

### each

    $view->each( sub ( $guid, @components ) { ... } );

Takes a code reference which will be called once per entity in the view.

The code reference will be called with the GUID for the current entity as the
first parameter, and the components in the requested set in the
order they were specified.

If the view was created with no components (in other words, if it's a view
of all entities), the list of components passed to the code reference will be
empty.

Within the callback, it is safe to add or delete entities, as well as to add
or remove components from those entities.

### first

    my ( $guid, @comps ) = $view->first( sub ( $guid, @comps ) { ... } );
    my ( $guid, @comps ) = $view->first;

_Since version 0.009, with no coderef since 0.102_

This function is similar to [each](#each), with the difference that iteration
through the view will stop early the first time the provided coderef returns a
true value. If no coderef is provided, the match will be the first element in
the view (it's equivalent to `sub { 1 }`).

If the coderef ever returns true, a flat list with the GUID and the components
in the view will be returned. If it never returns true, this method will
return an empty list.

This function is equivalent to the following code

    my ( $guid, @comps )
        = map { ( $_[0], @{ $_[1] } ) }
        List::Util::first { $coderef->( $_[0], @{ $_[1] } ) } @{ $view };

### entities

    @guids = $view->entities;

Returns a list of only the GUIDs of the entities in this view.

### components

    @components = $view->components;

Returns a list of array references, each of which will hold the list of
components for a single entity in the view. The components will be in the
order provided when the view was created.

Useful for iterating like

    for ( $ECS->view(qw( A B C )) )->components ) {
        my ( $a, $b, $c ) = @$_;
        ...
    }

# PERFORMANCE

Game::Entities aims to implement a simple entity registry that is as fast as
possible. Specifically, this means that it needs to be fast enough to be used
in game development, which is the natural use case for ECS designs.

To this end, the library caches component iterators which are invalidated
every time one of the components relevant to that iterator is either added
or removed from any entity. This should make the common case of systems
operating over sets of components that tend to be relatively stable
(eg. across game frames) as fast as possible.

The distribution includes two tests in its extended suite to test the
performance with iterations over large number of entities
(`xt/short-loops.t`), and many iterations over small numbers of entities
(`xt/long-loops.t`). Please refer to these files for accurate estimations.

# SEE ALSO

- [EnTT](https://skypjack.github.io/entt)

    Much of the design and API of this distribution is based on that of the
    entity registry in EnTT (famously used in Minecraft). A significant part
    of the credit for the algorithms and data structures used by Game::Entities
    falls on the EnTT developers and [the blog posts](https://skypjack.github.io)
    they've made to explain how they work.

# COPYRIGHT AND LICENSE

Copyright 2021 José Joaquín Atria

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.
