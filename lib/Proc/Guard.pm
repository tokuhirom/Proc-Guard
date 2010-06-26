package Proc::Guard;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.02';

# functional interface
our @EXPORT = qw/proc_guard/;
use Exporter 'import';
sub proc_guard { Proc::Guard->new(command => [@_]) }

# OOish interface
use POSIX;
use Class::Accessor::Lite;
Class::Accessor::Lite->mk_accessors(qw/pid/);

sub new {
    my ($class, %args) = @_;

    my $self = bless {
        _owner_pid => $$,
        auto_start => 1,
        %args,
    }, $class;
    $self->{command} = [$self->{command}] unless ref $self->{command};

    $self->start()
        if $self->{auto_start};

    return $self;
}

sub start {
    my $self = shift;

    my $pid = fork();
    die "fork failed: $!" unless defined $pid;
    if ($pid == 0) { # child
        exec @{$self->{command}};
        die "cannot exec @{$self->{command}}: $!";
    }
    $self->pid($pid);
}

sub stop {
    my ( $self, $sig ) = @_;
    return
        unless defined $self->pid;
    $sig ||= SIGTERM;

    kill $sig, $self->pid;
    1 while waitpid( $self->pid, 0 ) <= 0;

    $self->pid(undef);
}

sub DESTROY {
    my $self = shift;
    $self->stop() if defined $self->pid && $$ == $self->{_owner_pid};
}

1;
__END__

=encoding utf8

=head1 NAME

Proc::Guard - process runner with RAII pattern

=head1 SYNOPSIS

    use Test::TCP qw/empty_port wait_port/;
    use File::Which qw/which/;
    use Proc::Guard;

    my $port = empty_port();
    my $proc = proc_guard(which('memcached'), '-p', $port);
    wait_port($port);

    # your code here

=head1 DESCRIPTION

Proc::Guard runs process, and destroys it when the perl script exits.

This is useful for testing code working with server process.

=head1 FUNCTIONS

=over 4

=item proc_guard(@cmdline)

This is shorthand for:

    Proc::Guard->new(
        command => \@cmdline,
    );

=back

=head1 METHODS

=over 4

=item my $proc = Proc::Guard->new(%args);

Create and run a process. The process is terminated when the returned object is being DESTROYed.

=over 4

=item command

    Proc::Guard->new(command => '/path/to/memcached');
    # or
    Proc::Guard->new(command => ['/path/to/memcached', '-p', '11211']);

The command line.

=item auto_start

    Proc::Guard->new(auto_start => 0);

Start child process automatically or not(default: 1).

=back

=item pid

Returns process id (or undef if not running).

=item start

Starts process.

=item stop

Stops process.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
