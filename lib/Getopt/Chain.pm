package Getopt::Chain;

use warnings;
use strict;

use constant DEBUG => $ENV{GOC_TRACE} ? 1 : 0;
our $DEBUG = DEBUG;

=head1 NAME

Getopt::Chain - Option and subcommand processing in the style of svn and git

=head1 VERSION

Version 0.005

=cut

our $VERSION = '0.005';

=head1 SYNPOSIS 

=head1 DESCRIPTION

Getopt::Chain can be used to provide C<svn(1)>- and C<git(1)>-style option and subcommand processing. Any option specification
covered by L<Getopt::Long> is fair game.

CAVEAT: Unfortunately, Getopt::Long slurps up the entire arguments array at once. Usually, this isn't a problem (as Getopt::Chain uses 
pass_through). However, if a subcommand has an option with the same name or alias as an option for a parent, then that option won't be available
for the subcommand. For example:

    ./script --verbose --revision 36 edit --revision 48 --file xyzzy.c
    # Getopt::Chain will not associate the second --revision with "edit"

So, for now, try to use distinct option names/aliases :)

=cut

use Moose;
use Getopt::Chain::Carp;

use Getopt::Chain::Builder;
use Getopt::Chain::Context;

has builder => qw/is ro lazy_build 1/, handles => [qw/ dispatcher /];
sub _build_builder {
    return Getopt::Chain::Builder->new;
}

sub process {
    if (! ref $_[0] && $_[0] && $_[0] eq 'Getopt::Chain') {
        shift;
        require Getopt::Chain::v005;
        carp "Deprecated: Use Getopt::Chain::v005->process( ... ) to avoid this warning";
        return Getopt::Chain::v005->process( @_ );
    }
}

sub run {
    my $self = shift;
    my $arguments = shift;

    $arguments = [ @ARGV ] unless $arguments;

    my $context = Getopt::Chain::Context->new( dispatcher => $self->dispatcher, arguments => $arguments );
    $context->run;
    return $context->options;
}

1;

__END__

use Getopt::Chain::Context;

use Getopt::Long qw/GetOptionsFromArray/;

has options => qw/is ro/;

has schema => qw/is ro isa Maybe[HashRef]/;
has _getopt_long_options => qw/is rw isa ArrayRef/;

has commands => qw/is rw isa Maybe[HashRef]/;

has run => qw/is ro isa Maybe[CodeRef]/;

has validate => qw/is ro isa Maybe[CodeRef]/;

has error => qw/is ro/;

sub BUILD {
    my $self = shift;
    my $given = shift;

    my $commands = $self->_parse_commands($self->commands);
    my ($schema, $getopt_long_options) = $self->_parse_schema($self->options);

    $self->{commands} = $commands;
    $self->{schema} = $schema;
    $self->_getopt_long_options($getopt_long_options);
}

sub _parse_commands {
    my $self = shift;
    my $commands = shift;

    return unless $commands;

    my $class = ref $self;

    my %commands;
    while (my ($name, $command) = each %$commands) {
        $commands{$name} = $class->new(inherit => $self, ref $command eq "CODE" ? (run => $command) : %$command);
    }

    return \%commands;
}

sub _parse_schema {
    my $self = shift;
    my $schema = shift;

    my %schema;
    my @getopt_long_options;
    $schema = { map { $_ => undef } @$schema } if ref $schema eq "ARRAY";

    while (my ($specification, $more) = each %$schema) {

        my (%option, %ParseOptionSpec);

        my ($key, $name) = Getopt::Long::ParseOptionSpec($specification, \%ParseOptionSpec);

        $option{key} = $key;
        $option{name} = $name;
        $option{aliases} = [ keys %ParseOptionSpec ];

        $schema{$key} = \%option;
        push @getopt_long_options, $specification;
    }

    return (\%schema, \@getopt_long_options);
}

sub process {
    my $self = shift;
    unless (ref $self) {
        my @process;
        push @process, shift if ref $_[0] eq "ARRAY";
        return $self->new(@_)->process(@process);
    }
    my $arguments = shift;
    my %given = 1 == @_ && ref $_[0] eq "HASH" ? %{ $_[0] } : @_;

    my %options;
    $arguments = [ @ARGV ] unless $arguments;
    my $remaining_arguments = [ @$arguments ]; # This array will eventually contain leftover arguments

    my $context = $given{context} ||= Getopt::Chain::Context->new;
    $context->push(processor => $self, command => $given{command},
                    arguments => $arguments, remaining_arguments => $remaining_arguments, options => \%options);

    eval {
        if (my $getopt_long_options = $self->_getopt_long_options) {
            Getopt::Long::Configure(qw/pass_through/);
            GetOptionsFromArray($remaining_arguments, \%options, @$getopt_long_options);
        }
    };
    $self->_handle_option_processing_error($@, $context) if $@;

    $context->update;

    if (@$remaining_arguments && $remaining_arguments->[0] =~ m/^--\w/) {
        $self->_handle_have_remainder('Have remainder "' . $remaining_arguments->[0] . '"', $context);
    }

    $context->valid($self->validate->($context)) if $self->validate;

    $self->run->($context, @$remaining_arguments) if $self->run;

    if (my $commands = $self->commands) {
        my @arguments = @$remaining_arguments;
        my $command = shift @arguments;

        my $processor = $commands->{defined $command ? $command : 'DEFAULT'} || $commands->{DEFAULT};

        if ($processor) {
            return $processor->process(\@arguments, command => $command, context => $context);
        }
        elsif (defined $command) {
            $self->_handle_unknown_command("Unknown command \"$command\"", $context);
        }
    }

    return $context->options;
}

sub _handle_option_processing_error {
    my $self = shift;
    return $self->_handle_error(option_processing_error => @_);
}

sub _handle_have_remainder {
    my $self = shift;
    return $self->_handle_error(have_remainder => @_);
}

sub _handle_unknown_command {
    my $self = shift;
    return $self->_handle_error(unknown_command => @_);
}

sub _handle_error {
    my $self = shift;
    my $event = shift;
    my $description = shift;

    my $error = $self->error;

    if (ref $error eq "CODE") {
        return $error->($event, $description, @_);
    }
    elsif (ref $error eq "HASH") {
        goto _handle_error_croak unless defined (my $response = $error->{$event});

        if (ref $response eq "CODE") {
            return $response->($event, $description, @_);
        }
        elsif ($response) {
            goto _handle_error_croak;
        }
        else {
            # Ignore the error
            return;
        }
    }

    croak "Don't understand error handler ($error)" if $error;

_handle_error_croak:
    croak "$description ($event)";
}

use MooseX::MakeImmutable;
MooseX::MakeImmutable->lock_down;

=head1 SEE ALSO

L<Getopt::Chain::Context>

L<Getopt::Long>

L<App::Cmd>

L<MooseX::App::Cmd>

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 SOURCE

You can contribute or fork this project via GitHub:

L<http://github.com/robertkrimen/getopt-chain/tree/master>

    git clone git://github.com/robertkrimen/getopt-chain.git Getopt-Chain

=head1 BUGS

Please report any bugs or feature requests to C<bug-getopt-chain at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Getopt-Chain>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Getopt::Chain


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Getopt-Chain>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Getopt-Chain>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Getopt-Chain>

=item * Search CPAN

L<http://search.cpan.org/dist/Getopt-Chain>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Getopt::Chain
