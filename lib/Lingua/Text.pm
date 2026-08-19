package Lingua::Text;

use strict;
use warnings;
use autodie qw(:all);

use Carp;
use HTML::Entities;
use Object::Configure;
use Params::Get;
use Readonly;
use Scalar::Util qw(blessed);
use I18N::LangTags::Detect;

# enforce mode lets Sub::Private work correctly with OO dispatch ($self->_helper).
# Tests bypass the check automatically when HARNESS_ACTIVE is set by prove.
BEGIN { $Sub::Private::config{mode} = 'enforce' }
use Sub::Private;

=encoding utf-8

=head1 NAME

Lingua::Text - Class to contain text in many different languages

=head1 VERSION

Version 0.08

=cut

our $VERSION = '0.08';
our $AUTOLOAD;

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# ISO 639-1 language code with optional ISO 3166-1 country suffix (e.g. 'en', 'en_US').
# The pattern is case-sensitive: lower-case lang, upper-case country.
Readonly::Scalar my $LANG_RE => qr/^[a-z]{2}(?:_[A-Z]{2})?$/;

# Error message catalog.  All templates accept the package name as first
# sprintf argument so callers never hard-code the package string.
# Capitalised "Usage:" marks programmer errors (croak); lower-case marks
# runtime warnings (carp) -- the carp.t suite relies on this distinction.
Readonly::Hash my %MESSAGES => (
    new_oo_style => '%s: use ->new() not ::new() to instantiate',
    set_no_args  => '%s: Usage: set(text => $text, lang => $language)',
    set_usage    => '%s: usage: set(text => $text, lang => $language)',
    str_usage    => '%s: usage: as_string(lang => $language)',
);

use overload (
	'""'     => \&as_string,
	bool     => sub { 1 },
	fallback => 1,    # let boolean tests bypass as_string
);

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# Purpose:  Format a message from the catalog with the package name filled in.
# Entry:    $key -- key into %MESSAGES.
# Exit:     Formatted string ready for Carp.
# Effects:  None.
sub _err :Private {
	my ($key) = @_;
	return sprintf($MESSAGES{$key} // "Unknown internal error: $key", __PACKAGE__);
}

# Purpose:  Issue a carp warning for a set() usage mistake and return undef.
#           Extracted to eliminate the duplicated carp + return pattern in set().
# Entry:    None (uses package-level _err).
# Exit:     undef.
# Effects:  Emits a Carp warning visible at the caller's call site.
sub _carp_set_usage :Private {
	Carp::carp(_err('set_usage'));
	return;
}

# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
# https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html
#
# Purpose:  Determine the two-letter ISO 639-1 language code for the running
#           environment by probing standard locale environment variables in
#           precedence order.
# Entry:    Environment variables: LANGUAGE, LC_ALL, LC_MESSAGES, LANG.
# Exit:     Lower-case two-letter code (e.g. 'en', 'fr'), or undef if the
#           locale is absent, empty, or set to the POSIX 'C' locale.
#           Returns 'en' when LANG=C or LANG=C.<encoding>.
# Effects:  Read-only; no side-effects on the environment.
sub _get_language :Private {
	for my $tag (I18N::LangTags::Detect::detect()) {
		return lc($1) if $tag =~ /^([a-z]{2})/i;
	}

	return lc($1)
		if ($ENV{'LANGUAGE'} // '') =~ /^([a-z]{2})/i;

	for my $var ('LC_ALL', 'LC_MESSAGES', 'LANG') {
		my $val = $ENV{$var} // next;
		if($val =~ /^([a-z]{2})/i) {
			my $code = lc($1);
			return $code if _is_valid_language($code);
		}
	}

	# POSIX 'C' locale is treated as English
	return 'en' if ($ENV{'LANG'} // '') =~ /^C(\.|$)/;
	return;
}

# Purpose:  Validate that a string is a well-formed language code accepted by
#           this module (ISO 639-1 with optional ISO 3166-1 country suffix).
# Entry:    $lang -- candidate string.
# Exit:     True if $lang matches $LANG_RE; false otherwise.
# Effects:  None.
sub _is_valid_language :Private {
	my ($lang) = @_;
	return $lang =~ $LANG_RE;
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

=head1 SYNOPSIS

    use Lingua::Text;

    my $str = Lingua::Text->new();
    $str->fr('Bonjour Tout le Monde');
    $str->en('Hello, World');

    $ENV{'LANG'} = 'en_GB';
    print "$str\n";     # Hello, World
    $ENV{'LANG'} = 'fr_FR';
    print "$str\n";     # Bonjour Tout le Monde

    my $text = Lingua::Text->new('hello');  # stores under the current locale

=head1 METHODS

=head2 new

=head3 PURPOSE

Construct a Lingua::Text object, optionally pre-populated with translations.
Also supports cloning an existing object (with or without additional keys).

=head3 EXAMPLE

    # Empty object, add translations later
    my $t = Lingua::Text->new();

    # Inline key/value pairs
    my $t = Lingua::Text->new(en => 'boat', fr => 'bateau');

    # Hash reference
    my $t = Lingua::Text->new({ en => 'boat', fr => 'bateau' });

    # Single scalar -- stored under the current locale language
    my $t = Lingua::Text->new('hello');

    # Clone with an extra translation
    my $t2 = $t->new(de => 'Boot');

=head3 API SPECIFICATION

=head4 Input

    args : HASH | HASHREF | SCALAR | Lingua::Text | ()

=head4 Output

    Returns a blessed Lingua::Text reference, or undef on misuse.

=head3 MESSAGES

    "use ->new() not ::new() to instantiate"
        Cause:   Called as a function with arguments (Lingua::Text::new(...)).
        Fix:     Use Lingua::Text->new(...).

=head3 FORMAL SPECIFICATION

    ┌─ LinguaText ────────────────────────────────────────────
    │ texts : LANG ↦ TEXT
    └─────────────────────────────────────────────────────────

    LANG ≙ { l : ℤ* | l matches /^[a-z]{2}(_[A-Z]{2})?$/ }
    TEXT ≙ ℤ*   (any Perl string)

    ┌─ new ───────────────────────────────────────────────────
    │ ΔLinguaText
    │ args?  : ℙ(LANG × TEXT) ∪ {∅}
    │ obj!   : LinguaText
    ├─────────────────────────────────────────────────────────
    │ obj!.texts = args? ≠ ∅ ⟹ args?
    │                         | ∅
    └─────────────────────────────────────────────────────────

=cut

sub new {
	my $class = shift;

	# Detect function-style misuse: Lingua::Text::new(args...)
	# A legitimate invocant is either a blessed object (clone) or a class name
	# that inherits from this package.  Anything else (e.g. the first key of a
	# hash accidentally consumed as the invocant) triggers a warning.
	my $is_class  = !ref($class) && defined($class) && eval { $class->isa(__PACKAGE__) };
	my $is_object = blessed($class);

	if(!defined($class) || (!$is_class && !$is_object)) {
		# undef invocant = bare Lingua::Text::new() call with no args -- allowed
		if(defined($class)) {
			Carp::carp(_err('new_oo_style'));
			return;
		}
		$class = __PACKAGE__;
	}

	# Build the initial parameter hash from whatever form the caller used
	my $params;
	if((scalar(@_) == 1) && (!ref($_[0])) && (my $lang = _get_language())) {
		$params = { $lang => $_[0] };
	} elsif(@_) {
		$params = Params::Get::get_params(undef, @_);
	}

	# Clone path: caller is an existing object
	if($is_object) {
		if($params) {
			return bless { texts => {%{$class->{'texts'}}, %{$params}} }, ref($class);
		}
		return bless { %{$class} }, ref($class);
	}

	# Allow Object::Configure to inject defaults (e.g. from a config file)
	$params = Object::Configure::configure($class, $params);
	return bless( $params ? { texts => $params } : {}, $class );
}

=head2 set

=head3 PURPOSE

Store a translation for a given language code.  Equivalent to calling the
AUTOLOAD accessor (e.g. C<$t->en('Hello')>) but allows the language to be
supplied at runtime.

=head3 EXAMPLE

    $t->set({ text => 'House', lang => 'en' });
    $t->set(text => 'Maison', lang => 'fr');
    $t->set('Haus');   # stores under the current locale language

=head3 API SPECIFICATION

=head4 Input

    text : SCALAR           -- the translation string (required)
    lang : LANG             -- ISO 639-1 language code (default: system locale)

=head4 Output

    Returns $self on success (chainable via the C<""> overload).
    Returns undef and emits a carp warning on missing arguments.

=head3 MESSAGES

    "Usage: set(text => $text, lang => $language)"  [croak]
        Cause:   Called with no arguments at all.
        Fix:     Provide at minimum a text string.

    "usage: set(text => $text, lang => $language)"  [carp]
        Cause:   lang cannot be determined, or text is absent/undef.
        Fix:     Pass lang explicitly or ensure the locale environment is set.

=head3 FORMAL SPECIFICATION

    ┌─ set ───────────────────────────────────────────────────
    │ ΔLinguaText
    │ text? : TEXT
    │ lang? : LANG
    ├─────────────────────────────────────────────────────────
    │ texts' = texts ⊕ { lang? ↦ text? }
    └─────────────────────────────────────────────────────────

=cut

sub set {
	my $self = shift;

	Carp::croak(_err('set_no_args')) unless @_;

	my $params = Params::Get::get_params('text', @_);

	my $lang = $params->{'lang'} || _get_language();
	return _carp_set_usage() unless defined($lang);

	my $text = $params->{'text'};
	return _carp_set_usage() unless defined($text);

	$self->{'texts'}->{$lang} = $text;
	return $self;
}

=head2 as_string

=head3 PURPOSE

Return the stored translation for a requested language, or for the system
locale when no language is specified.  This method is also the target of the
C<""> stringification overload, so objects interpolate naturally in strings.

=head3 EXAMPLE

    my $t = Lingua::Text->new(en => 'boat', fr => 'bateau');

    print $t->as_string(),             "\n";  # uses $ENV{LANG}
    print $t->as_string('fr'),         "\n";  # bateau
    print $t->as_string(lang => 'en'), "\n";  # boat
    print $t->as_string({ lang => 'fr' }), "\n";  # bateau
    print "$t\n";                             # uses $ENV{LANG}

=head3 API SPECIFICATION

=head4 Input

    lang : LANG | ()    -- language code (optional; default: system locale)

=head4 Output

    Returns the translation string, undef if none is stored for that language,
    or undef with a carp warning when no language can be determined at all.

=head3 MESSAGES

    "usage: as_string(lang => $language)"  [carp]
        Cause:   No lang argument and locale environment variables are absent.
        Fix:     Pass lang explicitly or set LANG/LC_MESSAGES.

=head3 FORMAL SPECIFICATION

    ┌─ as_string ─────────────────────────────────────────────
    │ ΞLinguaText
    │ lang? : LANG ∪ {undef}
    │ result! : TEXT ∪ {undef}
    ├─────────────────────────────────────────────────────────
    │ lang? ∈ dom texts ⟹ result! = texts(lang?)
    │ lang? ∉ dom texts ⟹ result! = undef
    └─────────────────────────────────────────────────────────

=cut

sub as_string {
	my $self = shift;

	# Guard against the overload calling convention: Perl passes ($self, $other, $swap)
	# when the "" handler is invoked during a comparison.  We only want the first arg.
	my $lang;
	if(@_ && defined($_[0])) {
		my $params = Params::Get::get_params('lang', @_);
		$lang = $params && $params->{'lang'};
	}
	$lang //= _get_language();

	if(defined($lang)) {
		return $self->{'texts'}->{$lang};
	}
	Carp::carp(_err('str_usage'));
	return;
}

=head2 encode

=head3 PURPOSE

HTML-entity-encode every stored translation in place.  Call once before
emitting text into an HTML context.

B<Note>: There is currently no C<decode()> counterpart; avoid double-encoding
by calling C<encode()> only once on a freshly constructed object.

=head3 EXAMPLE

    my $t = Lingua::Text->new(en => 'study', fr => 'étude')->encode();
    print $t->fr();    # h&eacute;tude

=head3 API SPECIFICATION

=head4 Input

    None.

=head4 Output

    Returns $self (chainable).

=head3 FORMAL SPECIFICATION

    ┌─ encode ────────────────────────────────────────────────
    │ ΔLinguaText
    │ encode : TEXT → TEXT
    │ encode(t) = HTML_entity_encode(utf8_decode(t))
    ├─────────────────────────────────────────────────────────
    │ ∀ l ∈ dom texts • texts'(l) = encode(texts(l))
    └─────────────────────────────────────────────────────────

=cut

sub encode {
	my $self = shift;

	# Iterate over keys to avoid stale iterator state from each()
	for my $lang (keys %{$self->{'texts'}}) {
		my $v = $self->{'texts'}->{$lang};
		utf8::decode($v) unless utf8::is_utf8($v);
		$self->{'texts'}->{$lang} = HTML::Entities::encode_entities($v);
	}
	return $self;
}

=head2 AUTOLOAD (language accessors)

=head3 PURPOSE

Any two-letter lower-case method name that matches a valid ISO 639-1 code is
treated as a getter/setter for that language's translation.

    $t->en('Hello');       # set English
    my $fr = $t->fr();     # get French (undef if not stored)

Setting a translation to C<undef> or the empty string C<''> is valid and will
store that value (clearing a translation is intentional).

=cut

sub AUTOLOAD {
	my $self = shift or return;

	my ($key) = $AUTOLOAD =~ /::(\w+)$/;

	return if $key eq 'DESTROY';
	return unless ref($self) eq __PACKAGE__;
	return unless $key =~ /^[a-z]{2}$/i;
	return unless _is_valid_language($key);

	# Use @_ presence (not truthiness) so falsy values like '0' or '' are stored
	if(@_) {
		$self->{'texts'}->{$key} = shift;
	}

	return $self->{'texts'}->{$key};
}

=head1 LIMITATIONS

=over 4

=item * No C<decode()> method exists to reverse C<encode()>.  Double-encoding
is a real risk if C<encode()> is called on an already-encoded object.

=item * Language fallback is absent: if a requested language has no stored
translation, C<undef> is returned rather than falling back to a related locale
(e.g. C<en_GB> → C<en>).

=item * The AUTOLOAD accessor silently ignores unrecognised method names that
are not two-letter codes, returning C<undef>.  Typos in language codes produce
no diagnostic.

=item * C<Object::Configure> support is best-effort; the exact semantics depend
on the installed version and any project-level configuration that is present.

=back

=head1 AUTHOR

Nigel Horne, C<< <njh at nigelhorne.com> >>

=head1 BUGS

Please report bugs via L<https://github.com/nigelhorne/Lingua-Text/issues>.

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
If you use it, please let me know.

=cut

1;
