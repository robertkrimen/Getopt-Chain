use strict;
use warnings;

use Test::Most;

use Getopt::Chain;

plan qw/no_plan/;

my $buddy = Getopt::Chain->new(

    options => {

        'lEngth|l' => undef,
        'veRbose' => undef,
        'fiLe=s' => undef,
    }, 

    commands => {
    },

    validate => sub {
    },

    catch => sub {
    },

);

