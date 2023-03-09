package WordGames::Schema::Result::HangmanArchive;

use strict;
use warnings;
use DateTime;

use base 'DBIx::Class::Core';

__PACKAGE__->table('hangman_archive');
__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->add_columns(
    word => {
        data_type => 'varchar',
        size => 10,
    },
    started_at => {
        data_type => 'datetime',
    },
    ended_at => {
        data_type => 'datetime',
    },
    guesses => {
        data_type => 'integer',
    });
__PACKAGE__->set_primary_key('word', 'started_at');

sub started_at_formatted {
    my ($self) = @_;
    my $dt = $self->started_at();

    return $self->format($dt);
}

sub ended_at_formatted {
    my ($self) = @_;
    my $dt = $self->started_at();

    return $self->format($dt);
}

sub format {
    my ($self, $dt) = @_;

    my $now = DateTime->now;
    
}

1;
