package Proc::Guard;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.07';
use Carp ();

our $EXIT_STATUS;

# killer helper borrowed from IPC::Cmd
# to send both SIGTERM and SIGKILL on Unix
# and to avoid hanging on Windows
# where waitpid after killing doesn't work "by design"
#

my $HAVE_MONOTONIC;

BEGIN {
    eval {
        require POSIX; POSIX->import();
        require Time::HiRes; Time::HiRes->import();
    };

    eval {
        my $wait_start_time = Time::HiRes::clock_gettime(&Time::HiRes::CLOCK_MONOTONIC);
    };
    if ($@) {
        $HAVE_MONOTONIC = 0;
    }
    else {
        $HAVE_MONOTONIC = 1;
    }
}

sub get_monotonic_time {
    if ($HAVE_MONOTONIC) {
        return Time::HiRes::clock_gettime(&Time::HiRes::CLOCK_MONOTONIC);
    }
    else {
        return time();
    }
}

sub adjust_monotonic_start_time {
    my ($ref_vars, $now, $previous) = @_;

    # workaround only for those systems which don't have
    # Time::HiRes::CLOCK_MONOTONIC (Mac OSX in particular)
    return if $HAVE_MONOTONIC;

    # don't have previous monotonic value (only happens once
    # in the beginning of the program execution)
    return unless $previous;

    my $time_diff = $now - $previous;

    # adjust previously saved time with the skew value which is
    # either negative when clock moved back or more than 5 seconds --
    # assuming that event loop does happen more often than once
    # per five seconds, which might not be always true (!) but
    # hopefully that's ok, because it's just a workaround
    if ($time_diff > 5 || $time_diff < 0) {
        foreach my $ref_var (@{$ref_vars}) {
            if (defined($$ref_var)) {
                $$ref_var = $$ref_var + $time_diff;
            }
        }
    }
}




#
# give process a chance sending TERM,
# waiting for a while (2 seconds)
# and killing it with KILL
sub kill_gently {
  my ($pid, $opts) = @_;

  $opts = {} unless $opts;
  $opts->{'wait_time'} = 2 unless defined($opts->{'wait_time'});
  $opts->{'first_kill_type'} = 'just_process' unless $opts->{'first_kill_type'};
  $opts->{'final_kill_type'} = 'just_process' unless $opts->{'final_kill_type'};

  if ($opts->{'first_kill_type'} eq 'just_process') {
    kill(15, $pid);
  }
  elsif ($opts->{'first_kill_type'} eq 'process_group') {
    kill(-15, $pid);
  }

  my $do_wait = 1;
  my $child_finished = 0;

  my $wait_start_time = get_monotonic_time();
  my $now;
  my $previous_monotonic_value;

  while ($do_wait) {
    $previous_monotonic_value = $now;
    $now = get_monotonic_time();

    adjust_monotonic_start_time([\$wait_start_time], $now, $previous_monotonic_value);

    if ($now > $wait_start_time + $opts->{'wait_time'}) {
        $do_wait = 0;
        next;
    }

    my $waitpid = waitpid($pid, POSIX::WNOHANG);

    if ($waitpid eq -1) {
        $child_finished = 1;
        $do_wait = 0;
        next;
    }

    Time::HiRes::usleep(250000); # quarter of a second
  }

  if (!$child_finished) {
    if ($opts->{'final_kill_type'} eq 'just_process') {
      kill(9, $pid);
    }
    elsif ($opts->{'final_kill_type'} eq 'process_group') {
      kill(-9, $pid);
    }
  }
}

# functional interface
our @EXPORT = qw/proc_guard/;
use Exporter 'import';
sub proc_guard {
    return Proc::Guard->new(do {
        if (@_==1 && ref($_[0])  && ref($_[0]) eq 'CODE') {
            +{ code => $_[0] }
        } else {
            +{ command => [@_] }
        }
    });
}

# OOish interface
use POSIX qw/:signal_h/;
use Errno qw/EINTR ECHILD/;
use Class::Accessor::Lite 0.05 (
	rw => ['pid'],
);

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;

    my $self = bless {
        _owner_pid => $$,
        auto_start => 1,
        %args,
    }, $class;

    if ($self->{command} && !ref($self->{command})) {
        $self->{command} = [$self->{command}];
    }
    unless ($self->{command} || $self->{code}) {
        Carp::croak("'command' or 'code' is required.");
    }

    $self->start()
        if $self->{auto_start};

    return $self;
}

sub start {
    my $self = shift;

    my $pid = fork();
    die "fork failed: $!" unless defined $pid;
    if ($pid == 0) { # child
        if ($self->{command}) {
            exec @{$self->{command}};
            die "cannot exec @{$self->{command}}: $!";
        } else {
            $self->{code}->();
            exit(0); # exit after work
        }
    }
    $self->pid($pid);
}

sub stop {
    my ( $self, $sig ) = @_;
    return
        unless defined $self->pid;

    kill_gently $self->pid;
    $self->pid(undef);
}

sub DESTROY {
    my $self = shift;
    if (defined $self->pid && $$ == $self->{_owner_pid}) {
        local $?; # "END" function and destructors can change the exit status by modifying $?.(perldoc -f exit)
        $self->stop()
    }
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
    my $proc = proc_guard(scalar(which('memcached')), '-p', $port);
    wait_port($port);

    # your code here

    # --------------
    # or, use perl code
    my $proc = proc_guard(sub {
        ... # run this code in child process
    });
    ...

=head1 DESCRIPTION

Proc::Guard runs process, and destroys it when the perl script exits.

This is useful for testing code working with server process.

=head1 FUNCTIONS

=over 4

=item proc_guard(@cmdline|\&code)

This is shorthand for:

    Proc::Guard->new(
        command => \@cmdline,
    );

or

    Proc::Guard->new(
        code => \&code,
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

=item code

    Proc::Guard->new(code => sub { ... });

'code' or 'command' is required.

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

=head1 VARIABLES

=over 4

=item $Proc::Guard::EXIT_STATUS

The last exit status code by C<< $proc->stop >>.  If C<waitpid>
failed with an error, this will be set to C<undef>.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
