package WordGames::Schema::Result::Word;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('words');
__PACKAGE__->add_columns(
    word => {
	data_type => 'varchar',
	length    => 100,
    });
__PACKAGE__->set_primary_key('word');

__PACKAGE__->has_many('hangman_games', 'WordGames::Schema::Result::Hangman', 'word');

1;
