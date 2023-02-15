package WordGames::Schema::ResultSet::Hangman;

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::ResultSet';

sub new_game {
    my ($self, $word, $player_id) = @_;

    my $game;
    my $expired = DateTime->now()->clone->subtract(hours => 4);
    my $dt_formatter = $self->result_source->schema->storage->datetime_parser;
    if ($player_id) {
        $game = $self->find_or_create({player_id => $player_id, word => $word});
    } else {
	foreach my $id (2..9) {
	    $game = $self->find({ player_id => $id });
	    next if  $game && $game->started_at >= $expired;
	    if ($game) {
		# too old, delete
		$game->delete();
	    }
	    $game = $self->create({player_id => $id, word => $word});
	    last if $game;
	}
    }
    return $game;
}

1;
