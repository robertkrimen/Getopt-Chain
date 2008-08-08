use inc::Module::Install;

name 'Getopt-Chain';
all_from 'lib/Getopt/Chain.pm';

build_requires 'Test::More';

auto_install;

WriteAll;

