#!/usr/bin/perl

use Mojolicious::Lite -signatures;
use Imager;
use Path::Class;
use Regexp::Common 'profanity';
use Data::Dumper;

use lib 'lib/';
use WordGames::Schema;

my $display_file = 'saywhat_display.png';

my $default_font = 'Ac437_ApricotPortable.ttf';

my $dsn_wordgames = 'dbi:SQLite:dbname=wordgames.db';

my $proxied = '/flipdot';

get '/' => sub ($c) {
    $c->render(template => 'index');
};

get '/saywhat' => sub ($c) {
    my @fonts = map {
        { long => $_, file => file($_)->basename }
    } grep {1} glob 'fonts/ttf\ -\ Ac*/*';
    $c->stash(inverted => $c->param('inverted') || 0);
    $c->stash(pfont => $c->param('pfont') || $default_font);
    $c->render(template => 'saywhat', fonts => \@fonts);
};

get '/saywhat/image' => sub ($c) {
    my $file_data;
    if (-e './saywhat_display.png') {
        my $imager = Imager->new(file => 'saywhat_display.png');
        my $newimage = $imager->scale(scalefactor=>10, qtype => 'preview');
        $newimage->write(data => \$file_data, type => 'png');
    } else {
        Imager->new(xsize => 84*10, ysize => 7*10)->write(data => \$file_data, type => 'png');
    }
    $c->render(data => $file_data, format => 'png');
} => 'image';

post '/saywhat/update' => sub ($c) {
    my $str = $c->param('updateString') || '<empty>';
    $str =~ s/($RE{profanity})/'X' x length($1)/ge;
    # move previous image into archive dir?
    my $image = to_flipdot_image($c->param('font'), $str, $c->param('inverted'));

    $image->write(file => 'saywhat_display.png') or die $image->errstr;
    my $pfont = $c->param('font') || $default_font;
    my $inverted = $c->param('inverted') ? '&inverted=1' : '';
    return $c->redirect_to("$proxied/saywhat?pfont=$pfont$inverted");
};

get '/hangman' => sub ($c) {
    my $sess = $c->session();
    my $game;
    my $newuser = 0;
    my $ended_word;
    ## just in case:
    my $schema = WordGames::Schema->connect($dsn_wordgames);
    $schema->txn_do(sub {
        if($sess && $sess->{player_id}) {
            $game = $schema->resultset('Hangman')->find({player_id => $sess->{player_id}});
            ## Cleanup if this game is finished!
            if ($game) {
                my $done = $game->archive_if_finished();
                if($done) {
                    $ended_word = $game->word;
                    $game = undef;
                }
            }
            if (!$game) {
                delete $c->session->{player_id};
            }
        }
        $game ||= $schema->resultset('Hangman')->find({ player_id => 1});
        if (!$game) {
            # start new co-op
            my $word = $schema->resultset('Word')->random_word();
            ## This should be player 1!
            $game = $schema->resultset('Hangman')->new_game($word, 1);
        } 
        $c->session->{player_id} = $game->player_id;
    });

    my @letters = ();
    if ($game) {
        # List of guessed letters
        @letters = map { $_->letter } ($game->guesses);
    }
    $c->render(template => 'hangman',
               game => $game,
               newuser => $newuser,
               letters => \@letters,
               finished_word => $ended_word
        );
};

post '/hangman/guess' => sub ($c) {
    my $guess = lc $c->param('guess');
    if (!$guess || length($guess) > 1 || $guess =~ /\W/) {
        return $c->redirect_to("$proxied/hangman");
    }

    my $sess = $c->session();
    my $schema = WordGames::Schema->connect($dsn_wordgames);
    my $game;

    if ($c->param('startNew')) {
        # new player:
        my $word = $schema->resultset('Word')->random_word();
        $game = $schema->resultset('Hangman')->new_game($word);
        print STDERR "Game: ", $game->player_id, "\n";
    } else {
        $game = $schema->resultset('Hangman')->find({ player_id => $sess->{player_id}});
    }
    # If someone else finished it / deleted it, this will fail!
    if ($game) {
        $c->session({'player_id' => $game->player_id});

        $game->add_guess($guess);
    }
    $c->redirect_to("$proxied/hangman");
};

# test feature, display what would be on the flipdot
get 'hangman/status' => sub ($c) {
    my $sess = $c->session();
    my $game;
#    print STDERR Dumper($sess);
    if (%$sess && $sess->{player_id}) {
        my $schema = WordGames::Schema->connect($dsn_wordgames);
        $game = $schema->resultset('Hangman')->find({player_id => $sess->{player_id}});
    }

    my $game_state = '';
    my $image;
    if($game) {
        $game_state = $game->game_state();
        $image = to_flipdot_image('', $game_state, 0);
    } else {
        $image = Imager->new(xsize => 84, ysize => 7, channels => 1);
        $image->box(color => 'white', filled => 1);
    }
    $image = $image->scale(scalefactor=>10, qtype => 'preview');
    my $file_data;
    $image->write(data => \$file_data, type => 'png');
    $c->render(data => $file_data, format => 'png');
};

get '/hangman/history' => sub ($c) {
    my $schema = WordGames::Schema->connect($dsn_wordgames);
    my $archive = $schema->resultset('HangmanArchive')->search_rs(
        {},
        { order_by => { '-desc' => 'started_at' }}
        );
    $c->render(template => 'hangman_history',
               games => $archive);
};

app->start;

# Copied into F::H::D
sub to_flipdot_image {
    my ($fontname, $str, $inverted) = @_;

    my $fontfile = $fontname || 'fonts/ttf - Ac (aspect-corrected)/' . $default_font;
    my $font = Imager::Font->new(
        file  => $fontfile,
        color => 'white',
        size  => 8);
    my $bbox =  $font->bounding_box(string => $str);
    my $image = Imager->new(xsize => $bbox->display_width, ysize => 7, channels => 1);
    $image->string(x => 0, y => 7,
                   string => $str,
                   font => $font);

    if ($inverted) {
        $image->filter(type => 'hardinvert') or die "Cannot invert: ".$image->errstr;
    }
    return $image;
}
