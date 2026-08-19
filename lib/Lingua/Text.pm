package Lingua::Text;

use strict;
use warnings;
use autodie qw(:all);

use Carp;
use HTML::Entities;
use Object::Configure;
use Params::Get;
use Scalar::Util qw(blessed);
use I18N::LangTags::Detect;

# TODO: Investigate Locale::Maketext

=head1 NAME

Lingua::Text - Class to contain text in many different languages

=head1 VERSION

Version 0.08

=cut

our $VERSION = '0.08';
our $AUTOLOAD;

use overload (
	'""' => \&as_string,
	bool => sub { 1 },
	fallback => 1	# So that boolean tests don't cause as_string to be called
);

=head1 SYNOPSIS

Hold many texts in one object,
thereby encapsulating internationalized text.

    use Lingua::Text;

    my $str = Lingua::Text->new();

    $str->fr('Bonjour Tout le Monde');
    $str->en('Hello, World');

    $ENV{'LANG'} = 'en_GB';
    print "$str\n";	# Prints Hello, World
    $ENV{'LANG'} = 'fr_FR';
    print "$str\n";	# Prints Bonjour Tout le Monde
    $ENV{'LANG'} = 'de_DE';
    print "$str\n";	# Prints nothing

    my $text = Lingua::Text->new('hello');	# Initialises the 'current' language

=cut

=head1 METHODS

=head2 new

Create a Lingua::Text object.

    use Lingua::Text;

    my $str = Lingua::Text->new({ 'en' => 'Here', 'fr' => 'Ici' });

Accepts various input formats, e.g., HASH or reference to a HASH.
Clones existing objects with or without modifications.
Uses Carp::carp to log warnings for incorrect usage or potential mistakes.

=cut

sub new {
	my $class = shift;

	my $params;
	if((scalar(@_) == 1) && (!ref($_[0])) && (my $lang = _get_language())) {
		$params = { $lang => $_[0] };
	} elsif(@_) {
		$params = Params::Get::get_params(undef, @_);
	}

	if(!defined($class)) {
		if($params && scalar keys %{$params}) {
			# Using Lingua::Text->new(), not Lingua::Text::new()
			Carp::carp(__PACKAGE__, ' use ->new() not ::new() to instantiate');
			return;
		}

		# FIXME: this only works when no arguments are given
		$class = __PACKAGE__;
	} elsif(blessed($class)) {
		# If $class is an object, clone it with new arguments
		if($params) {
			return bless { texts => {%{$class->{'texts'}}, %{$params}} }, ref($class);
		}
		return bless { %{$class} }, ref($class);
	}

	$params = Object::Configure::configure($class, $params);
	if($params) {
		return bless { texts => $params }, $class;
	}

	return bless { }, $class;
}

=head2 set

Sets a text in a language.

    $str->set({ text => 'House', lang => 'en' });

Autoload will do this for you as

    $str->en('House');

=cut

sub set {
	my $self = shift;

	if(!@_) {
		Carp::croak(__PACKAGE__, ': Usage: set(text => text, lang => $language)');
		return;
	}

	my $params = Params::Get::get_params('text', @_);

	my $lang = $params->{'lang'} || $self->_get_language();
	if(!defined($lang)) {
		Carp::carp(__PACKAGE__, ': usage: set(text => text, lang => $language)');
		return;
	}

	my $text = $params->{'text'};
	if(!defined($text)) {
		Carp::carp(__PACKAGE__, ': usage: set(text => text, lang => $language)');
		return;
	}

	$self->{'texts'}->{$lang} = $text;

	return $self;
}

# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
# https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html
sub _get_language {
	for my $tag (I18N::LangTags::Detect::detect()) {
		if($tag =~ /^([a-z]{2})/i) {
			return lc($1);
		}
	}
	if(($ENV{'LANGUAGE'}) && ($ENV{'LANGUAGE'} =~ /^([a-z]{2})/i)) {
		return lc($1);
	}

	for my $variable('LC_ALL', 'LC_MESSAGES', 'LANG') {
		my $val = $ENV{$variable};
		next unless defined($val);

		if($val =~ /^([a-z]{2})/i) {
			$val = lc($1);
			return $val if _is_valid_language($val);
		}
	}

	return 'en' if defined($ENV{'LANG'}) && $ENV{'LANG'} =~ /^C(\.|$)/;
	return;	# undef
}

=head2 as_string

Returns the text in the language requested in the parameter.
If that parameter is not given, the system language is used.

    my $text = Lingua::Text->new(en => 'boat', fr => 'bateau');
    print $text->as_string(), "\n";
    print $text->as_string('fr'), "\n";
    print $text->as_string({ lang => 'en' }), "\n";

=cut

sub as_string {
	my $self = shift;

	my $lang;
	if(@_ && defined($_[0])) {
		my $params = Params::Get::get_params('lang', @_);
		$lang = $params && $params->{'lang'};
	}
	$lang ||= $self->_get_language();

	if($lang) {
		return $self->{'texts'}->{$lang};
	}
	Carp::carp(__PACKAGE__, ': usage: as_string(lang => $language)');
	return;
}

=head2 encode

=encoding utf-8

Turns the encapsulated texts into HTML entities

    my $text = Lingua::Text->new(en => 'study', fr => 'etude')->encode();
    print $text->fr(), "\n";	# Prints &eacute;tude

=cut

sub encode {
	my $self = shift;

	for my $lang (keys %{$self->{'texts'}}) {
		my $v = $self->{'texts'}->{$lang};
		utf8::decode($v) unless utf8::is_utf8($v);
		$self->{'texts'}->{$lang} = HTML::Entities::encode_entities($v);
	}
	return $self;
}

sub AUTOLOAD {
	my $self = shift or return;

	my ($key) = $AUTOLOAD =~ /::(\w+)$/;

	return if $key eq 'DESTROY';
	return unless ref($self) eq __PACKAGE__;
	return unless $key =~ /^[a-z]{2}$/i;
	return unless _is_valid_language($key);

	if(my $value = shift) {
		$self->{'texts'}->{$key} = $value;
	}

	return $self->{'texts'}->{$key};
}

# Language validation
sub _is_valid_language {
	my $lang = shift;
	return $lang =~ /^[a-z]{2}(?:_[A-Z]{2})?$/;	# en or en_US format
}

=head1 AUTHOR

Nigel Horne, C<< <njh at nigelhorne.com> >>

=head1 BUGS

There's no decode() (yet),
so you'll have to be extra careful to avoid double encoding.

=head1 SEE ALSO

=over 4

=item * L<Configure an Object at Runtime|Object::Configure>

=item * L<Test Dashboard|https://nigelhorne.github.io/CGI-Info/coverage/>

=back

=head1 SUPPORT

This module is provided as-is without any warranty.

You can find documentation for this module with the perldoc command.

    perldoc Lingua::Text

You can also look for information at:

=over 4

=item * MetaCPAN

L<https://metacpan.org/release/Lingua-Text>

=item * RT: CPAN's request tracker

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Lingua-Text>

=item * CPANTS

L<http://cpants.cpanauthors.org/dist/Lingua-Text>

=item * CPAN Testers' Matrix

L<http://matrix.cpantesters.org/?dist=Lingua-Text>

=item * CPAN Testers Dependencies

L<http://deps.cpantesters.org/?module=Lingua-Text>

=back

=head1 LICENCE AND COPYRIGHT

Copyright 2021-2026 Nigel Horne.

Usage is subject to the GPL2 licence terms.
If you use it,
please let me know.

=cut

1;
