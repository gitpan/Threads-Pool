package Threads::Pool;

#    ©2013 - Francesco Serra fn.serra@gmail.com
#    ©2013 - Frozen Stone Dev.
# 
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#    API to get a Pool of reusable threads
#

=pod

=head1 NAME

C<Threads::Pool> - API to get a Pool of reusable threads

=head1 SYNOPSIS

	my $pool = Threads::Pool->getInstance( [[NUMBER OF THREADS, SUB CODEREF], WAIT SECONDS] );
	$pool->addToTheQueue( \@array );
	$pool->destroy();

=head1 DESCRIPTION

This class instances a pool of reusable threads, gives them a task, and then adds to a shared queue any $obj you want to give them to evaluate. 
Your $obj MUST be shareable ( look for which kinds are allowed in perl's documentation ) and shared before being added to the queue, or at least 
serialized, so that you can then deserialize it inside the SUB CODEREF you supplied, and put in an ARRAYREF ( mandatory ).
You must also supply the number of threads you want to be run inside the pool at creation time.
Optionally you can give a wait time for the threads to wait between executions of the coderef, defaults to 0.3 seconds.

You can call the pool's instance from wherever in your code, passing as argument always the same CODEREF, as it's a static member of this class; 
once the instance is created, every attempt to recreate it will just be ignored, so you need to destroy it ( via ->destroy() ) before doing it.

The pool can't give you any assurance that all the threads will get their jobs finished before exiting the main program, so you MUST ensure that they'll 
have enough time to run ( if you care ). It's thus advisable that you destroy() the pool when you're done. Otherwise perl will most probably complain
that you still have running threads while exiting ( mostly if you've got more than a pool at once in the same scope, as the reference are statically
kept by the class itself, so that no automagic cleanup method will be invoked ), although the pool will do its best to kill them beforehand.

Requires at least Perl 5.8.0 and the support to ithreads, with the presence of the threads and threads::shared modules.

=head1 METHODS

=head2 C<getInstance( [[NUMBER OF THREADS, SUB CODEREF], WAIT SECONDS] )>

This method returns the pool's instance, if already created, or creates it with arguments you pass;

=head2 C<addToTheQueue( $obj )>

This method lets you add the args you want to be passed to the coderef by the threads. This must be an ARRAYREF to a previously SHARED array.

=head2 C<destroy()>

This method destroys the pool's instance, waiting for all the threads to have their jobs done.

=cut

use strict;
use threads;
use threads::shared;
use Carp;
use 5.8.0;

our $VERSION = 0.6;

my %instance;									####### Global instance which will be returned every time the constructor's called

### Private method : this is the 'core' of each thread
my $_threadRun = sub {

	my $job = shift;
	my $queue = shift;
	my $waitTime = shift;
	my $sem = shift;

	my $ON_THREAD_DESTROY = 0;

	local $SIG{'KILL'} = sub { $ON_THREAD_DESTROY = 1; };

        while ( ! $ON_THREAD_DESTROY && ! ${ $sem } ) {

                if ( ( @{ $queue } ) && ( scalar( @{ $queue } ) > 0 ) ) {

			my $item;

                        {

                                lock( $queue );
                                $item = shift @{ $queue };

                        }

			if ( defined( $item ) ) {

                        	$job->( @{ $item } );

                	}

                }

                select( undef, undef, undef, $waitTime );
		threads->yield();

        }

	return;

};

my $usage = q/Usage: $obj = Threads::Pool->getInstance( [[<number_of_threads_you_want>, \&coderef_to_execute], thread_wait_time] )/;

### Constructor/Singleton as pool manager
#   This is the only method provided to access the pool. The very first time, you must give the number of threads to be run, and the CODEREF 
#   you want them to run

sub getInstance() {

	my $job;

	if ( scalar( @_ ) > 0 ) {

		$job = $_[ 2 ] or croak "$usage";					####### Trick to get the $job identifier

	}

	unless ( defined( $instance{ $job } ) ) {                     			####### This won't let the class complain if you try to pass 
											####### a new number of threads to the constructor
		my $class = shift;
		my $numberOfThreads = shift or croak "$usage";
                croak "$usage" unless ( $numberOfThreads =~ m/^\d+$/ );         	####### Let's make sure we got the right arguments

                $job = shift or croak "$usage";
                croak "$usage" unless ( ref( $job ) eq 'CODE' );                	####### Let's make sure we got the right arguments
		
                my $waitTime = shift || '0.3';                                  	####### 0.3 seconds sounds a fair wait time for a few threads.
                                                                                	####### If you've got more work to do, decrease it.
                croak "$usage" unless ( $waitTime =~ /^[-]?\d+(?:[.]\d+)?$/ );  	####### Let's make sure we got the right arguments

		$instance{ $job } = bless {}, $class;

		my @queue : shared;
		my $sem : shared = 0;

		$instance{ $job }->{ job } = $job;
		$instance{ $job }->{ pool } = [];
		$instance{ $job }->{ queue } = \@queue;
		$instance{ $job }->{ sem } = \$sem;					###### Add a semaphore, just in case signaling is not functional
		
		for ( my $i = 0 ; $i < $numberOfThreads ; ++$i ) {

			$instance{ $job }->{ pool }->[ $i ] =				####### Keep a reference to the created threads, so we can turn 
				threads->create( 					####### them off later...
							$_threadRun, 
							$job, 
							$instance{ $job }->{ queue }, 		 
							$waitTime,
							\$sem
						); 				

		}

	}

	return $instance{ $job };

}

### End of constructor

### This method adds an argument for the task accomplished by threads to the internal queue of the pool. Everytime something gets 
### added, a thread will pick it up.
### It requires that the argument be an ARRAYREF to a previously shared ARRAY as that's gonna work as input to the task of each thread
### 
sub addToTheQueue( $ ) {

	my $self = shift;

	unless ( defined( $instance{ $self->{ job } } ) ) {

		carp "You're trying to add something to an empty instance!";
		return;

	}

	my $item = shift || croak "You have to give your argument!";

	unless ( ref( $item ) eq 'ARRAY' ) {

		croak "Your argument must be a ref to an array!";

	}

	my @local_array : shared = @{ $item };

	if ( scalar( @local_array ) > 0 ) {

		lock( $self->{ queue } );
		push( @{ $self->{ queue } }, \@local_array );

	} else {

		carp "Your argument cannot be empty!";

	}

	return;

}

sub destroy() {

	my $self = shift;

	local $@;

	while ( my $t = shift @{ $self->{ pool } } ) {

		eval {

			$t->kill('KILL');						####### Sending the KILL signal to the threads
			$t->join();

		};

		if ( $@ ) {

			$t->detach();							####### Will detach, if we couldn't signal

		}

	}

	${ $self->{ sem } } = 1;                                                        ####### We should be able to manually adjust everything...

	eval {

		$self->{ pool } = undef if exists( $self->{ pool } ); 

	};

	eval {
	
		$instance{ $self->{ job } } = undef if exists( $instance{ $self->{ job } } );		####### from now on, you're on your own.

	};

	carp "Unable to free resources: during global destruction?" if $@;

	return;

}


sub DESTROY {

	my $self = shift;
	
	local $@;

	for ( @{ $self->{ pool } } ) {
											
		eval {
											####### Just make sure everything gets tidy up before leaving
			$_->kill('KILL');						####### if we make to catch up before the instance is gone. Note that this will
											####### be invoked only when every reference contained in the class will be
											####### destroied. Otherwise, perl will probably complain that you
		};									####### still have running threads while exiting

		eval {

			$_->detach();							####### Try to detach, as last resort, if ever needed.
		
		};
											
	}									

	return;

}


1;

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Francesco Serra, fn.serra@gmail.com

Copyright 2013.

=cut
