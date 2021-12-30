#!/usr/bin/perl

use strict;
use warnings;

use Future::AsyncAwait;
use Term::ReadKey;
use Imager;
use Imager::Font;
use Getopt::Long;
use IO::Async::Loop;
use IO::Async::Handle;
use IO::Async::Stream;
use IO::Async::Timer::Periodic;
use feature 'say';
use DateTime;
use List::Util 'shuffle';
    
use lib 'lib/';
use FlipDot::Hanover::Display;

# small display
my $rows = 7;
my $cols = 84;
my $address = 5;
# big display
# my $rows = 16;
# my $cols = 96;
# my $address = 3;
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
    size => 8,
    );

my $loop = IO::Async::Loop->new();

my $length = 2;
my $snakeY = 6;
my $snakeX = 2;
my $dir = 'x+';

my @dots = ();
my $dotcount = 3;

open my $portfh, '>/dev/ttyUSB0' or die "can't open /dev/ttyUSB0: $!";
my $termios = POSIX::Termios->new;
$termios->getattr($portfh->fileno);
$termios->setispeed(POSIX::B4800());
$termios->setospeed(POSIX::B4800());
$termios->setattr($portfh->fileno, POSIX::TCSANOW());
$portfh->autoflush(1);
say "portfh: $portfh";

my $stream = 
    IO::Async::Stream->new(
        read_handle => \*STDIN,
        write_handle => $portfh,
        on_read => sub {
            return 0;
        },
        # Attempt to write everything in one call to the kernel write().
        # write_all => 1,
    );

async sub reader {
    while (1) {
        my ($char, $eof) = await $stream->read_exactly(1);
        return if $eof;
        handle_keypress($char);
    }
}

async sub writer {
    while (1) {
        my $packet = draw_display();
        await $stream->write($packet);
        my $fh = $stream->write_handle;
        # Really, really write right now.
        # $fh->flush;
        # $fh->sync;
    }
}

ReadMode 3;

$loop->add($stream);

# update dotcount for difficulty
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 5,
        on_tick => sub {
            $dotcount++;
        }
    )->start
);

my $reader_f = reader();
my $writer_f = writer();

$loop->await($reader_f);

# $loop->run;

# close $portfh or die "Couldn't close: $!";

sub handle_keypress {
    my ($input) = @_;
    print "Received input: $input\n";
    if($input eq q{'} or
       $input eq 'w') {
        # turn up
        $dir = 'y+';
    } elsif($input eq '/' or
            $input eq 's') {
        # turn down
        $dir = 'y-';
    } elsif($input eq 'z' or
            $input eq 'a'
        ) {
        # turn left
        $dir = 'x-';
    } elsif($input eq 'x' or
            $input eq 'd') {
        # turn right
        $dir = 'x+';
    }
}

sub draw_dots {
    # ensure we have enough dots left
    my @allpossible;
    foreach my $index ($#dots .. $dotcount) {
        
    }
}

# needs to cope with turning corners!
sub draw_display {
    my $image = Imager->new(xsize => $cols, ysize => $rows, channels => 1);
    my ($snakeX2,$snakeY2);
    say "dir: $dir";
    if($dir eq 'x+') {
        $snakeX2 = $snakeX + $length;
        $snakeY2 = $snakeY;
        $snakeX++;
        $snakeX = $cols-$length if $snakeX > $cols-$length;
    } elsif($dir eq 'x-') {
        $snakeX2 = $snakeX - $length;
        $snakeY2 = $snakeY;
        $snakeX--;
        $snakeX = 0 if $snakeX < 0;
    } elsif($dir eq 'y+') {
        $snakeY2 = $snakeY - $length;
        $snakeX2 = $snakeX;
        $snakeY--;
        $snakeY = 0 if $snakeY < 0;
    } elsif($dir eq 'y-') {
        $snakeY2 = $snakeY + $length;
        $snakeX2 = $snakeX;
        $snakeY++;
        $snakeY = $rows-$length if $snakeY > $rows-$length;
    }

    $image->line(color => 'white',
                 x1=> $snakeX, x2 => $snakeX2,
                 y1=> $snakeY, y2 => $snakeY2);
    my $packet = $display->imager_to_packet($image);
    # say $packet;
    return $packet;
}
    
