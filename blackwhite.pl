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

my $n = 0;
my $white = Imager->new(xsize => 96, ysize => 16, channels => 1);
$white->box(color=>'white', filled => 1);
my $black = Imager->new(xsize => 96, ysize => 16, channels => 1);
$black->box(color=>'black', filled => 1);
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick => sub {
            my $image;
            if (($n / 100) & 1) {
                say "white";
                $image = $white;
            } else {
                say "black";
                $image = $black;
            }
            $n++;

            say $n;
            $display->send_image($image);
        },
    )->start );
$loop->run;
