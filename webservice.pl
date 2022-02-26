#!/usr/bin/perl

use Mojolicious::Lite -signatures;
use Imager;
use Path::Class;
use Regexp::Common 'profanity';

my $display_file = 'festival_display.png';

my $default_font = 'Ac437_ApricotPortable.ttf';

get '/' => sub ($c) {
    my @fonts = map {
        { long => $_, file => file($_)->basename }
    } grep {1} glob 'fonts/ttf\ -\ Ac*/*';
    $c->stash(inverted => $c->param('inverted') || 0);
    $c->stash(pfont => $c->param('pfont') || $default_font);
    $c->render(template => 'index', fonts => \@fonts);
};

get '/image' => sub ($c) {
    my $file_data;
    if (-e './festival_display.png') {
        my $imager = Imager->new(file => 'festival_display.png');
        my $newimage = $imager->scale(scalefactor=>10, qtype => 'preview');
        $newimage->write(data => \$file_data, type => 'png');
    } else {
        Imager->new(xsize => 84*10, ysize => 7*10)->write(data => \$file_data, type => 'png');
    }
    $c->render(data => $file_data, format => 'png');
} => 'image';

post '/update' => sub ($c) {
    my $str = $c->param('updateString') || '<empty>';
    $str =~ s/($RE{profanity})/'X' x length($1)/ge;
    # move previous image into archive dir?
    my $fontfile = $c->param('font') || 'fonts/ttf - Ac (aspect-corrected)/' . $default_font;
    my $font = Imager::Font->new(
        file  => $fontfile,
        color => 'white',
        size  => 8);
    my $bbox =  $font->bounding_box(string => $str);
    my $image = Imager->new(xsize => $bbox->display_width, ysize => 7, channels => 1);
    $image->string(x => 0, y => 7,
                   string => $str,
                   font => $font);
    if ($c->param('inverted')) {
        $image->filter(type => 'hardinvert') or die "Cannot invert: ".$image->errstr;
    }
    $image->write(file => 'festival_display.png') or die $image->errstr;
    my $pfont = $fontfile ? file($fontfile)->basename : $default_font;
    my $inverted = $c->param('inverted') ? '&inverted=1' : '';
    return $c->redirect_to("/?pfont=$pfont$inverted");
};

 
app->start;
