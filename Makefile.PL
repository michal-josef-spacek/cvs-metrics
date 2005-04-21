use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'CVS::Metrics',
    'VERSION_FROM'  => 'Metrics.pm',
    'ABSTRACT'      => 'Utilities for process cvs log',
    'PREREQ_PM'     => {
                        'Chart::Plot::Canvas'   => 0,
                        'HTML::Template'        => 0,
                        'GD'                    => 0,
                        'GD::Graph'             => 0,
                        'Parse::RecDescent'     => 0,
    },
    'PM'            => {
                        'Metrics.pm'        => '$(INST_LIBDIR)/Metrics.pm',
                        'Parser.pm'         => '$(INST_LIBDIR)/Metrics/Parser.pm',
                        'Graph.pm'          => '$(INST_LIBDIR)/Metrics/Graph.pm',
                        'TaggedChart.pm'    => '$(INST_LIBDIR)/Metrics/TaggedChart.pm',
    },
    'EXE_FILES'     => [
                        'cvs_activity.pl',
                        'cvs_energy.pl',
                        'cvs_tklog.pl',
                        'cvs_wxlog.pl',
                        'cvs_current.pl',
                        'cvs_revbytag.pl',
                        'cgi_cvs_evolq.pl',
                        'cgi_cvs_evolr.pl',
    ],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);

