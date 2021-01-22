package Lingua::String;

use strict;
use warnings;
use Carp;

=head1 NAME

Lingua::String - Class to contain a string in many different languages

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use overload (
        # '==' => \&equal,
        # '!=' => \&not_equal,
        '""' => \&as_string,
        bool => sub { 1 },
        fallback => 1   # So that boolean tests don't cause as_string to be called
);

=head1 SYNOPSIS

Hold many strings in one object.

    use Lingua::String;

    my $str = Lingua::String->new();

    $str->fr('Bonjour Tout le Monde');
    $str->en('Hello, World');

    $ENV{'LANG'} = 'en_GB';
    print "$str\n";	# Prints Hello, World
    $ENV{'LANG'} = 'fr_FR';
    print "$str\n";	# Prints Bonjour Tout le Monde
    $LANG{'LANG'} = 'de_DE';
    print "$str\n";	# Prints nothing

=cut

=head1 METHODS

=head2 new

Create a Lingua::String object.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	# Use Lingua::String->new, not Lingua::String::new
	return unless($class);

	return bless { }, $class;
}

=head2 set

Sets a string in a language.

    $str->set({ string => 'House', lang => 'en' });

Autoload will do this for you as

    $str->en('House');

=cut

sub set {
	my $self = shift;

	my %params;
	if(ref($_[0]) eq 'HASH') {
		%params = %{$_[0]};
	} elsif(scalar(@_) % 2 == 0) {
		%params = @_;
	} else {
		$params{'string'} = shift;
	}

	my $lang = $params{'lang'};

	if(!defined($lang)) {
		$lang ||= $self->_get_language();
		if(!defined($lang)) {
			Carp::croak(__PACKAGE__, ': usage: set(string => string, lang => $language)');
			return;
		}
	}

	my $string = $params{'string'};

	if(!defined($string)) {
		Carp::croak(__PACKAGE__, ': usage: set(string => string, lang => $language)');
		return;
	}

	$self->{$lang} = $string;

	return $self;
}

# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
# https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html
sub _get_language {
	if($ENV{'LANGUAGE'}) {
		if($ENV{'LANGUAGE'} =~ /^([a-z]{2})/i) {
			return lc($1);
		}
	}
	foreach my $variable('LC_ALL', 'LC_MESSAGES', 'LANG') {
		my $val = $ENV{$variable};
		next unless(defined($val));

		if($val =~ /^([a-z]{2})/i) {
			return lc($1);
		}
	}
}

=head2 as_string

Returns the string in the language requested in the parameter.
If that parameter is not given, the system language is used.

	print $string->as_string(), "\n";
	print $string->as_string('fr'), "\n";
	print $string->as_string({ lang => 'en' }), "\n";

=cut

sub as_string {
	my $self = shift;
	my %params;

	if(ref($_[0]) eq 'HASH') {
		%params = %{$_[0]};
	} elsif(scalar(@_) == 0) {
		# $params{'lang'} = $self->_get_language();
	} elsif(scalar(@_) % 2 == 0) {
		if(defined($_[0])) {
			%params = @_;
		}
	} else {
		$params{'lang'} = shift;
	}
	my $lang = $params{'lang'} || $self->_get_language();

	if(!defined($lang)) {
		Carp::croak(__PACKAGE__, ': usage: as_string(lang => $language)');
		return;
	}
	return $self->{$lang};
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my $key = $AUTOLOAD;

	$key =~ s/.*:://;

	return if($key eq 'DESTROY');

	my $self = shift;

	if(my $value = shift) {
		$self->{$key} = $value;
	}

	return $self->{$key};
}

=head1 AUTHOR

Nigel Horne, C<< <njh at bandsman.co.uk> >>

=head1 BUGS

=head1 SEE ALSO

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Lingua::String

You can also look for information at:

=over 4

=item * MetaCPAN

L<https://metacpan.org/release/Lingua-String>

=item * RT: CPAN's request tracker

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Lingua-String>

=item * CPANTS

L<http://cpants.cpanauthors.org/dist/Lingua-String>

=item * CPAN Testers' Matrix

L<http://matrix.cpantesters.org/?dist=Lingua-String>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Lingua-String>

=item * CPAN Testers Dependencies

L<http://deps.cpantesters.org/?module=Lingua-String>

=back

=head1 LICENCE AND COPYRIGHT

Copyright 2021 Nigel Horne.

This program is released under the following licence: GPL2

=cut

1;
