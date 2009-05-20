#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

our @did;

package My::Command;

use Getopt::Chain::Declare;

rewrite qr/^\?(.*)/ => sub { "help ".($1||'') };

rewrite [ ['about', 'copying'] ] => sub { "help $1" };

start [qw//], sub {
    my $context = shift;
    push @did, [ $context->command ];
#    $context->continue;
};

#on 'apple' => undef, sub {
#    my $context = shift;
#    push @did, [ $context->command ];
#};

on 'apple banana' => undef, sub {
    my $context = shift;
    push @did, [ 'apple banana' ];
};

on 'apple *' => undef, sub {
    my $context = shift;
    push @did, [ 'apple' ];
};

on help => undef, sub {
    my $context = shift;

    # Do help stuff ...
    # First argument is undef because help
    # doesn't take any options
    
    push @did, [ $context->command, ];
};

under help => sub {

    # my-command help create
    # my-command help initialize
    on [ [ qw/create initialize/ ] ] => undef, sub {
        my $context = shift;

        # Do help for create/initialize
        # Both: "help create" and "help initialize" go here

        push @did, [ 'help', $context->command, ];
    };

    # my-command help about
    on 'about' => undef, sub {
        my $context = shift;

        # Help for about...

        push @did, [ 'help', $context->command, ];
    };

    # my-command help copying
    on 'copying' => undef, sub {
        my $context = shift;

        # Help for copying...

        push @did, [ 'help', $context->command, ];
    };

    # my-command help ...
    # Also, on '*' will sort of work...
    on '*' => undef, sub {
#    on qr/^(\S+)$/ => undef, sub {
       my $context = shift;
       my $topic = $1;

        # Catch-all for anything not fitting into the above...
        
        push @did, [ 'help', $context->command, "I don't know about \"$topic\"" ]
    };
};

on qr/.*/ => undef, sub {
    push @did, [ '.* fallthrough' ];
};

#on apple => [qw/ c3 /], sub {
#    my $context = shift;
#
#    $context->option( apple => 1 );
#};
#
#on help => undef, sub {
#    my $context = shift;
#
#    $context->option( help => 1 );
#};

#on 'help xyzzy' => undef, sub {
#    my $context = shift;

#    $context->option( help_xyzzy => 1 );
#};

no Getopt::Chain::Declare;

package main;

my $options;

sub run {
    undef @did;
    $options = My::Command->new->run( [ @_ ] );
}

#use XXX;

run qw//;
cmp_deeply( \@did, [ [ undef ] ] );

run qw/apple/;
cmp_deeply( \@did, [ [qw/ apple /] ] );

run qw/apple argument/;
cmp_deeply( \@did, [ [qw/ apple /] ] );

run qw/apple argument/;
cmp_deeply( \@did, [ [qw/ apple /] ] );
run qw/editxyzzy/;
cmp_deeply( \@did, [ [ '.* fallthrough' ] ] );

run qw/apple banana/;
cmp_deeply( \@did, [ [ 'apple banana' ] ] );

run qw/help/;
cmp_deeply( \@did, [ [ 'help' ] ] );

run qw/help xyzzy/;
cmp_deeply( \@did, [ [ 'help', 'xyzzy', 'I don\'t know about "xyzzy"'  ] ] );

run qw/about/;
cmp_deeply( \@did, [ [ 'help', 'about'  ] ] );
