package WordGames::Schema::ResultSet::Hangman;

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::ResultSet';

sub new_player {
    my ($self, $word) = @_;

    my $player;
    my $expired = DateTime->now()->clone->subtract(hours => 4);
    my $dt_formatter = $self->result_source->schema->storage->datetime_parser;
    foreach my $id (1..9) {
        $player = $self->find({ player_id => $id });
        next if  $player && $player->started_at >= $expired;
        if(!$player) {
            $player = $self->create({player_id => $id, word => $word});
        }
        last if $player;
    }
    return $player;
}

1;
