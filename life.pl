#!/usr/bin/perl

use strict;
use warnings;

use Imager;
use Imager::Font;
use Getopt::Long;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use feature 'say';
use DateTime;
use Time::HiRes 'time';
use Game::Life;
    
use lib 'lib/';
use FlipDot::Hanover::Display;

# small display
my $rows = 7;
my $cols = 84;
my $address = 5;
# big display
#my $rows = 16;
#my $cols = 96;
#my $address = 3;
my $font_file = '/mnt/shared/projects/flipdot/fonts/ttf - Ac (aspect-corrected)/AcPlus_IBM_MDA.ttf'; #8x14

GetOptions('rows=i' => \$rows,
           'cols=i' => \$cols,
           'address=i' => \$address,
           'font:s' => \$font_file,
    ) or die "Missing command line args\n";

my $frames = 0;
my $start_time = time;

my $display = FlipDot::Hanover::Display->new(
    width => $cols,
    height => $rows,
    address => $address);

my $loop = IO::Async::Loop->new();

my $p = 0.25;
my $gol = Game::Life->new([$rows, $cols]);
for my $x (0..$cols) {
    for my $y (0..$rows) {
	if (rand() < $p) {
	    $gol->set_point($x, $y);
	}
    }
}

$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick => sub {
            $frames++;
	    
            my $image = Imager->new(xsize => $cols, ysize => $rows, channels => 1);
	    my $golgrid = $gol->get_grid;

	    for my $x (0..$cols) {
		for my $y (0..$rows) {
		    if ($golgrid->[$x][$y]) {
			$image->setpixel(x=>$x, y=>$y, color=>'white');
		    }
		}
	    }
	    $gol->process;
		    

	    
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
        },
    )->start );
$loop->run;
