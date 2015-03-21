# Socket activated SOCKS5 proxy using SSH

This is a collection of systemd units that enable the setup of a
SOCKS5 proxy over SSH. A script to manage multiple instances of them
in a systemd user session is also included.

## Requirements

* openssh
* systemd
* Ruby (for the management script)


## Setup

You should setup your `~/.ssh/config` in a way such that `ssh host` works
and requires no interaction. Then obtain this repository with:

```sh
git clone https://github.com/jhass/socket_activated_socks.git
cd socket_activated_socks
```

By default the port prefix is `2380`, so if you do:

```sh
./manage.rb add host 1
```

This sets up a SOCKS5 proxy to `host` on port `23801`. You can change the
prefix by editing `manage.rb`.

See `./manage.rb help` for more commands.
