# NAME

Getopt::Class - Extended dictionary version of Getopt::Long

# SYNOPSIS

    use Getopt::Class;
    our $DEBUG = 0;
    our $VERBOSE = 0;
    our $VERSION = '0.1';
    my $dict =
    {
        create_user     => { type => 'boolean', alias => [qw(create_person create_customer)], action => 1 },
        create_product  => { type => 'boolean', action => 1 },
        debug           => { type => 'integer', default => \$DEBUG },
        # Can be enabled with --enable-recurse
        disable_recurse => { type => 'boolean', default => 1 },
        # Can be disabled also with --disable-logging
        enable_logging  => { type => 'boolean', default => 0 },
        help            => { type => 'code', code => sub{ pod2usage(1); }, alias => '?', action => 1 },
        man             => { type => 'code', code => sub{ pod2usage( -exitstatus => 0, -verbose => 2 ); }, action => 1 },
        quiet           => { type => 'boolean', default => 0, alias => 'silent' },
        verbose         => { type => 'boolean', default => \$VERBOSE, alias => 'v' },
        version         => { type => 'code', code => sub{ printf( "v%.2f\n", $VERSION ); }, action => 1 },
    
        api_server      => { type => 'string', default => 'api.example.com' },
        api_version     => { type => 'string', default => 1 },
        as_admin        => { type => 'boolean' },
        dry_run         => { type => 'boolean', default => 0 },
        
        # Can be enabled also with --with-zlib
        without_zlib    => { type => 'integer', default => 1 },
    
        name            => { type => 'string', class => [qw( person product )] },
        created         => { type => 'datetime', class => [qw( person product )] },
        define          => { type => 'string-hash', default => {} },
        langs           => { type => 'array', class => [qw( person product )], re => qr/^[a-z]{2}([_|-][A-Z]{2})?/, min => 1, default => [qw(en)] },
        currency        => { type => 'string', class => [qw(product)], name => 'currency', re => qr/^[a-z]{3}$/, error => "must be a three-letter iso 4217 value" },
        age             => { type => 'integer', class => [qw(person)], name => 'age', },
        path            => { type => 'file' },
        skip            => { type => 'file-array' },
        url             => { type => 'uri', package => 'URI' },
        urls            => { type => 'uri-array', package => 'URI::Fast' },
    };
    
    # Assuming command line arguments like:
    prog.pl --create-user --name Bob --langs fr ja --age 30 --created now --debug 3 \
            --path ./here/some/where --skip ./bad/directory ./not/here ./avoid/me/

    my $opt = Getopt::Class->new({
        dictionary => $dict,
    }) || die( Getopt::Class->error, "\n" );
    my $opts = $opt->exec || die( $opt->error, "\n" );
    $opt->required( [qw( name langs )] );
    my $err = $opt->check_class_data( 'person' );
    printf( "User is %s and is %d years old\n", $opts{qw( name age )} ) if( $opts->{debug} );

    # Get all the properties for class person
    my $props = $opt->class_properties( 'person' );

    # Get values collected for class 'person'
    if( $opts->{create_user} )
    {
        my $values = $opt->get_class_values( 'person' );
        # Having collected the values for our class of properties, and making sure all 
        # required are here, we can add them to database or make api calls, etc
    }
    elsif( $opts->{create_product} )
    {
        # etc...
    }
    
    # Or you can also access those values as object methods
    if( $opts->create_product )
    {
        $opts->langs->push( 'en_GB' ) if( !$opts->langs->length );
        printf( "Created on %s\n", $opts->created->iso8601 );
    }

# VERSION

    v1.1.0

# DESCRIPTION

[Getopt::Class](https://metacpan.org/pod/Getopt%3A%3AClass) is a lightweight wrapper around [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) that implements the idea of class of properties and makes it easier and powerful to set up [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong). This module is particularly useful if you want to provide several sets of options for different features or functions of your program. For example, you may have a part of your program that deals with user while another deals with product. Each of them needs their own properties to be provided.

# CONSTRUCTOR

## new

To instantiate a new [Getopt::Class](https://metacpan.org/pod/Getopt%3A%3AClass) object, pass an hash reference of following parameters:

- `dictionary`

    This is required. It must contain a key value pair where the value is an anonymous hash reference that can contain the following parameters:

    - `alias`

        This is an array reference of alternative options that can be used in an interchangeable way

            my $dict =
            {
            last_name => { type => 'string', alias => [qw( family_name surname )] },
            };
            # would make it possible to use either of the following combinations
            --last-name Doe
            # or
            --surname Doe
            # or
            --family-name Doe

    - `default`

        This contains the default value. For a string, this could be anything, and also a reference to a scalar, such as:

            our $DEBUG = 0;
            my $dict =
            {
            debug => { type => 'integer', default => \$DEBUG },
            };

        It can also be used to provide default value for an array, such as:

            my $dict =
            {
            langs => { type => 'array', class => [qw( person product )], re => qr/^[a-z]{2}([_|-][A-Z]{2})?/, min => 1, default => [qw(en)] },
            };

        But beware that if you provide a value, it will not superseed the existing default value, but add it on top of it, so

            --langs en fr ja

        would not produce an array with `en`, `fr` and `ja` entries, but an array such as:

            ['en', 'en', 'fr', 'ja' ]

        because the initial default value is not replaced when one is provided. This is a design from [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) and although I could circumvent this, I a not sure I should.

    - `error`

        A string to be used to set an error by ["check\_class\_data"](#check_class_data). Typically the string should provide meaningful information as to what the data should normally be. For example:

            my $dict =
            {
            currency => { type => 'string', class => [qw(product)], name => 'currency', re => qr/^[a-z]{3}$/, error => "must be a three-letter iso 4217 value" },
            };

    - `max`

        This is well explained in ["Options with multiple values" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#Options-with-multiple-values)

        It serves "to specify the minimal and maximal number of arguments an option takes".

    - `min`

        Same as above

    - `re`

        This must be a regular expression and is used by ["check\_class\_data"](#check_class_data) to check the sanity of the data provided by the user.
        So, for example:

            my $dict =
            {
            currency => { type => 'string', class => [qw(product)], name => 'currency', re => qr/^[a-z]{3}$/, error => "must be a three-letter iso 4217 value" },
            };

        then the user calls your program with, among other options:

            --currency euro

        would set an error that can be retrieved as an output of ["check\_class\_data"](#check_class_data)

    - `required`

        Set this to true or false (1 or 0) to instruct ["check\_class\_data"](#check_class_data) whether to check if it is missing or not.

        This is an alternative to the ["required"](#required) method which is used at an earlier stage, during ["exec"](#exec)

    - `type`

        Supported types are:

        - `array`

            This type will set the resulting value to be a [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object of values provided.

        - `boolean`

            If type is `boolean` and the key is either `with`, `without`, `enable`, `disable`, their counterpart will automatically be available as well, such as you can do, as show in the excerpt in the synopsis above:

                --enable-recurse --with-zlib

            Be careful though. If, in your dictionary, as shown in the synopsis, you defined `without_zlib` with a default value of true, then using the option `--with-zlib` will set that value to false. So in your application, you would need to check like this:

                if( $opts->{without_zlib} )
                {
                    # Do something
                }
                else
                {
                    # Do something else
                }

        - `code`

            Type code implies an anonymous sub routine and should be accompanied with the attribute _code_, such as:

                { type => 'code', code => sub{ pod2usage(1); exit( 0 ) }, alias => '?', action => 1 },

        - `datetime`

            This type will set the resulting value to be a [DateTime](https://metacpan.org/pod/DateTime) object of the value provided.

        - `decimal`

            This type will set the resulting value to be a [Module::Generic::Number](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3ANumber) object of the value provided.

        - `file`

            This type will mark the value as a directory or file path and will become a [Module::Generic::File](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AFile) object.

            This is particularly convenient when the user provided you with a relative path, such as:

                ./my_prog.pl --debug 3 --path ./here/

            And if you are not very careful and inadvertently change directory like when using [File::Find](https://metacpan.org/pod/File%3A%3AFind), then this relative path could lead to some unpleasant surprise.

            Setting this argument type to `file` ensure the resulting value is a [Module::Generic::File](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AFile), whose underlying file or directory will be resolved to their absolute path.

        - `file-array`

            Same as `file` argument type, but allows multiple value saved as an array. For example:

                ./my_prog.pl --skip ./not/here ./avoid/me/ ./skip/this/directory

            This would result in the option property `skip` being an [array object](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) containing 3 entries.

        - `hash`

            Type `hash` is convenient for free key-value pair such as:

                --define customer_id=10 --define transaction_id 123

            would result for `define` with an anonymous hash as value containing `customer_id` with value `10` and `transaction_id` with value `123`

        - `integer`

            This type will set the resulting value to be a [Module::Generic::Number](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3ANumber) object of the value provided.

        - `scalar`

            This type will set the resulting value to be a [Module::Generic::Scalar](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AScalar) object of the value provided.

        - `string`

            Same as `scalar`. This type will set the resulting value to be a [Module::Generic::Scalar](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AScalar) object of the value provided.

        - `string-hash`
        - `uri`

            This type will mark the value as a directory or file path and will become a [URI](https://metacpan.org/pod/URI) object, by default.

            You can override this default pacage, by using `package` property, such as:

                url => { type => 'uri', package => 'URI' }

        - `uri-array`

            Same as `uri` argument type, but allows multiple value saved as an array. For example:

                ./my_prog.pl --uris https://example.com/some/where https://example.com/some/where/else

            This would result in the option property `uris` being an [array object](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) containing 2 entries.

        Also as seen in the example above, you can add additional properties to be used in your program, here such as `action` that could be used to identify all options that are used to trigger an action or a call to a sub routine.

- `debug`

    This takes an integer, and is used to set the level of debugging. Anything under 3 will not provide anything meaningful.

# METHODS

## check\_class\_data

Provided with a string corresponding to a class name, this will check the data provided by the user.

Currently this means it checks if the data is present when the attribute _required_ is set, and it checks the data against a regular expression if one is provided with the attribute _re_

It returns an hash reference with 2 keys: _missing_ and _regexp_. Each with an anonymous hash reference with key matching the option name and the value the error string. So:

    my $dict =
    {
    name => { type => 'string', class => [qw( person product )], required => 1 },
    langs => { type => 'array', class => [qw( person product )], re => qr/^[a-z]{2}([_|-][A-Z]{2})?/, min => 1, default => [qw(en)] },
    };

Assuming your user calls your program without `--name` and with `--langs FR EN` this would have ["check\_class\_data"](#check_class_data) return the following data structure:

    $errors =
    {
    missing => { name => "name (name) is missing" },
    regexp => { langs => "langs (langs) does not match requirements" },
    };

## class

Provided with a string representing a property class, and this returns an hash reference of all the dictionary entries matching this class

## classes

This returns an hash reference containing class names, each of which has an anonymous hash reference with corresponding dictionary entries

## class\_properties

Provided with a string representing a class name, this returns an array reference of options, a.k.a. class properties.

The array reference is a [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object.

## configure

This calls ["configure" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#configure) with the ["configure\_options"](#configure_options).

It can be overriden by calling ["configure"](#configure) with an array reference.

If there is an error, it will return undef and set an ["error"](#error) accordingly.

Otherwise, it returns the [Getopt::Class](https://metacpan.org/pod/Getopt%3A%3AClass) object, so it can be chained.

## configure\_errors

This returns an array reference of the errors generated by [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) upon calling ["getoptions" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#getoptions) by ["exec"](#exec)

The array is an [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object

## configure\_options

This returns an array reference of the [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) configuration options upon calling ["configure" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#configure) by method ["configure"](#configure)

The array is an [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object

## dictionary

This returns the hash reference representing the dictionary set when the object was instantiated. See ["new"](#new) method.

## error

Return the last error set as a [Module::Generic::Exception](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AException) object. Because the object can be stringified, you can do directly:

    die( $opt->error, "\n" ); # with a stack trace

or

    die( sprintf( "Error occurred at line %d in file %s with message %s\n", $opt->error->line, $opt->error->file, $opt->error->message ) );

## exec

This calls ["getoptions" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#getoptions) with the ["options"](#options) hash reference and the ["parameters"](#parameters) array reference and after having called ["configure"](#configure) to configure [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) with the proper parameters according to the dictionary provided at the time of object instantiation.

If there are any [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) error, they can be retrieved with method ["configure\_errors"](#configure_errors)

    my $opt = Getopt::Class->new({ dictionary => $dict }) || die( Getopt::Class->error );
    my $opts = $opt->exec || die( $opt->error );
    if( $opt->configure_errors->length > 0 )
    {
        # do something about it
    }

If any required options have been specified with the method ["required"](#required), it will check any missing option then and set an array of those missing options that can be retrieved with method ["missing"](#missing)

This method makes sure that any option can be accessed with underscore or dash whichever, so a dictionary entry such as:

    my $dict =
    {
    create_customer => { type => 'boolean', alias => [qw(create_client create_user)], action => 1 },
    };

can be called by your user like:

    ---create-customer
    # or
    --create-client
    # or
    --create-user

because a duplicate entry with the underscore replaced by a dash is created (actually it's an alias of one to another). So you can say in your program:

    my $opts = $opt->exec || die( $opt->error );
    if( $opts->{create_user} )
    {
        # do something
    }

["exec"](#exec) returns an hash reference whose properties can be accessed directly, but those properties can also be accessed as methods.

This is made possible because the hash reference returned is a blessed object from [Getopt::Class::Values](https://metacpan.org/pod/Getopt%3A%3AClass%3A%3AValues) and provides an object oriented access to all the option values.

A string is an object from [Module::Generic::Scalar](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AScalar)

    $opts->customer_name->index( 'Doe' ) != -1

A boolean is an object from [Module::Generic::Boolean](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3ABoolean)

An integer or decimal is an object from [Text::Number](https://metacpan.org/pod/Text%3A%3ANumber)

A date/dateime value is an object from [DateTime](https://metacpan.org/pod/DateTime)

    $opts->created->iso8601 # 2020-05-01T17:10:20

An hash reference is an object created with ["\_set\_get\_hash\_as\_object" in Module::Generic](https://metacpan.org/pod/Module%3A%3AGeneric#set_get_hash_as_object)

    $opts->metadata->transaction_id

An array reference is an object created with ["\_set\_get\_array\_as\_object" in Module::Generic](https://metacpan.org/pod/Module%3A%3AGeneric#set_get_array_as_object)

    $opts->langs->push( 'en_GB' ) if( !$opts->langs->exists( 'en_GB' ) );
    $opts->langs->forEach(sub{
        $self->active_user_lang( shift( @_ ) );
    });

Whatever the object type of the option value is based on the dictionary definitions you provide to ["new"](#new)

## get\_class\_values

Provided with a string representing a property class, and this returns an hash reference of all the key-value pairs provided by your user. So:

    my $dict =
    {
    create_customer => { type => 'boolean', alias => [qw(create_client create_user)], action => 1 },
    name        => { type => 'string', class => [qw( person product )] },
    created     => { type => 'datetime', class => [qw( person product )] },
    define      => { type => 'string-hash', default => {} },
    langs       => { type => 'array', class => [qw( person product )], re => qr/^[a-z]{2}([_|-][A-Z]{2})?/, min => 1, default => [] },
    currency    => { type => 'string', class => [qw(product)], name => 'currency', re => qr/^[a-z]{3}$/, error => "must be a three-letter iso 4217 value" },
    age         => { type => 'integer', class => [qw(person)], name => 'age', },
    };

Then the user calls your program with:

    --create-user --name Bob --age 30 --langs en ja --created now

    # In your app
    my $opt = Getopt::Class->new({ dictionary => $dict }) || die( Getopt::Class->error );
    my $opts = $opt->exec || die( $opt->error );
    # $vals being an hash reference as a subset of all the values returned in $opts above
    my $vals = $opt->get_class_values( 'person' )
    # returns an hash only with keys name, age, langs and created

## getopt

Sets or get the [Getopt::Long::Parser](https://metacpan.org/pod/Getopt%3A%3ALong%3A%3AParser) object. You can provide yours if you want but beware that certain options are necessary for [Getopt::Class](https://metacpan.org/pod/Getopt%3A%3AClass) to work. You can check those options with the method ["configure\_options"](#configure_options)

## missing

Returns an array of missing options. The array reference returned is a [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object, so you can do thins like

    if( $opt->missing->length > 0 )
    {
        # do something
    }

## options

Returns an hash reference of options created by ["new"](#new) based on the dictionary you provide. This hash reference is used by ["exec"](#exec) to call ["getoptions" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#getoptions)

## parameters

Returns an array reference of parameters created by ["new"](#new) based on the dictionary you provide. This hash reference is used by ["exec"](#exec) to call ["getoptions" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#getoptions)

This array reference is a [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object

## required

Set or get the array reference of required options. This returns a [Module::Generic::Array](https://metacpan.org/pod/Module%3A%3AGeneric%3A%3AArray) object.

## usage

Set or get the anonymous subroutine or sub routine reference used to show the user the proper usage of your program.

This is called by ["exec"](#exec) after calling ["getoptions" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#getoptions) if there is an error, i.e. if ["getoptions" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#getoptions) does not return a true value.

If you use object to call the sub routine usage, I recommend using the module [curry](https://metacpan.org/pod/curry)

If this is not set, ["exec"](#exec) will simply return undef or an empty list depending on the calling context.

# ERROR HANDLING

This module never dies, or at least not by design. If an error occurs, each method returns undef and sets an error that can be retrieved with the method ["error"](#error)

# AUTHOR

Jacques Deguest <`jack@deguest.jp`>

# SEE ALSO

[Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)

# COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.
