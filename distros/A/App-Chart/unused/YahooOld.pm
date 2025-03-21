# Copyright 2007, 2008, 2009, 2010, 2011, 2015, 2016, 2017, 2018, 2024 Kevin Ryde

# This file is part of Chart.
#
# Chart is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3, or (at your option) any later version.
#
# Chart is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along
# with Chart.  If not, see <http://www.gnu.org/licenses/>.


#------------------------------------------------------------------------------
# Quotes bits generally.
#
# This uses the csv format quotes like
#
#     http://download.finance.yahoo.com/d/quotes.csv?f=snl&e=.csv&s=BHP.AX
#
# The "f" field keys can be found at the following (open an account to get
# to them).
#
#         http://edit.my.yahoo.com/config/edit_pfview?.vk=v1
#         http://edit.finance.yahoo.com/e9?.intl=au
#
# http://download.finance.yahoo.com/d?
#   s=  # symbol
#   f=  # format, concat of the following
#     s   # symbol
#     n   # company name
#     l1  # last price
#     d1  # last trade date (in home exchange's timezone)
#     t1  # last trade time (in yahoo server timezone)
#     c1  # change
#     p2  # percent change
#     v   # volume
#     a2  # average daily volume
#     b   # bid
#     b6  # bid size
#     a   # ask
#     a5  # ask size
#     k1  # "time - last" (ECN), with <b> and <i> markup
#     c6  # change (ECN)
#     m2  # day's range (ECN)
#     b3  # bid (ECN)
#     b2  # ask (ECN)
#     p   # previous close
#     o   # today's open
#     m   # day's range, eg. "1.23 - 4.56"
#     w   # 52-week range, eg. "1.23 - 4.56"
#     e   # earnings per share
#     r   # p/e ratio
#     d   # div per share
#     q   # ex div date, eg. "Mar 31" or "N/A"
#     r1  # div pay date
#     y   # div yield
#     j1  # market cap
#     x   # stock exchange
#     c4  # currency, eg. "AUD"
#     i   # more info links, letters
#         #    c=chart, n=news, p=profile, r=research, i=insider,
#         #    m=message board (yahoo)
#     k   # 52-week high
#
# Don't know what the distinction between b,a and b3,b2 quotes are actually
# meant to be.
#     - For the Australian Stock Exchange, b,a are "N/A", and b3,b2 is the
#       SEATS best quote.
#     - For US stocks b,a seem to be "N/A", and b3,b2 an ECN quote.  The
#       latter has been seen a long way away from from recent trades though,
#       eg. in BRK-A.
#
# d1,t1 are a bit odd, the time is the yahoo server's zone, but the date
# seems to be always GMT.  The zone for the time can be seen easily by
# looking at a quote from the various international XX.finance.yahoo.com.
# For the zone for the date however you need to be watching at midnight
# GMT, where it ticks over (at all the international XX.finance.yahoo.com).


# quote_parse_div_date ($str) returns an iso YYYY-MM-DD date string for a
# dividend $str coming from quote.csv data, or undef if none.  There are
# several different formats,
#           "Jan 7"        # finance.yahoo.com
#           " 5 Jan"  	   # au.finance, uk.finance
#           "24-Sep-04"    # ABB.AX on finance.yahoo.com
#           "24 Sep, 2004" # ABB.AX on au.finance
#           "Sep 24, 2004" # ABB.AX on ca.finance
#
# An error is thrown for an unrecognised string, don't want some new form to
# end up with dividends silently forgotten.
#
sub quote_parse_div_date {
  my ($str) = @_;
  if (DEBUG) { print "quote_parse_div_date() '$str'\n"; }
  if (! defined $str || $str eq 'N/A' || $str eq '') {
    return undef; # no info
  }

  my ($ss,$mm,$hh,$day,$month,$year,$zone) = Date::Parse::strptime ($str);
  $month++;
  if ($year) {
    $year += 1900;
    if ($year < 2000) {  # "04" returned as 1904, bump to 2004
      $year += 100;
    }
  } else {
    # year not given, try nearest
    $year = App::Chart::Download::month_to_nearest_year ($month);
  }
  if (! Date::Calc::check_date ($year, $month, $day)) {
    warn "Yahoo invalid dividend date '$str'";
  }
  return App::Chart::ymd_to_iso ($year, $month, $day);
}

#------------------------------------------------------------------------------
# Latest Quotes by CSV

# wget -S -O /dev/stdout 'http://download.finance.yahoo.com/d/quotes.csv?f=snc4b3b2d1t1oml1c1vqdx&e=.csv&s=GM'
#

# sub latest_download {
#   my ($symbol_list) = @_;
#   App::Chart::Download::status (__('Yahoo quotes'));
# 
#   # App::Chart::Download::verbose_message ("Yahoo crumb $crumb cookies\n"
#   #                                        . $jar->as_string);
# 
#   my $crumb_errors = 0;
#  SYMBOL: foreach my $symbol (@$symbol_list) {
#     my $tdate = daily_available_tdate ($symbol);
# 
#     App::Chart::Download::status(__('Yahoo quote'), $symbol);
# 
#     my $lo_timet = tdate_to_unix($tdate - 4);
#     my $hi_timet = tdate_to_unix($tdate + 2);
# 
#     my $data  = daily_cookie_data($symbol);
#     if (! defined $data) {
#       print "Yahoo $symbol does not exist\n";
#       next SYMBOL;
#     }
#     my $crumb = URI::Escape::uri_escape($data->{'crumb'});
#     my $jar = http_cookies_from_string($data->{'cookies'} // '');
# 
#     my $events = 'history';
#     my $url = "http://query1.finance.yahoo.com/v7/finance/download/"
#       . URI::Escape::uri_escape($symbol)
#       . "?period1=$lo_timet&period2=$hi_timet&interval=1d&events=$events&crumb=$crumb";
# 
#     my $resp = App::Chart::Download->get ($url,
#                                           allow_401 => 1,
#                                           allow_404 => 1,
#                                           cookie_jar => $jar,
#                                          );
#     if ($resp->code == 401) {
#       if (++$crumb_errors >= 2) { die "Yahoo: crumb authorization failed"; }
#       App::Chart::Database->write_extra ('', 'yahoo-daily-cookies', undef);
#       redo SYMBOL;
#     }
#     if ($resp->code == 404) {
#       print "Yahoo $symbol does not exist\n";
#       next SYMBOL;
#     }
# 
#     App::Chart::Download::write_latest_group
#         (latest_parse($symbol,$resp,$tdate));
#   }
# }
# 
# sub latest_parse {
#   my ($symbol, $resp, $tdate) = @_;
# 
#   my $h = { source      => __PACKAGE__,
#             resp        => $resp,
#             prefer_decimals => 2,
#             date_format => 'ymd' };
#   daily_parse($symbol,$resp,$h);
# 
#   my $data = $h->{'data'};
#   @$data = sort {$a->{'date'} cmp $b->{'date'}} @$data;
# 
#   my $this = (@$data ? $data->[-1] : {});
#   $this->{'symbol'} = $symbol;
#   $this->{'last_date'} = delete $this->{'date'};
#   my $last = $this->{'last'} = delete $this->{'close'};
#   if (defined $last && @$data >= 2) {
#     my $prev = $data->[-2]->{'close'};
#     if (defined $prev) {
#       $this->{'change'} = decimal_subtract($last, $prev);
#     }
#   }
#   @$data = ($this);
#   return $h;
# }

# Return the difference $x - $y, done as a "decimal" subtract, so retaining
# as many decimal places there are on $x and $y.
# It's done with some sprint %f fakery, not actual decimal arithmetic, but
# that's close enough for 4 decimal place currencies.
sub decimal_subtract {
  my ($x, $y) = @_;
  my $decimals = max (App::Chart::count_decimals($x),
                      App::Chart::count_decimals($y));
  return sprintf ('%.*f', $decimals, $x - $y);
}


# use constant DEFAULT_DOWNLOAD_HOST => 'download.finance.yahoo.com';
# 
# App::Chart::LatestHandler->new
#   (pred => $latest_pred,
#    proc => \&latest_download,
#    max_symbols => MAX_QUOTES);
# 
# sub latest_download {
#   my ($symbol_list) = @_;
# 
#   App::Chart::Download::status
#       (__x('Yahoo quotes {symbol_range}',
#            symbol_range =>
#            App::Chart::Download::symbol_range_string ($symbol_list)));
# 
#   my $host = App::Chart::Database->preference_get
#     ('yahoo-quote-host', DEFAULT_DOWNLOAD_HOST);
#   my $url = "http://$host/d/quotes.csv?f=snc4b3b2d1t1oml1c1vqdx&e=.csv&s="
#     . join (',', map { URI::Escape::uri_escape($_) } @$symbol_list);
# 
#   my $resp = App::Chart::Download->get ($url);
#   App::Chart::Download::write_latest_group (latest_parse ($resp));
# }
#
# sub latest_parse {
#   my ($resp) = @_;
#   my $content = $resp->decoded_content (raise_error => 1);
#   ### Yahoo quotes: $content
# 
#   my @data = ();
#   my $h = { source => __PACKAGE__,
#             resp   => $resp,
#             prefer_decimals => 2,
#             date_format => 'mdy',  # eg. '6/26/2015'
#             data   => \@data };
# 
#   require Text::CSV_XS;
#   my $csv = Text::CSV_XS->new;
#   foreach my $line (App::Chart::Download::split_lines ($content)) {
#     $csv->parse($line);
#     ### csv fields: $csv->fields()
#     my ($symbol, $name, $currency, $bid, $offer, $last_date, $last_time,
#         $open, $range, $last, $change, $volume,
#         $div_date, $div_amount, $exchange)
#       = $csv->fields();
#     if (! defined $symbol) {
#       # blank line maybe
#       print "Yahoo quotes blank line maybe:\n---\n$content\n---\n";
#       next;
#     }
# 
#     # for unknown stocks the name is a repeat of the symbol, which is pretty
#     # useless
#     if ($name eq $symbol) { $name = undef; }
# 
#     my ($low, $high) = split /-/, $range;
#     my $quote_delay_minutes = symbol_quote_delay ($symbol);
# 
#     # have seen wildly garbage date for unknown symbols, like
#     # GC.CMX","GC.CMX","MRA",N/A,N/A,"8/352/19019","4:58am",N/A,"N/A - N/A",0.00,N/A,N/A,"N/A",N/A,"N/A
#     # depending what else in the same request ...
#     #
# 
#     # In the past date/times were in New York timezone, for shares anywhere
#     # in the world.  The Chart database is in the timezone of the exchange.
#     # As of June 2015 believe Yahoo is now also the exchange timezone so no
#     # transformation.
#     #
#     # my $symbol_timezone = App::Chart::TZ->for_symbol ($symbol);
#     # ($last_date, $last_time)
#     #   = quote_parse_datetime ($last_date, $last_time,
#     #                           App::Chart::TZ->newyork,
#     #                           $symbol_timezone);
# 
#     # dividend is "0.00" for various unknowns or estimates, eg. from ASX
#     # trusts
#     if (App::Chart::Download::str_is_zero ($div_amount)) {
#       $div_amount = __('unknown');
#     }
# 
#     # dividend shown only if it's today
#     # don't show if no last_date, just in case have a div_date but no
#     # last_date for some reason
#     $div_date = quote_parse_div_date ($div_date);
#     if (! ($div_date && $last_date && $div_date eq $last_date)) {
#       $div_amount = undef;
#     }
# 
#     push @data, { symbol      => $symbol,
#                   name        => $name,
#                   exchange    => $exchange,
#                   currency    => $currency,
# 
#                   quote_delay_minutes => $quote_delay_minutes,
#                   bid         => $bid,
#                   offer       => $offer,
# 
#                   last_date   => $last_date,
#                   last_time   => $last_time,
#                   open        => $open,
#                   high        => $high,
#                   low         => $low,
#                   last        => $last,
#                   change      => $change,
#                   volume      => $volume,
#                   dividend    => $div_amount,
#                 };
#   }
# 
#   ### $h
#   return $h;
# }
# 
# sub mktime_in_zone {
#   my ($sec, $min, $hour, $mday, $mon, $year, $zone) = @_;
#   my $timet;
# 
#   { local $Tie::TZ::TZ = $zone->tz;
#     $timet = POSIX::mktime ($sec, $min, $hour,
#                             $mday, $mon, $year, 0,0,0);
#     my ($Xsec,$Xmin,$Xhour,$Xmday,$Xmon,$Xyear,$wday,$yday,$isdst)
#       = localtime ($timet);
#     return POSIX::mktime ($sec, $min, $hour,
#                           $mday, $mon, $year, $wday,$yday,$isdst);
#   }
# }
# 
# # $date is dmy like 7/15/2007, in GMT
# # $time is h:mp like 10:05am, in $server_zone
# #
# # return ($date, $time) iso strings like ('2008-06-11', '10:55:00') in
# # $want_zone
# #
# sub quote_parse_datetime {
#   my ($date, $time, $server_zone, $want_zone) = @_;
#   if (DEBUG) { print "quote_parse_datetime $date, $time\n"; }
#   if ($date eq 'N/A' || $time eq 'N/A') { return (undef, undef); }
# 
#   my ($sec,$min,$hour,$mday,$mon,$year)
#     = Date::Parse::strptime($date . ' ' . $time);
#   $sec //= 0; # undef if not present
#   if (DEBUG) { print "  parse $sec,$min,$hour,$mday,$mon,$year\n"; }
# 
#   my $timet = mktime_in_zone ($sec, $min, $hour,
#                               $mday, $mon, $year, $server_zone);
#   if (DEBUG) {
#     print "  timet     Serv ",do { local $Tie::TZ::TZ = $server_zone->tz;
#                                    POSIX::ctime($timet) };
#     print "  timet     GMT  ",do { local $Tie::TZ::TZ = 'GMT';
#                                    POSIX::ctime($timet) };
#   }
# 
#   my ($gmt_sec,$gmt_min,$gmt_hour,$gmt_mday,$gmt_mon,$gmt_year,$gmt_wday,$gmt_yday,$gmt_isdst) = gmtime ($timet);
# 
#   if ($gmt_mday != $mday) {
#     if (DEBUG) { print "  mday $mday/$mon cf gmt_mday $gmt_mday/$gmt_mon, at $timet\n"; }
#     if (cmp_modulo ($gmt_mday, $mday, 31) < 0) {
#       $mday++;
#     } else {
#       $mday--;
#     }
#     $timet = mktime_in_zone ($sec, $min, $hour,
#                              $mday, $mon, $year, $server_zone);
#     if (DEBUG) { print "  switch to $mday        giving $timet = $timet\n"; }
#     if (DEBUG) {
#       print "  timet     GMT  ",do { local $Tie::TZ::TZ = 'GMT';
#                                      POSIX::ctime($timet) };
#       print "  timet     Targ ",do { local $Tie::TZ::TZ = $want_zone->tz;
#                                      POSIX::ctime($timet) };
#     }
#   }
#   return $want_zone->iso_date_time ($timet);
# }
# 
# sub cmp_modulo {
#   my ($x, $y, $modulus) = @_;
#   my $half = int ($modulus / 2);
#   return (($x - $y + $half) % $modulus) <=> $half;
# }
# 
# sub decode_hms {
#   my ($str) = @_;
#   my ($hour, $minute, $second) = split /:/, $str;
#   if (! defined $second) { $second = 0; }
#   return ($hour, $minute, $second);
# }



#------------------------------------------------------------------------------
# quote_parse_div_date()

SKIP: {
  $have_test_mocktime or skip 'due to Test::MockTime not available', 6;

  Test::MockTime::set_fixed_time ('1981-01-01T00:00:00Z');
  is (App::Chart::Yahoo::quote_parse_div_date('Jan  7'), '1981-01-07');
  is (App::Chart::Yahoo::quote_parse_div_date(' 5 Jan'), '1981-01-05');
  is (App::Chart::Yahoo::quote_parse_div_date('31 Dec'), '1980-12-31');
  is (App::Chart::Yahoo::quote_parse_div_date('24-Sep-04'),    '2004-09-24');
  is (App::Chart::Yahoo::quote_parse_div_date('24 Sep, 2004'), '2004-09-24');
  is (App::Chart::Yahoo::quote_parse_div_date('Sep 24, 2004'), '2004-09-24');
  Test::MockTime::restore_time();
}


#-----------------------------------------------------------------------------
# stock info
#
# Eg. http://download.finance.yahoo.com/d?f=snxc4qr1d&s=TLS.AX
#
# This was the past info fetching using fields from the quote feature.
# That feature now gone.

# max symbols to any /q? quotes request
# Finance::Quote::Yahoo uses a limit of 40 to stop the url getting too
# long, which apparently some servers or proxies can't handle
use constant MAX_QUOTES => 40;

# App::Chart::DownloadHandler->new
#   (name         => __('Yahoo info'),
#    key          => 'Yahoo-info',
#    pred         => $download_pred,
#    proc         => \&info_download,
#    recheck_days => 7,
#    max_symbols  => MAX_QUOTES);
# 
# sub info_download {
#   my ($symbol_list) = @_;
# 
#   App::Chart::Download::status
#       (__x('Yahoo info {symbolrange}',
#            symbolrange =>
#            App::Chart::Download::symbol_range_string ($symbol_list)));
# 
#   my $url = 'http://download.finance.yahoo.com/d?f=snxc4qr1d&s='
#     . join (',', map { URI::Escape::uri_escape($_) } @$symbol_list);
#   my $resp = App::Chart::Download->get ($url);
#   my $h = info_parse($resp);
#   $h->{'recheck_list'} = $symbol_list;
#   App::Chart::Download::write_daily_group ($h);
# }
# 
# sub info_parse {
#   my ($resp) = @_;
# 
#   my $content = $resp->decoded_content (raise_error => 1);
#   if (DEBUG >= 2) { print "Yahoo info:\n$content\n"; }
# 
#   my @info;
#   my @dividends;
#   my $h = { source    => __PACKAGE__,
#             info      => \@info,
#             dividends => \@dividends };
# 
#   require Text::CSV_XS;
#   my $csv = Text::CSV_XS->new;
# 
#   foreach my $line (App::Chart::Download::split_lines ($content)) {
#     $csv->parse($line);
#     my ($symbol, $name, $exchange, $currency, $ex_date, $pay_date, $amount)
#       = $csv->fields();
# 
#     $ex_date  = quote_parse_div_date ($ex_date);
#     $pay_date = quote_parse_div_date ($pay_date);
# 
#     push @info, { symbol => $symbol,
#                   name   => $name,
#                   currency => $currency,
#                   exchange => $exchange };
#     # circa 2015 the "d" dividend amount field is "N/A" when after the
#     # dividend payment (with "r1" pay date "N/A" too)
#     if ($ex_date && $amount ne 'N/A' && $amount != 0) {
#       push @dividends, { symbol   => $symbol,
#                          ex_date  => $ex_date,
#                          pay_date => $pay_date,
#                          amount   => $amount };
#     }
#   }
#   return $h;
# }


#--------------------------------------------------------------------
# Past Weblink info page
#
# For reference, past was like http://finance.yahoo.com/q?s=BHP.AX
# but that's been taken away so as to break everybody's bookmarks.


#-----------------------------------------------------------------------------
# v7 cookies and crumb
# Download Data
#
# This uses the historical prices page like
#
#     https://finance.yahoo.com/quote/AMP.AX/history?p=AMP.AX
#
# which puts a cookie like
#
#     Set-Cookie: B=fab5sl9cqn2rd&b=3&s=i3; expires=Sun, 03-Sep-2018 04:56:13 GMT; path=/; domain=.yahoo.com
#
# and contains buried within 1.5 mbytes of hideous script
#
#    <script type="application/json" data-sveltekit-fetched data-url="https://query1.finance.yahoo.com/v1/test/getcrumb?lang=en-US&amp;region=US" data-ttl="59">{"status":200,"statusText":"OK","headers":{},"body":"DKVWQE/ggh4"}</script>
#
# Any \u002F or similar is escaped "/" character or similar.
# The crumb is included in a CSV download query like the following
# (alas can't use http, it redirects to https)
#
#     https://query1.finance.yahoo.com/v7/finance/download/AMP.AX?period1=1503810440&period2=1504415240&interval=1d&events=history&crumb=hdDX/HGsZ0Q
#
# period1 is the start time, period2 the end time, both as Unix seconds
# since 1 Jan 1970.  Not sure of the timezone needed.  Some experiments
# suggest it depends on the timezone of the symbol.  http works as well as
# https.  The result is like
#
#     Date,Open,High,Low,Close,Adj Close,Volume
#     2017-09-07,30.299999,30.379999,30.000000,30.170000,30.170000,3451099
#
# The "9999s" are some bad rounding off to what would be usually at most
# 3 (maybe 4?) decimal places.
#
# Response is 404 if no such symbol, 401 unauthorized if no cookie or crumb.
#
# "events=div" gives dividends like
#
#     Date,Dividends
#     2017-08-11,0.161556
#
# "events=div" gives splits like, for a consolidation (GXY.AX)
#
#     Date,Stock Splits
#     2017-05-22,1/5
#
#----------------
# For reference, there's a "v8" which is json format (%7C = "|")
#
#     https://query2.finance.yahoo.com/v8/finance/chart/IBM?formatted=true&lang=en-US&region=US&period1=1504028419&period2=1504428419&interval=1d&events=div%7Csplit&corsDomain=finance.yahoo.com
#
# This doesn't require a cookie and crumb, has some info like symbol
# timezone.  The numbers look like they're rounded through 32-bit single
# precision floating point, for example "142.55999755859375" which is 142.55
# in a 23-bit mantissa.  log(14255000)/log(2) = 23.76 bits
# Are they about the same precision as the CSV ?
#
# FIXME: All prices look like they're split-adjusted, which is ok if that's
# what you want and are downloading a full data set, but bad for incremental
# since you don't know when a change is applied.
#

App::Chart::DownloadHandler->new
  (name       => __('Yahoo'),
   pred       => $download_pred,
   available_tdate_by_symbol => \&daily_available_tdate,
   available_tdate_extra     => 2,
   proc       => \&daily_download,
   chunk_size => 150);

sub daily_available_tdate {
  my ($symbol) = @_;

  # Sep 2017: daily data is present for the current day's trade, during the
  # trading session.  Try reckoning it complete at 6pm.
  return App::Chart::Download::tdate_today_after
    (18,0, App::Chart::TZ->for_symbol ($symbol));

  # return App::Chart::Download::tdate_today_after
  #   (10,30, App::Chart::TZ->for_symbol ($symbol))
  #     - 1;
}

sub daily_download {
  my ($symbol_list) = @_;
  App::Chart::Download::status (__('Yahoo daily data'));

  # App::Chart::Download::verbose_message ("Yahoo crumb $crumb cookies\n"
  #                                        . $jar->as_string);

  my $crumb_errors = 0;
 SYMBOL: foreach my $symbol (@$symbol_list) {
    my $lo_tdate = App::Chart::Download::start_tdate_for_update (@$symbol_list);
    my $hi_tdate = daily_available_tdate ($symbol);

    App::Chart::Download::status
        (__('Yahoo data'), $symbol,
         App::Chart::Download::tdate_range_string ($lo_tdate, $hi_tdate));

    my $lo_timet = tdate_to_unix($lo_tdate - 2);
    my $hi_timet = tdate_to_unix($hi_tdate + 2);

    my $data  = daily_cookie_data($symbol);
    if (! defined $data) {
      print "Yahoo $symbol no daily cookie data\n";
      next SYMBOL;
    }
    my $crumb = URI::Escape::uri_escape($data->{'crumb'});
    my $jar = http_cookies_from_string($data->{'cookies'} // '');

    my $h = { source          => __PACKAGE__,
              prefer_decimals => 2,
              date_format   => 'ymd',
            };
    foreach my $elem (['history',\&daily_parse],
                      ['div',    \&daily_parse_div],
                      ['split',  \&daily_parse_split]) {
      my ($events,$parse) = @$elem;
      my $url = "https://query1.finance.yahoo.com/v7/finance/download/"
        . URI::Escape::uri_escape($symbol)
        . "?period1=$lo_timet"
        . "&period2=$hi_timet"
        . "&interval=1d"
        . "&events=$events"
        . "&crumb=$crumb"
        ;

      my $resp = App::Chart::Download->get ($url,
                                            allow_401 => 1,
                                            allow_404 => 1,
                                            # cookie_jar => $jar,
                                           );
      if ($resp->code == 401) {
        if (++$crumb_errors >= 2) {
          die "Yahoo: crumb authorization failed"; 
        }
        App::Chart::Database->write_extra ('', 'yahoo-daily-cookies', undef);
        redo SYMBOL;
      }
      if ($resp->code == 404) {
        print "Yahoo $symbol does not exist\n";
        next SYMBOL;
      }
      $parse->($symbol,$resp,$h, $hi_tdate);
    }
    ### $h
    App::Chart::Download::write_daily_group ($h);
  }
}

sub daily_parse {
  my ($symbol, $resp, $h, $hi_tdate) = @_;
  my @data = ();
  $h->{'data'} = \@data;
  my $hi_tdate_iso;
  if (defined $hi_tdate){ $hi_tdate_iso = App::Chart::tdate_to_iso($hi_tdate); }

  my $body = $resp->decoded_content (raise_error => 1);
  my @line_list = App::Chart::Download::split_lines($body);

  unless ($line_list[0] =~ /^Date,Open,High,Low,Close,Adj Close,Volume/) {
    die "Yahoo: unrecognised daily data headings: " . $line_list[0];
  }
  shift @line_list;

  foreach my $line (@line_list) {
    my ($date, $open, $high, $low, $close, $adj_volume, $volume)
      = split (/,/, $line);

    $date = daily_date_fixup ($symbol, $date);
    if (defined $hi_tdate_iso && $date gt $hi_tdate_iso) {
      # Sep 2017: There's a daily data record during the trading day, but
      # want to write the database only at the end of trading.
      ### skip date after hi_tdate ...
      next;
    }

    # Sep 2017 have seen "null,null,null,...", maybe for non-trading days
    foreach my $field ($open, $high, $low, $close, $adj_volume, $volume) {
      if ($field eq 'null') {
        $field = undef;
      }
    }

    if ($index_pred->match($symbol)) {
      # In the past indexes which not calculated intraday had
      # open==high==low==close and volume==0, eg. ^WIL5.  Use the close
      # alone in this case, with the effect of drawing line segments instead
      # of OHLC or Candle figures with no range.

      if (defined $open && defined $high && defined $low && defined $close
          && $open == $high && $high == $low && $low == $close && $volume == 0){
        $open = undef;
        $high = undef;
        $low = undef;
      }

    } else {
      # In the past shares with no trades had volume==0,
      # open==low==close==bid price, and high==offer price, from some time
      # during the day, maybe the end of day.  Zap all the prices in this
      # case.
      #
      # For a public holiday it might be good to zap the volume to undef
      # too, but don't have anything to distinguish holiday, suspension,
      # delisting vs just no trades.
      #
      # On the ASX when shares are suspended the bid/offer can be crossed as
      # usual for pre-open auction, and this gives high<low.  For a part-day
      # suspension then can have volume!=0 in this case too.  Don't want to
      # show a high<low, so massage high/low to open/close range if the high
      # looks like a crossed offer.

      if (defined $high && defined $low && $high < $low) {
        $high = App::Chart::max_maybe ($open, $close);
        $low  = App::Chart::min_maybe ($open, $close);
      }

      if (defined $open && defined $low && defined $close && defined $volume
          && $open == $low && $low == $close && $volume == 0) {
        $open  = undef;
        $high  = undef;
        $low   = undef;
        $close = undef;
      }
    }

    push @data, { symbol => $symbol,
                  date   => $date,
                  open   => crunch_trailing_nines($open),
                  high   => crunch_trailing_nines($high),
                  low    => crunch_trailing_nines($low),
                  close  => crunch_trailing_nines($close),
                  volume => $volume };
  }
  return $h;
}
sub daily_parse_div {
  my ($symbol, $resp, $h) = @_;
  my @dividends = ();
  $h->{'dividends'} = \@dividends;

  my $body = $resp->decoded_content (raise_error => 1);
  my @line_list = App::Chart::Download::split_lines($body);

  # Date,Dividends
  # 2015-11-04,1.4143
  # 2016-05-17,1.41428
  # 2017-05-16,1.4143
  # 2016-11-03,1.4143

  unless ($line_list[0] =~ /^Date,Dividends/) {
    warn "Yahoo: unrecognised dividend headings: " . $line_list[0];
    return;
  }
  shift @line_list;

  foreach my $line (@line_list) {
    my ($date, $amount) = split (/,/, $line);

    push @dividends, { symbol  => $symbol,
                       ex_date => daily_date_fixup ($symbol, $date),
                       amount  => $amount };
  }
  return $h;
}
sub daily_parse_split {
  my ($symbol, $resp, $h) = @_;
  my @splits = ();
  $h->{'splits'} = \@splits;

  my $body = $resp->decoded_content (raise_error => 1);
  my @line_list = App::Chart::Download::split_lines($body);

  # For example GXY.AX split so $10 shares become $2
  # Date,Stock Splits
  # 2017-05-22,1:5
  #
  # In the past it was a "/" instad of ":"
  # 2017-05-22,1/5

  unless ($line_list[0] =~ /^Date,Stock Splits/) {
    warn "Yahoo: unrecognised split headings: " . $line_list[0];
    return;
  }
  shift @line_list;

  foreach my $line (@line_list) {
    my ($date, $ratio) = split (/,/, $line);
    my ($old, $new) = split m{[:/]}, $ratio;

    push @splits, { symbol  => $symbol,
                    date    => daily_date_fixup ($symbol, $date),
                    new     => $new,
                    old     => $old };
  }
  return $h;
}

# return a hashref
#   { cookies => string,   # in format HTTP::Cookies ->as_string()
#     crumb   => string
#   }
#
# If no such $symbol then return undef;
#
# Any $symbol which exists is good enough to get a crumb for all later use.
# Could hard-code something likely here, but better to go from the symbol
# which is wanted.
#
# As of April 2024, some User-Agent strings result in 503 Service Unavailable.
# Doesn't seem to affect other download parts, just this cookie/crumb
# getting part.  "Mozilla/5.0" works.
#
sub daily_cookie_data {
  my ($symbol) = @_;
  require App::Chart::Pagebits;
  $symbol = URI::Escape::uri_escape($symbol);
  return App::Chart::Pagebits::get
    (name       => __('Yahoo daily cookie'),
     url        => "https://finance.yahoo.com/quote/$symbol/history?p=$symbol",
     key        => 'yahoo-daily-cookies',
     freq_days  => 3,
     parse      => \&daily_cookie_parse,
     user_agent => 'Mozilla/5.0',
     allow_404  => 1);
}
sub daily_cookie_parse {
  my ($content, $resp) = @_;

  # script like, with backslash escaping on "\uXXXX"
  #   "user":{"age":0,"crumb":"8OyCBPyO4ZS"
  # The form prior to about July 2023 was
  #   "user":{"crumb":"hdDX\u002FHGsZ0Q",
  # The form prior to about January 2023 was
  #   "CrumbStore":{"crumb":"hdDX\u002FHGsZ0Q"}
  # The form prior to about May 2024 was
  #   "RequestPlugin":{"user":{"age":0,"crumb":"8OyCBPyO4ZS"
  #
  $content =~ /getcrumb.*?"body":"([^"]*)"/
    or die "Yahoo daily data: getcrumb not found in parse";
  my $crumb = App::Chart::Yahoo::javascript_string_unquote($1);

  # header like
  # Set-Cookie: B=fab5sl9cqn2rd&b=3&s=i3; expires=Sun, 03-Sep-2018 04:56:13 GMT; path=/; domain=.yahoo.com
  #
  # Expiry time is +1 year.  Who knows whether would really work that long.
  #
  require HTTP::Cookies;
  my $jar = HTTP::Cookies->new;
  $jar->extract_cookies($resp);
  my $cookies_str = $jar->as_string;

  App::Chart::Download::verbose_message ("Yahoo new crumb $crumb\n"
                                         . $cookies_str);
  return { crumb   => $crumb,
           cookies => $cookies_str };
}

# $str is an ISO date string like 2017-11-05
# It is date GMT of 9:30am in the timezone of $symbol.
# Return the date in the symbol timezone.
# 
# This was a fix needed for CSV where dates were (unhelpfully)
# in GMT rather than the timezone of the exchange.
#
sub daily_date_fixup {
  my ($symbol, $str) = @_;
  ### daily_date_fixup: "$symbol  $str"
  my ($year, $month, $day) = App::Chart::iso_to_ymd ($str);

  my $timezone = App::Chart::TZ->for_symbol($symbol);
  if (timezone_gmtoffset_at_ymd($timezone, $year, $month, $day+1)
      <= - (10*60+20)*60) {
    my $adate = App::Chart::ymd_to_adate ($year, $month, $day);
    $str = App::Chart::adate_to_iso ($adate+1);
    my $today = $timezone->iso_date();
    if ($str gt $today) {
      $str = $today;
    }
  }
  return $str;
}
sub timezone_gmtoffset_at_ymd {
  my ($timezone, $year, $month, $day) = @_;
  my $timet = $timezone->call(\&POSIX::mktime,
                              0, 0, 0, $day, $month-1, $year-1900);
  my ($sec,$min,$hour,$gmt_day) = gmtime($timet);
  return $sec + 60*$min + 3600*$hour + 86400*($gmt_day - $day);
}

# $str is a string from previous HTTP::Cookies ->as_string()
# Return a new HTTP::Cookies object with that content.
sub http_cookies_from_string {
  my ($str) = @_;
  require File::Temp;
  my $fh = File::Temp->new (TEMPLATE => 'chart-XXXXXX',
                            TMPDIR => 1);
  print $fh "#LWP-Cookies-1.0\n", $str or die;
  close $fh or die;
  require HTTP::Cookies;
  my $jar = HTTP::Cookies->new;
  $jar->load($fh->filename);
  return $jar;
}

# (String quoting for parsing of <script> in HTML to get crumb.)
# undo javascript string backslash quoting in STR, per
#
#     https://developer.mozilla.org/en/JavaScript/Guide/Values,_Variables,_and_Literals#String_Literals
#
# Encode::JavaScript::UCS does \u, but not the rest
#
# cf Java as such not quite the same:
#   unicode: http://java.sun.com/docs/books/jls/third_edition/html/lexical.html#100850
#   strings: http://java.sun.com/docs/books/jls/third_edition/html/lexical.html#101089
#
my %javascript_backslash = ('b' => "\b",   # backspace
                            'f' => "\f",   # formfeed
                            'n' => "\n",   # newline
                            'r' => "\r",
                            't' => "\t",   # tab
                            'v' => "\013", # vertical tab
                           );
sub javascript_string_unquote {
  my ($str) = @_;
  $str =~ s{\\(?:
              ((?:[0-3]?[0-7])?[0-7]) # $1 \377 octal latin-1
            |x([0-9a-fA-F]{2})        # $2 \xFF hex latin-1
            |u([0-9a-fA-F]{4})        # $3 \uFFFF hex unicode
            |(.)                      # $4 \n etc escapes
            )
         }{
           (defined $1 ? chr(oct($1))
            : defined $4 ? ($javascript_backslash{$4} || $4)
            : chr(hex($2||$3)))   # \x,\u hex
         }egx;
  return $str;
}


#-----------------------------------------------------------------------------
