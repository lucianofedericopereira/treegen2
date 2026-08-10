use strict;
use warnings;
use Test::More tests => 20;
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use FindBin ();

my $BIN = "$FindBin::RealBin/../bin/treegen2";
my $LIB = "$FindBin::RealBin/../lib";

sub run_cli {
    my (@args) = @_;
    my $cmd = join(' ', 'perl', "-I$LIB", $BIN, map { quotemeta($_) } @args);
    my $out = `$cmd 2>&1`;
    my $status = $? >> 8;
    return ($status, $out);
}

# --- --version ---------------------------------------------------------------
{
    my ($status, $out) = run_cli('--version');
    is($status, 0, '--version exits 0');
    like($out, qr/^treegen2 \d+\.\d+\.\d+/, '--version prints a semver-looking string');
}

# --- --style validation --------------------------------------------------------
{
    my ($status, $out) = run_cli('--style', 'bogus');
    isnt($status, 0, 'an invalid --style is rejected');
    like($out, qr/invalid --style/, 'error message names the bad option');
}

# --- missing readme pattern -----------------------------------------------------
# A pattern that is entirely blank after trimming resolves to zero candidate
# paths at all (not even a literal fallback), which is the one case that
# actually hits "no README files matched".
{
    my ($status, $out) = run_cli('--readme', '   ,  ');
    isnt($status, 0, 'an all-blank --readme pattern is an error');
    like($out, qr/no README files matched/, 'error names the problem');
}

# A glob that matches nothing still falls back to treating the literal
# pattern as a candidate path (matching the original Python tool's
# behaviour), so this surfaces as a missing-file error instead.
{
    my $dir = tempdir(CLEANUP => 1);
    my ($status, $out) = run_cli('--readme', "$dir/nope-*.md");
    isnt($status, 0, 'a non-matching glob with no real file is still an error');
    like($out, qr/skipping missing file/, 'the unmatched literal pattern is reported as a missing file');
    like($out, qr/no existing README files to process/, 'and ultimately no files were processed');
}

# --- a full run: expand, write, idempotent re-run, --check -----------------------
{
    my $dir = tempdir(CLEANUP => 1);
    mkpath("$dir/src");
    open my $fh, '>', "$dir/src/main.py" or die $!;
    close $fh;
    open $fh, '>', "$dir/README.md" or die $!;
    print $fh qq{# Demo\n\n[[files dir="src"]]\n};
    close $fh;

    my ($status1, $out1) = run_cli('--readme', "$dir/README.md", '--base', $dir);
    is($status1, 0, 'first run exits 0');
    like($out1, qr/changed/, 'first run reports changed');

    open $fh, '<', "$dir/README.md" or die $!;
    my $content = do { local $/; <$fh> };
    close $fh;
    like($content, qr/main\.py/, 'README.md now contains the rendered tree');

    my ($status2, $out2) = run_cli('--readme', "$dir/README.md", '--base', $dir);
    is($status2, 0, 'second run exits 0');
    like($out2, qr/unchanged/, 'second run reports unchanged (idempotent)');

    my ($status3, $out3) = run_cli('--readme', "$dir/README.md", '--base', $dir, '--check');
    is($status3, 0, '--check on an up-to-date file exits 0');

    # Go stale: add a new file, then --check should fail without writing.
    open $fh, '>', "$dir/src/extra.py" or die $!;
    close $fh;
    my ($status4, $out4) = run_cli('--readme', "$dir/README.md", '--base', $dir, '--check');
    isnt($status4, 0, '--check on a stale file exits non-zero');
    like($out4, qr/out of date/, 'stale-check error message is informative');

    open $fh, '<', "$dir/README.md" or die $!;
    my $unchanged_content = do { local $/; <$fh> };
    close $fh;
    is($unchanged_content, $content, '--check never writes to disk, even when stale');
}

# --- GITHUB_OUTPUT integration --------------------------------------------------
{
    my $dir = tempdir(CLEANUP => 1);
    mkpath("$dir/src");
    open my $fh, '>', "$dir/README.md" or die $!;
    print $fh qq{[[files dir="src"]]\n};
    close $fh;

    my $output_file = "$dir/gh_output.txt";
    open my $touch, '>', $output_file or die $!;
    close $touch;

    local $ENV{GITHUB_OUTPUT} = $output_file;
    my $cmd = join(' ', 'perl', "-I$LIB", $BIN, '--readme', quotemeta("$dir/README.md"), '--base', quotemeta($dir));
    system("$cmd >/dev/null 2>&1");

    open my $gh_fh, '<', $output_file or die $!;
    my $gh_content = do { local $/; <$gh_fh> };
    close $gh_fh;
    like($gh_content, qr/changed=true/, 'GITHUB_OUTPUT records changed=true');
    like($gh_content, qr/blocks=1/, 'GITHUB_OUTPUT records the block count');
}
