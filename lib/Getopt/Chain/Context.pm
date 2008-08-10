package Getopt::Chain::Context;

use strict;
use warnings;

use Moose;

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

has arguments => qw/is ro reader _arguments required 1 isa ArrayRef/;
sub arguments {
    return @{ shift->_arguments };
}

has remaining_arguments => qw/is ro reader _remaining_arguments required 1 isa ArrayRef/;
sub remaining_arguments {
    return @{ shift->_remaining_arguments };
}

sub remainder {
    return scalar shift->remaining_arguments;
}

has valid => qw/is rw/;

1;
