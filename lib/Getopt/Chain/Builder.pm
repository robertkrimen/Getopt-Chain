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
    );
    
    my $matcher;
    if (ref $path eq 'ARRAY') {
        $matcher = $path;
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
        elsif ($path =~ s/\s+\*\s*$//) {
            $matcher = qr/$path\b/;
        }
        elsif ($path =~ m/^\s*\*\s*$/) {
            $matcher = qr/(.*)/;
        }
        else {
            $matcher = [ split m/\s+/, $path ];
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

sub under {
    my $self = shift;
    $self->builder->under( @_ );
}

1;
