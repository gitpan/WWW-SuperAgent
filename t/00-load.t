use Test::More tests => 1;

BEGIN {
    use_ok( 'WWW::SuperAgent' ) || print "Bail out!\n";
}

diag( "Testing WWW::SuperAgent $WWW::SuperAgent::VERSION, Perl $], $^X" );
