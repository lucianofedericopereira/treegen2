package Treegen2;
use strict;
use warnings;

# Inject directory trees into Markdown/HTML files — ASCII, themeable SVG,
# or a GitHub-native collapsible tree. See lib/Treegen2/CLI.pm for the
# command-line entry point and bin/treegen2 for the executable wrapper.

our $VERSION = '0.1.0';

1;

__END__

=head1 NAME

Treegen2 - inject directory trees into README (and other) files

=head1 DESCRIPTION

A from-scratch Perl port of L<treegen|https://github.com/lucianofedericopereira/treegen>:
turns a C<[[files]]> marker into a directory tree (ascii, svg, or a
collapsible C<E<lt>detailsE<gt>> tree) and keeps it in sync on every run.
Pure core Perl, no CPAN dependencies. See L<Treegen2::CLI> for the
command-line entry point.

=head1 AUTHOR

Luciano Federico Pereira E<lt>https://github.com/lucianofedericopereiraE<gt>

=head1 LICENSE

This software is copyright (c) 2026 by Luciano Federico Pereira.

This is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See the LICENSE file for the full text.

=cut
