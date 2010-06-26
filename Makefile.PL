use inc::Module::Install;
name 'Proc-Guard';
all_from 'lib/Proc/Guard.pm';

requires 'Class::Accessor::Lite';
requires 'Exporter' => 5.63;
requires 'Test::More' => 0.94;

readme_markdown_from 'lib/Proc/Guard.pm';
tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
author_tests('xt');
auto_include;
WriteAll;
