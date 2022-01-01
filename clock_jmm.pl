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
my $font_file = '/mnt/shared/projects/flipdot/fonts/ttf - Ac (aspect-corrected)/AcPlus_IBM_MDA.ttf'; #8x14

GetOptions('rows=i' => \$rows,
           'cols=i' => \$cols,
           'address=i' => \$address,
           'font:s' => \$font_file,
    ) or die "Missing command line args\n";

my $frames = 0;
my $start_time = time;

my @formats = (
    #{ type=>'delta', base=>{year => 2022, month => 6, day => 2}},
    #{ type=>'cldr', format=>'yyyy-MM-dd hh:mm:ss'},
    #{ type=>'cldr', format=>'d MMMM yyyy GGGG'},
    #{ type=>'cldr', format=>'MMMM d yyyy GGGG'},
    #{ type=>'framerate'},
    #{ type => 'cldr', format=>'HH:MM:ss' },
    { type => 'countdown', until=>DateTime->new(year => '2022', time_zone => 'Europe/London'), when => sub { return $_[0]->is_positive; }, end_text => 'HAPPY NEW YEAR!'},
);

sub load_font {
    my $path = shift;
    
    my $f=Imager::Font->new(file => $_,
			    color => 'white',
			    size => 16);
    return if not $f;
    my $bbox =  $f->bounding_box(string => '1234567890:');
    my $bbox_height = $bbox->text_height;
    my $right_size = $bbox_height / 16 * $rows+2;
    $right_size = sprintf('%.0f', $right_size);
    
    say "font $path, bbox height $bbox_height, right_size=$right_size";
    
    $f=Imager::Font->new(file => $_,
			 color => 'white',
			 size => $right_size);
    
    $bbox =  $f->bounding_box(string => '1234567890:');
    $bbox_height = $bbox->text_height;
    say "after adjustment, $bbox_height";
			 
    return $f;
}

my @fonts = map {load_font($_)}
grep {1}
glob 'fonts/ttf\ -\ Ac*/*';

print "loaded ".@fonts." fonts\n";

sub do_format {
   my ($now, $format) = @_;

    if ($format->{type} eq 'delta') {
        my $base = DateTime->new(%{$format->{base}});
        my $dur = $now->subtract($base);
        my $since_to = $dur->is_posistive ? 'EMF+' : 'EMF-';
        return $since_to . $dur->months . 'm '. $dur->days. 'd '. $dur->hours. 'h '. $dur->minutes. 'm '. $dur->seconds. 's';
    } elsif ($format->{type} eq 'cldr') {
        return $now->format_cldr($format->{format});
    } elsif ($format->{type} eq 'framerate') {
        my $etime = time() - $start_time;
        my $fps = $frames/$etime;
        return $fps . " fps";
    } elsif ($format->{type} eq 'countdown') {
        my $duration = DateTime->now->subtract_datetime($format->{until});
	my $text = '';
	if (exists $format->{when} && $format->{when}->($duration)) {
	    $text = $format->{end_text};
        } else {
	    $text = "T";
	    if ($duration->is_positive) {
		$text .= "+";
	    } else {
		$text .= "-";
	    }
        
	    my %show;
	    if ($duration->days() != 0) {
		$show{d} = 1;
		$show{h} = 1;
		$show{m} = 1;
		$show{s} = 1;
	    } elsif ($duration->hours() != 0) {
		$show{h} = 1;
		$show{m} = 1;
		$show{s} = 1;
	    } elsif ($duration->minutes() != 0) {
		$show{m} = 1;
		$show{fs} = 1;
	    } else {
		$show{fs} = 1;
	    }

	    if ($show{d}) {
		$text .= sprintf "%dd", $duration->days();
	    }
	    if ($show{h}) {
		$text .= sprintf "%dh", $duration->hours();
	    }
	    if ($show{m}) {
		$text .= sprintf "%dm", $duration->minutes();
	    }
	    if ($show{s}) {
		$text .= sprintf "%ds", $duration->seconds();
	    }
	    if ($show{fs}) {
		$text .= sprintf "%02.4fs", $duration->seconds() + $duration->nanoseconds()  * 1e-9;
	    }
	}

        return $text;

    } else {
        return $format->{type} . " not known";
    }
}

my $display = FlipDot::Hanover::Display->new(
    width => $cols,
    height => $rows,
    address => $address,
    upside_down => 0);

my $loop = IO::Async::Loop->new();

$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 0.01,
        on_tick => sub {
            $frames++;
	    my $format = $formats[rand @formats];
	    my $now = DateTime->now;
	    my $t_string = do_format($now, $format);
	    
	    say "text: $t_string";
            # testing sizes!
	    my $font = $fonts[4];
	    #my $font = $fonts[rand @fonts];
            my $bbox =  $font->bounding_box(string => $t_string);
            #print "BBox $t_string H/W :", $bbox->text_height, "/", $bbox->display_width, "\n";
            my $image = Imager->new(xsize => $cols, ysize => $rows, channels => 1);
            $image->string(x=>0,y=>$rows,
                           string => $t_string,
                           font   => $font,
                );
            # $t_string =~ s/:/_/g;
            # $image->write(file=>"./$t_string.png") or die $image->errstr;
            # send image to display!
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
