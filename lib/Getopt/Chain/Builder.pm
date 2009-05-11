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
    $self->on( '' => shift, shift);
}

sub on {
    my $self = shift;
    my $path = shift;
    my $argument_schema = shift;
    my $run = shift;
    my %given = @_;

    my %control = (
        always_process_arguments => 0,
        always_run => $given{always_run} || 0,
    );
    
    my $matcher;
    if (ref $path eq 'ARRAY') {
        # Also, check for '*', '$', etc. Ignore if literal => 1
        $matcher = [ split m/\s+/, $path ];
    }
    elsif (ref $path eq 'Regexp') {
        $matcher = $path;
    }
    elsif (! ref $path) {
        # Also, check for '*', '$', etc. Ignore if literal => 1
        if ($path eq '') { # The start rule, special case
            $control{always_run} = 1 unless exists $given{always_run};
            $matcher = [];
        }
        else {
            $matcher = join '\s+', split m/\s+/, $path;
            $matcher = qr/^\s*$matcher\s*$/; # Fuzzy matching?
        }
    
    }
    else {
        croak "Don't recogonize matcher ($path)";
    }
    $self->builder->on( $matcher, sub { # The builder should do the split for us!
        my $context = shift;
        return $context->run_step( $argument_schema, $run, { %control } );
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
