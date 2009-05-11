package Getopt::Chain::Declare;

use strict;
use warnings;

use Moose();
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_caller => [qw/ start on rewrite /],
    also => [qw/ Moose /],
);

sub init_meta {
    shift;
    return Moose->init_meta( @_, base_class => 'Getopt::Chain', metaclass => 'Getopt::Chain::Meta::Class' );
}

sub start {
    my $caller = shift;
    $caller->meta->add_replay( start => @_ );
}

sub on {
    my $caller = shift;
    $caller->meta->add_replay( on => @_ );
}

sub rewrite {
    my $caller = shift;
    $caller->meta->add_replay( rewrite => @_ );
}

package Getopt::Chain::Meta::Class;

use Moose;
use MooseX::AttributeHelpers;

extends qw/Moose::Meta::Class/;

has _replay_list => qw/metaclass Collection::Array is ro isa ArrayRef/, default => sub { [] }, provides => {qw/
    push        _add_replay
    elements    replay_list
/};

around new_object => sub {
    my $around = shift;
    my $self = $around->( @_ );

    for my $replay ($self->meta->replay_list) {
        my @replay = @$replay;
        my $method = shift @replay;
        $self->builder->$method( @replay );
    }

    return $self;
};

sub add_replay {
    my $self = shift;
    $self->_add_replay( [ @_ ] );
}

1;
