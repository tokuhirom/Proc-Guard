requires 'Class::Accessor::Lite', '0.05';
requires 'Exporter', '5.63';
requires 'Test::More', '0.94';
requires 'perl', '5.00800';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Test::More';
    requires 'Test::Requires';
};
