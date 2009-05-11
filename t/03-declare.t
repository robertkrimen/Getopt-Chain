#!/usr/bin/perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

package t::App;

use Getopt::Chain::Declare;

start [qw/ a1 b2:s /];

rewrite qr/^\?(.*)/ => sub { "help ".($1||'') };

on apple => [qw/ c3 /], sub {
    my $context = shift;

    $context->option( apple => 1 );
};

on 'help $' => undef, sub {
    my $context = shift;

    $context->option( help => 1 );
};

# Automatically put '$' unless '*' is at the end, then strip it!
on 'help xyzzy $' => undef, sub {
    my $context = shift;

    $context->option( help_xyzzy => 1 );
};

no Getopt::Chain::Declare;

package main;

my @arguments = qw/--a1 apple --c3/;
my ($options);

my $app = t::App->new;

ok( $app );

$options = $app->run( [ @arguments ] );

ok( $options->{a1} );
ok( $options->{c3} );
ok( $options->{apple} );

$options = $app->run( [qw/ help /] );

ok( $options->{help} );

$options = $app->run( [qw/ ? /] );

ok( $options->{help} );

$options = $app->run( [qw/ help xyzzy /] );

ok( ! $options->{help} );
ok( $options->{help_xyzzy} );
