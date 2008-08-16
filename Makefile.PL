use inc::Module::Install;

name 'Getopt-Chain';
all_from 'lib/Getopt/Chain.pm';

resources repository => 'http://github.com/robertkrimen/getopt-chain/tree/master';

{
    require ExtUtils::MakeMaker;
    use strict;
    no strict 'refs';

    my $libscan = \&{"ExtUtils::MM_Any::libscan"};
    *{"ExtUtils::MM_Any::libscan"} = sub {
        return '' unless $libscan->(@_);
        return '' if $_[1] =~ /\.sw[p-z]$/;
        return $_[1];
    };
}

{
    map { my ($pk, $vr) = split m/\s/; build_requires $pk => $vr || 0 } grep { ! /^\s*#/ } split m/\n/, <<_END_;
Test::Most
_END_

    map { my ($pk, $vr) = split m/\s/; requires $pk => $vr || 0 } grep { ! /^\s*#/ } split m/\n/, <<_END_;
Getopt::Long 2.37
Carp::Clan::Share
Hash::Param
Moose
MooseX::MakeImmutable 0.002
_END_
}

auto_install;

WriteAll;

