#!/usr/bin/perl

use strict;
use warnings;

use Imager;
use Imager::Font;
use Getopt::Long;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use feature 'say';
    
use lib 'lib/';
use FlipDot::Hanover::Display;

my $rows = 7;
my $cols = 84;
my $address = 5;
my $font_file = '/mnt/shared/projects/flipdot/fonts/ttf - Ac (aspect-corrected)/AcPlus_IBM_MDA.ttf'; #8x14

GetOptions('rows=i' => \$rows,
           'cols=i' => \$cols,
           'address=i' => \$address,
           'font:s' => \$font_file,
    ) or die "Missing command line args\n";

my $display = FlipDot::Hanover::Display->new(width => $cols,
					     height => $rows,
					     address => $address);
my $font = Imager::Font->new(
    file => $font_file,
    color => 'white',
    size => 10,
    );

my $loop = IO::Async::Loop->new();
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick => sub {
            my $image = Imager->new(xsize => $cols, ysize => $rows, channels => 1);
	    for my $x (1,2,3) {
		for my $y (4,5,6) {
		    $image->setpixel(x=>$x, y=>$y);
		}
	    }
	    my $packet = $display->imager_to_packet($image);
	    say $packet;
	    open my $portfh, '>/dev/ttyUSB0' or die "can't open /dev/ttyUSB0: $!";
	    my $termios = POSIX::Termios->new;
	    $termios->getattr($portfh->fileno);
	    $termios->setispeed(POSIX::B4800());
	    $termios->setospeed(POSIX::B4800());
	    $termios->setattr($portfh->fileno, POSIX::TCSANOW());
	    $portfh->print($packet) or die "Couldn't write packet: $!";
	    close $portfh or die "Couldn't close: $!";

	    exit;
        },
    )->start );
$loop->run;
