package Getopt::Chain::Context;

use strict;
use warnings;

use Moose;
use MooseX::AttributeHelpers;
use Getopt::Chain::Carp;

use Getopt::Chain;

use Getopt::Long qw/GetOptionsFromArray/;
use Hash::Param;

use constant DEBUG => Getopt::Chain->DEBUG;
our $DEBUG = DEBUG;

# Should probably move these into Getopt::Chain
# ...or even... Getopt::Longer :)
sub is_option_like($) {
    return $_[0] =~ m/^-/;
}

sub consume_arguments($$) { # Will modify arguments, reflecting consumption
    my $argument_schema = shift;
    my $arguments = shift;

    my %options;
    eval {
        if ($argument_schema && @$argument_schema) {
            Getopt::Long::Configure(qw/pass_through/);
            GetOptionsFromArray($arguments, \%options, @$argument_schema);
        }
    };
    croak "There was an error option-processing arguments: $@" if $@;

    if (@$arguments && is_option_like $arguments->[0]) {
        croak "Have remainder arguments after option-processing: ", $arguments->[0];
    }

    return ( \%options );
}

has dispatcher => qw/is ro required 1/;

has _options => qw/is ro isa Hash::Param lazy_build 1/, handles => {qw/option param options params/};
sub _build__options {
    my $self = shift;
    return Hash::Param->new(params => {});
}

has stash => qw/is ro isa HashRef/, default => sub { {} };

# The original arguments from the commandline (or wherever)... read only!
has arguments => qw/metaclass Collection::Array reader _arguments required 1 lazy 1 isa ArrayRef/, default => sub { [] }, provides => {qw/
    elements    arguments
/};

# The arguments remaining after each step does argument consuming... written by the step!
has remaining_arguments => qw/metaclass Collection::Array accessor _remaining_arguments isa ArrayRef/, provides => {qw/
    elements    remaining_arguments
    shift       shift_remaining_argument
    first       first_remaining_argument
/};

has steps => qw/metaclass Collection::Array reader _steps required 1 lazy 1 isa ArrayRef/, default => sub { [] }, provides => {qw/
    elements    steps   
    first       first_step
    last        last_step
    push        push_step
/};

has _path => qw/metaclass Collection::Array is ro required 1 lazy 1 isa ArrayRef/, default => sub { [] }, provides => {qw/
    elements    path
    push        push_path
/};

sub initialize_run {
    my $self = shift;
    $self->_remaining_arguments( [ $self->arguments ] );
}

sub run {
    my $self = shift;

    $self->initialize_run;
    1 while $self->next;
}

sub next {
    my $self = shift;

    unless (defined $self->_remaining_arguments) { # Haven't been run yet
        $self->initialize_run;
    }

    warn "Context::next ", $self->path_as_string if $DEBUG;

    $self->dispatcher->run( join( ' ', $self->path ) , $self ); # This will (indirectly) call ->run_step( ... ) below
    my $next_path_part;
    $self->push_path( $next_path_part ) if $next_path_part = $self->next_path_part;
    return $next_path_part;
}

sub next_path_part {
    my $self = shift;

    return unless defined (my $argument = $self->first_remaining_argument);
    croak "Had remainder arguments after option-processing: ", $argument, " @ ", $self->path_as_string, " [", $self->remaining_arguments, "]" if is_option_like $argument;
    return $self->shift_remaining_argument;
}

sub path_as_string {
    my $self = shift;
    return  join '/', '^START', $self->path;
}

sub run_step { # Called from within the Path::Dispatcher rule
    my $self = shift;
    my $argument_schema = shift;
    my $run = shift;

    $argument_schema = [] unless defined $argument_schema;
    
    my $step = $self->add_step( argument_schema => $argument_schema, run => $run ); 
    $step->run;
}

sub add_step {
    my $self = shift;
    my %given = @_; # Should be: argument_schema, run

    my $parent = $self->last_step; # Could be undef
    my $step = Getopt::Chain::Context::Step->new( context => $self, parent => $parent, path => [ $self->path ], arguments => [ $self->remaining_arguments ], %given );
    $self->push_step( $step );
    return $step;
}

sub command {
    my $self = shift;
    return $self->last_step->last_path_part;
}

sub local_option {
    my $self = shift;
    return $self->last_step->option( @_ );
}

sub local_options {
    my $self = shift;
    return $self->last_step->options( @_ );
}

sub local_path {
    my $self = shift;
    return $self->last_step->path;
}

package Getopt::Chain::Context::Step;

use Moose;
use Getopt::Chain::Carp;

use Hash::Param;

has context => qw/is ro required 1 isa Getopt::Chain::Context/;

has _options => qw/is ro isa Hash::Param lazy_build 1/, handles => {qw/option param options params/};
sub _build__options {
    my $self = shift;
    return Hash::Param->new( params => {} );
}

has arguments => qw/metaclass Collection::Array accessor _arguments required 1 isa ArrayRef/, provides => {qw/
    elements arguments
/};

has argument_schema => qw/metaclass Collection::Array accessor _argument_schema required 1 isa ArrayRef/, provides => {qw/
    elements argument_schema
/};

has run => qw/is ro reader _run isa Maybe[CodeRef]/;

has _path => qw/metaclass Collection::Array is ro required 1 lazy 1 isa ArrayRef init_arg path/, default => sub { [] }, provides => {qw/
    elements    path
    last        last_path_part
    push        push_path
/};

has parent => qw/is ro isa Maybe[Getopt::Chain::Context::Step]/;

sub run {
    my $self = shift;

    my $options = {};
    my $arguments = [ $self->arguments ];
    my $argument_schema = [ $self->argument_schema ];

    warn "Context::Step::run ", $self->context->path_as_string, " [@$arguments] {@$argument_schema}" if $DEBUG;

    eval {
        $options = Getopt::Chain::Context::consume_arguments $argument_schema, $arguments;
    };
    if ($@) {
        chomp( my $error = $@ );
        croak "At ", join( '/', $self->path ), " with arguments [@$arguments]: $@";
    }
    $self->context->_remaining_arguments( $arguments );

    while (my ($key, $value) = each %$options) {
        $self->option( $key => $value );
        $self->context->option( $key => $value ); # TODO Better way to do this...
    }

    my $run = $self->_run;
    $run->( $self->context, @$arguments ) if $run;
}

1;

__END__

=head1 NAME

Getopt::Chain::Context - Per-command context

=head1 DESCRIPTION

A context encapsulates the current state of execution, including:

    The name of the current command (or undef if at the "root")
    Every option parsed so far
    Options local to the current command
    The arguments as they were BEFORE parsing options for this command
    The arguments remaining AFTER parsing options for this command

=head1 METHODS

=head2 $context->command

Returns the name of the current command (or undef in a special case)

    ./script --verbose edit --file xyzzy.c 
    # The command name is "edit" in the edit subroutine

    ./script --help
    # The command name is undef in the root subroutine

=head2 $context->option( <name> )

Returns the value of the option for <name> 

<name> should be primary name of the option (see L<Getopt::Long> for more information
on primary/alias naming)

If called in list context and the value of option is an ARRAY reference,
then this method returns a list:

    ./script --exclude apple --exclude banana --exclude --cherry
    ...
    my @exclude = $context->option( exclude )

See L<Hash::Param> for more usage information

=head2 $context->options( <name>, <name>, ... )

Similar to ->option( <name> ) except for many-at-once

Returns a list in list context, and an ARRAY reference otherwise (you could
end up with a LoL situation in that case)

See L<Hash::Param> for more usage information

=head2 $context->options

Returns the keys of the option hash in list context

Returns the option HASH reference in scalar context

    ./script --verbose
    ...
    if ( $context->options->{verbose} ) { ... }

See L<Hash::Param> for more usage information

=head2 $context->local_option

=head2 $context->local_options

Behave similarly to ->option and ->options, except only cover options local to the current command

    ./script --verbose edit --file xyzzy.c
    $context->local_option( file ) # Returns 'xyzzy.c'
    $context->local_option( verbose ) # Doesn't return anything
    $context->option( verbose ) # Returns 1

=head2 $context->stash

An initially empty  HASH reference that can be used for sharing inter-command information

Similar to the stash in L<Catalyst>

=head2 $context->arguments

Returns a copy of the arguments (@ARGV) for the current command BEFORE option parsing

Returns an ARRAY reference (still a copy) when called in scalar context

    ./script --verbose edit --file xyzzy.c

    # At the very beginning: 
    $context->arguments # Returns ( --verbose edit --file xyzzy.c )

    # In the "edit" subroutine:
    $context->arguments # Returns ( edit --file xyzzy.c )

=head2 $context->remaining_arguments

Returns a copy of the remaining arguments (@ARGV) for the current command AFTER option parsing

Returns an ARRAY reference (still a copy) when called in scalar context

    ./script --verbose edit --file xyzzy.c

    # At the very beginning: 
    $context->remaining_arguments # Returns ( edit --file xyzzy.c )

    # In the "edit" subroutine:
    $context->remaining_arguments # Returns ( )

=head2 $context->abort( [ ... ] )

Immediately exit the process with exit code of -1

If the optional ... (message) is given, then print that out to STDERR first

=head1 SEE ALSO

L<Getopt::Chain>

=cut

use Hash::Param;

has options => qw/reader _options lazy_build 1 isa HashRef/;
sub _build_options {
    my $self = shift;
    return {};
}

has options_ => qw/is ro isa Hash::Param lazy_build 1/, handles => {qw/option param options params/};
sub _build_options_ {
    my $self = shift;
    return Hash::Param->new(params => $self->_options);
}

has chain => qw/is ro isa ArrayRef/, default => sub { [] };

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

    my $local_options = $self->local_options_;
    my $options = $self->options_;

    for my $key ($local_options->params) {
        $options->param($key => scalar $local_options->param($key));
    }
}

sub link {
    my $self = shift;
    my $at = shift;

    $at = -1 unless defined $at;
    return $self->chain->[$at];
}

sub local_option {
    my $self = shift;
    return $self->link->option(@_);
}

sub local_options {
    my $self = shift;
    return $self->link->options(@_);
}

sub local_options_ {
    my $self = shift;
    return $self->link->options_(@_);
}

for my $method (qw/processor command arguments remaining_arguments remainder valid/) {
    no strict 'refs';
    *$method = sub {
        my $self = shift;
        return $self->link->$method(@_);
    };
}

sub abort {
    my $self = shift;
    print STDERR "$0: ";
    if (@_) {
        my @__ = @_; # Modification of read-only value ...
        chomp $__[-1];
        print STDERR join "", @__, "\n";
    }
    else {
        print STDERR "Unknown error: aborting";
    }
    exit -1;
}

package Getopt::Chain::Context::Link;

use Moose;
use Getopt::Chain::Carp;

use Hash::Param;

has context => qw/is ro required 1 isa Getopt::Chain::Context/, handles => [qw/all_options/];

has processor => qw/is ro required 1 isa Getopt::Chain/;

has command => qw/is ro required 1 isa Maybe[Str]/;

has options => qw/reader _options required 1 isa HashRef/;

has options_ => qw/is ro isa Hash::Param lazy_build 1/, handles => {qw/option param options params/};
sub _build_options_ {
    my $self = shift;
    return Hash::Param->new(params => $self->_options);
}

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

1;

__END__

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
