package Getopt::Chain;

use warnings;
use strict;

=head1 NAME

Getopt::Chain - The great new Getopt::Chain!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use Moose;
use Getopt::Long qw/GetOptionsFromArray/;
use XXX -dumper;

has options => qw/is rw isa HashRef/;

has schema => qw/is ro isa Maybe[HashRef]/;
has _getopt_long_options => qw/is rw isa ArrayRef/;

has commands => qw/is ro isa Maybe[HashRef]/;

has do => qw/is ro isa Maybe[CodeRef]/;

has _next => qw/is ro isa Getopt::Buddy/;

has validate => qw/is ro isa Maybe[CodeRef]/;

has catch => qw/is ro isa Maybe[CodeRef]/;

sub BUILD {
    my $self = shift;
    my $given = shift;

    my ($schema, $getopt_long_options) = $self->_parse_schema($self->schema);

    $self->{schema} = $schema;
    $self->_getopt_long_options($getopt_long_options);
}

sub _parse_schema {
    my $self = shift;
    my $schema = shift;

    my %schema;
    my @getopt_long_options;

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
    my $arguments = shift;

    my %options;
    my $validate = $self->validate;
    my $catch = $self->catch;
    my $do = $self->do;
    my $commands = $self->commands;
    $arguments = [ @ARGV ] unless $arguments;

    eval {
        if (my $getopt_long_options = $self->_getopt_long_options) {
            GetOptionsFromArray($arguments, \%options, @$getopt_long_options);
        }
    };
    if (my $error = $@) {
        die $@ unless $catch;
        $catch->($@);
    }

    $self->options(\%options);

    $validate->(\%options, $self) if $validate;

    $do->(\%options, $self) if $do;
}

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

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
