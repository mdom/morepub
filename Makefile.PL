use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "App::morepub",
    VERSION_FROM => "bin/morepub",
    EXE_FILES    => ['bin/morepub'],
    PREREQ_PM    => {
        Mojolicious   => 0,
    },
);
