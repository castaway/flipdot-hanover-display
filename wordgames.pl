#!/usr/bin/perl

use strict;
use warnings;

use Imager;
use Getopt::Long;
use DateTime;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use feature 'say';
    
use lib 'lib/';
use FlipDot::Hanover::Display;
use WordGames::Schema;

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
    display => '7x84x5',
#    display => '16x96x3',
    upside_down => 0);

my $last_update; #  = DateTime->now()->subtract(days => 1);
my $schema = WordGames::Schema->connect('dbi:SQLite:dbname=wordgames.db');
my $loop = IO::Async::Loop->new();

$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick => sub {
            my $game = $schema->resultset('Hangman')->find({ player_id => 1 });
            my $image;
	    my $latest_update = $game->latest_update;
            if ($game && (!$last_update || $latest_update > $last_update)) {
		$last_update = $latest_update;
                my $game_state = $game->game_state();
		print "Current hangman: $game_state\n";
                $image = $display->text_to_image('', $game_state, 0);
	    }
	    if(!$image) {
	     # print "Failed to get state\n";
	     # print "Game: $game\n";
	     # print "Last update: " . $game->latest_update, "\n";
	    }
            # } else {
            #     $image = Imager->new(xsize => 84, ysize => 7, channels => 1);
            #     $image->box(color => 'white', filled => 1);
            # }
	    if ($image) {
		$display->send_image($image);
	    }
        },
    )->start );
$loop->run;
