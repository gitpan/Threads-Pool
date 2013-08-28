BEGIN {

	use Config;

  	if (! $Config{'useithreads'}) {

		print("1..0 # Skip this test as Perl not compiled with 'useithreads'\n");
    		exit(0);
  
	}

}

use Test::Simple tests => 8;

use Threads::Pool;

my @out : shared;
my @out2 : shared;

my $test = sub {

	my $arg = shift;
	push( @out, $arg );

};

my $test2 = sub {

	my $arg = shift;
	push( @out2, $arg );

};

my @arg; 
push( @arg, '1' );

my $pool = Threads::Pool->getInstance( $test, 1, 0.1 );         		# test if we can create an object
my $pool_alt = Threads::Pool->getInstance( { code => $test2, threads => '1', wait => '0.1' } );

ok( defined $pool, 'getInstance returned an instance with positionalarguments'  );              # check that we got something
ok( defined $pool_alt, 'getInstance returned an instance passing an hash as argument' );	# check that we got something
ok( $pool->isa('Threads::Pool'), 'and it\'s the right type 1' );     				# and it's the right class
ok( $pool_alt->isa('Threads::Pool'), 'and it\'s the right type 2' );     				# and it's the right class
$pool->addToTheQueue( \@arg );
$pool_alt->addToTheQueue( \@arg );
select( undef, undef, undef, 0.2 );
ok( $out[ 0 ] eq '1', 'and it does what it has' );				# and it works correctly
ok( $out2[ 0 ] eq '1', 'and it does what it has' );				# and it works correctly
$pool->destroy();
$pool_alt->destroy();
ok( $pool->addToTheQueue( \@arg ) ? 0 : 1, 'and the destroier works' );		# and that the destroier makes the pool unusable
ok( $pool_alt->addToTheQueue( \@arg ) ? 0 : 1, 'and the destroier works' );		# and that the destroier makes the pool unusable
