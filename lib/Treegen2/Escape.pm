package Treegen2::Escape;
use strict;
use warnings;

# Two escaping flavours, matching the two Python stdlib escapers the
# original tool relies on:
#   escape_html - like Python's html.escape(s, quote=True): & < > " '
#   escape_xml  - like xml.sax.saxutils.escape: & < > only (used inside
#                 SVG attribute values that treegen2 always double-quotes
#                 itself, so quotes need not be escaped there).

use Exporter 'import';
our @EXPORT_OK = qw(escape_html escape_xml);

sub escape_html {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#x27;/g;
    return $s;
}

sub escape_xml {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}

1;
