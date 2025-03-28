# NAME

HTML::CalendarMonthSimple - Perl Module for Generating HTML Calendars

# SYNOPSIS

    use HTML::CalendarMonthSimple;
    $cal = new HTML::CalendarMonthSimple('year'=>2001,'month'=>2);
    $cal->width('50%');
    $cal->border(10);
    $cal->header('Text at the top of the Grid');
    $cal->setcontent(14,"Valentine's Day");
    $cal->setdatehref(14, 'http://localhost/');
    $cal->addcontent(14,"<p>Don't forget to buy flowers.");
    $cal->addcontent(13,"Guess what's tomorrow?");
    $cal->bgcolor('pink');
    print $cal->as_HTML;

# DESCRIPTION

Note: This package is no longer being maintained by Gregor Mosheh <stigmata@blackangel.net>.  It is recommended that new development be built against [HTML::CalendarMonth](https://metacpan.org/pod/HTML%3A%3ACalendarMonth).

HTML::CalendarMonthSimple is a Perl module for generating, manipulating, and printing a HTML calendar grid for a specified month. It is intended as a faster and easier-to-use alternative to HTML::CalendarMonth.

This module requires the Date::Calc module, which is available from CPAN if you don't already have it.

# INTERFACE METHODS

## new(ARGUMENTS)

Naturally, new() returns a newly constructed calendar object.

The optional constructor arguments 'year' and 'month' can specify which month's calendar will be used. If either is omitted, the current value (e.g. "today") is used. An important note is that the month and the year are NOT the standard C or Perl -- use a month in the range 1-12 and a real year, e.g. 2001.

The arguments 'today\_year', 'today\_month', and 'today\_date' may also be specified, to specify what "today" is. If not specified, the system clock will be used. This is particularly useful when the todaycolor() et al methods are used, and/or if you're dealing with multiple timezones. Note that these arguments change what "today" is, which means that if you specify a today\_year and a today\_month then you are effectively specifying a 'year' and 'month' argument as well, though you can also specify a year and month argument and override the "today" behavior.

    # Examples:
    # Create a calendar for this month.
    $cal = new HTML::CalendarMonthSimple();
    # A calendar for a specific month/year
    $cal = new HTML::CalendarMonthSimple('month'=>2,'year'=>2000);
    # Pretend that today is June 10, 2000 and display the "current" calendar
    $cal = new HTML::CalendarMonthSimple('today_year'=>2000,'today_month'=>6,'today_date'=>10);

## year

## month

## today\_year

## today\_month

## today\_date

## monthname

These methods simply return the year/month/date of the calendar, as specified in the constructor.

monthname() returns the text name of the month, e.g. "December".

## setcontent(DATE,STRING)

## addcontent(DATE,STRING)

## highlight (@DATE)

Highlights the particular dates given.

    $cal->highlight(1,10,22);

## getcontent(DATE)

These methods are used to control the content of date cells within the calendar grid. The DATE argument may be a numeric date or it may be a string describing a certain occurrence of a weekday, e.g. "3MONDAY" to represent "the third Monday of the month being worked with", or it may be the plural of a weekday name, e.g. "wednesdays" to represent all occurrences of the given weekday. The weekdays are case-insensitive.

Since plural weekdays (e.g. 'wednesdays') is not a single date, getcontent() will return the content only for the first occurrence of that day within a month.

    # Examples:
    # The cell for the 15th of the month will now say something.
    $cal->setcontent(15,"An Important Event!");
    # Later down the program, we want the content to be boldfaced.
    $cal->setcontent(15,"<b>" . $cal->getcontent(15) . "</b>");

    # addcontent() does not clobber existing content.
    # Also, if you setcontent() to '', you've deleted the content.
    $cal->setcontent(16,'');
    $cal->addcontent(16,"<p>Hello World</p>");
    $cal->addcontent(16,"<p>Hello Again</p>");
    print $cal->getcontent(16); # Prints 2 sentences

    # Padded and decimal numbers may be used, as well:
    $cal->setcontent(3.14159,'Third of the month');
    $cal->addcontent('00003.0000','Still the third');
    $cal->getcontent('3'); # Gets the 2 sentences

    # The second Sunday of May is some holiday or another...
    $cal->addcontent('2sunday','Some Special Day') if ($cal->month() == 5);

    # Every Wednesday is special...
    $cal->addcontent('wednesdays','Every Wednesday!');

    # either of these will return the content for the 1st Friday of the month
    $cal->getcontent('1friday');
    $cal->getcontent('Fridays'); # you really should use '1friday' for the first Friday

Note: A change in 1.21 is that all content is now stored in a single set of date-indexed buckets. Previously, the content for weekdays, plural weekdays, and numeric dates were stored separately and could be fetched and set independently. This led to buggy behavior, so now a single storage set is used.

    # Example:
    # if the 9th of the month is the second Wednesday...
    $cal->setcontent(9,'ninth');
    $cal->addcontent('2wednesday','second wednesday');
    $cal->addcontent('wednesdays','every wednesday');
    print $cal->getcontent(9);

In version 1.20 and previous, this would print 'ninth' but in 1.21 and later, this will print all three items (since the 9th is not only the 9th but also a Wednesday and the second Wednesday). This could have implications if you use setcontent() on a set of days, since other content may be overwritten:

    # Example:
    # the second setcontent() effectively overwrites the first one
    $cal->setcontent(9,'ninth');
    $cal->setcontent('2wednesday','second wednesday');
    $cal->setcontent('wednesdays','every wednesday');
    print $cal->getcontent(9); # returns 'every wednesday' because that was the last assignment!

## as\_HTML

This method returns a string containing the HTML table for the month.

    # Example:
    print $cal->as_HTML();

It's okay to continue modifying the calendar after calling as\_HTML(). My guess is that you'd want to call as\_HTML() again to print the further-modified calendar, but that's your business...

## weekstartsonmonday(\[1|0\])

By default, calendars are displayed with Sunday as the first day of the week (American style). Most of the world prefers for calendars to start the week on Monday. This method selects which type is used: 1 specifies that the week starts on Monday, 0 specifies that the week starts on Sunday (the default). If no value is given at all, the current value (1 or 0) is returned.

    # Example:
    $cal->weekstartsonmonday(1); # switch over to weeks starting on Monday
    $cal->weekstartsonmonday(0); # switch back to the default, where weeks start on Sunday

    # Example:
    print "The week starts on " . ($cal->weekstartsonmonday() ? 'Sunday' : 'Monday') . "\n";

## Days\_in\_Month

This function returns the number of days on the current calendar.

    foreach my $day (1 .. $cal->Days_in_Month) {
      $cal->setdatehref($day, &make_url($cal->year, $cal->month, $day));
    }

## setdatehref(DATE,URL\_STRING)

## getdatehref(DATE)

These allow the date-number in a calendar cell to become a hyperlink to the specified URL. The DATE may be either a numeric date or any of the weekday formats described in setcontent(), et al. If plural weekdays (e.g. 'wednesdays') are used with getdatehref() the URL of the first occurrence of that weekday in the month will be returned (since 'wednesdays' is not a single date).

    # Example:
    # The date number in the cell for the 15th of the month will be a link
    # then we change our mind and delete the link by assigning a null string
    $cal->setdatehref(15,"http://sourceforge.net/");
    $cal->setdatehref(15,'');

    # Example:
    # the second Wednesday of the month goes to some website
    $cal->setdatehref('2wednesday','http://www.second-wednesday.com/');

    # Example:
    # every Wednesday goes to a website
    # note that this will effectively undo the '2wednesday' assignment we just did!
    # if we wanted the second Wednesday to go to that special URL, we should've done that one after this!
    $cal->setdatehref('wednesdays','http://every-wednesday.net/');

## contentfontsize(\[STRING\])

contentfontsize() sets the font size for the contents of the cell, overriding the browser's default. Can be expressed as an absolute (1 .. 6) or relative (-3 .. +3) size.

## border(\[INTEGER\])

This specifies the value of the border attribute to the <TABLE> declaration for the calendar. As such, this controls the thickness of the border around the calendar table. The default value is 5.

If a value is not specified, the current value is returned. If a value is specified, the border value is changed and the new value is returned.

## cellpadding

## cellspacing

## width(\[INTEGER\]\[%\])

This sets the value of the width attribute to the <TABLE> declaration for the calendar. As such, this controls the horizontal width of the calendar.

The width value can be either an integer (e.g. 600) or a percentage string (e.g. "80%"). Most web browsers take an integer to be the table's width in pixels and a percentage to be the table width relative to the screen's width. The default width is "100%".

If a value is not specified, the current value is returned. If a value is specified, the border value is changed and the new value is returned.

    # Examples:
    $cal->width(600);    # absolute pixel width
    $cal->width("100%"); # percentage of screen size

## showdatenumbers(\[1 or 0\])

If showdatenumbers() is set to 1, then the as\_HTML() method will put date labels in each cell (e.g. a 1 on the 1st, a 2 on the 2nd, etc.) If set to 0, then the date labels will not be printed. The default is 1.

If no value is specified, the current value is returned.

The date numbers are shown in boldface, normal size font. If you want to change this, consider setting showdatenumbers() to 0 and using setcontent()/addcontent() instead.

## showweekdayheaders(\[1 or 0\])

## weekdayheadersbig(\[1 or 0\])

If showweekdayheaders() is set to 1 (the default) then calendars rendered via as\_HTML() will display the names of the days of the week. If set to 0, the days' names will not be displayed.

If weekdayheadersbig() is set to 1 (the default) then the weekday headers will be in &lt;th> cells. The effect in most web browsers is that they will be boldfaced and centered. If set to 0, the weekday headers will be in &lt;td> cells and in normal text.

For both functions, if no value is specified, the current value is returned.

## cellalignment(\[STRING\])

## vcellalignment(\[STRING\])

cellalignment() sets the value of the align attribute to the <TD> tag for each day's cell. This controls how text will be horizontally centered/aligned within the cells. vcellalignment() does the same for vertical alignment. By default, content is aligned horizontally "left" and vertically "top"

Any value can be used, if you think the web browser will find it interesting. Some useful alignments are: left, right, center, top, and bottom.

## header(\[STRING\])

By default, the current month and year are displayed at the top of the calendar grid. This is called the "header".

The header() method allows you to set the header to whatever you like. If no new header is specified, the current header is returned.

If the header is set to an empty string, then no header will be printed at all. (No, you won't be stuck with a big empty cell!)

    # Example:
    # Set the month/year header to something snazzy.
    my($y,$m) = ( $cal->year() , $cal->monthname() );
    $cal->header("<center><font size=+2 color=red>$m $y</font></center>\n\n");

## bgcolor(\[STRING\])

## weekdaycolor(\[STRING\])

## weekendcolor(\[STRING\])

## todaycolor(\[STRING\])

## bordercolor(\[STRING\])

## highlightbordercolor(\[STRING\])

## weekdaybordercolor(\[STRING\])

## weekendbordercolor(\[STRING\])

## todaybordercolor(\[STRING\])

## contentcolor(\[STRING\])

## highlightcontentcolor(\[STRING\])

## weekdaycontentcolor(\[STRING\])

## weekendcontentcolor(\[STRING\])

## todaycontentcolor(\[STRING\])

## headercolor(\[STRING\])

## headercontentcolor(\[STRING\])

## weekdayheadercolor(\[STRING\])

## weekdayheadercontentcolor(\[STRING\])

## weekendheadercolor(\[STRING\])

## weekendheadercontentcolor(\[STRING\])

These define the colors of the cells. If a string (which should be either a HTML color-code like '#000000' or a color-word like 'yellow') is supplied as an argument, then the color is set to that specified. Otherwise, the current value is returned. To unset a value, try assigning the null string as a value.

The bgcolor defines the color of all cells. The weekdaycolor overrides the bgcolor for weekdays (Monday through Friday), the weekendcolor overrides the bgcolor for weekend days (Saturday and Sunday), and the todaycolor overrides the bgcolor for today's date. (Which may not mean a lot if you're looking at a calendar other than the current month.)

The weekdayheadercolor overrides the bgcolor for the weekday headers that appear at the top of the calendar if showweekdayheaders() is true, and weekendheadercolor does the same thing for the weekend headers. The headercolor overrides the bgcolor for the month/year header at the top of the calendar. The headercontentcolor(), weekdayheadercontentcolor(), and weekendheadercontentcolor() methods affect the color of the corresponding headers' contents and default to the contentcolor().

The colors of the cell borders may be set: bordercolor determines the color of the calendar grid's outside border, and is the default color of the inner border for individual cells. The inner bordercolor may be overridden for the various types of cells via weekdaybordercolor, weekendbordercolor, and todaybordercolor.

Finally, the color of the cells' contents may be set with contentcolor, weekdaycontentcolor, weekendcontentcolor, and todaycontentcolor. The contentcolor is the default color of cell content, and the other methods override this for the appropriate days' cells.

    # Example:
    $cal->bgcolor('white');                  # Set the default cell bgcolor
    $cal->bordercolor('green');              # Set the default border color
    $cal->contentcolor('black');             # Set the default content color
    $cal->headercolor('yellow');             # Set the bgcolor of the Month+Year header
    $cal->headercontentcolor('yellow');      # Set the content color of the Month+Year header
    $cal->weekdayheadercolor('orange');      # Set the bgcolor of weekdays' headers
    $cal->weekendheadercontentcolor('blue'); # Set the color of weekday headers' contents
    $cal->weekendheadercolor('pink');        # Set the bgcolor of weekends' headers
    $cal->weekdayheadercontentcolor('blue'); # Set the color of weekend headers' contents
    $cal->weekendcolor('palegreen');         # Override weekends' cell bgcolor
    $cal->weekendcontentcolor('blue');       # Override weekends' content color
    $cal->todaycolor('red');                 # Override today's cell bgcolor
    $cal->todaycontentcolor('yellow');       # Override today's content color
    print $cal->as_HTML;                     # Print a really ugly calendar!

## datecolor(DATE,\[STRING\])

## datecontentcolor(DATE,\[STRING\])

## datebordercolor(DATE,\[STRING\])

These methods set the cell color and the content color for the specified date, and will return the current value if STRING is not specified. These color settings will override any of the settings mentioned above, even todaycolor() and todaycontentcolor().

The date may be a numeric date or a weekday string as described in setcontent() et al. Note that if a plural weekday is used (e.g. 'sundays') then, since it's not a single date, the value for the first occurrence of that weekday will be returned (e.g. the first Sunday's color).

    # Example: a red-letter day!
    $cal->datecolor(3,'pink');
    $cal->datecontentcolor(3,'red');

    # Example:
    # Every Tuesday is a Soylent Green day...
    # Note that if the 3rd was a Tuesday, this later assignment would override the previous one.
    # see the docs for setcontent() et all for more information.
    $cal->datecolor('tuesdays','green');
    $cal->datecontentcolor('tuesdays','yellow');

## nowrap(\[1 or 0\])

If set to 1, then calendar cells will have the NOWRAP attribute set, preventing their content from wrapping. If set to 0 (the default) then NOWRAP is not used and very long content may cause cells to become stretched out.

## sharpborders(\[1 or 0\])

If set to 1, this gives very crisp edges between the table cells. If set to 0 (the default) standard HTML cells are used. If neither value is specified, the current value is returned.

FYI: To accomplish the crisp border, the entire calendar table is wrapped inside a table cell.

## cellheight(\[NUMBER\])

This specifies the height in pixels of each cell in the calendar. By default, no height is defined and the web browser usually chooses a reasonable default.

If no value is given, the current value is returned.

To unspecify a height, try specifying a height of 0 or undef.

## tableclass(\[STRING\])

## cellclass(\[STRING\])

## weekdaycellclass(\[STRING\])

## weekendcellclass(\[STRING\])

## todaycellclass(\[STRING\])

## datecellclass(DATE,\[STRING\])

## headerclass(\[STRING\])

These specify which CSS class will be attributed to the calendar's table and the calendar's cells. By default, no classes are specified or used.

tableclass() sets the CSS class for the calendar table.

cellclass() is used for all calendar cells. weekdaycellclass(), weekendcellclass(), and todaycellclass() override the cellclass() for the corresponding types of cells. headerclass() is used for the calendar's header.

datecellclass() sets the CSS class for the cell for the specified date. This setting will override any of the other cell class settings, even todaycellclass()  This date must be numeric; it cannot be a string such as "2wednesday"

If no value is given, the current value is returned.

To unspecify a class, try specifying an empty string, e.g. cellclass('')

## sunday(\[STRING\])

## saturday(\[STRING\])

## weekdays(\[MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY\])

These functions allow the days of the week to be "renamed", which is useful for displaying the weekday headers in another language.

    # show the days of the week in Spanish
    $cal->saturday('Sábado');
    $cal->sunday('Domingo');
    $cal->weekdays('Lunes','Martes','Miércoles','Jueves','Viernes');

    # show the days of the week in German
    $cal->saturday('Samstag');
    $cal->sunday('Sonntag');
    $cal->weekdays('Montag','Dienstag','Mittwoch','Donnerstag','Freitag');

If no value is specified (or, for weekdays() if exactly 5 arguments aren't given) then the current value is returned.

# BUGS

Send bug reports to the author and log on RT.

# LICENSE

This program is free software licensed under the...

    The BSD License

The full text of the license can be found in the LICENSE file included with this module.

Note: Versions prior to 1.26 were licensed under a BSD-like statement "This Perl module is freeware. It may be copied, derived, used, and distributed without limitation."

# AUTHORS, CREDITS, COPYRIGHTS

HTML::CalendarMonth was written and is copyrighted by Matthew P. Sisk <sisk@mojotoad.com> and provided inspiration for the module's interface and features. None of Matt Sisk's code appears herein.

HTML::CalendarMonthSimple was written by Gregor Mosheh <stigmata@blackangel.net> Frankly, the major inspiration was the difficulty and unnecessary complexity of HTML::CalendarMonth. (Laziness is a virtue.)

This would have been extremely difficult if not for Date::Calc. Many thanks to Steffen Beyer <sb@engelschall.com> for a very fine set of date-related functions!

Dave Fuller <dffuller@yahoo.com> added the getdatehref() and setdatehref() methods, and pointed out the bugs that were corrected in 1.01.

Danny J. Sohier <danny@gel.ulaval.ca> provided many of the color functions.

Bernie Ledwick <bl@man.fwltech.com> provided base code for the today\*() functions, and for the handling of cell borders.

Justin Ainsworth <jrainswo@olemiss.edu> provided the vcellalignment() concept and code.

Jessee Porter <porterje@us.ibm.com> provided fixes for 1.12 to correct those warnings.

Bray Jones <bjones@vialogix.com> supplied the sharpborders(), nowrap(), cellheight(), cellclass() methods.

Bill Turner <b@brilliantcorners.org> supplied the headerclass() method and the rest of the methods added to 1.13

Bill Rhodes <wrhodes@27.org> provided the contentfontsize() method for version 1.14

Alberto Simões <albie@alfarrabio.di.uminho.pt> provided the tableclass() function and the saturday(), sunday(), and weekdays() functions for version 1.18. Thanks, Alberto, I've been wanting this since the beginning!

Blair Zajac <blair@orcaware.com> provided the fixes for 1.19

Thanks to Kurt <kurt@otown.com> for the bug report that made all the new stuff in 1.21 possible.

Many thanks to Stefano Rodighiero <larsen@libero.it> for the code that made weekstartsonmonday() possible. This was a much-requested feature that will make many people happy!

Dan Boitnott <dboitnot@yahoo.com> provided today\_year() et al in 1.23

Peter Venables <pvenables@rogers.com> provided the XML validation fixes for 1.24
