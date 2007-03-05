#!/usr/bin/perl
use warnings;
use strict;

my $data_dir = "data";
$data_dir = "t/$data_dir" unless -d $data_dir;

use Test::More qw(no_plan);
use Log::Log4perl qw(:easy);
use File::Temp qw(tempfile);
use XML::Simple;

# Log::Log4perl->easy_init($DEBUG);

my($fh, $outfile) = tempfile(CLEANUP => 1);

use XML::RSS::FromHTML::Simple;

my $f = XML::RSS::FromHTML::Simple->new({
    html_file => "$data_dir/art_eng.html",
    base_url  => "http://perlmeister.com",
    rss_file  => $outfile,
});

$f->link_filter( sub {
    my($url, $text) = @_;
    # print "URL=$url\n";
    if($url =~ m#linux-magazine\.com/#) {
        return 1;
    } else {
        return 0;
    }
});

$f->make_rss();

ok(-s $outfile, "RSS file created");

  # Read XML file back in
my $data = XMLin($outfile);

is($data->{item}->[0]->{link}, 
   'http://www.linux-magazine.com/issue/71/Perl_Link_Spam.pdf', 
   "Check RSS (first item)");

my %urls = map { $_->{link} => 1 } 
           @ { $data->{item} };

ok(!exists $urls{'http://www.perl.com/pub/a/2002/09/11/log4perl.html'},
   "Non linux-magazine url doesn't exist");

#use Data::Dumper;
# print STDERR Dumper($data);
