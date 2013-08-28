use Config;
use Test::Simple tests => 1;

if (! $Config{'useithreads'}) {


	ok( require Threads::Pool, "Test to load the module in non-threaded environment" );

} else {
	
	ok( 1, "# Skip this test cause it's only for non-threade environments\n" );
	# print("1..1 # Skip this test cause it's only for non-threade environments\n");
    	# exit(0);
	
}
