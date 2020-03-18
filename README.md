# NAME

Proc::Guard - process runner with RAII pattern

# SYNOPSIS

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

# DESCRIPTION

Proc::Guard runs process, and destroys it when the perl script exits.

This is useful for testing code working with server process.

# FUNCTIONS

- proc\_guard(@cmdline|\\&code)

    This is shorthand for:

        Proc::Guard->new(
            command => \@cmdline,
        );

    or

        Proc::Guard->new(
            code => \&code,
        );

# METHODS

- my $proc = Proc::Guard->new(%args);

    Create and run a process. The process is terminated when the returned object is being DESTROYed.

    - command

            Proc::Guard->new(command => '/path/to/memcached');
            # or
            Proc::Guard->new(command => ['/path/to/memcached', '-p', '11211']);

        The command line.

    - code

            Proc::Guard->new(code => sub { ... });

        'code' or 'command' is required.

    - auto\_start

            Proc::Guard->new(auto_start => 0);

        Start child process automatically or not(default: 1).

- pid

    Returns process id (or undef if not running).

- start

    Starts process.

- stop

    Stops process.

# VARIABLES

- $Proc::Guard::EXIT\_STATUS

    The last exit status code by `$proc->stop`.  If `waitpid`
    failed with an error, this will be set to `undef`.

# AUTHOR

Tokuhiro Matsuno &lt;tokuhirom AAJKLFJEF GMAIL COM>

# LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
