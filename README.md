wp2git
======

This program allows you to download and convert any Wikipedia article's history to a git repository, for easy browsing and blaming.

### Usage

    $ wp2git Article_name_here

`wp2git` will create a directory, in which a new git repository will be created.

Run `wp2git --help` for more options.

### Requirements

The commands `git` and `curl` should be accessible from `PATH`.

### Download

You can find compiled Windows binaries on [files.thecybershadow.net](http://files.thecybershadow.net/wp2git/).

### Building

You will need a [D compiler](http://dlang.org/download.html) to build `wp2git`.

    $ git clone --recursive https://github.com/CyberShadow/wp2git
    $ rdmd --build-only wp2git
