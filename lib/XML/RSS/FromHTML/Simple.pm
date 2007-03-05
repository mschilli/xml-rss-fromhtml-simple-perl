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
use base qw(Class::Accessor);

our $VERSION = "0.01";

__PACKAGE__->mk_accessors($_) for qw(url html_file rss_file encoding 
                                     link_filter
                                     html title base_url ua);

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
          return undef;
      }

      $self->html( $resp->decoded_content() );

      my $http_time = 
                $resp->header('last-modified');
      INFO "Last modified: $http_time";
    
      $mtime   = str2time($http_time);
  }

    # Read infile
  if($self->html_file()) {
      LOGDIE "base_url required with HTML file" unless 
          defined $self->base_url();

      INFO "Reading HTML file ", $self->html_file();
      local $/ = undef;
      open FILE, "<", $self->html_file() or 
          LOGDIE "Cannot open ", $self->html_file();
      $self->html(scalar <FILE>);
      close FILE;
      $mtime = (stat($self->html_file))[9];
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
   
    $self->url( "" ) unless defined $self->url();
    $self->html_file( "" ) unless defined $self->html_file();
    $self->rss_file( "out.xml" ) unless defined $self->rss_file();
    $self->encoding( "utf-8" ) unless $self->encoding();
    $self->link_filter( sub { 1 } ) unless defined $self->link_filter();
    $self->html( "" ) unless defined $self->html();
    $self->title( "No Title" ) unless defined $self->title();
    $self->base_url( "" ) unless defined $self->base_url();
    $self->ua( LWP::UserAgent->new() ) unless defined $self->ua();
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

XML::RSS::FromHTML::Simple - Turn links on an HTML page into a RSS file

=head1 SYNOPSIS

    use XML::RSS::FromHTML::Simple;

    my $proc = XML::RSS::FromHTML::Simple->new(
        url    => "http://perlmeister.com/art_eng.html",
        output => "out.xml",
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

        # Create out.xml
    $proc->run();

=head1 ABSTRACT

Examines an HTML document, extracts its links and puts them into an RSS.

=head1 DESCRIPTION

C<XML::RSS::FromHTML::Simple> helps reeling in web pages and 
creating RSS files out of them.
Typically, it is used to contact websites displaying news content in HTML, 
which aren't providing RSS files on their own.
RSS files are typically used to track the content on frequently 
changing news websites and to provide a way for other programs to figure
out if new news have arrived.

C<XML::RSS::FromHTML>'s C<make> method takes a URL as one of its arguments
and fetches the underlying content via a HTTP request. It then parses
the HTML of the page, rummaging through all hyperlinks.

For each one found, it will call a supplied filter function, which 
will return a true or false value, indicating if the link is a news 
headline or not and will therefore end up in the resulting RSS file
or be discarded.
For each link found in the HTML of the web page, 
the filter function will receive the URL and the text of the link 
as arguments. In addition to decide if the Link is RSS-worthy,
the filter may also change the value of 
the URL or the corresponding text by modifying C<$_[0]> or C<$_[1]>
directly.

The C<make> method will store its RSS result with all then links it finds
newsworthy in the output file defined via the C<-output> parameter.

This module has been inspired by Sean Burke's article in TPJ 11/2002.

    http://www.linux-magazine.com/issue/51/Perl_Collecting_News_Headlines.pdf

=head1 LEGALESE

This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2007, Mike Schilli <m@perlmeister.com>
