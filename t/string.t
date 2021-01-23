#!perl -wT

use strict;
use warnings;
use Test::Most tests => 16;
use Test::NoWarnings;

BEGIN {
	use_ok('Lingua::String');
}

STRING: {
	delete $ENV{'LANGUAGE'};
	$ENV{'LC_MESSAGES'} = 'en_GB';

	my $str = new_ok('Lingua::String');

	is($str->en('Hello'), 'Hello', 'Set English');

	is($str->as_string(), 'Hello', 'English');

	is($str->fr('Bonjour'), 'Bonjour', 'Set French');

	is($str->as_string(), 'Hello', 'English');
	is($str->fr(), 'Bonjour', 'French');

	is($str->as_string(), 'Hello', 'English');
	is($str->as_string(lang => 'fr'), 'Bonjour', 'French');
	is($str->as_string('fr'), 'Bonjour', 'French');
	is($str->as_string({ lang => 'es' }), undef, 'Spanish');

	is($str, 'Hello', 'calls as_string in English');
	$ENV{'LC_MESSAGES'} = 'fr_FR';
	is($str, 'Bonjour', 'calls as_string in French');
	$ENV{'LC_MESSAGES'} = 'en_GB';

	is($str->set(lang => 'en', string => 'Goodbye'), 'Goodbye', 'Set Goodbye');
	is($str->as_string(), 'Goodbye', 'Set works');
}
