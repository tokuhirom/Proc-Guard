use inc::Module::Install;

name 'Proc-Guard';
all_from 'lib/Proc/Guard.pm';

requires 'Class::Accessor::Lite' => 0.05;
requires 'Exporter' => 5.63;
requires 'Test::More' => 0.94;

test_requires 'Test::More';
test_requires 'Test::Requires';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';

WriteAll();
