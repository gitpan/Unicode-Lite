use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'         => 'Unicode::Lite',
    'VERSION_FROM' => 'Lite.pm',
    'PREREQ_PM'    => { 
        'Unicode::String' => 2.06,
        'Unicode::Map'    => 0.110,
    },
);
