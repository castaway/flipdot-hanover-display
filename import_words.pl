#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib/';
use WordGames::Schema;

my $minlen = 5;
my $maxlen = 10;
my $wordsfile = '/etc/dictionaries-common/words';

if (!-e 'wordgames.db') {
    WordGames::Schema->connect('dbi:SQLite:dbname=wordgames.db')->deploy({ add_drop_table => 1 });
}
my $schema = WordGames::Schema->connect('dbi:SQLite:dbname=wordgames.db');

open(my $fh, "<", $wordsfile) or die "Can't open $wordsfile($!)\n";

while(my $word = <$fh>) {
    chomp($word);
    next if $word =~ /^[A-Z]/;
    next if $word =~ /\W/;
    next if length($word) < $minlen;
    next if length($word) > $maxlen;
    print("$word\n");
    $schema->resultset('Word')->find_or_create({word => $word});
}
