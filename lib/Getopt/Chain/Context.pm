package Getopt::Chain::Context;

use strict;
use warnings;

use Moose;
use Getopt::Chain::Carp;

has chain => qw/is ro isa ArrayRef/, default => sub { [] };

has all_options => qw/is ro isa HashRef/, default => sub { {} };

sub BUILD {
    my $self = shift;
    my $given = shift;
}

sub push {
    my $self = shift;
    my $link = Getopt::Chain::Context::Link->new(context => $self, @_);
    push @{ $self->chain }, $link;
    return $link;
}

sub pop {
    my $self = shift;
    pop @{ $self->chain };
}

sub run {
    my $self = shift;
    my $path = shift || "";

    my @path = grep { length $_ } split m/[ \/]+/, $path;

    my $link = $self->link;
    my $processor = $self->link(0)->processor;
    for (@path) {
        # TODO Probably call this 'resolve'
        $processor = $processor->commands->{$_} or croak "Couldn't traverse $path: $_ not found";
    }

    $self->push(processor => $processor, command => $path[-1],
        arguments => $link->_arguments, remaining_arguments => $link->_remaining_arguments, options => $link->options);

    $processor->run->($self, @_);

    $self->pop;
}

sub update {
    my $self = shift;

    my $link = $self->link;
    my $options = $link->options;
    my $all_options = $self->all_options;

    for my $key (keys %$options) {
        $all_options->{$key} = $options->{$key};
    }
}

sub link {
    my $self = shift;
    my $at = shift;

    $at = -1 unless defined $at;
    return $self->chain->[$at];
}

for my $method (qw/processor command options arguments remaining_arguments remainder valid/) {
    no strict 'refs';
    *$method = sub {
        my $self = shift;
        return $self->link->$method(@_);
    };
}

package Getopt::Chain::Context::Link;

use Moose;

has context => qw/is ro required 1 isa Getopt::Chain::Context/, handles => [qw/all_options/];

has processor => qw/is ro required 1 isa Getopt::Chain/;

has command => qw/is ro required 1 isa Maybe[Str]/;

has options => qw/is ro required 1 isa HashRef/;

has arguments => qw/required 1 isa ArrayRef reader _arguments/;
sub arguments {
    return @{ shift->_arguments };
}

has remaining_arguments => qw/required 1 isa ArrayRef reader _remaining_arguments/;
sub remaining_arguments {
    return @{ shift->_remaining_arguments };
}

sub remainder {
    return scalar shift->remaining_arguments;
}

has valid => qw/is rw/;

1;
