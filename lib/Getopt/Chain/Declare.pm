package Getopt::Chain::Declare;

use strict;
use warnings;

=head1 NAME

Getopt::Chain::Declare - Option and subcommand processing in the style of svn and git

=head1 SYNPOSIS 

    package My::Command;

    use Getopt::Chain::Declare;

    start [qw/ verbose|v /]; # These are "global"
                             # my-command --verbose ...

    # my-command ? initialize ... --> my-command help initialize ...
    rewrite qr/^\?(.*)/ => sub { "help ".($1||'') };

    # NOTE: Rewriting applies to the command sequence, NOT options

    # my-command about ... --> my-command help about
    rewrite [ ['about', 'copying'] ] => sub { "help $1" };

    # my-command initialize --dir=...
    on initialize => [qw/ dir|d=s /], sub {
        my $context = shift;

        my $dir = $context->option( 'dir' )

        # Do initialize stuff with $dir
    };

    # my-command help
    on help => undef, sub {
        my $context = shift;

        # Do help stuff ...
        # First argument is undef because help
        # doesn't take any options
        
    };

    under help => sub {

        # my-command help create
        # my-command help initialize
        on [ [ qw/create initialize/ ] ] => undef, sub {
            my $context = shift;

            # Do help for create/initialize
            # Both: "help create" and "help initialize" go here
        };

        # my-command help about
        on 'about' => undef, sub {
            my $context = shift;

            # Help for about...
        };

        # my-command help copying
        on 'copying' => undef, sub {
            my $context = shift;

            # Help for copying...
        };

        # my-command help ...
        on qr/^(\S+)$/ => undef, sub {
           my $context = shift;
           my $topic = $1;

            # Catch-all for anything not fitting into the above...
            
            warn "I don't know about \"$topic\"\n"
        };
    };

    # ... elsewhere ...

    My::Command->new->run( [ @arguments ] )
    My::Command->new->run # Just run with @ARGV

=head1 DESCRIPTION

For more information, see L<Getopt::Chain>

=cut

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
