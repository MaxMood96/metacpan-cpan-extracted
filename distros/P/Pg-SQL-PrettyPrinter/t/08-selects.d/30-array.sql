SELECT ARRAY[ 1, 2, 3 ], ARRAY[ 'a', NULL, 'c' ]::text[], format( '%s, %s', VARIADIC ARRAY[ 1, 2 ] ), format( '%s, %s', ARRAY[ 1, 2 ], 'a' )
