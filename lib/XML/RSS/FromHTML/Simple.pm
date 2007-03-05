###########################################
package XML::RSS::FromHTML::Simple;
use warnings;
use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use XML::RSS;
use HTML::Entities qw(decode_entities);
use URI::URL ();
use HTTP::Date;
use DateTime;
use HTML::TreeBuilder;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Encode qw(is_utf8);
use base qw(Class::Accessor);

our $VERSION = "0.01";

__PACKAGE__->mk_accessors($_) for qw(url html_file rss_file encoding 
                                     link_filter
                                     html title base_url ua error);

###########################################
sub make_rss {
###########################################
  my($self) = @_;

  $self->defaults_set();

  my $mtime;

    # Fetch URL
  if($self->url()) {

      INFO "Fetching URL ", $self->url();

      my $resp = $self->ua()->get($self->url());

      if($resp->is_error()) {
          ERROR "Fetching ", $self->url(), " failed (", $resp->message, ")";
          $self->error($self->url(), ": ", $resp->message);
          return undef;
      }

      $self->html( $resp->decoded_content() );

      DEBUG "HTML is ",
            is_utf8($self->html) ? "" : "*not* ",
            "utf8";

      my $http_time = 
                $resp->header('last-modified');
      DEBUG Dumper($resp->headers());

      if($http_time) {
          INFO "Last modified: $http_time";
          $mtime   = str2time($http_time);
      } else {
          ERROR "'Last modified' missing (using current time).";
          $mtime = time;
      }

  } elsif($self->html_file()) {
      LOGDIE "base_url required with HTML file" unless 
          defined $self->base_url();

      INFO "Reading HTML file ", $self->html_file();
      local $/ = undef;
      open FILE, "<", $self->html_file() or 
          LOGDIE "Cannot open ", $self->html_file();
      $self->html(scalar <FILE>);
      close FILE;
      $mtime = (stat($self->html_file))[9];
  } else {
      if(! $self->html()) {
           $self->error("No HTML found (use html_file or url)");
           return undef;
      }
  }

  my $isotime = DateTime->from_epoch(
                              epoch => $mtime);
  DEBUG "Last modified: $isotime";

  my $rss = XML::RSS->new(
    encoding => $self->encoding()
  );

  $rss->channel(
    title => $self->title(),
    link  => $self->url(),
    dc    => { date => $isotime . "Z"},
  );

  $self->url( $self->base_url() ) unless $self->url();

  foreach(exlinks($self->html(), $self->url())) {

    my($lurl, $text) = @$_;
      
    $text = decode_entities($text);

    if($self->link_filter()->($lurl, $text)) {
      INFO "Adding rss entry: $text $lurl";
      $rss->add_item(
        title => $text,
        link  => $lurl,
      );
    }
  }

  INFO "Saving output in ", $self->rss_file();
  $rss->save($self->rss_file()) or 
      die "Cannot write to ", $self->rss_file();
}

###########################################
sub exlinks {
###########################################
  my($html, $base_url) = @_;

  DEBUG "Extracting links from HTML base=$base_url", 

  my @links = ();

  my $tree = HTML::TreeBuilder->new();

  $tree->parse($html) or return ();

  for(@{$tree->extract_links('a')}) {
      my($link, $element, $attr, 
         $tag) = @$_;
    
      next unless $attr eq "href";

      my $uri = URI->new_abs($link, 
                             $base_url);
      next unless 
        length $element->as_trimmed_text();

      push @links, 
           [URI->new_abs($link, $base_url),
            $element->as_trimmed_text()];
    }

    return @links;
}


###########################################
sub defaults_set {
###########################################
    my($self) = @_;
   
    $self->url( "" ) unless defined $self->{url};
    $self->html_file( "" ) unless defined $self->{html_file};
    $self->rss_file( "out.xml" ) unless defined $self->{rss_file};
    $self->encoding( "utf-8" ) unless $self->{encoding};
    $self->link_filter( sub { 1 } ) unless defined $self->{link_filter};
    $self->html( "" ) unless defined $self->{html};
    $self->title( "No Title" ) unless defined $self->{title};
    $self->base_url( "" ) unless defined $self->{base_url};
    $self->ua( LWP::UserAgent->new() ) unless defined $self->{ua};
}

##################################################
# Poor man's Class::Struct
##################################################
sub make_accessor {
##################################################
    my($package, $name) = @_;

    DEBUG "Making accessor $name for package $package";

    no strict qw(refs);

    my $code = <<EOT;
        *{"$package\\::$name"} = sub {
            my(\$self, \$value) = \@_;

            if(defined \$value) {
                \$self->{$name} = \$value;
            }
            if(exists \$self->{$name}) {
                return (\$self->{$name});
            } else {
                return "";
            }
        }
EOT
    if(! defined *{"$package\::$name"}) {
        eval $code or die "$@";
    }
}

1;

__END__

=head1 NAME

XML::RSS::FromHTML::Simple - Create RSS feeds for sites that don't offer them

=head1 SYNOPSIS

    use XML::RSS::FromHTML::Simple;

    my $proc = XML::RSS::FromHTML::Simple->new(
        url    => "http://perlmeister.com/art_eng.html",
        output => "new_articles.xml",
    );

    $prod->link_filter( sub {
        my($link, $text) = @_;

            # Only extract links that contain 'linux-magazine'
            # in their URL
        if( $link =~ m#linux-magazine#) {
            return 1;
        } else {
            return 0;
        }
    };

        # Create RSS file
    $proc->run();

=head1 ABSTRACT

This module helps creating RSS feeds for sites that don't them.
It examines HTML documents, extracts their links and puts them and
their textual descriptions into an RSS file.

=head1 DESCRIPTION

C<XML::RSS::FromHTML::Simple> helps reeling in web pages and 
creating RSS files out of them.
Typically, it is used to contact websites that are displaying news 
content in HTML, but aren't providing RSS files of their own.
RSS files are typically used to track the content on frequently 
changing news websites and to provide a way for other programs to figure
out if new news have arrived.

To create a new RSS generator, call C<new()>: 

    use XML::RSS::FromHTML::Simple;

    my $f = XML::RSS::FromHTML::Simple->new({
        url      => "http://perlmeister.com/art_eng.html",
        rss_file => $outfile,
    });

C<url> is the URL to a site whichs content you'd like to track. 
C<rss_file> is the name of the resulting RSS file, it defaults
to C<out.xml>. 

Instead of reeling in a document via HTTP, you can just as well
use a local file:

    my $f = XML::RSS::FromHTML::Simple->new({
        html_file => "art_eng.html",
        base_url  => "http://perlmeister.com",
        rss_file  => "perlnews.xml",
    });

Note that in this case, a C<base_url> is necessary to allow the
generator to put fully qualified URLs into the RSS file later.

C<XML::RSS::FromHTML::Simple> creates accessor functions for all
of its attributes. Therefore, you could just as well create a boilerplate
object and set its properties afterwards:

    my $f = XML::RSS::FromHTML::Simple->new();
    $f->html_file("art_eng.html");
    $f->base_url("http://perlmeister.com");
    $f->rss_file("perlnews.xml");

Typically, not all links embedded in the HTML document should be
copied to the resulting RSS file. The C<link_filter()> attribute
takes a subroutine reference, which decides on each URL whether to 
process it or ignore it:

    $f->link_filter( sub {
        my($url, $text) = @_;

        if($url =~ m#linux-magazine\.com/#) {
            return 1;
        } else {
            return 0;
        }
    });

The C<link_filter> subroutine gets called with each URL and its link text,
as found in the HTML content. If C<link_filter> returns 1, the link will
be added to the RSS file. If C<link_filter> returns 0, the link will
be ignored.

In addition to decide if the Link is RSS-worthy,
the filter may also change the value of 
the URL or the corresponding text by modifying C<$_[0]> or C<$_[1]>
directly.

To start the RSS generator, run

    $f->make_rss() or die $f->error();

which will generate the RSS file. If anything goes wrong, C<make_rss()>
returns false and the C<error()> method will tell why it failed.

This module has been inspired by Sean Burke's article in TPJ 11/2002.
I've discussed its code in the following 02/2005 issue of Linux Magazine:

    http://www.linux-magazine.com/issue/51/Perl_Collecting_News_Headlines.pdf

There's also XML::RSS::FromHTML on CPAN, which looks like it's offering
a more powerful API. The focus of XML::RSS::FromHTML::Simple, on the other
hand, is simplicity.

=head1 LEGALESE

This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2007, Mike Schilli <m@perlmeister.com>
