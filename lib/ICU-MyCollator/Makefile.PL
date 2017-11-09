#use 5.010001;
use ExtUtils::MakeMaker;

$CC = 'g++';

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'ICU::MyCollator',
    VERSION_FROM      => 'lib/ICU/MyCollator.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/ICU/MyCollator.pm', # retrieve abstract from module
       AUTHOR         => 'Beau <beau@adres.pl>') : ()),
    LIBS              => ['-licui18n -licuuc -licudata' ],
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    CC                => $CC,
    LD                => '$(CC)',
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
    XSOPT             => '-C++',
    TYPEMAPS          => ['perlobject.map' ],
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
