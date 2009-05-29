package Getopt::Chain;

use warnings;
use strict;

use constant DEBUG => $ENV{GOC_TRACE} ? 1 : 0;
our $DEBUG = DEBUG;

=head1 NAME

Getopt::Chain - Command-line processing like svn and git

=head1 VERSION

Version 0.013

=cut

our $VERSION = '0.013';

=head1 SYNPOSIS 

    package My::Command;

    use Getopt::Chain::Declare;

    start [qw/ verbose|v /]; # These are "global"
                             # my-command --verbose initialize ...

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

Getopt::Chain can be used to provide C<svn(1)>- and C<git(1)>-style option and command processing. Any option specification
covered by L<Getopt::Long> is fair game.

This is a new version of Getopt::Chain that uses L<Path::Dispatcher>

CAVEAT 1: This is pretty beta, so the sugar/interface above WILL be tweaked

CAVEAT 2: Unfortunately, Getopt::Long slurps up the entire arguments array at once. Usually, this isn't a problem (as Getopt::Chain uses 
pass_through). However, if a subcommand has an option with the same name or alias as an option for a parent, then that option won't be available
for the subcommand. For example:

    ./script --verbose --revision 36 edit --revision 48 --file xyzzy.c
    # Getopt::Chain will not associate the second --revision with "edit"

So, for now, try to use distinct option names/aliases :)

DEBUG: You can get some extra information about what Getopt::Chain is doing by setting the environment variable C<GOC_TRACE> to 1

=head1 LEGACY

The old-style, non L<Path::Dispatcher> version is still available at L<Getopt::Chain::v005>

=cut

use Moose;
use Getopt::Chain::Carp;

use Getopt::Chain::Builder;
use Getopt::Chain::Context;

has builder => qw/is ro lazy_build 1/, handles => [qw/ dispatcher /];
sub _build_builder {
    return Getopt::Chain::Builder->new;
}

has context_from => qw/is ro isa Str|CodeRef lazy_build 1/;
sub _build_context_from {
    return 'Getopt::Chain::Context';
}

sub process {
    if (! ref $_[0] && $_[0] && $_[0] eq 'Getopt::Chain') {
        shift;
        require Getopt::Chain::v005;
        carp "Deprecated: Use Getopt::Chain::v005->process( ... ) to avoid this warning (this method will be removed in a future version)";
        return Getopt::Chain::v005->process( @_ );
    }
}

sub run {
    if (! ref $_[0] ) {
        croak "Can't call run on the package; use ->new first";
    }
    my $self = shift;
    my $arguments = shift;

    $arguments = [ @ARGV ] unless $arguments;

    my $context = $self->new_context( dispatcher => $self->dispatcher, arguments => $arguments );
    $context->run;
    return $context->options;
}

sub new_context {
    my $self = shift;

    my $context_from = $self->context_from;
    if (! ref $context_from) {
        return $context_from->new( @_ );
    }
    else {
        croak "Don't understand context source \"$context_from\"";
    }
}

use MooseX::MakeImmutable;
MooseX::MakeImmutable->lock_down;

=head1 SEE ALSO

L<Getopt::Long>

L<App::Cmd>

L<MooseX::App::Cmd>

=head1 ACKNOWLEDGEMENTS

Sartak for L<Path::Dispatcher>

obra for inspiration on the CLI (via Prophet & Sd: L<http://syncwith.us/>)

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 SOURCE

You can contribute or fork this project via GitHub:

L<http://github.com/robertkrimen/Getopt-Chain/tree/master>

    git clone git://github.com/robertkrimen/Getopt-Chain.git Getopt-Chain

=head1 BUGS

Please report any bugs or feature requests to C<bug-Getopt-Chain at rt.cpan.org>, or through
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


=head1 COPYRIGHT & LICENSE

Copyright 2008 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Getopt::Chain
