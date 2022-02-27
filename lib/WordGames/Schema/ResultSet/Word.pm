package WordGames::Schema::ResultSet::Word;

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::ResultSet';

sub random_word {
    my ($self) = @_;

    # select word from words order by random() limit 1;
    my $word;
    while(!$word) {
        $word = $self->search_rs({}, { order_by => \[ 'random()' ] })->first;
        if ($word->hangman_games->search_rs({ word => $word->word })->count >1 ) {
            $word = undef;
        }
        $word = $word->word;
    }
    return $word;
}

1;
