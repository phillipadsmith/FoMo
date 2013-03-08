#!/usr/bin/env perl

use Modern::Perl;
use FindBin;
use utf8::all;
use IO::All;
use JSON;
use Net::Twitter::Stream;
use Mango;
use Data::Dumper;


my $local_dev  = "$FindBin::Bin/../environment.json";
my $remote_dev = '/home/dotcloud/environment.json';

my $environment = do { -e $remote_dev ? $remote_dev : $local_dev };

# Override with the environment.json if it exists
my $json < io $environment;
my $env     = decode_json( $json );
my $db_user = $env->{'DOTCLOUD_DB_MONGODB_LOGIN'};
my $db_pass = $env->{'DOTCLOUD_DB_MONGODB_PASSWORD'};
my $db_host = $env->{'DOTCLOUD_DB_MONGODB_HOST'};
my $db_port = $env->{'DOTCLOUD_DB_MONGODB_PORT'};
my $tw_username = $env->{'tw_username'};
my $tw_password = $env->{'tw_password'};
my $stream_terms = $env->{'stream_terms'};
my $stream_users = $env->{'stream_users'};
my $db_name      = $env->{'db_name'};

#mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]

my $mango = Mango->new("mongodb://$db_user:$db_pass\@$db_host:$db_port");
 
Net::Twitter::Stream->new ( user => $tw_username, pass => $tw_password,
                            callback => \&_store_tweet,
                            track => $stream_terms,
                            follow => $stream_users
                            );
sub _store_tweet {
   my ( $tweet, $json ) = @_;   # a hash containing the tweet
                                # and the original json
   my $oid = $mango->db( $db_name )->collection('tweets')->insert( $tweet );
}
