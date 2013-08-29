use Config;
use Test::Simple tests => 1;

if (! $Config{'useithreads'}) {


	ok( 1, "# Test only for non-threaded environments\n" );
    	# exit(0);
	
} else {
	
	ok( require Threads::Pool, "# Test only for non-threaded environments\n" );
	
}
