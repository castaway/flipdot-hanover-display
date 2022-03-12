package WordGames::Schema::Result::Hangman;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('hangman');
__PACKAGE__->load_components('TimeStamp');
__PACKAGE__->add_columns(
    player_id => {
        data_type => 'integer',
    },
    started_at => {
        data_type => 'datetime',
        set_on_create => 1,
    },
    word => {
        data_type => 'varchar',
	length => 100,
    });
__PACKAGE__->set_primary_key('player_id');

__PACKAGE__->has_many('guesses', 'WordGames::Schema::Result::HangmanGuess', 'player_id');
__PACKAGE__->belongs_to('word_obj', 'WordGames::Schema::Result::Word', 'word');

=head2 add_guess

Insert a new row into the current hangman game's "guesses" table, a
guessed letter, and the time of the guess (for sorting).

=cut

sub add_guess {
    my ($self, $guess) = @_;

    $self->guesses->find_or_create({ letter => $guess });
}

sub latest_update {
    my ($self) = @_;

    my $latest = $self->guesses->search_rs({}, {
	order_by => { '-desc', 'guess_at' },
	rows => 1 })->first();
    if($latest) {
	return $latest->guess_at;
    }
    return $self->started_at();
}

=head2 game_state

Output a text string representing the current state of the game.

=cut

sub game_state {
    my ($self) = @_;

    # Get word, get guesses, output either "-" the letter.
    my $word = $self->word;
    my $string = '-' x length($word);
    my $gcount = 0;
    foreach my $guess ($self->guesses) {
        my $pos = 0;
        while((my $pos = index($word, $guess->letter, $pos++)) > -1) {
            substr($string, $pos, 1, $guess->letter);
        }
    }
    return $string;
}

sub archive_if_finished {
    my ($self) = @_;

    if ($self->game_state !~ /-/) {
        $self->result_source->schema->resultset('HangmanArchive')->create({
            word => $self->word,
            started_at => $self->started_at,
            ended_at => DateTime->now(),
            guesses => $self->guesses_rs->count,
        });
        $self->delete;
        return 1;
    }
    return 0;
}

1;
