##----------------------------------------------------------------------------
## Module Generic - ~/lib/Module/Generic/Scalar.pm
## Version v1.4.3
## Copyright(c) 2025 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2021/03/20
## Modified 2025/05/28
## All rights reserved
## 
## This program is free software; you can redistribute  it  and/or  modify  it
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
package Module::Generic::Scalar;
BEGIN
{
    use v5.26.1;
    use common::sense;
    use warnings;
    use warnings::register;
    use vars qw( $DEBUG $ERROR );
    use Config;
    use Encode ();
    use Module::Generic::Global ':const';
    # So that the user can say $obj->isa( 'Module::Generic::Scalar' ) and it would return true
    # use parent -norequire, qw( Module::Generic::Scalar );
    use Scalar::Util ();
    use Wanted;
    use overload (
        '""'    => 'as_string',
        '.='    => sub
        {
            my( $self, $other, $swap ) = @_;
            no warnings 'uninitialized';
            if( !CORE::defined( $$self ) )
            {
                return( $other );
            }
            elsif( !CORE::defined( $other ) )
            {
                return( $$self );
            }
            my $expr;
            if( $swap )
            {
                $expr = "\$other .= \$$self";
                return( $other );
            }
            else
            {
                $$self .= $other;
                return( $self );
            }
        },
        'x'     => sub
        {
            my( $self, $other, $swap ) = @_;
            no warnings 'uninitialized';
            my $expr = $swap ? "\"$other\" x \"$$self\"" : "\"$$self\" x \"$other\"";
            local $@;
            my $res  = eval( $expr );
            if( $@ )
            {
                CORE::warn( $@ );
                return;
            }
            return( $self->new( $res ) );
        },
        'eq'    => sub
        {
            my( $self, $other, $swap ) = @_;
            no warnings 'uninitialized';
            if( Scalar::Util::blessed( $other ) && ref( $other ) eq ref( $self ) )
            {
                return( $$self eq $$other );
            }
            else
            {
                return( $$self eq "$other" );
            }
        },
        fallback => 1,
    );
    $DEBUG = 0;
    our $VERSION = 'v1.4.3';
};

use v5.26.1;
use strict;
no warnings 'redefine';
require Module::Generic::Array;
require Module::Generic::Boolean;
require Module::Generic::Null;
require Module::Generic::Number;

# sub new { return( shift->_new( @_ ) ); }
sub new
{
    my $this = shift( @_ );
    my $class = ref( $this ) || $this;
    my $init = '';
    if( ref( $_[0] ) eq 'SCALAR' || UNIVERSAL::isa( $_[0], 'SCALAR' ) )
    {
        $init = ${$_[0]};
    }
    elsif( ref( $_[0] ) eq 'ARRAY' || UNIVERSAL::isa( $_[0], 'ARRAY' ) )
    {
        $init = CORE::join( '', @{$_[0]} );
    }
    elsif( ref( $_[0] ) )
    {
        return( $this->error( "I do not know what to do with \"", overload::StrVal( $_[0] ), "\". ${class} only supports string, scalar reference or array reference." ) );
    }
    elsif( @_ )
    {
        $init = $_[0];
    }
    else
    {
        $init = undef();
    }
    return( bless( \$init => ( ref( $this ) || $this ) ) );
}

sub append { ${$_[0]} .= ( ( Scalar::Util::reftype( $_[1] ) // '' ) eq 'SCALAR' ? ${$_[1]} : $_[1] ); return( $_[0] ); }

sub as_array { return( Module::Generic::Array->new( [ ${$_[0]} ] ) ); }

sub as_boolean { return( Module::Generic::Boolean->new( ${$_[0]} ? 1 : 0 ) ); }

sub as_number { return( $_[0]->_number( ${$_[0]} ) ); }

## sub as_string { CORE::defined( ${$_[0]} ) ? return( ${$_[0]} ) : return; }

sub as_string { return( ${$_[0]} ); }

sub callback
{
    my $self = CORE::shift( @_ );
    my( $what, $code ) = @_;
    if( !defined( $what ) )
    {
        return( $self->error( "No callback type was provided." ) );
    }
    elsif( $what ne 'add' && $what ne 'remove' )
    {
        return( $self->error( "Callback type provided ($what) is unsupported. Use 'add' or 'remove'." ) );
    }
    elsif( scalar( @_ ) == 1 )
    {
        return( $self->error( "No callback code was provided. Provide an anonymous subroutine, or reference to an existing subroutine." ) );
    }
    elsif( defined( $code ) && ref( $code ) ne 'CODE' )
    {
        return( $self->error( "Callback provided is not a code reference. Provide an anonymous subroutine, or reference to an existing subroutine." ) );
    }

    if( !defined( $code ) )
    {
        # undef is passed as an argument, so we remove the callback
        if( scalar( @_ ) >= 2 )
        {
            # The array is not tied, so there is nothing to remove.
            my $tie = tied( $$self );
            return(1) if( !$tie );
            my $rv = $tie->unset_callback( $what );
            if( !$tie->has_callback )
            {
                undef( $tie );
                untie( $$self );
            }
            return( $rv );
        }
        # Only 1 argument: get mode only
        else
        {
            my $tie = tied( $$self );
            return if( !$tie );
            return( $tie->get_callback( $what ) );
        }
    }
    # $code is defined, so we have something to set
    else
    {
        my $tie = tied( $$self );
        # Not tied yet
        if( !$tie )
        {
            $tie = tie( $$self => 'Module::Generic::Scalar::Tie',
            {
                data  => $self,
                debug => $DEBUG,
                $what => $code,
            }) || return( $self->error( "Failed to tie scalar: $!" ) );
            return(1);
        }
        $tie->set_callback( $what => $code ) || return( $self->error( "Failed to set callback for $what" ) );
        return(1);
    }
}

# Credits: John Gruber, Aristotle Pagaltzis
# https://gist.github.com/gruber/9f9e8650d68b13ce4d78
sub capitalise
{
    my $self = CORE::shift( @_ );
    my @small_words = qw( (?<!q&)a an and as at(?!&t) but by en for if in of on or the to v[.]? via vs[.]? );
    my $small_re = CORE::join( '|', @small_words );

    my $apos = qr/ (?: ['’] [[:lower:]]* )? /x;

    my $copy = $$self;
    return( $self->_new( $copy ) ) if( !CORE::defined( $copy ) );
    $copy =~ s{\A\s+}{};
    $copy =~ s{\s+\z}{};
    $copy = CORE::lc( $copy ) if( $copy !~ /[[:lower:]]/ );
    $copy =~ s{
        \b (_*) (?:
            ( (?<=[ ][/\\]) [[:alpha:]]+ [-_[:alpha:]/\\]+ |   # file path or
              [-_[:alpha:]]+ [@.:] [-_[:alpha:]@.:/]+ $apos )  # URL, domain, or email
            |
            ( (?i: $small_re ) $apos )                         # or small word (case-insensitive)
            |
            ( [[:alpha:]] [[:lower:]'’()\[\]{}]* $apos )       # or word w/o internal caps
            |
            ( [[:alpha:]] [[:alpha:]'’()\[\]{}]* $apos )       # or some other word
        ) (_*) \b
    }{
        $1 . (
          defined $2 ? $2         # preserve URL, domain, or email
        : defined $3 ? "\L$3"     # lowercase small word
        : defined $4 ? "\u\L$4"   # capitalize word w/o internal caps
        : $5                      # preserve other kinds of word
        ) . $6
    }xeg;


    # Exceptions for small words: capitalize at start and end of title
    $copy =~ s{
        (  \A [[:punct:]]*         # start of title...
        |  [:.;?!][ ]+             # or of subsentence...
        |  [ ]['"“‘(\[][ ]*     )  # or of inserted subphrase...
        ( $small_re ) \b           # ... followed by small word
    }{$1\u\L$2}xig;

    $copy =~ s{
        \b ( $small_re )      # small word...
        (?= [[:punct:]]* \Z   # ... at the end of the title...
        |   ['"’”)\]] [ ] )   # ... or of an inserted subphrase?
    }{\u\L$1}xig;

    # Exceptions for small words in hyphenated compound words
    # e.g. "in-flight" -> In-Flight
    $copy =~ s{
        \b
        (?<! -)                 # Negative lookbehind for a hyphen; we don't want to match man-in-the-middle but do want (in-flight)
        ( $small_re )
        (?= -[[:alpha:]]+)      # lookahead for "-someword"
    }{\u\L$1}xig;

    # e.g. "Stand-in" -> "Stand-In" (Stand is already capped at this point)
    $copy =~ s{
        \b
        (?<!…)                  # Negative lookbehind for a hyphen; we don't want to match man-in-the-middle but do want (stand-in)
        ( [[:alpha:]]+- )       # $1 = first word and hyphen, should already be properly capped
        ( $small_re )           # ... followed by small word
        (?! - )                 # Negative lookahead for another '-'
    }{$1\u$2}xig;

    return( $self->_new( $copy ) );
}

sub chomp { no warnings 'uninitialized'; return( CORE::chomp( ${$_[0]} ) ); }

sub chop { no warnings 'uninitialized'; return( CORE::chop( ${$_[0]} ) ); }

sub clone
{
    my $self = shift( @_ );
    if( @_ )
    {
        return( $self->_new( @_ ) );
    }
    else
    {
        return( $self->_new( ${$self} ) );
    }
}

sub crypt { return( __PACKAGE__->_new( CORE::crypt( ${$_[0]}, $_[1] ) ) ); }

sub defined { return( CORE::defined( ${$_[0]} ) ? 1 : 0 ); }

sub empty { return( shift->reset( @_ ) ); }

sub error
{
    my $self = CORE::shift( @_ );
    my $addr = Scalar::Util::refaddr( $self ) || $self;
    my $class = ref( $self ) || $self;
    my $o;
    no strict 'refs';
    my $repo = Module::Generic::Global->new( 'errors' => $self );

    if( @_ )
    {
        my $args = {};
        # We got an object as first argument. It could be a child from our exception package or from another package
        # Either way, we use it as it is
        if( ( Scalar::Util::blessed( $_[0] ) && $_[0]->isa( 'Module::Generic::Exception' ) ) ||
            Scalar::Util::blessed( $_[0] ) )
        {
            $o = CORE::shift( @_ );
        }
        elsif( ref( $_[0] ) eq 'HASH' )
        {
            $args  = CORE::shift( @_ );
        }
        else
        {
            $args->{message} = CORE::join( '', CORE::map( ref( $_ ) eq 'CODE' ? $_->() : $_, @_ ) );
        }

        $args->{class} //= '';
        my $ex_class = CORE::length( $args->{class} )
            ? $args->{class}
            : ( defined( ${"${class}\::EXCEPTION_CLASS"} ) && CORE::length( ${"${class}\::EXCEPTION_CLASS"} ) )
                ? ${"${class}\::EXCEPTION_CLASS"}
                : 'Module::Generic::Exception';
        unless( CORE::scalar( CORE::keys( %{"${ex_class}\::"} ) ) )
        {
            my $pl = "use $ex_class;";
            local $SIG{__DIE__} = sub{};
            local $@;
            eval( $pl );
            # We have to die, because we have an error within another error
            die( "${class}\::error() is unable to load exception class \"$ex_class\": $@" ) if( $@ );
        }

        $o = $ex_class->new( $args );
        $repo->set( $o );
        $ERROR = $o;

        # try-catch
        local $@;
        my $enc_str = eval
        {
            Encode::encode( 'UTF-8', "$o", Encode::FB_CROAK );
        };
        # Display warnings if warnings for this class is registered and enabled or if not registered
        warn( $@ ? $o : $enc_str ) if( $self->_warnings_is_enabled );

        if( !$args->{no_return_null_object} && want( 'OBJECT' ) )
        {
            # try-catch
            local $@;
            if( !$self->_is_class_loaded( 'Module::Generic::Null' ) )
            {
                eval( 'require Module::Generic::Null' );
                die( "Unable to load module Module::Generic::Null" ) if( $@ );
            }
            my $null = Module::Generic::Null->new( $o, { debug => $DEBUG, has_error => 1 });
            rreturn( $null );
        }
        return;
    }

    $o = $repo->get;
    if( !$o && want( 'OBJECT' ) )
    {
        # try-catch
        local $@;
        if( !$self->_is_class_loaded( 'Module::Generic::Null' ) )
        {
            eval( 'require Module::Generic::Null' );
            die( "Unable to load module Module::Generic::Null" ) if( $@ );
        }
        my $null = Module::Generic::Null->new( $o, { debug => $DEBUG, wants => 'object' });
        rreturn( $null );
    }
    return( $o );
}

sub fc { return( CORE::fc( ${$_[0]} ) eq CORE::fc( $_[1] ) ); }

sub hex { return( $_[0]->_number( CORE::hex( ${$_[0]} ) ) ); }

sub index
{
    my $self = shift( @_ );
    my( $substr, $pos ) = @_;
    return( $self->_number( CORE::index( ${$self}, $substr, $pos ) ) ) if( CORE::defined( $pos ) );
    return( $self->_number( CORE::index( ${$self}, $substr ) ) );
}

sub is_alpha { return( CORE::defined( ${$_[0]} ) && ${$_[0]} =~ /^[[:alpha:]]+$/ ); }

sub is_alpha_numeric { return( CORE::defined( ${$_[0]} ) && ${$_[0]} =~ /^[[:alnum:]]+$/ ); }

sub is_empty { return( CORE::length( ${$_[0]} // '' ) == 0 ); }

sub is_lower { return( CORE::defined( ${$_[0]} ) && ${$_[0]} =~ /^[[:lower:]]+$/ ); }

sub is_numeric { return( Scalar::Util::looks_like_number( ${$_[0]} ) ); }

sub is_upper { return( CORE::defined( ${$_[0]} ) && ${$_[0]} =~ /^[[:upper:]]+$/ ); }

sub join { return( __PACKAGE__->new( CORE::join( CORE::splice( @_, 1, 1 ), ${ shift( @_ ) }, @_ ) ) ); }

sub lc { no warnings 'uninitialized'; return( __PACKAGE__->_new( CORE::lc( ${$_[0]} ) ) ); }

sub lcfirst { no warnings 'uninitialized'; return( __PACKAGE__->_new( CORE::lcfirst( ${$_[0]} ) ) ); }

sub left { no warnings 'uninitialized'; return( $_[0]->_new( CORE::substr( ${$_[0]}, 0, CORE::int( $_[1] ) ) ) ); }

sub length { no warnings 'uninitialized'; return( $_[0]->_number( CORE::length( ${$_[0]} ) ) ); }

sub like
{
    my $self = shift( @_ );
    my $str = shift( @_ );
    my @matches = ();
    my @rv = ();
    no warnings 'uninitialized';
    $str = CORE::defined( $str ) 
        ? ( ref( $str ) eq 'Regexp' || ref( $str ) eq 'Regexp::Common' )
            ? $str
            : qr/(?:\Q$str\E)+/
        : qr/[[:blank:]\r\n]*/;
    @rv = $$self =~ /$str/;
    if( scalar( @{^CAPTURE} ) )
    {
        for( my $i = 0; $i < scalar( @{^CAPTURE} ); $i++ )
        {
            push( @matches, ${^CAPTURE}[$i] );
        }
    }
    # For named captures
    my $names = { %+ };
    unless( want( 'OBJECT' ) || want( 'SCALAR' ) || want( 'LIST' ) || scalar( @matches ) )
    {
        return(0);
    }
    return( Module::Generic::RegexpCapture->new( result => \@rv, capture => \@matches, name => $names ) );
}

sub lower { return( shift->lc ); }

sub ltrim
{
    my $self = shift( @_ );
    my $str = shift( @_ );
    no warnings 'uninitialized';
    $str = CORE::defined( $str ) 
        ? ( ref( $str ) eq 'Regexp' || ref( $str ) eq 'Regexp::Common' )
            ? $str
            : qr/(?:\Q$str\E)+/
        : qr/[[:blank:]\r\n]*/;
    $$self =~ s/^$str//g;
    return( $self );
}

sub match
{
    my( $self, $re ) = @_;
    my @matches = ();
    my @rv = ();
    no warnings 'uninitialized';
    $re = CORE::defined( $re ) 
        ? ( ref( $re ) eq 'Regexp' || ref( $re ) eq 'Regexp::Common' )
            ? $re
            : qr/(?:\Q$re\E)+/
        : $re;
    @rv = $$self =~ /$re/;
    if( scalar( @{^CAPTURE} ) )
    {
        for( my $i = 0; $i < scalar( @{^CAPTURE} ); $i++ )
        {
            push( @matches, ${^CAPTURE}[$i] );
        }
    }
    # For named captures
    my $names = { %+ };
    unless( want( 'OBJECT' ) || want( 'SCALAR' ) || want( 'LIST' ) || scalar( @matches ) )
    {
        return(0);
    }
    return( Module::Generic::RegexpCapture->new( result => \@rv, capture => \@matches, name => $names ) );
}

sub object { return( $_[0] ); }

sub open
{
    my $self = shift( @_ );
    $self->_load_class( 'Module::Generic::Scalar::IO' ) || return( $self->pass_error );
    my $io = Module::Generic::Scalar::IO->new( $self, @_ ) || 
        return( $self->pass_error( Module::Generic::Scalar::IO->error ) );
    return( $io );
}

sub ord { return( $_[0]->_number( CORE::ord( ${$_[0]} ) ) ); }

sub pack { return( __PACKAGE__->_new( CORE::pack( $_[1], ${$_[0]} ) ) ); }

sub pad
{
    my $self = shift( @_ );
    my( $n, $str ) = @_;
    $str //= ' ';
    if( !CORE::length( $n ) )
    {
        warn( "No number provided to pad the string object.\n" ) if( $self->_warnings_is_enabled );
    }
    elsif( $n !~ /^\-?\d+$/ )
    {
        warn( "Number provided \"$n\" to pad string is not an integer.\n" ) if( $self->_warnings_is_enabled );
    }

    if( $n < 0 )
    {
        $$self .= ( "$str" x CORE::abs( $n ) );
    }
    else
    {
        CORE::substr( $$self, 0, 0 ) = ( "$str" x $n );
    }
    return( $self );
}

sub pass_error
{
    my $self = CORE::shift( @_ );
    my $class = ref( $self ) || $self;
    my $opts = {};
    my $err;
    my $ex_class;
    no strict 'refs';
    my $err_key = HAS_THREADS() ? CORE::join( ';', $class, $$, threads->tid ) : CORE::join( ';', $class, $$ );
    my $repo = Module::Generic::Global->new( 'errors' => $class, key => $err_key );

    if( scalar( @_ ) )
    {
        # Either an hash defining a new error and this will be passed along to error(); or
        # an hash with a single property: { class => 'Some::ExceptionClass' }
        if( CORE::scalar( @_ ) == 1 && CORE::ref( $_[0] ) eq 'HASH' )
        {
            $opts = $_[0];
        }
        else
        {
            # $self->pass_error( $error_object, { class => 'Some::ExceptionClass' } );
            if( CORE::scalar( @_ ) > 1 && CORE::ref( $_[-1] ) eq 'HASH' )
            {
                $opts = CORE::pop( @_ );
            }
            $err = $_[0];
        }
    }
    # We set $ex_class only if the hash provided is a one-element hash and not an error-defining hash
    $ex_class = CORE::delete( $opts->{class} ) if( CORE::scalar( CORE::keys( %$opts ) ) == 1 && [CORE::keys( %$opts )]->[0] eq 'class' );

    # called with no argument, most likely from the same class to pass on an error 
    # set up earlier by another method; or
    # with an hash containing just one argument class => 'Some::ExceptionClass'
    if( !CORE::defined( $err ) && ( !CORE::scalar( @_ ) || CORE::defined( $ex_class ) ) )
    {
        my $error = $repo->get;
        if( !CORE::defined( $error ) )
        {
            warnings::warnif( "No error object provided and no previous error set either! It seems the previous method call returned a simple undef\n" );
        }
        else
        {
            $err = ( CORE::defined( $ex_class ) ? bless( $error => $ex_class ) : $error );
        }
    }
    elsif( CORE::defined( $err ) && 
           Scalar::Util::blessed( $err ) && 
           ( CORE::scalar( @_ ) == 1 || 
             ( CORE::scalar( @_ ) == 2 && CORE::defined( $ex_class ) ) 
           ) )
    {
        my $o = ( CORE::defined( $ex_class ) ? bless( $err => $ex_class ) : $err );
        $repo->set( $o );
        $ERROR = $o;
    }
    # If the error provided is not an object, we call error to create one
    else
    {
        return( $self->error( @_ ) );
    }

    if( want( 'OBJECT' ) )
    {
        # try-catch
        local $@;
        if( !$self->_is_class_loaded( 'Module::Generic::Null' ) )
        {
            eval( 'require Module::Generic::Null' );
            die( "Unable to load module Module::Generic::Null" ) if( $@ );
        }
        my $null = Module::Generic::Null->new( $err, { has_error => 1 });
        rreturn( $null );
    }
    return;
}

sub pos { return( $_[0]->_number( @_ > 1 ? ( CORE::pos( ${$_[0]} ) = $_[1] ) : CORE::pos( ${$_[0]} ) ) ); }

sub prepend { return( shift->substr( 0, 0, ( ( Scalar::Util::reftype( $_[0] ) // '' ) eq 'SCALAR' ? ${$_[0]} : $_[0] ) ) ); }

sub quotemeta { return( __PACKAGE__->_new( CORE::quotemeta( ${$_[0]} ) ) ); }

sub right { return( $_[0]->_new( CORE::substr( ${$_[0]}, ( CORE::int( $_[1] ) * -1 ) ) ) ); }

sub replace
{
    my( $self, $re, $replacement ) = @_;
    # Only to test if this was a regular expression. If it was the array will contain successful match, other it will be empty
    # @rv will contain the regexp matches or the result of the eval
    my @matches = ();
    my @rv = ();
    $re = CORE::defined( $re ) 
        ? ( ref( $re ) eq 'Regexp' || ref( $re ) eq 'Regexp::Common' )
            ? $re
            : qr/(?:\Q$re\E)+/
        : $re;
    # return( $$self =~ s/$re/$replacement/gs );
    @rv = $$self =~ s/$re/$replacement/gs;
    if( scalar( @{^CAPTURE} ) )
    {
        for( my $i = 0; $i < scalar( @{^CAPTURE} ); $i++ )
        {
            push( @matches, ${^CAPTURE}[$i] );
        }
    }
    # For named captures
    my $names = { %+ };
    unless( want( 'OBJECT' ) || want( 'SCALAR' ) || want( 'LIST' ) || scalar( @matches ) )
    {
        return(0);
    }
    return( Module::Generic::RegexpCapture->new( result => \@rv, capture => \@matches, name => $names ) );
}

sub reset { ${$_[0]} = ''; return( $_[0] ); }

sub reverse { return( __PACKAGE__->_new( CORE::scalar( CORE::reverse( ${$_[0]} ) ) ) ); }

sub rindex
{
    my $self = shift( @_ );
    my( $substr, $pos ) = @_;
    return( $self->_number( CORE::rindex( ${$self}, $substr, $pos ) ) ) if( CORE::defined( $pos ) );
    return( $self->_number( CORE::rindex( ${$self}, $substr ) ) );
}

sub rtrim
{
    my $self = shift( @_ );
    my $str = shift( @_ );
    $str = CORE::defined( $str ) 
        ? ( ref( $str ) eq 'Regexp' || ref( $str ) eq 'Regexp::Common' )
            ? $str
            : qr/(?:\Q$str\E)+/
        : qr/[[:blank:]\r\n]*/;
    $$self =~ s/${str}$//g;
    return( $self );
}

sub scalar { return( shift->as_string ); }

sub set
{
    my $self = CORE::shift( @_ );
    if( @_ )
    {
        my $init;
        my $type = Scalar::Util::reftype( $_[0] ) // '';
        if( $type eq 'SCALAR' )
        {
            $init = ${$_[0]};
        }
        elsif( $type eq 'ARRAY' )
        {
            $init = CORE::join( '', @{$_[0]} );
        }
        elsif( ref( $_[0] ) )
        {
            warn( "I do not know what to do with \"", $_[0], "\" (", overload::StrVal( $_[0] ), ")\n" ) if( $self->_warnings_is_enabled );
            return;
        }
        else
        {
            $init = shift( @_ );
        }
        $$self = $init;
    }
    return( $self );
}

sub split
{
    my $self = CORE::shift( @_ );
    my( $expr, $limit ) = @_;
    if( !scalar( @_ ) )
    {
        CORE::warn( "No argument was provided to split string in Module::Generic::Scalar::split\n" ) if( $self->_warnings_is_enabled );
        # NOTE: As per perlfunc: "If omitted, PATTERN defaults to a single space, " ", triggering the previously described *awk* emulation."
        $expr = ' ';
    }
    unless( ref( $expr ) eq 'Regexp' || ref( $expr ) eq 'Regexp::Common' )
    {
        if( ref( $expr ) )
        {
            CORE::warn( "Expression provided is a reference of type '", ref( $expr ), "', but I was expecting either a regular expression or a simple string.\n" );
            return;
        }
        $expr = qr/\Q$expr\E/;
    }
    my $ref;
    $limit = "$limit" if( CORE::defined( $limit ) );
    if( CORE::defined( $limit ) && $limit =~ /^\d+$/ )
    {
        $ref = [ CORE::split( $expr, $$self, $limit ) ];
    }
    else
    {
        $ref = [ CORE::split( $expr, $$self ) ];
    }
    if( Wanted::want( 'OBJECT' ) ||
        Wanted::want( 'SCALAR' ) )
    {
        rreturn( $self->_array( $ref ) );
    }
    elsif( Wanted::want( 'LIST' ) )
    {
        rreturn( @$ref );
    }
    return;
}

sub sprintf { return( __PACKAGE__->_new( CORE::sprintf( ${$_[0]}, @_[1..$#_] ) ) ); }

sub substr
{
    my $self = CORE::shift( @_ );
    my( $offset, $length, $replacement ) = @_;
    return( __PACKAGE__->_new( CORE::substr( ${$self}, $offset, $length, $replacement ) ) ) if( CORE::defined( $length ) && CORE::defined( $replacement ) );
    return( __PACKAGE__->_new( CORE::substr( ${$self}, $offset, $length ) ) ) if( CORE::defined( $length ) );
    return( __PACKAGE__->_new( CORE::substr( ${$self}, $offset ) ) );
}

# The 3 dash here are just so my editor does not get confused with colouring
sub tr ###
{
    my $self = CORE::shift( @_ );
    my( $search, $replace, $opts ) = @_;
    $opts //= '';
    local $@;
    eval( "\$\$self =~ CORE::tr/$search/$replace/$opts" );
    return( $self );
}

sub trim
{
    my $self = shift( @_ );
    my $str  = shift( @_ );
    $str = CORE::defined( $str ) ? CORE::quotemeta( $str ) : qr/[[:blank:]\r\n]*/;
    $$self =~ s/^$str|$str$//gs;
    return( $self );
}

sub uc { return( __PACKAGE__->_new( CORE::uc( ${$_[0]} ) ) ); }

sub ucfirst { return( __PACKAGE__->_new( CORE::ucfirst( ${$_[0]} ) ) ); }

sub undef
{
    my $self = shift( @_ );
    $$self = undef;
    return( $self );
}

sub unpack
{
    my( $self, $tmpl ) = @_;
    my $ref = [CORE::unpack( $tmpl, $$self )];
    if( Wanted::want( 'OBJECT' ) || Wanted::want( 'ARRAY' ) )
    {
        rreturn( $self->_array( $ref ) );
    }
    elsif( Wanted::want( 'LIST' ) )
    {
        rreturn( @$ref );
    }
    # In scalar context, return the first element, as per the original unpack behaviour
    elsif( Wanted::want( 'SCALAR' ) )
    {
        rreturn( $ref->[0] );
    }
    return;
}

sub upper { return( shift->uc ); }

sub _array
{
    my $self = shift( @_ );
    my $arr  = shift( @_ );
    if( !defined( $arr ) )
    {
        if( Wanted::want( 'OBJECT' ) )
        {
            # We might have need to specify, because I found a race condition where
            # even though the context is object, once in Null, the context became 'code'
            $self->_load_class( 'Module::Generic::Null' ) || return( $self->pass_error );
            return( Module::Generic::Null->new( wants => 'OBJECT' ) );
        }
        else
        {
            return;
        }
    }
    return( $arr ) if( ( Scalar::Util::reftype( $arr ) // '' ) ne 'ARRAY' );
    return( Module::Generic::Array->new( $arr ) );
}

sub _is_class_loaded
{
    my $self = CORE::shift( @_ );
    my $class = CORE::shift( @_ );
    ( my $pm = $class ) =~ s{::}{/}gs;
    $pm .= '.pm';
    return(1) if( CORE::exists( $INC{ $pm } ) );
    return(0);
}

sub _load_class
{
    my $self = shift( @_ );
    my $class = shift( @_ );
    die( "No class was provided to load." ) if( !$class );
    my $args = [@_];
    my $is_loaded = $self->_is_class_loaded( $class );
    if( $is_loaded )
    {
        if( CORE::scalar( @$args ) )
        {
            my $pl = "$class->import(" . ( CORE::scalar( @$args ) ? "'" . CORE::join( "', '", @$args ) . "'" : '' ) . ");";
            eval( $pl );
            return( $self->error( "Error importing class $class: $@" ) ) if( $@ );
        }
        return( $class );
    }

    local $@;
    local $SIG{__DIE__} = sub{};

    # Load the module with thread safety
    my $key  = HAS_THREADS ? CORE::join( ';', $class, threads->tid() ) : $class;
    my $repo = Module::Generic::Global->new( 'loaded_classes' => CORE::ref( $self ), key => $key );
    my $pl = "require $class;";
    eval( $pl );
    return( $self->error( "Unable to load package ${class}: $@\nCode executed was:\n${pl}" ) ) if( $@ );
    $pl = "$class->import(" . ( CORE::scalar( @$args ) ? "'" . CORE::join( "', '", @$args ) . "'" : '' ) . ");";
    eval( $pl );
    return( $self->error( "Error importing class $class: $@" ) ) if( $@ );
    $repo->set(1);
    return( $class );
}

sub _number
{
    my $self = shift( @_ );
    my $num = shift( @_ );
    if( !defined( $num ) )
    {
        if( Wanted::want( 'OBJECT' ) )
        {
            # We might have need to specify, because I found a race condition where
            # even though the context is object, once in Null, the context became 'code'
            $self->_load_class( 'Module::Generic::Null' ) || return( $self->pass_error );
            return( Module::Generic::Null->new( wants => 'OBJECT' ) );
        }
        else
        {
            return;
        }
    }
    return( $num ) if( !CORE::length( $num ) );
    return( Module::Generic::Number->new( $num ) );
}

sub _new { return( shift->Module::Generic::Scalar::new( @_ ) ); }

sub _warnings_is_enabled
{
    my $self = shift( @_ );
    # I hate dying, but here this is a show-stopper
    die( "Object provided is undef!\n" ) if( @_ && !defined( $_[0] ) );
    my $obj = @_ ? shift( @_ ) : $self;
    return(0) if( !$self->_warnings_is_registered( $obj ) );
    return( warnings::enabled( ref( $obj ) || $obj ) );
}

sub _warnings_is_registered
{
    my $self = shift( @_ );
    # I hate dying, but here this is a show-stopper
    die( "Object provided is undef!\n" ) if( @_ && !defined( $_[0] ) );
    my $obj = @_ ? shift( @_ ) : $self;
    return(1) if( defined( $warnings::Bits{ ref( $obj ) || $obj } ) );
    return(0);
}

sub DESTROY
{
    # <https://perldoc.perl.org/perlobj#Destructors>
    CORE::local( $., $@, $!, $^E, $? );
    CORE::return if( ${^GLOBAL_PHASE} eq 'DESTRUCT' );
    my $self = CORE::shift( @_ );
    CORE::return if( !CORE::defined( $self ) );
    if( my $obj = Module::Generic::Global->new( 'errors' => $self ) )
    {
        $obj->remove;
    }
    if( my $obj = Module::Generic::Global->new( 'loaded_classes' => $self ) )
    {
        $obj->remove;
    }
};

sub FREEZE
{
    my $self = CORE::shift( @_ );
    my $serialiser = CORE::shift( @_ ) // '';
    my $class = CORE::ref( $self ) || $self;
    # Return an array reference rather than a list so this works with Sereal and CBOR
    # On or before Sereal version 4.023, Sereal did not support multiple values returned
    CORE::return( [$class, $$self] ) if( $serialiser eq 'Sereal' && Sereal::Encoder->VERSION <= version->parse( '4.023' ) );
    # But Storable want a list with the first element being the serialised element
    CORE::return( $$self );
}

sub STORABLE_freeze { CORE::return( CORE::shift->FREEZE( @_ ) ); }

sub STORABLE_thaw { CORE::return( CORE::shift->THAW( @_ ) ); }

sub THAW
{
    my( $self, undef, @args ) = @_;
    my( $class, $str );
    if( CORE::scalar( @args ) == 1 && CORE::ref( $args[0] ) eq 'ARRAY' )
    {
        ( $class, $str ) = @{$args[0]};
    }
    else
    {
        $class = CORE::ref( $self ) || $self;
        $str = CORE::shift( @args );
    }
    my $new;
    # Storable pattern requires to modify the object it created rather than returning a new one
    if( CORE::ref( $self ) )
    {
        $$self = $str;
        $new = $self;
    }
    else
    {
        $new = CORE::return( $class->new( $str ) );
    }
    CORE::return( $new );
}

sub TO_JSON { CORE::return( ${$_[0]} ); }


# NOTE: Module::Generic::RegexpCapture package
{
    package
        Module::Generic::RegexpCapture;
    BEGIN
    {
        use strict;
        use warnings;
        use parent qw( Module::Generic );
        use vars qw( $ERROR $VERSION );
        use overload (
            '""' => sub{ $_[0]->matched },
            '0+' => sub{ $_[0]->matched },
            fallback => 1,
        );
        our $ERROR = '';
        our $VERSION = 'v0.1.1';
    };

    sub init
    {
        my $self = shift( @_ );
        $self->{capture}    = [];
        $self->{name}       = {};
        $self->{result}     = 0;
        $self->{_init_strict_use_sub} = 1;
        return( $self->SUPER::init( @_ ) );
    }

    sub capture { return( shift->_set_get_array_as_object( 'capture', @_ ) ); }

    sub matched
    {
        my $res = shift->result;
        # There may be one entry of empty value when there is no match, so we check for length
        return( $res->length->scalar ) if( $res->length && length( $res->get(0) ) );
        return(0);
    }

    sub name { return( shift->_set_get_hash_as_object( 'name', @_ ) ); }

    sub result { return( shift->_set_get_array_as_object( 'result', @_ ) ); }

    sub FREEZE
    {
        my $self = CORE::shift( @_ );
        my $serialiser = CORE::shift( @_ ) // '';
        my $class = CORE::ref( $self );
        my %hash  = %$self;
        # Return an array reference rather than a list so this works with Sereal and CBOR
        # On or before Sereal version 4.023, Sereal did not support multiple values returned
        CORE::return( [$class, \%hash] ) if( $serialiser eq 'Sereal' && Sereal::Encoder->VERSION <= version->parse( '4.023' ) );
        # But Storable want a list with the first element being the serialised element
        CORE::return( $class, \%hash );
    }

    sub STORABLE_freeze { return( shift->FREEZE( @_ ) ); }

    sub STORABLE_thaw { return( shift->THAW( @_ ) ); }

    # NOTE: CBOR will call the THAW method with the stored classname as first argument, the constant string CBOR as second argument, and all values returned by FREEZE as remaining arguments.
    # NOTE: Storable calls it with a blessed object it created followed with $cloning and any other arguments initially provided by STORABLE_freeze
    sub THAW
    {
        # STORABLE_thaw would issue $cloning as the 2nd argument, while CBOR would issue
        # 'CBOR' as the second value.
        my( $self, undef, @args ) = @_;
        my $ref = ( CORE::scalar( @args ) == 1 && CORE::ref( $args[0] ) eq 'ARRAY' ) ? CORE::shift( @args ) : \@args;
        my $class = ( CORE::defined( $ref ) && CORE::ref( $ref ) eq 'ARRAY' && CORE::scalar( @$ref ) > 1 ) ? CORE::shift( @$ref ) : ( CORE::ref( $self ) || $self );
        my $hash = CORE::ref( $ref ) eq 'ARRAY' ? CORE::shift( @$ref ) : {};
        my $new;
        # Storable pattern requires to modify the object it created rather than returning a new one
        if( CORE::ref( $self ) )
        {
            foreach( CORE::keys( %$hash ) )
            {
                $self->{ $_ } = CORE::delete( $hash->{ $_ } );
            }
            $new = $self;
        }
        else
        {
            $new = CORE::bless( $hash => $class );
        }
        CORE::return( $new );
    }
}

{
    # NOTE: Module::Generic::Scalar::Tie class
    package
        Module::Generic::Scalar::Tie;
    BEGIN
    {
        use strict;
        use warnings;
        use vars qw( $LOCK );
        use Config;
        use Scalar::Util ();
        use constant HAS_THREADS => $Config{useithreads};
        use constant IN_THREAD => ( $Config{useithreads} && threads->tid != 0 );
        if( HAS_THREADS )
        {
            require threads;
            require threads::shared;
            threads->import();
            threads::shared->import();
            my $lock :shared;
            $LOCK = \$lock;
        }
    };

    our $dummy_callback = sub{1};

    sub TIESCALAR
    {
        my( $class, $opts ) = @_;
        $opts //= {};
        if( ( Scalar::Util::reftype( $opts ) // '' ) ne 'HASH' )
        {
            warn( "Options provided (", overload::StrVal( $opts ), ") is not an hash reference\n" );
            $opts = {};
        }
        $opts->{data} //= '';
        $opts->{debug} //= 0;
        if( CORE::length( $opts->{add} ) && ref( $opts->{add} ) ne 'CODE' )
        {
            warnings::warn( "Code provided for the scalar add callback is not a code reference.\n" ) if( warnings::enabled( 'Module::Generic::Scalar' ) || $opts->{debug} );
            return;
        }
        if( CORE::length( $opts->{remove} ) && ref( $opts->{remove} ) ne 'CODE' )
        {
            warnings::warn( "Code provided for the scalar remove callback is not a code reference.\n" ) if( warnings::enabled( 'Module::Generic::Scalar' ) || $opts->{debug} );
            return;
        }

        my $data = ( ( Scalar::Util::reftype( $opts->{data} ) // '' ) eq 'SCALAR' ? \"${$opts->{data}}" : \undef );
        if( HAS_THREADS )
        {
            threads::shared::share( $data );
        }
        my $ref =
        {
            callback_add => $opts->{add},
            callback_remove => $opts->{remove},
            data => $data,
            debug => $opts->{debug},
        };
        print( STDERR ( ref( $class ) || $class ), "::TIESCALAR: Using ", CORE::length( ${$ref->{data}} ), " bytes of data in scalar vs ", CORE::length( ${$opts->{data}} ), " bytes received via opts->data.\n" ) if( $ref->{debug} );
        return( bless( $ref => ( ref( $class ) || $class ) ) );
    }

    sub FETCH
    {
        my $self = shift( @_ );
        lock( $LOCK ) if( IN_THREAD );
        return( ${$self->{data}} );
    }

    sub STORE
    {
        my( $self, $value ) = @_;
        my $index = 0;
        my $rv;
        # New value is smaller than our current, so this is a removal. It could be partial or total
        if( CORE::length( "$value" ) < CORE::length( ${$self->{data}} ) )
        {
            my $cb = $self->{callback_remove} || $dummy_callback;
            if( !$cb )
            {
                warnings::warn( "No callback remove found. This should not happen.\n" ) if( warnings::enabled( 'Module::Generic::Scalar' ) || $self->{debug} );
                $rv = 1;
            }
            else
            {
                $rv = $cb->({ type => 'remove', removed => \"${$self->{data}}", added => \$value });
            }
        }
        else
        {
            my $cb = $self->{callback_add} || $dummy_callback;
            if( !$cb )
            {
                warnings::warn( "No callback add found. This should not happen.\n" ) if( warnings::enabled( 'Module::Generic::Scalar' ) || $self->{debug} );
                $rv = 1;
            }
            else
            {
                $rv = $cb->({ type => 'add', added => \$value });
            }
        }

        print( STDERR ref( $self ), "::STORE: adding ", CORE::length( "$value" ), " bytes of data ($value) at position $index with current data of ", CORE::length( ${$self->{data}} ), " bytes (", ${$self->{data}}, ") -> callback returned ", ( defined( $rv ) ? 'true' : 'undef' ), "\n" ) if( $self->{debug} );
        return if( !defined( $rv ) );
        lock( $LOCK ) if( IN_THREAD );
        ${$self->{data}} = $value;
    }

    sub has_callback
    {
        my $self = shift( @_ );
        return(1) if( ref( $self->{callback_add} ) eq 'CODE' || ref( $self->{callback_remove} ) eq 'CODE' );
        return(0);
    }

    sub set_callback
    {
        my( $self, $what, $code ) = @_;
        if( !defined( $what ) )
        {
            warn( "No callback type was provided. Use \"add\" or \"remove\".\n" );
            return;
        }
        elsif( $what ne 'add' && $what ne 'remove' )
        {
            warn( "Unknown callback type was provided: '$what'. Use \"add\" or \"remove\".\n" );
            return;
        }
        elsif( !defined( $code ) )
        {
            warn( "No callback anonymous subroutine or subroutine reference was provided.\n" );
            return;
        }
        elsif( ref( $code ) ne 'CODE' )
        {
            warn( "Callback provided (", overload::StrVal( $code ), ") is not a code reference.\n" );
            return;
        }
        lock( $LOCK ) if( IN_THREAD );
        $self->{ "callback_${what}" } = $code;
        return(1);
    }

    sub unset_callback
    {
        my( $self, $what ) = @_;
        if( !defined( $what ) )
        {
            warn( "No callback type was provided. Use \"add\" or \"remove\".\n" );
            return;
        }
        elsif( $what ne 'add' && $what ne 'remove' )
        {
            warn( "Unknown callback type was provided: '$what'. Use \"add\" or \"remove\".\n" );
            return;
        }
        lock( $LOCK ) if( IN_THREAD );
        $self->{ "callback_${what}" } = undef;
        return(1);
    }
}

1;

__END__
