#!/usr/bin/perl

use strict;
use warnings;

use Imager;
use Imager::Font;
use Getopt::Long;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;
    
use lib 'lib/';
use FlipDot::Hanover::Display;

my $rows = 7;
my $cols = 32;
my $address = 1;
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
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                localtime(time());
            my $t_string = sprintf("%02d:%02d:%02d",
                                   $hour, $min, $sec);
            # testing sizes!
            my $bbox =  $font->bounding_box(string => $t_string);
            print "BBox $t_string H/W :", $bbox->text_height, "/", $bbox->display_width, "\n";
            my $image = Imager->new(xsize => $cols, ysize => $rows, channels => 1);
            $image->string(x=>0,y=>$rows,
                           string => $t_string,
                           font   => $font,
                );
            # $t_string =~ s/:/_/g;
            # $image->write(file=>"./$t_string.png") or die $image->errstr;
            # send image to display!
            $display->imager_to_packet($image);
                           
        },
    )->start );
$loop->run;
