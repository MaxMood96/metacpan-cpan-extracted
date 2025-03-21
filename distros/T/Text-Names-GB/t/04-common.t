use warnings;
use strict;

use Test::More;
use Text::Names::GB qw/isCommonSurname isCommonFirstname guessGender firstnamePrevalence surnamePrevalence isLikelyMisparsed/;

ok(isCommonSurname('Smith'),'No threshold test, positive');
ok(isCommonSurname('Kennedy'),'No threshold test, positive');
ok(!isCommonSurname('Sdakljdslkafdjdfsa'),'No threshold test, negative');
ok(isCommonSurname('Smith',0.01),'Threshold test, positive');
ok(!isCommonSurname('Smith',5),'Threshold test, negative');
ok(isCommonFirstname('Mary'),'Firstname no threshold test, positive');
ok(isCommonFirstname('David'),'Firstname no threshold test, positive');
ok(!isCommonFirstname('Aklajldkfsjfd'),'Firstname no threshold test, negative');
ok(isCommonFirstname('Mary',0.5),'Firstname threshold test, positive');
ok(isCommonFirstname('John',1),'Firstname threshold test, positive');
ok(!isCommonFirstname('Mark',3),'Firstname threshold test, negative');
ok(guessGender('David') eq 'M');
ok(!defined(guessGender('lkjasdf')));
ok(guessGender('Mary') eq 'F');
ok(guessGender('Arthur') eq 'M');
ok(guessGender('William') eq 'M');
is(guessGender('Christian'), 'M');
is(guessGender('Arthur Flintstone'), 'M');
is(guessGender("Christian Loew"),"M");
is(guessGender('Natalia'), 'F');
is(guessGender('Ana'), 'F');
is(guessGender('Eleni'), 'F');
is(guessGender('Reece'), 'M');
ok(firstnamePrevalence('David') > 1);
ok(surnamePrevalence('Smith') > 1);
ok(firstnamePrevalence('Angela') > 0);
ok(surnamePrevalence('Bourvici') == 0);
ok(isLikelyMisparsed('Bourget, David John Richard Bill'));
ok(isLikelyMisparsed('Alexia, Smith'));
ok(!isLikelyMisparsed('Bourget, David'));
ok(isLikelyMisparsed('Bourget, David Dr'), 'Misparsed is likely misparsed');
ok(isLikelyMisparsed('Gilbert Daniel R.'));
ok(!isLikelyMisparsed('Smith, Daniel R.'));

done_testing();
