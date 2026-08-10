package Treegen2::JSONLite;
use strict;
use warnings;

# A minimal, dependency-free JSON decoder.
#
# treegen2 only needs to read small "path -> description" objects, so this
# is deliberately not a general-purpose JSON library — just enough of the
# grammar (objects, arrays, strings with escapes, numbers, true/false/null)
# to read any well-formed JSON document. Written from scratch against core
# Perl (string ops, regex, hex()) rather than JSON::PP so the whole tool
# stays runnable on interpreters far older than JSON::PP's Perl 5.14
# core-bundling cutoff.

use Exporter 'import';
our @EXPORT_OK = qw(decode_json_lite);

sub decode_json_lite {
    my ($text) = @_;
    my $pos = 0;
    my $len = length $text;
    my $value = _parse_value($text, \$pos, $len);
    _skip_ws($text, \$pos, $len);
    return $value;
}

sub _skip_ws {
    my ($text, $posref, $len) = @_;
    $$posref++ while $$posref < $len && substr($text, $$posref, 1) =~ /[ \t\r\n]/;
}

sub _parse_value {
    my ($text, $posref, $len) = @_;
    _skip_ws($text, $posref, $len);
    die "treegen2: unexpected end of JSON input\n" if $$posref >= $len;
    my $char = substr($text, $$posref, 1);
    return _parse_object($text, $posref, $len) if $char eq '{';
    return _parse_array($text, $posref, $len)  if $char eq '[';
    return _parse_string($text, $posref, $len) if $char eq '"';
    if ($char eq 't') { _expect_literal($text, $posref, $len, 'true');  return 1; }
    if ($char eq 'f') { _expect_literal($text, $posref, $len, 'false'); return 0; }
    if ($char eq 'n') { _expect_literal($text, $posref, $len, 'null');  return undef; }
    return _parse_number($text, $posref, $len) if $char =~ /[-0-9]/;
    die "treegen2: unexpected character '$char' in JSON at offset $$posref\n";
}

sub _expect_literal {
    my ($text, $posref, $len, $literal) = @_;
    my $slice = substr($text, $$posref, length $literal);
    die "treegen2: invalid JSON literal near offset $$posref\n" unless $slice eq $literal;
    $$posref += length $literal;
}

sub _parse_object {
    my ($text, $posref, $len) = @_;
    $$posref++; # consume '{'
    my %obj;
    _skip_ws($text, $posref, $len);
    if (substr($text, $$posref, 1) eq '}') { $$posref++; return \%obj; }
    while (1) {
        _skip_ws($text, $posref, $len);
        die "treegen2: expected string key in JSON object\n"
            unless substr($text, $$posref, 1) eq '"';
        my $key = _parse_string($text, $posref, $len);
        _skip_ws($text, $posref, $len);
        die "treegen2: expected ':' in JSON object\n"
            unless substr($text, $$posref, 1) eq ':';
        $$posref++;
        $obj{$key} = _parse_value($text, $posref, $len);
        _skip_ws($text, $posref, $len);
        my $next = substr($text, $$posref, 1);
        if ($next eq ',') { $$posref++; next; }
        if ($next eq '}') { $$posref++; last; }
        die "treegen2: expected ',' or '}' in JSON object\n";
    }
    return \%obj;
}

sub _parse_array {
    my ($text, $posref, $len) = @_;
    $$posref++; # consume '['
    my @arr;
    _skip_ws($text, $posref, $len);
    if (substr($text, $$posref, 1) eq ']') { $$posref++; return \@arr; }
    while (1) {
        push @arr, _parse_value($text, $posref, $len);
        _skip_ws($text, $posref, $len);
        my $next = substr($text, $$posref, 1);
        if ($next eq ',') { $$posref++; next; }
        if ($next eq ']') { $$posref++; last; }
        die "treegen2: expected ',' or ']' in JSON array\n";
    }
    return \@arr;
}

sub _parse_string {
    my ($text, $posref, $len) = @_;
    $$posref++; # consume opening quote
    my $out = '';
    while (1) {
        die "treegen2: unterminated JSON string\n" if $$posref >= $len;
        my $char = substr($text, $$posref, 1);
        if ($char eq '"') { $$posref++; last; }
        if ($char eq '\\') {
            $$posref++;
            my $esc = substr($text, $$posref, 1);
            if    ($esc eq '"')  { $out .= '"' }
            elsif ($esc eq '\\') { $out .= '\\' }
            elsif ($esc eq '/')  { $out .= '/' }
            elsif ($esc eq 'b')  { $out .= "\b" }
            elsif ($esc eq 'f')  { $out .= "\f" }
            elsif ($esc eq 'n')  { $out .= "\n" }
            elsif ($esc eq 'r')  { $out .= "\r" }
            elsif ($esc eq 't')  { $out .= "\t" }
            elsif ($esc eq 'u')  {
                my $hex = substr($text, $$posref + 1, 4);
                $out .= chr(hex($hex));
                $$posref += 4;
            }
            else { die "treegen2: invalid JSON escape '\\$esc'\n"; }
            $$posref++;
            next;
        }
        $out .= $char;
        $$posref++;
    }
    return $out;
}

sub _parse_number {
    my ($text, $posref, $len) = @_;
    my $start = $$posref;
    $$posref++ if substr($text, $$posref, 1) eq '-';
    $$posref++ while $$posref < $len && substr($text, $$posref, 1) =~ /[0-9]/;
    if ($$posref < $len && substr($text, $$posref, 1) eq '.') {
        $$posref++;
        $$posref++ while $$posref < $len && substr($text, $$posref, 1) =~ /[0-9]/;
    }
    if ($$posref < $len && substr($text, $$posref, 1) =~ /[eE]/) {
        $$posref++;
        $$posref++ if $$posref < $len && substr($text, $$posref, 1) =~ /[+-]/;
        $$posref++ while $$posref < $len && substr($text, $$posref, 1) =~ /[0-9]/;
    }
    return substr($text, $start, $$posref - $start) + 0;
}

1;
