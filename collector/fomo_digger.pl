#!/usr/bin/env perl 

use Modern::Perl;
use FindBin;
use utf8::all;
use IO::All;
use Net::Twitter;
use Data::Dumper;
use JSON;
use Mango;

# TODO Switch to DotCloud::Environment
my $local_dev  = "$FindBin::Bin/../environment.json";
my $remote_dev = '/home/dotcloud/environment.json';
my $environment = do { -e $remote_dev ? $remote_dev : $local_dev };

# TODO Switch to Mojo::Plugin::JSONConfig
# For now, override with the environment.json if it exists
my $json < io $environment;
my $env     = decode_json( $json );
my $db_user = $env->{'DOTCLOUD_DB_MONGODB_LOGIN'};
my $db_pass = $env->{'DOTCLOUD_DB_MONGODB_PASSWORD'};
my $db_host = $env->{'DOTCLOUD_DB_MONGODB_HOST'};
my $db_port = $env->{'DOTCLOUD_DB_MONGODB_PORT'};
my $tw_username = $env->{'tw_username'};
my $tw_password = $env->{'tw_password'};
my $search_terms = $env->{'search_terms'};
my $db_name      = $env->{'db_name'};

# Find old tweets
my $nt = Net::Twitter->new( traits => [qw/API::Search API::REST/] );
my @results;
for ( my $i = 1; $i <= 15; $i++ ) {
    my $r = $nt->search(
        $search_terms,
        {   rpp  => 100,
            page => $i,
            include_entities => 'true',
        }
    );

    if ( @{ $r->{'results'} } ) {
        push @results, @{ $r->{'results'} };
    }
};
# Debugging
say 'Got ' . scalar @results . ' results';

# Find or add
my $mango = Mango->new("mongodb://$db_user:$db_pass\@$db_host:$db_port");
for my $tweet ( reverse @results ) { 
   # Do we have this Tweet? 
   my $result = $mango->db( $db_name )->collection('tweets')->find_one({ id_str => $tweet->{'id_str'}});
   # Debugging
   say "Already had it" if $result;
   #say Dumper( $result );
   # If $result isn't defined, we should add the Tweet
   next if defined $result;
   my $oid = $mango->db( $db_name )->collection('tweets')->insert( $tweet );
   # Debugging
   say 'Added a new record with ObjectId ' . $oid;
};
