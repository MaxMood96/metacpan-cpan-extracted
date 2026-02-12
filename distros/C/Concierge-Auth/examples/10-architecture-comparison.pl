#!/usr/bin/env perl

use v5.40;
use strict;
use warnings;
use lib '../../';

# Demonstrates the architectural differences before and after refactoring

use Concierge::Auth;
use Concierge::Auth::Generators qw(gen_uuid gen_random_token);

say "=" x 70;
say "Architecture Comparison: Before vs After Refactoring";
say "=" x 70;
say "";

say "BEFORE (v0.17.0): Generators embedded in Auth.pm";
say "-" x 70;
say "";
say "Limitations:";
say "  • Generators were object methods in Auth.pm";
say "  • Required Auth object even for utility-only usage";
say "  • Tight coupling between auth logic and utilities";
say "  • Difficult to use generators independently";
say "  • Not easily extensible for alternative implementations";
say "";
say "Usage:";
say "  my \$auth = Concierge::Auth->new({no_file => 1});";
say "  my \$uuid = \$auth->gen_uuid();  # Required object for simple utility";
say "";

say "=" x 70;
say "";

say "AFTER (v0.18.0): Generators in separate module";
say "-" x 70;
say "";
say "Benefits:";
say "  • Generators are plain subroutines in Generators.pm";
say "  • Can be used directly without Auth object";
say "  • Clear separation: auth logic vs utilities";
say "  • Independent usage via Exporter";
say "  • Ready for plugin architecture";
say "";
say "Usage Options:";
say "";
say "1. Direct functional usage (NEW):";
say "   use Concierge::Auth::Generators qw(gen_uuid);";
say "   my \$uuid = gen_uuid();  # No object needed!";
say "";
say "2. Via Auth object (works as before):";
say "   my \$auth = Concierge::Auth->new({file => \$path});";
say "   my \$uuid = \$auth->gen_uuid();  # Still works";
say "";

say "=" x 70;
say "";

say "PRACTICAL EXAMPLE: File naming utility";
say "-" x 70;
say "";

say "Scenario: Generate unique filenames without authentication";
say "";

say "BEFORE: Had to create unnecessary Auth object";
say "";
say "  use Concierge::Auth;";
say "  my \$auth = Concierge::Auth->new({no_file => 1});  # Unnecessary overhead";
say "  my \$filename = \$auth->gen_uuid() . '.txt';";
say "";
say "  Result: Created Auth object just to call gen_uuid()";
say "";

say "AFTER: Use generator directly";
say "";
say "  use Concierge::Auth::Generators qw(gen_uuid);";
say "  my \$filename = gen_uuid() . '.txt';";
say "";
say "  Result: Direct function call, no object overhead";
say "";

say "=" x 70;
say "";

say "PRACTICAL EXAMPLE: Token generation for API";
say "-" x 70;
say "";

say "Scenario: Generate API token within authenticated app";
say "";

say "BEFORE: Mixed concerns in Auth object";
say "";
say "  my \$auth = Concierge::Auth->new({file => '/app/auth.dat'});";
say "  # Authentication methods and generators in same object";
say "  my \$token = \$auth->gen_random_token(32);";
say "";
say "  Result: No separation between auth logic and utilities";
say "";

say "AFTER: Clear separation, same convenience";
say "";
say "  my \$auth = Concierge::Auth->new({file => '/app/auth.dat'});";
say "  # Auth object handles authentication";
say "  my \$token = \$auth->gen_random_token(32);  # Works as before";
say "";
say "  OR use directly:";
say "  use Concierge::Auth::Generators qw(gen_random_token);";
say "  my \$token = gen_random_token(32);  # Simpler if no auth needed";
say "";
say "  Result: Flexible - use OO or functional as needed";
say "";

say "=" x 70;
say "";

say "TECHNICAL IMPROVEMENTS";
say "-" x 70;
say "";
say "1. Module size reduction:";
say "   Auth.pm: ~510 lines → ~470 lines (40 lines moved to Generators.pm)";
say "";
say "2. Dependency management:";
say "   Time::HiRes and Crypt::PRNG now only in Generators.pm";
say "";
say "3. Error handling:";
say "   Generators use g_success/g_error (no fatal errors)";
say "   Auth wrappers use reply/reject for consistency";
say "";
say "4. Inheritance pattern:";
say "   Auth.pm uses 'use parent' but wraps inherited functions";
say "   Provides consistent response pattern across all methods";
say "";
say "5. Testing:";
say "   Separate test file for generators (07-generators.t)";
say "   29 new tests, all 71 tests passing";
say "";

say "=" x 70;
say "";

say "BACKWARDS COMPATIBILITY";
say "-" x 70;
say "";
say "✓ All existing code works unchanged";
say "✓ Same API through Auth object methods";
say "✓ Same return behavior (scalar/list context)";
say "✓ No breaking changes to any method signatures";
say "";
say "Plus new capabilities:";
say "✓ Direct functional usage without objects";
say "✓ Exportable functions for functional programming";
say "✓ Cleaner separation of concerns";
say "";

say "=" x 70;
say "Conclusion: Cleaner architecture with full backwards compatibility";
say "=" x 70;
