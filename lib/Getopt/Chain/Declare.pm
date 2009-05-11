package Getopt::Chain::Declare;

use strict;
use warnings;

use Moose();
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_caller => [qw/ start on rewrite under /],
    also => [qw/ Moose /],
);

sub init_meta {
    shift;
    return Moose->init_meta( @_, base_class => 'Getopt::Chain', metaclass => 'Getopt::Chain::Meta::Class' );
}

sub start {
    my $caller = shift;
    $caller->meta->start( @_ );
}

sub on {
    my $caller = shift;
    $caller->meta->on( @_ );
}

sub under {
    my $caller = shift;
    $caller->meta->under( @_ );
}

sub rewrite {
    my $caller = shift;
    $caller->meta->rewrite( @_ );
}

package Getopt::Chain::Meta::Class;

use Moose;
use MooseX::AttributeHelpers;

extends qw/Moose::Meta::Class/;

has builder => qw/is ro lazy_build 1/, handles => [qw/ start on under rewrite /];
sub _build_builder {
    return Getopt::Chain::Builder->new;
}

around new_object => sub {
    my $around = shift;
    my $meta = shift;
    my $self = $around->( $meta, @_ );
    $self->{builder} = $meta->builder;

#    for my $replay ($self->meta->replay_list) {
#        my @replay = @$replay;
#        my $method = shift @replay;
#        $self->builder->$method( @replay );
#    }

    return $self;
};

#has _replay_list => qw/metaclass Collection::Array is ro isa ArrayRef/, default => sub { [] }, provides => {qw/
#    push        _add_replay
#    elements    replay_list
#/};

#sub add_replay {
#    my $self = shift;
#    $self->_add_replay( [ @_ ] );
#}

1;
