#!perl
use strict;
use warnings;

use Test::More;

BEGIN {
  use_ok('Hash::Util::Join::PP', qw[ hash_partition
                                     hash_partition_by ]);
}

subtest 'Test hash_partition', sub {
  
  # Basic binary partition
  {
    my %data = (
      a => 1,
      b => 2,
      c => 3,
      d => 4,
      e => 5,
    );
    
    my ($even, $odd) = hash_partition %data, sub {
      my ($k, $v) = @_;
      return $v % 2 == 0;
    };
    
    is_deeply($even, { b => 2, d => 4 }, 'even values');
    is_deeply($odd,  { a => 1, c => 3, e => 5 }, 'odd values');
  }
  
  # Empty hash
  {
    my %empty;
    my ($true, $false) = hash_partition %empty, sub { 1 };
    
    is_deeply($true,  {}, 'empty hash - true partition');
    is_deeply($false, {}, 'empty hash - false partition');
  }
  
  # All true
  {
    my %data = (a => 1, b => 2, c => 3);
    my ($true, $false) = hash_partition %data, sub { 1 };
    
    is_deeply($true,  { a => 1, b => 2, c => 3 }, 'all true - true partition');
    is_deeply($false, {}, 'all true - false partition');
  }
  
  # All false
  {
    my %data = (a => 1, b => 2, c => 3);
    my ($true, $false) = hash_partition %data, sub { 0 };
    
    is_deeply($true,  {}, 'all false - true partition');
    is_deeply($false, { a => 1, b => 2, c => 3 }, 'all false - false partition');
  }
  
  # Partition by key
  {
    my %data = (
      apple  => 1,
      apricot => 2,
      banana => 3,
      cherry => 4,
    );
    
    my ($true, $false) = hash_partition %data, sub {
      my ($k, $v) = @_;
      return $k =~ /^a/;
    };
    
    is_deeply($true, { apple => 1, apricot => 2 }, 'keys starting with a');
    is_deeply($false, { banana => 3, cherry => 4 }, 'other keys');
  }
  
  # Partition with undef values
  {
    my %data = (
      a => 1,
      b => undef,
      c => 0,
      d => '',
    );
    
    my ($defined, $undefined) = hash_partition %data, sub {
      my ($k, $v) = @_;
      return defined $v;
    };
    
    is_deeply($defined, { a => 1, c => 0, d => '' }, 'defined values');
    is_deeply($undefined, { b => undef }, 'undefined values');
  }
  
  # Partition with nested structures
  {
    my %data = (
      1 => { name => 'Alice', active => 1 },
      2 => { name => 'Bob',   active => 0 },
      3 => { name => 'Carol', active => 1 },
    );
    
    my ($active, $inactive) = hash_partition %data, sub {
      my ($k, $v) = @_;
      return $v->{active};
    };
    
    is_deeply($active, {
      1 => { name => 'Alice', active => 1 },
      3 => { name => 'Carol', active => 1 },
    }, 'active users');
    
    is_deeply($inactive, {
      2 => { name => 'Bob', active => 0 },
    }, 'inactive users');
  }
  
  # Predicate receives both key and value
  {
    my %data = (x => 10, y => 20);
    my @calls;
    
    hash_partition %data, sub {
      push @calls, [@_];
      return 1;
    };
    
    is(scalar(@calls), 2, 'predicate called twice');
    is(scalar(@{$calls[0]}), 2, 'predicate receives 2 arguments');
  }
};

subtest 'Test hash_partition_by' => sub {
  
  # Scalar context returns hashref
  {
    my %data = (a => 1, b => 2);
    my $result = hash_partition_by %data, sub {
      return $_[1] % 2 == 0 ? 'even' : 'odd';
    };
    
    is(ref($result), 'HASH', 'scalar context returns hashref');
    is_deeply($result, {
      odd  => { a => 1 },
      even => { b => 2 },
    }, 'scalar context result correct');
  }
  
  # List context returns hash
  {
    my %data = (a => 1, b => 2);
    my %result = hash_partition_by %data, sub {
      return $_[1] % 2 == 0 ? 'even' : 'odd';
    };
    
    is_deeply(\%result, {
      odd  => { a => 1 },
      even => { b => 2 },
    }, 'list context result correct');
  }
  
  # Basic grouping
  {
    my %data = (
      1 => { name => 'Alice', dept => 'Eng' },
      2 => { name => 'Bob',   dept => 'Sales' },
      3 => { name => 'Carol', dept => 'Eng' },
      4 => { name => 'Dave',  dept => 'Sales' },
    );
    
    my %by_dept = hash_partition_by %data, sub {
      my ($k, $v) = @_;
      return $v->{dept};
    };
    
    is_deeply(\%by_dept, {
      Eng => {
        1 => { name => 'Alice', dept => 'Eng' },
        3 => { name => 'Carol', dept => 'Eng' },
      },
      Sales => {
        2 => { name => 'Bob',   dept => 'Sales' },
        4 => { name => 'Dave',  dept => 'Sales' },
      },
    }, 'group by department');
  }
  
  # Empty hash
  {
    my %empty;
    my %result = hash_partition_by %empty, sub { 'bucket' };
    
    is_deeply(\%result, {}, 'empty hash returns empty result');
  }
  
  # All to same bucket
  {
    my %data = (a => 1, b => 2, c => 3);
    my %result = hash_partition_by %data, sub { 'same' };
    
    is_deeply(\%result, {
      same => { a => 1, b => 2, c => 3 }
    }, 'all items in same bucket');
  }
  
  # Multiple buckets
  {
    my %data = (
      a => 1,
      b => 5,
      c => 10,
      d => 15,
      e => 25,
    );
    
    my %by_range = hash_partition_by %data, sub {
      my ($k, $v) = @_;
      return $v < 10  ? 'low'
           : $v < 20  ? 'mid'
           : 'high';
    };
    
    is_deeply(\%by_range, {
      low  => { a => 1, b => 5 },
      mid  => { c => 10, d => 15 },
      high => { e => 25 },
    }, 'partition by numeric ranges');
  }
  
  # Skipping entries (undef bucket)
  {
    my %data = (
      a => 1,
      b => 2,
      c => 3,
      d => 4,
    );
    
    my %result = hash_partition_by %data, sub {
      my ($k, $v) = @_;
      return undef if $v % 2 == 0;
      return 'odd';
    };
    
    is_deeply(\%result, {
      odd => { a => 1, c => 3 }
    }, 'undef bucket skips entries');
  }
  
  # Group by key pattern
  {
    my %data = (
      user_1  => 'Alice',
      user_2  => 'Bob',
      admin_1 => 'Carol',
      admin_2 => 'Dave',
    );
    
    my %by_type = hash_partition_by %data, sub {
      my ($k, $v) = @_;
      return $k =~ /^user/ ? 'user' : 'admin';
    };
    
    is_deeply(\%by_type, {
      user => {
        user_1 => 'Alice',
        user_2 => 'Bob',
      },
      admin => {
        admin_1 => 'Carol',
        admin_2 => 'Dave',
      },
    }, 'group by key pattern');
  }
  
  # Numeric bucket names
  {
    my %data = (a => 1, b => 2, c => 3);
    my %result = hash_partition_by %data, sub { $_[1] };
    
    is_deeply(\%result, {
      1 => { a => 1 },
      2 => { b => 2 },
      3 => { c => 3 },
    }, 'numeric bucket names work');
  }
  
  # Empty string bucket name
  {
    my %data = (a => 1, b => 2);
    my %result = hash_partition_by %data, sub { '' };
    
    is_deeply(\%result, {
      '' => { a => 1, b => 2 }
    }, 'empty string bucket name works');
  }

  # Classifier receives both key and value
  {
    my %data = (x => 10);
    my @calls;
    
    hash_partition_by %data, sub {
      push @calls, [@_];
      return 'bucket';
    };
    
    is(scalar(@calls), 1, 'classifier called once');
    is(scalar(@{$calls[0]}), 2, 'classifier receives 2 arguments');
    is($calls[0][0], 'x', 'first argument is key');
    is($calls[0][1], 10, 'second argument is value');
  }
  
  # Complex nested values
  {
    my %data = (
      1 => { name => 'Alice', tags => ['admin', 'user'] },
      2 => { name => 'Bob',   tags => ['user'] },
      3 => { name => 'Carol', tags => ['admin', 'super'] },
    );

    my %by_admin = hash_partition_by %data, sub {
      my ($k, $v) = @_;
      my $has_admin_tag = grep { $_ eq 'admin' } @{$v->{tags}};
      return $has_admin_tag ? 'admin' : 'user';
    };

    is_deeply(\%by_admin, {
      admin => {
        1 => { name => 'Alice', tags => ['admin', 'user'] },
        3 => { name => 'Carol', tags => ['admin', 'super'] },
      },
      user => {
        2 => { name => 'Bob', tags => ['user'] },
      },
    }, 'complex nested value grouping');
  }
};

subtest 'edge cases' => sub {
    
  # Single element
  {
    my %data = (a => 1);
    
    my ($t, $f) = hash_partition %data, sub { 1 };
    is_deeply($t, { a => 1 }, 'single element - true');
    is_deeply($f, {}, 'single element - false part empty');
    
    my %result = hash_partition_by %data, sub { 'bucket' };
    is_deeply(\%result, { bucket => { a => 1 } }, 'single element grouping');
  }
  
  # Large number of buckets
  {
    my %data = map { $_ => $_ } 1..100;
    my %result = hash_partition_by %data, sub { $_[1] };
    
    is(scalar(keys %result), 100, '100 different buckets');
    is(scalar(keys %{$result{50}}), 1, 'each bucket has one item');
  }
  
  # Zero as bucket name
  {
    my %data = (a => 1, b => 2);
    my %result = hash_partition_by %data, sub { 0 };
    
    is_deeply(\%result, {
        0 => { a => 1, b => 2 }
    }, 'zero as bucket name works');
  }
  
  # Predicate/classifier returns various falsy values
  {
    my %data = (a => 1, b => 2, c => 3, d => 4);
    my $i = 0;
    my %result = hash_partition_by %data, sub {
        return (0, '', undef, '0')[$i++ % 4];
    };
    
    ok(exists $result{0}, 'bucket "0" exists');
    ok(exists $result{''}, 'bucket "" exists');
    ok(!exists $result{undef}, 'undef bucket skipped');
    ok(exists $result{'0'}, 'bucket "0" (string) exists');
  }
};

subtest 'error conditions' => sub {
    
  # Predicate dies
  {
    my %data = (a => 1, b => 2);
    eval {
      hash_partition %data, sub { die "error" };
    };
    like($@, qr/error/, 'predicate death propagates');
  }
  
  # Classifier dies
  {
    my %data = (a => 1);
    eval {
      hash_partition_by %data, sub { die "classifier error" };
    };
    like($@, qr/classifier error/, 'classifier death propagates');
  }
};

done_testing;
