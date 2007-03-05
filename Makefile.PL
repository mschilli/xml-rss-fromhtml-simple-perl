use 5.008002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'XML::RSS::FromHTML::Simple',
    VERSION_FROM      => 'lib/XML/RSS/FromHTML/Simple.pm',
    PREREQ_PM         => {
        LWP::UserAgent => 0,
        HTTP::Request::Common => 0,
        XML::RSS => 1.05,
        HTML::Entities => 0,
        URI::URL => 0,
        HTTP::Date => 0,
        DateTime => 0,
        HTML::TreeBuilder => 0,
        Log::Log4perl => 1.0,
        Class::Accessor => 0,
        XML::Simple => 0,
        Encode      => 0,
        File::Temp => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/XML/RSS/FromHTML/Simple.pm',
       AUTHOR         => 'Mike <m@perlmeister.com>') : ()),
);
