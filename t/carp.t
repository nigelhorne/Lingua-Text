#!perl -wT

use strict;
use warnings;
use Test::Carp;
use Test::Most tests => 4;

BEGIN {
	use_ok('Lingua::String');
}

CARP: {
	does_carp_that_matches(sub { Lingua::String->new('foo') }, qr/usage/);

	my $str = new_ok('Lingua::String');

	does_carp_that_matches(sub { $str->set() }, qr/usage/);
}
