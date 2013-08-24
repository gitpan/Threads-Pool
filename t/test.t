BEGIN {

	use Config;

  	if (! $Config{'useithreads'}) {

		print("1..0 # Skip: Perl not compiled with 'useithreads'\n");
    		exit(0);
  
	}

}

use Test::Simple tests => 4;

use Threads::Pool;

my @out : shared;

my $test = sub {

	my $arg = shift;
	push( @out, $arg );

};

my @arg; 
push( @arg, '1' );

my $pool = Threads::Pool->getInstance( 1, $test, 0.1 );         		# test if we can create an object
ok( defined $pool, 'getInstance returned an instance'  );                	# check that we got something
ok( $pool->isa('Threads::Pool'), 'and it\'s the right type' );     		# and it's the right class
$pool->addToTheQueue( \@arg );
select( undef, undef, undef, 0.2 );
ok( $out[ 0 ] eq '1', 'and it does what it has' );				# and it works correctly
$pool->destroy();
ok( $pool->addToTheQueue( \@arg ) ? 0 : 1, 'and the destroier works' );		# and that the destroier makes the pool unusable
