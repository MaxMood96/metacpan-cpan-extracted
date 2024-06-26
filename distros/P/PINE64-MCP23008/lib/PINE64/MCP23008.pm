#!/usr/bin/perl 
use strict;
use Device::I2C;
use IO::Handle;
use Fcntl;

package PINE64::MCP23008;

our $VERSION = '0.901';

#global vars
my ($i2cbus, $addr, $gpext);
my $gpregval = 0; 	#init gpio register value to 0

my @pin_nums = (1,2,4,8,16,32,64,128);

sub new{
	my $class = shift;
	my $self = bless {}, $class;

	#first arg is device address
	$addr = $_[0];

	#second arg i2c bus; optional
	$i2cbus = $_[1];
	
	if($i2cbus eq ''){
		$i2cbus = '/dev/i2c-0';
	}#end if
	
	$gpext = Device::I2C->new($i2cbus, "r+"); 

	#init i2c device
	$gpext->checkDevice($addr);
	$gpext->selectDevice($addr);

	#init gp register val to all off
	$gpregval = 0; 

	return $self;
}#end new

sub set_direction{
	#sets value of the IO direction register
	#ie 255 makes all input; 0 makes all output

	my $direction = $_[1];
	$gpext->writeByteData(0x00, $direction);	
}#end set_direction

sub enable_pullup{
	#when a pin is configured as an input
	#you can enable internal 100K pull-up
	#resistors by writing to the GPPU register
	#0-255 are valid values: 0 - all disabled
	#255 - all enabled
	
	my $en_gppu = $_[1];
	$gpext->writeByteData(0x06, $en_gppu);
}#end enable_pullup

sub set_polarity{
	#sets the polarity of the gpio pins; 
	#0 is normal polarity
	#255 is all pins reversed
	
	my $io_pol = $_[1];
	$gpext->writeByteData(0x01, $io_pol);
}#end set_polarity

sub write_pin{
	my $ind = $_[1];
	my $iox = $pin_nums[$ind];

	#1 or 0
	my $val = $_[2];

	#check 0x09 register to see if
	#pin already high; if so, do nothing
	my $regval = $gpext->readByteData(0x09);
	my $binout = sprintf("%08b", $regval);
	my @pinvals = split(//, $binout); 
	@pinvals = reverse(@pinvals); 
	my $already_high = $pinvals[$ind]; 

	if($val == 1 && $already_high == 0){
		$gpregval+=$iox; 
	}#end if
	if($val == 0 && $already_high == 1){
		$gpregval-=$iox;
	}#end if

	$gpext->writeByteData(0x09, $gpregval);
}#end write_pin

sub read_pin{
	my $ind = $_[1];
	my $iox = $pin_nums[$ind];
	my $pinval = 0; 

	#read GPIO register
	my $regval = $gpext->readByteData(0x09); 

	#ensure 8 binary places are displayed
	my $binout = sprintf("%08b", $regval);

	#parse eight binary digits into an array
	my @pinvals = split(//, $binout);
	
	#reverse array to match pin #'s
	@pinvals = reverse(@pinvals);

	#value of pin is index of $pinvals
	$pinval = $pinvals[$ind]; 

	return $pinval; 
}#end read_pin

sub read_gpio_register{
	#read GPIO register
	my $regval = $gpext->readByteData(0x09); 

	return $regval;
}#end read_gpio_register

1;
__END__

=head1 NAME

PINE64::MCP23008 - Perl interface to the MCP23008 GPIO extender. Can
be used on any single board computer that has I2C capabilities.

=head1 SYNOPSIS
	
	#--------READ PIN EXAMPLE---------------
	my $gpext = PINE64::MCP23008->new(0x20);

	$gpext->set_direction(255);	#all input
	$gpext->enable_pullup(255);	#enable internal pullup resistors
	$gpext->set_polarity(255);	#reverse io polarity

		#read pins 0 - 7
		for(my $i=0;$i<8;$i++){
			my $pinval = $gpext->read_pin($i); 
			print "pin $i:\t$pinval\n";
			sleep(1);
		}#end inner for
		print "---------------------------\n";

	#------WRITE PIN EXAMPLE---------------
	$gpext->set_direction(0);	#all output
	$gpext->enable_pullup(0);	#disable internal pullup resistors
	$gpext->set_polarity(0);	#normal io polarity

	$gpext->write_pin(2, 1);	#set gpio 2 high 

=head1 METHODS

=head2 new($address, $i2cbus)

Takes hexadecimal address of the i2c gpio extender chip and optionally,
a string containing the path of the i2c controller on your single
board computer i.e. /dev/i2c-1.  Defaults to /dev/i2c-0.  

=head2 set_direction()

Takes decimal from 0-255 as an argument and writes it to the IO direction
register, 0x00.  For example, if you want all the pins to be output, 
pass 0; all input pass 255; pin 7 and pin 1 as input, all others output, 
pass 130 (128 + 2).  

=head2 set_polarity()

Takes a decimal from 0 to 255 as an argument and writes it to the 
IO polarity register, 0x01.  Default is normal polarity. To reverse
polarity on all pins, pass 255.  If just to pins 2 & 3, pass 10
(4 + 8).  

=head2 enable_pullup()

Takes a decimal from 0 - 255 as an argument and writes that value to 
the GPPU register, 0x06.  A high value for a pin (that is configured
as an input) will enable the internal 100K pullup resistors.  The pin
will be a logical high unless pulled low externall.  

This method is most useful when used on pins configured as inputs. For
example, you can use with reverse polarity (see input example in the 
SYNOPSIS).  

=head2 write_pin($pin_number, $value)

Sets GPIO $pin_number (0 - 7) to $value (0 or 1) when pin is configured
as an output. 

=head2 read_pin($pin_number)

Returns the value of $pin_number.  As stated before, use with reversed
polarity, and enable the pullup resistors (or build an external pull up
resistor).  

=head2 read_gpio_register()

Returns the decimal value (0-255) of the 0x09 gpio register
