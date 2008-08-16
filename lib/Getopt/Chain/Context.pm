package Getopt::Chain::Context;

use strict;
use warnings;

use Moose;
use Getopt::Chain::Carp;

=head1 NAME Getopt::Chain::Context

=head1 SYNPOSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 $context->command

Returns the name of the current command (or undef in a special case)

    ./script --verbose edit --file xyzzy.c 
    # The command name is "edit" in the edit subroutine

    ./script --help
    # The command name is undef in the root subroutine

=head2 $context->option( <name> )

Returns the value of the option for <name> 

<name> should be primary name of the option (see L<Getopt::Long>)

If called in list context and the value of option is an ARRAY reference,
then this method returns a list (and an ARRAY reference in scalar context).

    ./script --exclude apple --exclude banana --exclude --cherry
    ...
    my @exclude = $context->option( exclude )

=head2 $context->option( <name>, <name>, ... )

Similar to ->option( <name> ) except for many-at-once

Returns a list in list context, and an ARRAY reference otherwise (you could
end up with a LoL situation in that case)

=head2 $context->options

Returns the keys of the option hash in list context

Returns the option HASH reference in scalar context

    ./script --verbose
    ...
    if ( $context->options->{verbose} ) { ... }

=head2 $context->all_options

# TODO Need a better name for this, maybe:

    global_option(s) 
    every_

=head2 $context->stash

=head2 $context->arguments

=head2 $context->remaining_arguments

=cut

has chain => qw/is ro isa ArrayRef/, default => sub { [] };

has all_options => qw/is ro isa HashRef/, default => sub { {} };

has stash => qw/is ro isa HashRef/, default => sub { {} };

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
        arguments => $link->_arguments, remaining_arguments => $link->_remaining_arguments, options => scalar $link->options);

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

has options => qw/reader _options required 1 isa HashRef/;

has arguments => qw/is ro reader _arguments required 1 isa ArrayRef/;
sub arguments {
    my @arguments = @{ shift->_arguments };
    return wantarray ? @arguments : \@arguments; 
}

has remaining_arguments => qw/is ro reader _remaining_arguments required 1 isa ArrayRef/;
sub remaining_arguments {
    my @arguments = @{ shift->_remaining_arguments };
    return wantarray ? @arguments : \@arguments; 
}

sub remainder {
    return scalar shift->remaining_arguments;
}

has valid => qw/is rw/;

sub options {
    my $self = shift;

    if (@_) {
        return $self->option(@_);
    }
    else {
        return wantarray ? keys %{ $self->_options } : $self->_options;
    }
}

sub option {
    my $self = shift;

    if (@_ == 0) {
        return $self->options;
    }

    if (@_ == 1) {

        my $option = shift;

        unless (exists $self->_options->{$option}) {
            return wantarray ? () : undef;
        }

        if (ref $self->_options->{$option} eq 'ARRAY') {
            return (wantarray)
              ? @{ $self->_options->{$option} }
              : $self->_options->{$option}->[0];
        }
        else {
            return (wantarray)
              ? ($self->_options->{$option})
              : $self->_options->{$option};
        }
    }
    elsif (@_ > 1) {
        my @options = map { scalar $self->option($_) } @_;
        return wantarray ? @options : \@options;
    }
}

1;
