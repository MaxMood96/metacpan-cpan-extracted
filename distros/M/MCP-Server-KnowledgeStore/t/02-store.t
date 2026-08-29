use v5.38;
use Test::Most;
use lib 't/lib';
use Test::StoreDouble qw(create_test_store);

# Use in-memory test double instead of requiring a live database
my $store = create_test_store;

subtest 'empty store' => sub {
  eq_or_diff $store->list('memory'), [], 'no memories yet';
  eq_or_diff $store->list('skill'),  [], 'no skills yet';
  is $store->get('memory', 'nope'), undef, 'missing memory is undef';
  eq_or_diff $store->history('memory', 'nope'), [], 'and has no history';
};

subtest 'save creates revision 1' => sub {
  my $entry = $store->save(
    'memory', 'user-background', "Comes from Perl.\n",
    type        => 'user',
    description => 'Where the user is coming from',
    author      => 'claude-code@machine-a',
  );

  is $entry->{name},        'user-background', 'name round-trips';
  is $entry->{type},        'user',            'type stored';
  is $entry->{description}, 'Where the user is coming from', 'description';
  is $entry->{revision},    1,                               'first revision';
  is $entry->{author},      'claude-code@machine-a',         'author recorded';
  is $entry->{body}, 'Comes from Perl.', 'body stored without frontmatter';

  # Frontmatter is rendered back from the columns, so a client sees the
  # same wire format the file-backed store produced.
  eq_or_diff [split /\n/, $entry->{content}],
    [
    '---',       'description: Where the user is coming from',
    'metadata:', '  type: user', 'name: user-background',
    '---',       '',             'Comes from Perl.',
    ],
    'frontmatter rendered from the columns';
};

subtest 'saving again appends a revision and moves the head' => sub {
  my $entry = $store->save(
    'memory',                          'user-background',
    "Comes from Perl, and says so.\n", author => 'other-agent'
  );

  is $entry->{revision}, 2,                               'head is revision 2';
  is $entry->{body},     'Comes from Perl, and says so.', 'new body';
  is $entry->{type},     'user', 'type inherited from the previous head';
  is $entry->{description}, 'Where the user is coming from',
    'description inherited too';

  my $old = $store->get('memory', 'user-background', 1);
  is $old->{body},   'Comes from Perl.',      'revision 1 still readable';
  is $old->{author}, 'claude-code@machine-a', 'with its own author';

  is scalar @{ $store->list('memory') }, 1, 'still one entry, not two';
};

subtest 'history reads newest first and marks the head' => sub {
  my $history = $store->history('memory', 'user-background');
  eq_or_diff [map { $_->{revision} } @$history], [2, 1], 'newest first';
  eq_or_diff [map { $_->{is_head} ? 1 : 0 } @$history], [1, 0],
    'only the newest is the head';
  eq_or_diff [map { $_->{author} } @$history],
    ['other-agent', 'claude-code@machine-a'], 'each revision keeps its author';
  ok $history->[0]{created_at}, 'and a timestamp';
};

subtest 'explicit metadata overrides the inherited value' => sub {
  my $entry = $store->save(
    'memory', 'user-background', 'Body.',
    type        => 'reference',
    description => 'Now a reference'
  );
  is $entry->{type},        'reference',       'type replaced';
  is $entry->{description}, 'Now a reference', 'description replaced';
  is $store->get('memory', 'user-background', 1)->{type}, 'user',
    'the old revision is untouched';
};

subtest 'frontmatter in the content is parsed into columns' => sub {
  my $entry
    = $store->save('memory', 'from-frontmatter', <<~'MD', type => 'project');
    ---
    name: from-frontmatter
    description: Came in as frontmatter
    project: knowledge-store
    ---

    The body.
    MD
  is $entry->{description}, 'Came in as frontmatter', 'description parsed out';
  eq_or_diff $entry->{projects}, ['knowledge-store'],
    'project parsed out of frontmatter as a tag';
  is $entry->{body}, 'The body.', 'body has no frontmatter left';
};

subtest 'list and project filter' => sub {
  my $all = $store->list('memory');
  eq_or_diff [map { $_->{name} } @$all],
    [qw(from-frontmatter user-background)],
    'sorted by name';

  my $filtered = $store->list('memory', 'Knowledge-Store');
  is scalar @$filtered,    1, 'project filter applies, case-insensitively';
  is $filtered->[0]{name}, 'from-frontmatter', '...to the right entry';
  eq_or_diff $store->list('memory', 'nosuch'), [], 'unknown project is empty';
};

subtest 'search' => sub {
  my $hits = $store->search('memory', 'the body');
  is scalar @$hits,    1,                  'case-insensitive body match';
  is $hits->[0]{name}, 'from-frontmatter', 'the right hit';
  eq_or_diff $hits->[0]{matches}, ['The body.'], 'matching line returned';

  eq_or_diff $store->search('memory', 'zzz'), [], 'no false hits';
  is scalar @{ $store->search('memory', 'reference') }, 1,
    'matches the description too';

  # Only the head is searched: an old revision's text must not resurface.
  eq_or_diff $store->search('memory', 'Comes from Perl'), [],
    'superseded content is not searchable';

  # A LIKE wildcard in the query is a literal, not a pattern.
  eq_or_diff $store->search('memory', '%'), [], 'percent matches nothing';
  eq_or_diff $store->search('memory', '_'), [], 'underscore matches nothing';

  throws_ok { $store->search('memory', '') } qr/query is required/,
    'empty query rejected';
};

subtest 'skills are a separate namespace' => sub {
  $store->save(
    'skill',                  'user-background',
    'A skill, not a memory.', description => 'Formatting'
  );
  my $skills = $store->list('skill');
  is scalar @$skills,    1,     'skill listed';
  is $skills->[0]{type}, undef, 'skills carry no type';
  is $store->get('skill', 'user-background')->{body},
    'A skill, not a memory.', 'same name, different kind';
  is $store->get('memory', 'user-background')->{body}, 'Body.',
    'the memory of that name is untouched';
};

subtest 'a memory needs a type' => sub {
  throws_ok { $store->save('memory', 'typeless', 'Body.') }
  qr/type is required/, 'refused without type';
  is $store->get('memory', 'typeless'), undef, 'and nothing was committed';
};

subtest 'bad names and kinds are refused' => sub {
  for my $bad ('../evil', '/etc/passwd', 'foo/bar', '.', '', 'a b', "x'; --") {
    throws_ok { $store->get('memory', $bad) }
    qr/invalid name|name is required/, "rejected name: '$bad'";
  }
  throws_ok { $store->list('notakind') } qr/invalid kind/, 'rejected kind';
};

done_testing;
