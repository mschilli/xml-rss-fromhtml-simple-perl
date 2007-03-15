#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use Encode qw(is_utf8 _utf8_on);
use File::Spec::Functions qw(rel2abs);
use Test::More qw(no_plan);
use Log::Log4perl qw(:easy);
use File::Temp qw(tempfile);
use XML::Simple;

my $data_dir = "data";
$data_dir = "t/$data_dir" unless -d $data_dir;

# Log::Log4perl->easy_init($DEBUG);

my($fh, $outfile) = tempfile(CLEANUP => 1);

use XML::RSS::FromHTML::Simple;

my $f = XML::RSS::FromHTML::Simple->new({
    url => "file://" . rel2abs("$data_dir/utf8.html"),
    base_url  => "http://perlmeister.com",
    rss_file  => $outfile,
});

$f->make_rss();

ok(-s $outfile, "RSS file created");

  # Read XML file back in
my $data = XMLin($outfile);

my $got = $data->{item}->{title};
_utf8_on($got);
ok(is_utf8($got), "got string is utf8");

is($data->{item}->{title}, "Hüsker Dü", "Title with umlaut");
