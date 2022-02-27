package WordGames::Schema::Result::HangmanGuess;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('hangman_guesses');
__PACKAGE__->load_components('TimeStamp');
__PACKAGE__->add_columns(
    player_id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    guess_at => {
        data_type => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
    letter => {
        data_type => 'varchar',
	length => 1,
    });
__PACKAGE__->set_primary_key('player_id', 'guess_at');

__PACKAGE__->belongs_to('player_id', 'WordGames::Schema::Result::Hangman', { 'foreign.player_id' => 'self.player_id'});

1;
