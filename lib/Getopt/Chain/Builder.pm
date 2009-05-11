package Getopt::Chain::Builder;

use Moose;
use Getopt::Chain::Carp;

use Path::Dispatcher;
use Path::Dispatcher::Builder;

has builder => qw/is ro lazy_build 1/, handles => [qw/ dispatcher rewrite /];
sub _build_builder {
    my $self = shift;
    return Path::Dispatcher::Builder->new;
}

sub start {
    my $self = shift;
    $self->on( '' => @_ );
}

sub on {
    my $self = shift;
    my $path = shift;
    my $argument_schema = shift;
    my $run = shift;

#    if (defined $_[0] && ref $_[0] eq '' || ref $_[0] eq 'ARRAY') {
#        $argument_schema = shift;
#    }
#    if (defined $_[0] && ref $_[0] eq 'CODE') {
#        $run = shift;
#    }
#    elsif (@_) {
#        croak "Don't understand arguments (@_)";
#    }

    $self->builder->on( [ split m/\s/, $path ], sub { # The builder should do the split for us!
        my $context = shift;
        $context->run_step( $argument_schema, $run );
    } );
}

1;

__END__

has argument_builder => qw/is ro lazy_build 1/, handles => {qw/ argument_dispatcher dispatcher /};
sub _build_argument_builder {
    my $self = shift;
    return Path::Dispatcher::Builder->new;
}

has command_builder => qw/is ro lazy_build 1/, handles => {qw/ command_dispatcher dispatcher /};
sub _build_command_builder {
    my $self = shift;
    return Path::Dispatcher::Builder->new;
}

sub argument_dispatch {
    my $self = shift;
    my $path = shift;
    my @argument_schema;
    $self->argument_dispatcher->run( $path, \@argument_schema );
    return map { ref $_ ? @$_ : $_ } @argument_schema;
}

sub start {
    my $self = shift;
    my $_argument_schema = shift;
    $self->argument_builder->then( sub {
        my $argument_schema = shift;
        push @$argument_schema, $_argument_schema;
    } );
}

sub on {
    my $self = shift;
    my $path = shift;
    my $_argument_schema;
    if (defined $_[0] && ref $_[0] eq '' || ref $_[0] eq 'ARRAY') {
        $_argument_schema = shift;
        $self->argument_builder->on( $path, sub {
            my $argument_schema = shift;
            push @$argument_schema, $_argument_schema;
        } );
    }
    my $run = shift;
    if (defined $run && ref $run eq 'CODE') {
        $self->command_builder->on( $path => $run );
    }
}

1;
