use strict;
use warnings;

use Test::Most;
use XXX;

use Getopt::Chain;

plan qw/no_plan/;

Getopt::Chain->process(

    [qw/--banana --file show/],

    options => {

        'apple|a' => undef,
        'banana' => undef,
        'cherry=s' => undef,
    }, 

    commands => {

        show => {
            grape => undef,

            run => sub {
                my $context = shift;

                WWW $context->all_options;

                warn "In ", $context->command;
            },
        },
    },

    validate => sub {
    },

);

ok(1);
