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

GetOptions('rows=i' => \$rows,
           'cols=i' => \$cols,
           'address=i' => \$address,
    ) or die "Bad command line args\n";

my $display = FlipDot::Hanover::Display->new(
#    display => '7x84x5',
    display => '16x96x3',
    upside_down => 0);


my $loop = IO::Async::Loop->new();

my $invert = 0;
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 2,
        on_tick => sub {
            my $image = Imager->new(xsize => 96, ysize => 16, channels => 1);
            if ($invert) {
                $image->box(color => 'black', filled => 1);
            } else {
                $image->box(color => 'white', filled => 1);
            }
            $invert = !$invert;

            $display->send_image($image);
        },
    )->start );
$loop->run;
