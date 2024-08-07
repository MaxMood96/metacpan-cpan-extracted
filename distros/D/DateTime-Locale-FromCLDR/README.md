# NAME

DateTime::Locale::FromCLDR - DateTime Localised Data from Unicode CLDR

# SYNOPSIS

    use DateTime::Locale::FromCLDR;
    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP' ) ||
        die( DateTime::Locale::FromCLDR->error );
    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP', calendar => 'japanese' ) ||
        die( DateTime::Locale::FromCLDR->error );
    my $array = $locale->am_pm_abbreviated;
    my $array = $locale->available_formats;
    $locale->calendar( 'hebrew' );
    my $str = $locale->calendar;
    # a Locale::Unicode object that stringifies to the initial locale value (ja-Kana-JP)
    my $obj = $locale->code;
    my $str = $locale->date_at_time_format_full;
    my $str = $locale->date_at_time_format_long;
    my $str = $locale->date_at_time_format_medium;
    my $str = $locale->date_at_time_format_short;
    my $str = $locale->date_format_default;
    my $str = $locale->date_format_full;
    my $str = $locale->date_format_long;
    my $str = $locale->date_format_medium;
    my $str = $locale->date_format_short;
    my $str = $locale->date_formats;
    my $str = $locale->datetime_format;
    my $str = $locale->datetime_format_default;
    my $str = $locale->datetime_format_full;
    my $str = $locale->datetime_format_long;
    my $str = $locale->datetime_format_medium;
    my $str = $locale->datetime_format_short;
    my $str = $locale->day_format_abbreviated;
    my $str = $locale->day_format_narrow;
    my $str = $locale->day_format_short;
    my $str = $locale->day_format_wide;
    my $str = $locale->day_period_format_abbreviated( $datetime_object );
    my $str = $locale->day_period_format_narrow( $datetime_object );
    my $str = $locale->day_period_format_wide( $datetime_object );
    my $str = $locale->day_period_stand_alone_abbreviated( $datetime_object );
    my $str = $locale->day_period_stand_alone_narrow( $datetime_object );
    my $str = $locale->day_period_stand_alone_wide( $datetime_object );
    my $hashref = $locale->day_periods;
    my $str = $locale->day_stand_alone_abbreviated;
    my $str = $locale->day_stand_alone_narrow;
    my $str = $locale->day_stand_alone_short;
    my $str = $locale->day_stand_alone_wide;
    my $str = $locale->default_date_format_length;
    my $str = $locale->default_time_format_length;
    my $str = $locale->era_abbreviated;
    my $str = $locale->era_narrow;
    my $str = $locale->era_wide;
    my $str = $locale->first_day_of_week;
    my $str = $locale->format_for( 'yMEd' );
    # Alias for method 'code'
    my $obj = $locale->id;
    my $array = $locale->interval_format( GyMEd => 'd' );
    my $hashref = $locale->interval_formats;
    my $greatest_diff = $locale->interval_greatest_diff( $datetime_object_1, $datetime_object_2 );
    my $str = $locale->language;
    my $str = $locale->language_code;
    # Alias for method 'language_code'
    my $str = $locale->language_id;
    # Locale::Unicode object
    my $obj = $locale->locale;
    # Equivalent to $locale->locale->as_string
    my $str = $locale->locale_as_string;
    # As per standard, it falls back to 'wide' format if it is not available
    my $str = $locale->month_format_abbreviated;
    my $str = $locale->month_format_narrow;
    my $str = $locale->month_format_wide;
    my $str = $locale->month_stand_alone_abbreviated;
    my $str = $locale->month_stand_alone_narrow;
    my $str = $locale->month_stand_alone_wide;
    # Language name in English. Here: Japanese
    my $str = $locale->name;
    # Alias for the method 'native_name'
    my $str = $locale->native_language;
    # Language name in the locale's original language. Here: 日本語
    my $str = $locale->native_name;
    # The local's script name in the locale's original language. Here: カタカナ
    my $str = $locale->native_script;
    # The local's territory name in the locale's original language. Here: 日本
    my $str = $locale->native_territory;
    # The local's variant name in the locale's original language. Here: undef since there is none
    my $str = $locale->native_variant;
    my $str = $locale->native_variants;
    # Returns 1 or 0
    my $bool = $locale->prefers_24_hour_time;
    my $str = $locale->quarter_format_abbreviated;
    my $str = $locale->quarter_format_narrow;
    my $str = $locale->quarter_format_wide;
    my $str = $locale->quarter_stand_alone_abbreviated;
    my $str = $locale->quarter_stand_alone_narrow;
    my $str = $locale->quarter_stand_alone_wide;
    # The locale's script name in English. Here: Katakana
    my $str = $locale->script;
    # The locale's script ID, if any. Here: Kana
    my $str = $locale->script_code;
    # Alias for method 'script_code'
    my $str = $locale->script_id;
    # The locale's territory name in English. Here: Japan
    my $str = $locale->territory;
    # The locale's territory ID, if any. Here: JP
    my $str = $locale->territory_code;
    # Alias for method 'territory_code'
    my $str = $locale->territory_id;
    my $str = $locale->time_format_default;
    my $str = $locale->time_format_full;
    my $str = $locale->time_format_long;
    my $str = $locale->time_format_medium;
    my $str = $locale->time_format_short;
    # Time patterns for 'full', 'long', 'medium', and 'short' formats
    my $array = $locale->time_formats;
    # The locale's variant name, if any, in English. Here undef, because there is none
    my $str = $locale->variant;
    # The locale's variant ID, if any. Here undef, since there is none
    my $str = $locale->variant_code;
    # Alias for method 'variant_code'
    my $str = $locale->variant_id;
    my $array = $locale->variants;
    # The CLDR data version. For example: 45.0
    my $str = $locale->version;

    # To get DateTime to use DateTime::Locale::FromCLDR for the locale data
    my $dt = DateTime->now(
        locale => DateTime::Locale::FromCLDR->new( 'en' ),
    );

# VERSION

    v0.1.1

# DESCRIPTION

This is a powerful replacement for [DateTime::Locale](https://metacpan.org/pod/DateTime%3A%3ALocale) and [DateTime::Locale::FromData](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromData) that use static data from over 1,000 pre-generated modules, whereas [DateTime::Locale::FromCLDR](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromCLDR) builds a `locale` object to access its Unicode [CLDR](https://cldr.unicode.org/) (Common Locale Data Repository) data from SQLite data made available with [Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData)

It provides the same API as [DateTime::Locale](https://metacpan.org/pod/DateTime%3A%3ALocale), but in a dynamic way. This is important since in the Unicode [LDML specifications](https://unicode.org/reports/tr35/), a `locale` inherits from its parent's data.

Once a data is retrieved by a method, it is cached to avoid waste of time.

It also adds a few methods to access the `locale` [at time patterns](https://unicode.org/reports/tr35/tr35-dates.html#dateTimeFormats), such as [date\_at\_time\_format\_full](#date_at_time_format_full), and [native\_variants](#native_variants)

It also provides key support for [day period](https://unicode.org/reports/tr35/tr35-dates.html#Day_Period_Rule_Sets)

It also provides support for interval datetime, and [a method to find the greatest datetime difference element between 2 datetimes](#interval_greatest_diff), as well as a method to get all the [available format patterns for intervals](#interval_formats), and a [method to retrieve the components of an specific interval patterns](#interval_format)

It adds the `short` format for day missing in [DateTime::Locale::FromData](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromData)

Note that in `CLDR` parlance, there are standard pattern formats. For example `full`, `long`, `medium`, `short` or also `abbreviated`, `short`, `wide`, `narrow` providing various level of conciseness.

# CONSTRUCTOR

## new

    # Japanese as spoken in Japan
    my $locale = DateTime::Locale::FromCLDR->new( 'ja-JP' ) ||
        die( DateTime::Locale::FromCLDR->error );
    # Okinawan as spoken in the Japan Southern island
    my $locale = DateTime::Locale::FromCLDR->new( 'ryu-Kana-JP-t-de-t0-und-x0-medical' ) ||
        die( DateTime::Locale::FromCLDR->error );

    use Locale::Unicode;
    my $loc = Locale::Unicode->new( 'fr-FR' );
    my $locale = DateTime::Locale::FromCLDR->new( $loc ) ||
        die( DateTime::Locale::FromCLDR->error );

Specifying a calendar ID other than the default `gregorian`:

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-JP', calendar => 'japanese' ) ||
        die( DateTime::Locale::FromCLDR->error );

or, using an hash reference:

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-JP', { calendar => 'japanese' } ) ||
        die( DateTime::Locale::FromCLDR->error );

Instantiate a new [DateTime::Locale::FromCLDR](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromCLDR) object based on a `locale` provided, and returns it. By default, it uses the calendar `gregorian`, but you can specify a different one with the `calendar` option.

You can provide any `locale`, even complex one as shown above, and only its core part will be retailed. So, for example:

    my $locale = DateTime::Locale::FromCLDR->new( 'ryu-Kana-JP-t-de-t0-und-x0-medical' ) ||
        die( DateTime::Locale::FromCLDR->error );
    say $locale; # ryu-Kana-JP

If an error occurs, it sets an [exception object](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromCLDR%3A%3AException) and returns `undef` in scalar context, or an empty list in list context, or possibly a special `DateTime::Locale::FromCLDR::NullObject` in object context. See ["error"](#error) for more information.

The object is overloaded and stringifies into the core part of the original string provided upon instantiation.

The core part is comprised of the `language` ID, an optional `script` ID, an optional `territory` ID and zero or multiple `variant` IDs. See [Locale::Unicode](https://metacpan.org/pod/Locale%3A%3AUnicode) and the [LDML specifications](https://unicode.org/reports/tr35/tr35.html#Locale) for more information.

# METHODS

All methods are read-only unless stated otherwise.

## am\_pm\_abbreviated

    my $array = $locale->am_pm_abbreviated;

Returns an array reference of the terms used to represent `am` and `pm`

The array reference could be empty if the `locale` does not support specifying `am`/`pm`

For example:

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $ampm = $locale->am_pm_abbreviated
    say @$ampm; # AM, PM

    my $locale = DateTime::Locale::FromCLDR->new( 'ja' );
    my $ampm = $locale->am_pm_abbreviated
    say @$ampm; # 午前, 午後

    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    my $ampm = $locale->am_pm_abbreviated
    say @$ampm; # Empty

See ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term)

## available\_formats

    my $array = $locale->available_formats;

Returns an array reference of all the format ID available for this `locale`

See ["calendar\_available\_format" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_available_format)

## calendar

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP', calendar => 'japanese' ) ||
        die( DateTime::Locale::FromCLDR->error );
    my $str = $locale->calendar; # japanese
    $locale->calendar( 'gregorian' );

Sets or gets the [calendar ID](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar) used to perform queries along with the given `locale`

## code

    my $obj = $locale->code;

Returns the [Locale::Unicode](https://metacpan.org/pod/Locale%3A%3AUnicode) object either received or created upon object instantiation.

## date\_at\_time\_format\_full

    my $str = $locale->date_at_time_format_full;

Returns the full [date at time pattern](https://unicode.org/reports/tr35/tr35-dates.html#dateTimeFormats)

For example:

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_at_time_format_full;
    # EEEE, MMMM d, y 'at' h:mm:ss a zzzz
    # Tuesday, July 23, 2024 at 1:26:38 AM UTC

    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->date_at_time_format_full;
    # EEEE d MMMM y 'à' HH:mm:ss zzzz
    # mardi 23 juillet 2024 à 01:27:11 UTC

## date\_at\_time\_format\_long

Same as [date\_at\_time\_format\_full](#date_at_time_format_full), but returns the long format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_at_time_format_long;
    # MMMM d, y 'at' h:mm:ss a z
    # July 23, 2024 at 1:26:11 AM UTC

## date\_at\_time\_format\_medium

Same as [date\_at\_time\_format\_full](#date_at_time_format_full), but returns the medium format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_at_time_format_medium;
    # MMM d, y 'at' h:mm:ss a
    # Jul 23, 2024 at 1:25:43 AM

## date\_at\_time\_format\_short

Same as [date\_at\_time\_format\_full](#date_at_time_format_full), but returns the short format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_at_time_format_short;
    # M/d/yy 'at' h:mm a
    # 7/23/24 at 1:25 AM

## date\_format\_default

This is an alias to [date\_format\_medium](#date_format_medium)

## date\_format\_full

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_format_full;
    # EEEE, MMMM d, y
    # Tuesday, July 23, 2024

Returns the [full date pattern](https://unicode.org/reports/tr35/tr35-dates.html#dateFormats)

See also ["calendar\_format\_l10n" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_format_l10n)

## date\_format\_long

Same as [date\_format\_full](#date_format_full), but returns the long format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_format_long;
    # MMMM d, y
    # July 23, 2024

## date\_format\_medium

Same as [date\_format\_full](#date_format_full), but returns the medium format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_format_long;
    # MMM d, y
    # Jul 23, 2024

## date\_format\_short

Same as [date\_format\_full](#date_format_full), but returns the short format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->date_format_short;
    # M/d/yy
    # 7/23/24

## date\_formats

    my $now = DateTime->now( locale => 'en' );
    my $ref = $locale->date_formats;
    foreach my $type ( sort( keys( %$ref ) ) )
    {
        say $type, ":";
        say $ref->{ $type };
        say $now->format_cldr( $ref->{ $type } ), "\n";
    }

Would produce:

    full:
    EEEE, MMMM d, y
    Tuesday, July 23, 2024

    long:
    MMMM d, y
    July 23, 2024

    medium:
    MMM d, y
    Jul 23, 2024

    short:
    M/d/yy
    7/23/24

Returns an hash reference with the keys being: `full`, `long`, `medium`, `short` and their value the result of their associated date format methods.

## datetime\_format

This is an alias for [datetime\_format\_medium](#datetime_format_medium)

## datetime\_format\_default

This is also an alias for [datetime\_format\_medium](#datetime_format_medium)

## datetime\_format\_full

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->datetime_format_full;
    # EEEE, MMMM d, y, h:mm:ss a zzzz
    # Tuesday, July 23, 2024, 1:53:27 AM UTC

Returns the [full datetime pattern](https://unicode.org/reports/tr35/tr35-dates.html#dateTimeFormats)

See also ["calendar\_datetime\_format" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_datetime_format)

## datetime\_format\_long

Same as [datetime\_format\_full](#datetime_format_full), but returns the long format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->datetime_format_long;
    # MMMM d, y, h:mm:ss a z
    # July 23, 2024, 1:57:02 AM UTC

## datetime\_format\_medium

Same as [datetime\_format\_full](#datetime_format_full), but returns the medium format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->datetime_format_medium;
    # MMM d, y, h:mm:ss a
    # Jul 23, 2024, 2:03:16 AM

## datetime\_format\_short

Same as [datetime\_format\_full](#datetime_format_full), but returns the short format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->datetime_format_short;
    # M/d/yy, h:mm a
    # 7/23/24, 2:04 AM

## day\_format\_abbreviated

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_format_abbreviated;
    say @$days;
    # Mon, Tue, Wed, Thu, Fri, Sat, Sun

Returns an array reference of week day names abbreviated format with Monday first and Sunday last.

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term)

## day\_format\_narrow

Same as [day\_format\_abbreviated](#day_format_abbreviated), but returns the narrow format days.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_format_abbreviated;
    say @$days;
    # M, T, W, T, F, S, S

## day\_format\_short

Same as [day\_format\_abbreviated](#day_format_abbreviated), but returns the short format days.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_format_short;
    say @$days;
    # Mo, Tu, We, Th, Fr, Sa, Su

## day\_format\_wide

Same as [day\_format\_abbreviated](#day_format_abbreviated), but returns the wide format days.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_format_wide;
    say @$days;
    # Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday

## day\_period\_format\_abbreviated

    my $dt = DateTime->new( year => 2024, hour => 7 );
    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->day_period_format_abbreviated( $dt );
    # in the morning

    my $dt = DateTime->new( year => 2024, hour => 13 );
    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->day_period_format_abbreviated( $dt );
    # in the afternoon

    my $dt = DateTime->new( year => 2024, hour => 7 );
    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP' );
    say $locale->day_period_format_abbreviated( $dt );
    # 朝
    # which means "morning" in Japanese

    my $dt = DateTime->new( year => 2024, hour => 13 );
    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->day_period_format_abbreviated( $dt );
    # après-midi

Returns a string representing the localised expression of the period of day the [DateTime](https://metacpan.org/pod/DateTime) object provided is.

If nothing relevant could be found somehow, this will return an empty string. `undef` is returned only if an error occurred.

This is used to provide the relevant value for the token `B` or `b` in the [Unicode LDML format patterns](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#Format-Patterns)

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term), ["day\_period" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#day_period) and [DateTime::Format::Unicode](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AUnicode)

## day\_period\_format\_narrow

Same as [day\_period\_format\_abbreviated](#day_period_format_abbreviated), but returns the narrow format of day period.

    my $dt = DateTime->new( year => 2024, hour => 7 );
    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->day_period_format_narrow( $dt );
    # in the morning

## day\_period\_format\_wide

Same as [day\_period\_format\_abbreviated](#day_period_format_abbreviated), but returns the wide format of day period.

    my $dt = DateTime->new( year => 2024, hour => 7 );
    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->day_period_format_wide( $dt );
    # in the morning

## day\_period\_stand\_alone\_abbreviated

    my $dt = DateTime->new( year => 2024, hour => 7 );
    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->day_period_stand_alone_abbreviated( $dt );
    # morning

    my $dt = DateTime->new( year => 2024, hour => 13 );
    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->day_period_stand_alone_abbreviated( $dt );
    # afternoon

    my $dt = DateTime->new( year => 2024, hour => 7 );
    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP' );
    say $locale->day_period_stand_alone_abbreviated( $dt );
    # ""

The previous example would yield nothing, and as per [the LDML specifications](https://unicode.org/reports/tr35/tr35-dates.html#dfst-period), you would need to use the localised AM/PM instead.

    my $dt = DateTime->new( year => 2024, hour => 13 );
    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->day_period_stand_alone_abbreviated( $dt );
    # ap.m.

Returns a string representing the localised expression of the period of day the [DateTime](https://metacpan.org/pod/DateTime) object provided is.

If nothing relevant could be found somehow, this will return an empty string. `undef` is returned only if an error occurred.

This is used to provide a stand-alone word that can be used as a title, or in a different context.

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term), ["day\_period" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#day_period) and [DateTime::Format::Unicode](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AUnicode)

## day\_period\_stand\_alone\_narrow

Same as [day\_period\_stand\_alone\_abbreviated](#day_period_stand_alone_abbreviated), but returns the narrow stand-alone version of the day period.

    my $dt = DateTime->new( year => 2024, hour => 13 );
    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->day_period_stand_alone_narrow( $dt );
    # ap.m.

## day\_period\_stand\_alone\_wide

Same as [day\_period\_stand\_alone\_abbreviated](#day_period_stand_alone_abbreviated), but returns the wide stand-alone version of the day period.

    my $dt = DateTime->new( year => 2024, hour => 13 );
    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->day_period_stand_alone_wide( $dt );
    # après-midi

## day\_periods

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $hash = $locale->day_periods;
    # Would return an hash reference like:
    {
        midnight => ["00:00", "00:00"],
        morning1 => ["06:00", "12:00"],
        noon => ["12:00", "12:00"],
        afternoon1 => ["12:00", "18:00"],
        evening1 => ["18:00", "21:00"],
        night1 => ["21:00", "06:00"],
    }

Returns an hash reference of day period token and values of 2-elements array (start time and end time in hours and minutes)

## day\_stand\_alone\_abbreviated

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_stand_alone_abbreviated;
    say @$days;
    # Mon, Tue, Wed, Thu, Fri, Sat, Sun

Returns an array reference of week day names in abbreviated format with Monday first and Sunday last.

This is often identical to the `format` type.

See the [LDML specifications](https://unicode.org/reports/tr35/tr35-dates.html#months_days_quarters_eras) for more information on the difference between the `format` and `stand-alone` types.

## day\_stand\_alone\_narrow

Same as [day\_stand\_alone\_abbreviated](#day_stand_alone_abbreviated), but returns the narrow format days.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_stand_alone_narrow;
    say @$days;
    # M, T, W, T, F, S, S

## day\_stand\_alone\_short

Same as [day\_stand\_alone\_abbreviated](#day_stand_alone_abbreviated), but returns the short format days.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_stand_alone_short;
    say @$days;
    # Mo, Tu, We, Th, Fr, Sa, Su

## day\_stand\_alone\_wide

Same as [day\_stand\_alone\_abbreviated](#day_stand_alone_abbreviated), but returns the wide format days.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $days = $locale->day_stand_alone_wide;
    say @$days;
    # Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday

## default\_date\_format\_length

This returns the string `medium`

## default\_time\_format\_length

This returns the string `medium`

## era\_abbreviated

    my $array = $locale->era_abbreviated;
    say @$array;
    # BC, AD

Returns an array reference of era names in abbreviated format.

See also ["calendar\_eras\_l10n" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_eras_l10n)

## era\_narrow

Same as [era\_abbreviated](#era_abbreviated), but returns the narrow format eras.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->era_narrow;
    say @$array;
    # B, A

## era\_wide

Same as [era\_abbreviated](#era_abbreviated), but returns the wide format eras.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->era_wide;
    say @$array;
    # Before Christ, Anno Domini

## error

Used as a mutator, this sets an [exception object](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromCLDR%3A%3AException) and returns an `DateTime::Locale::FromCLDR::NullObject` in object context (such as when chaining), or `undef` in scalar context, or an empty list in list context.

The `DateTime::Locale::FromCLDR::NullObject` class prevents the perl error of `Can't call method "%s" on an undefined value` (see [perldiag](https://metacpan.org/pod/perldiag)). Upon the last method chained, `undef` is returned in scalar context or an empty list in list context.

## first\_day\_of\_week

    my $integer = $locale->first_day_of_week;

Returns an integer ranging from 1 to 7 where 1 means Monday and 7 means Sunday.

This represents what is the first day of the week for this `locale`

Since the information on the first day of the week pertains to a `territory`, if the `locale` you provided does not have such information, this method will find out the [likely subtag](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#likely_subtag) to get the `locale`'s rightful `territory`

See the [LDML specifications about likely subtags](https://unicode.org/reports/tr35/tr35.html#Likely_Subtags) for more information.

For example:

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );

Since there is no `territory` associated, this will look up the likely subtag to find the target `locale` is `en-Latn-US`, and thus the `territory` for `en` is `US` and first day of the week is `7`

Another example:

    my $locale = DateTime::Locale::FromCLDR->new( 'fr-Latn' );

This will ultimately get the territory `FR` and first day of the week is `1`

    # Okinawan as spoken in the Japanese Southern islands
    my $locale = DateTime::Locale::FromCLDR->new( 'ryu' );

This will become `ryu-Kana-JP` and thus the `territory` would be `JP` and first day of the week is `7`

This information is cached in the current object, like for all the other methods in this API.

## format\_for

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $pattern = $locale->format_for( 'Bhm' );

Provided with the format ID of an [available format](#available_formats) and this will return the localised `CLDR` pattern.

Keep in mind that the `CLDR` formatting method of [DateTime](https://metacpan.org/pod/DateTime#format_cldr) does not recognise all the `CLDR` pattern tokens. Thus, for example, if you chose the standard available pattern `Bhm`, this method would return the localised pattern `h:mm B`. However, [DateTime](https://metacpan.org/pod/DateTime) does not understand the token `B`

    my $now = DateTime->now( locale => "en", time_zone => "Asia/Tokyo" );
    # Assuming $now = 2024-07-23T21:39:39
    say $now->format_cldr( 'h:mm B' );
    # 9:39 B

But `B` is the day period, which can be looked up with ["day\_period" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#day_period), which provides us with the day period token `night1`, which itself can be looked up with ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term) and gives us the localised string `at night`. Thus the proper `CLDR` formatting really should be `9:39 at night`

You can use [DateTime::Format::Unicode](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AUnicode) instead of the default [DateTime](https://metacpan.org/pod/DateTime) `CLDR` formatting if you want to get better support for all [CLDR pattern tokens](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#Format-Patterns).

With Japanese:

    my $locale = DateTime::Locale::FromCLDR->new( 'ja' );
    my $pattern = $locale->format_for( 'Bhm' );
    # BK:mm
    my $now = DateTime->now( locale => "ja", time_zone => "Asia/Tokyo" );
    say $now->format_cldr( 'BK:mm' );
    # B9:54

But, this should have yielded: `夜9:54` instead.

## id

This is an alias for [locale](#locale)

## interval\_format

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->interval_format( GyMEd => 'G' );
    # ["E, M/d/y G", " – ", "E, M/d/y G", "E, M/d/y G – E, M/d/y G"]
    my $array = $locale->interval_format( GyMEd => 'M' );
    # ["E, M/d/y", " – ", "E, M/d/y G", "E, M/d/y – E, M/d/y G"]
    my $array = $locale->interval_format( GyMEd => 'd' );
    # ["E, M/d/y", " – ", "E, M/d/y G", "E, M/d/y – E, M/d/y G"]
    my $array = $locale->interval_format( GyMEd => 'y' );
    # ["E, M/d/y", " – ", "E, M/d/y G", "E, M/d/y – E, M/d/y G"]

Provided with a format ID and a [greatest difference token](#interval_greatest_diff), and this will return an array reference composed of the following 4 elements:

- 1. the first part
- 2. the separator
- 3. the second part
- 4. the [full interval pattern](https://unicode.org/reports/tr35/tr35-dates.html#intervalFormats)

If nothing is found for the given format ID and greatest difference token, an empty array reference will be returned.

If an error occurred, this will set an [error object](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromCLDR%3A%3AException) and return `undef` in scalar context and an empty list.

With [DateTime::Format::Unicode](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AUnicode), you can do something like:

    my $fmt = DateTime::Format::Unicode->new(
        pattern => 'GyMEd',
        locale  => 'en',
    );
    my $str = $fmt->format_interval( $dt1, $dt2 );

This will use this method [interval\_format](#interval_format)

If nothing is found, you can use the fallback pattern, which is something like this (varies from `locale` to `locale`): `{0} - {1}`

    my $array = $locale->interval_format( default => 'default' );
    # ["{0}", " - ", "{1}", "{0} - {1}"]

However, note that not all locales have a fallback pattern, so even the query above may return an empty array.

For example, as of version `45.0` (2024) of the `CLDR` data:

    # German:
    my $locale = DateTime::Locale::FromCLDR->new( 'de' );
    my $array = $locale->interval_format( default => 'default' );
    # []

    # French:
    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    my $array = $locale->interval_format( default => 'default' );
    # []

    # Italian:
    my $locale = DateTime::Locale::FromCLDR->new( 'it' );
    my $array = $locale->interval_format( default => 'default' );
    # []

## interval\_formats

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $ref = $locale->interval_formats;

This would return something like:

    {
        Bh => [qw( B h )],
        Bhm => [qw( B h m )],
        d => ["d"],
        default => ["default"],
        Gy => [qw( G y )],
        GyM => [qw( G M y )],
        GyMd => [qw( d G M y )],
        GyMEd => [qw( d G M y )],
        GyMMM => [qw( G M y )],
        GyMMMd => [qw( d G M y )],
        GyMMMEd => [qw( d G M y )],
        H => ["H"],
        h => [qw( a h )],
        hm => [qw( a h m )],
        Hm => [qw( H m )],
        hmv => [qw( a h m )],
        Hmv => [qw( H m )],
        Hv => ["H"],
        hv => [qw( a h )],
        M => ["M"],
        Md => [qw( d M )],
        MEd => [qw( d M )],
        MMM => ["M"],
        MMMd => [qw( d M )],
        MMMEd => [qw( d M )],
        y => ["y"],
        yM => [qw( M y )],
        yMd => [qw( d M y )],
        yMEd => [qw( d M y )],
        yMMM => [qw( M y )],
        yMMMd => [qw( d M y )],
        yMMMEd => [qw( d M y )],
        yMMMM => [qw( M y )],
    }

Returns an hash reference of all available interval format IDs and their associated [greatest difference token](https://unicode.org/reports/tr35/tr35-dates.html#intervalFormats)

The `default` interval format pattern is something like `{0} – {1}`, but this changes depending on the `locale` and is not always available.

`{0}` is the placeholder for the first datetime and `{1}` is the placeholder for the second one.

See ["interval\_formats" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#interval_formats)

## interval\_greatest\_diff

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $diff = $locale->interval_greatest_diff( $dt1, $dt2 );

Provided with 2 [DateTime objects](https://metacpan.org/pod/DateTime), and this will compute the [greatest difference](https://unicode.org/reports/tr35/tr35-dates.html#intervalFormats).

Quoting from the [LDML specifications](https://unicode.org/reports/tr35/tr35-dates.html#intervalFormats):

"The data supplied in CLDR requires the software to determine the calendar field with the greatest difference before using the format pattern. For example, the greatest difference in "Jan 10-12, 2008" is the day field, while the greatest difference in "Jan 10 - Feb 12, 2008" is the month field. This is used to pick the exact pattern."

If both `DateTime` objects are identical, this will return an empty string.

If an error occurred, an [exception object](https://metacpan.org/pod/DateTime%3A%3ALocale%3A%3AFromCLDR) is set and `undef` is returned in scalar context, and an empty list in list context.

## language

    my $locale = DateTime::Locale::FromCLDR->new( 'ja' );
    my $str = $locale->language;
    # Japanese

Returns the name of the `locale` in English

## language\_code

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP' );
    my $str = $locale->language_code;
    # ja
    my $locale = DateTime::Locale::FromCLDR->new( 'ryu-JP' );
    my $str = $locale->language_code;
    # ryu

Returns the `language` ID part of the `locale`

## language\_id

This is an alias for [language\_code](#language_code)

## locale

Returns the current [Locale::Unicode](https://metacpan.org/pod/Locale%3A%3AUnicode) object used in the current object.

## month\_format\_abbreviated

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->month_format_abbreviated;
    say @$array;
    # Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec

Returns an array reference of month names in abbreviated format from January to December.

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term)

## month\_format\_narrow

Same as [month\_format\_abbreviated](#month_format_abbreviated), but returns the months in narrow format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->month_format_narrow;
    say @$array;
    # J, F, M, A, M, J, J, A, S, O, N, D

## month\_format\_wide

Same as [month\_format\_abbreviated](#month_format_abbreviated), but returns the months in wide format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->month_format_wide;
    say @$array;
    # January, February, March, April, May, June, July, August, September, October, November, December

## month\_stand\_alone\_abbreviated

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->month_stand_alone_abbreviated;
    say @$array;
    # Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec

Returns an array reference of month names in abbreviated stand-alone format from January to December.

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term)

Note that there is often little difference between the `format` and `stand-alone` format types.

See the [LDML specifications](https://unicode.org/reports/tr35/tr35-dates.html#months_days_quarters_eras) for more information on the difference between the `format` and `stand-alone` types.

## month\_stand\_alone\_narrow

Same as [month\_stand\_alone\_abbreviated](#month_stand_alone_abbreviated), but returns the months in narrow format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->month_stand_alone_narrow;
    say @$array;
    # J, F, M, A, M, J, J, A, S, O, N, D

## month\_stand\_alone\_wide

Same as [month\_format\_abbreviated](#month_format_abbreviated), but returns the months in wide format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->month_stand_alone_wide;
    say @$array;
    # January, February, March, April, May, June, July, August, September, October, November, December

## name

    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->name; # French

    my $locale = DateTime::Locale::FromCLDR->new( 'fr-CH' );
    say $locale->name; # Swiss French

The `locale`'s name in English.

See also [native\_name](#native_name)

## native\_language

    my $locale = DateTime::Locale::FromCLDR->new( 'fr-CH' );
    say $locale->native_language; # français

Returns the `locale`'s `language` name as written in the `locale` own language.

If nothing can be found, it will return an empty string.

## native\_name

    my $locale = DateTime::Locale::FromCLDR->new( 'fr-CH' );
    say $locale->native_name; # français suisse

Returns the `locale`'s name as written in the `locale` own language.

If nothing can be found, it will return an empty string.

## native\_script

    my $locale = DateTime::Locale::FromCLDR->new( 'fr-Latn-CH' );
    say $locale->native_script; # latin

    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->native_script; # undef

Returns the `locale`'s `script` name as written in the `locale` own language.

If there is no `script` specified in the `locale`, it will return `undef`

If there is a `script` in the `locale`, but, somehow, it cannot be found in the `locale`'s own [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), it will return an empty string.

## native\_territory

    my $locale = DateTime::Locale::FromCLDR->new( 'fr-CH' );
    say $locale->native_territory; # Suisse

    my $locale = DateTime::Locale::FromCLDR->new( 'fr' );
    say $locale->native_territory; # undef

    my $locale = DateTime::Locale::FromCLDR->new( 'en-Latn-003' );
    say $locale->native_territory; # North America

    my $locale = DateTime::Locale::FromCLDR->new( 'en-XX' );
    say $locale->native_territory; # ''

Returns the `locale`'s `territory` name as written in the `locale` own language.

If there is no `territory` specified in the `locale`, it will return `undef`

If there is a `territory` in the `locale`, but, somehow, it cannot be found in the `locale`'s own [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), it will return an empty string.

## native\_variant

    my $locale = DateTime::Locale::FromCLDR->new( 'es-valencia' );
    say $locale->native_variant; # Valenciano

    my $locale = DateTime::Locale::FromCLDR->new( 'es' );
    say $locale->native_variant; # undef

    my $locale = DateTime::Locale::FromCLDR->new( 'en-Latn-005' );
    say $locale->native_variant; # undef

Returns the `locale`'s `variant` name as written in the `locale` own language.

If there is no `variant` specified in the `locale`, it will return `undef`, and if there is more than one `variant` it will return the value for the first one only. To get the values for all variants, use [native\_variants](#native_variants)

If there is a `variant` in the `locale`, but, somehow, it cannot be found in the `locale`'s own [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), it will return an empty string.

## native\_variants

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Latn-fonipa-hepburn-heploc' );
    say $locale->native_variants;
    # ["IPA Phonetics", "Hepburn romanization", ""]

Here, `heploc` is an empty string in the array, because it is a deprecated `variant`, and as such there is no localised name value for it in the `CLDR` data.

    my $locale = DateTime::Locale::FromCLDR->new( 'es' );
    say $locale->native_variants; # []

Returns an array reference of each of the `locale`'s `variant` subtag name as written in the `locale` own language.

If there is no `variant` specified in the `locale`, it will return an empty array.

If a `variant` subtag cannot be found in the `locale`'s own [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), then an empty string will be set in the array instead.

Either way, the size of the array will always be equal to the number of variants in the `locale`

## prefers\_24\_hour\_time

This checks whether the `locale` prefers the 24H format or the 12H one and returns true (`1`) if it prefers the 24 hours format or false (`0`) otherwise.

## quarter\_format\_abbreviated

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->quarter_format_abbreviated;
    say @$array;
    # Q1, Q2, Q3, Q4

Returns an array reference of quarter names in abbreviated format.

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term)

## quarter\_format\_narrow

Same as [quarter\_format\_abbreviated](#quarter_format_abbreviated), but returns the quarters in narrow format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->quarter_format_narrow;
    say @$array;
    # 1, 2, 3, 4

## quarter\_format\_wide

Same as [quarter\_format\_abbreviated](#quarter_format_abbreviated), but returns the quarters in wide format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->quarter_format_wide;
    say @$array;
    # 1st quarter, 2nd quarter, 3rd quarter, 4th quarter

## quarter\_stand\_alone\_abbreviated

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->quarter_stand_alone_abbreviated;
    say @$array;
    # Q1, Q2, Q3, Q4

Returns an array reference of quarter names in abbreviated format.

See also ["calendar\_term" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_term)

Note that there is often little difference between the `format` and `stand-alone` format types.

See the [LDML specifications](https://unicode.org/reports/tr35/tr35-dates.html#months_days_quarters_eras) for more information on the difference between the `format` and `stand-alone` types.

## quarter\_stand\_alone\_narrow

Same as [quarter\_stand\_alone\_abbreviated](#quarter_stand_alone_abbreviated), but returns the quarters in narrow format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->quarter_stand_alone_narrow;
    say @$array;
    # 1, 2, 3, 4

## quarter\_stand\_alone\_wide

Same as [quarter\_stand\_alone\_abbreviated](#quarter_stand_alone_abbreviated), but returns the quarters in wide format.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->quarter_stand_alone_wide;
    say @$array;
    # 1st quarter, 2nd quarter, 3rd quarter, 4th quarter

## script

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP' );
    my $str = $locale->script;
    # Katakana

Returns the name of the `locale`'s `script` in English.

If there is no `script` specified in the `locale`, it will return `undef`

If there is a `script` in the `locale`, but, somehow, it cannot be found in the `en` `locale`'s [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), it will return an empty string.

## script\_code

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana-JP' );
    my $script = $locale->script_code;
    # Kana

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-JP' );
    my $script = $locale->script_code;
    # undef

Returns the `locale`'s `script` ID, or `undef` if there is none.

## script\_id

This is an alias for [script\_code](#script_code)

## territory

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-JP' );
    my $script = $locale->territory;
    # Japan

    my $locale = DateTime::Locale::FromCLDR->new( 'zh-034' );
    my $script = $locale->territory;
    # Southern Asia

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $script = $locale->territory;
    # undef

    my $locale = DateTime::Locale::FromCLDR->new( 'en-XX' );
    my $script = $locale->territory;
    # ''

Returns the name of the `locale`'s `territory` in English.

If there is no `territory` specified in the `locale`, it will return `undef`

If there is a `territory` in the `locale`, but, somehow, it cannot be found in the `en` `locale`'s [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), it will return an empty string.

## territory\_code

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-JP' );
    my $script = $locale->territory_code;
    # JP

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Kana' );
    my $script = $locale->territory_code;
    # undef

Returns the `locale`'s `territory` ID, or `undef` if there is none.

## territory\_id

This is an alias for [territory\_code](#territory_code)

## time\_format\_default

This is an alias for [time\_format\_medium](#time_format_medium)

## time\_format\_full

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->time_format_full;
    # h:mm:ss a zzzz
    # 10:44:07 PM UTC

Returns the [full date pattern](https://unicode.org/reports/tr35/tr35-dates.html#dateFormats)

See also ["calendar\_format\_l10n" in Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#calendar_format_l10n)

## time\_format\_long

Same as [time\_format\_full](#time_format_full), but returns the long format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->time_format_long;
    # h:mm:ss a z
    # 10:44:07 PM UTC

## time\_format\_medium

Same as [time\_format\_full](#time_format_full), but returns the medium format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->time_format_medium;
    # h:mm:ss a
    # 10:44:07 PM

## time\_format\_short

Same as [time\_format\_full](#time_format_full), but returns the short format pattern.

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->time_format_short;
    # h:mm a
    # 10:44 PM

## time\_formats

    my $now = DateTime->now( locale => 'en' );
    my $ref = $locale->time_formats;
    foreach my $type ( sort( keys( %$ref ) ) )
    {
        say $type, ":";
        say $ref->{ $type };
        say $now->format_cldr( $ref->{ $type } ), "\n";
    }

Would produce:

    full:
    h:mm:ss a zzzz
    10:44:07 PM UTC

    long:
    h:mm:ss a z
    10:44:07 PM UTC

    medium:
    h:mm:ss a
    10:44:07 PM

    short:
    h:mm a
    10:44 PM

Returns an hash reference with the keys being: `full`, `long`, `medium`, `short` and their value the result of their associated time format methods.

## variant

    my $locale = DateTime::Locale::FromCLDR->new( 'es-valencia' );
    my $script = $locale->variant;
    # Valencian

    my $locale = DateTime::Locale::FromCLDR->new( 'es' );
    my $script = $locale->variant;
    # undef

    # No such thing as variant 'klingon'. Language 'tlh' exists though :)
    my $locale = DateTime::Locale::FromCLDR->new( 'en-klingon' );
    my $script = $locale->variant;
    # ''

Returns the name of the `locale`'s `variant` in English.

If there is no `variant` specified in the `locale`, it will return `undef`

If there is a `variant` in the `locale`, but, somehow, it cannot be found in the `en` `locale`'s [language tree](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData#make_inheritance_tree), it will return an empty string.

## variant\_code

    my $locale = DateTime::Locale::FromCLDR->new( 'es-valencia' );
    my $script = $locale->variant_code;
    # valencia

    my $locale = DateTime::Locale::FromCLDR->new( 'es-ES' );
    my $script = $locale->variant_code;
    # undef

Returns the `locale`'s `variant` ID, or `undef` if there is none.

## variant\_id

This is an alias for [variant\_code](#variant_code)

## variants

    my $locale = DateTime::Locale::FromCLDR->new( 'es-valencia' );
    my $array = $locale->variants;
    # ["valencia"]

    my $locale = DateTime::Locale::FromCLDR->new( 'ja-Latn-fonipa-hepburn-heploc' );
    my $array = $locale->variants;
    # ["fonipa", "hepburn", "heploc"]

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    my $array = $locale->variants;
    # []

This returns an array reference of `variant` subtags for this `locale`, even if there is no variant.

## version

    my $locale = DateTime::Locale::FromCLDR->new( 'en' );
    say $locale->version; # 45.0

Returns the Unicode `CLDR` data version number.

# SERIALISATION

`Locale::Unicode` supports [Storable::Improved](https://metacpan.org/pod/Storable%3A%3AImproved), [Storable](https://metacpan.org/pod/Storable), [Sereal](https://metacpan.org/pod/Sereal) and [CBOR](https://metacpan.org/pod/CBOR%3A%3AXS) serialisation, by implementing the methods `FREEZE`, `THAW`, `STORABLE_freeze`, `STORABLE_thaw`

For serialisation with [Sereal](https://metacpan.org/pod/Sereal), make sure to instantiate the [Sereal encoder](https://metacpan.org/pod/Sereal%3A%3AEncoder) with the `freeze_callbacks` option set to true, otherwise, `Sereal` will not use the `FREEZE` and `THAW` methods.

See ["FREEZE/THAW CALLBACK MECHANISM" in Sereal::Encoder](https://metacpan.org/pod/Sereal%3A%3AEncoder#FREEZE-THAW-CALLBACK-MECHANISM) for more information.

For [CBOR](https://metacpan.org/pod/CBOR%3A%3AXS), it is recommended to use the option `allow_sharing` to enable the reuse of references, such as:

    my $cbor = CBOR::XS->new->allow_sharing;

Also, if you use the option `allow_tags` with [JSON](https://metacpan.org/pod/JSON), then all of those modules will work too, since this option enables support for the `FREEZE` and `THAW` methods.

# AUTHOR

Jacques Deguest <`jack@deguest.jp`>

# SEE ALSO

[Locale::Unicode](https://metacpan.org/pod/Locale%3A%3AUnicode), [Locale::Unicode::Data](https://metacpan.org/pod/Locale%3A%3AUnicode%3A%3AData), [DateTime::Format::Unicode](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AUnicode)

[DateTime::Locale](https://metacpan.org/pod/DateTime%3A%3ALocale)

# COPYRIGHT & LICENSE

Copyright(c) 2024 DEGUEST Pte. Ltd.

All rights reserved

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
