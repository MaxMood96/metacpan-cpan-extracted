#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use object;

# Test Role support (zero overhead)

# Define a role with slots
object::role('Serializable',
    'format:Str:default("json")',
);

# Add a method to the role
package Serializable;
sub serialize { 
    my ($self) = @_;
    return "serialized:" . $self->format; 
}
package main;

# Define a class
object::define('Document',
    'title:Str:required',
    'content:Str',
);

# Apply the role
object::with('Document', 'Serializable');

# Test 1: Class has role's slots
my $doc = Document->new(title => "Test");
ok($doc->can('format'), 'Document has format accessor from role');
is($doc->format, 'json', 'Default value from role slot works');

# Test 2: Class has role's methods
ok($doc->can('serialize'), 'Document has serialize method from role');
is($doc->serialize, 'serialized:json', 'Role method works');

# Test 3: object::does check
ok(object::does($doc, 'Serializable'), 'Object does Serializable');
ok(object::does('Document', 'Serializable'), 'Class does Serializable');
ok(!object::does($doc, 'NonExistent'), 'Object does not do NonExistent');

# Test 4: Role with required methods
object::role('Printable');
object::requires('Printable', 'to_string');

# Define class with required method
package PrintableDoc;
sub to_string { 
    my ($self) = @_;
    return $self->title; 
}
package main;

object::define('PrintableDoc', 'title:Str');
eval { object::with('PrintableDoc', 'Printable') };
ok(!$@, 'Class with required method consumes role OK');

# Test 5: Role without required method fails
object::define('BadDoc', 'title:Str');
eval { object::with('BadDoc', 'Printable') };
ok($@, 'Class without required method fails');
like($@, qr/does not implement required method 'to_string'/, 'Error mentions missing method');

# Test 6: Multiple roles
object::role('Timestamped',
    'created_at:Str',
    'updated_at:Str',
);

object::define('Article',
    'title:Str:required',
);
object::with('Article', 'Serializable', 'Timestamped');

my $article = Article->new(title => "News");
ok($article->can('format'), 'Article has Serializable slot');
ok($article->can('created_at'), 'Article has Timestamped slot');
ok(object::does($article, 'Serializable'), 'Article does Serializable');
ok(object::does($article, 'Timestamped'), 'Article does Timestamped');

# Test 7: Slot conflict detection
object::role('Conflicting',
    'title:Str',  # Same as Article's slot
);

eval { object::with('Article', 'Conflicting') };
ok($@, 'Slot conflict detected');
like($@, qr/Slot conflict.*'title'/, 'Error mentions conflicting slot');

done_testing();
