#!/usr/bin/env perl

use Modern::Perl;
use FindBin;
use utf8::all;
use IO::All;
use JSON;
use Mango;
use Data::Dumper;
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;
$ua = $ua->max_redirects( 6 );

# TODO Switch to DotCloud::Environment
my $local_dev   = "$FindBin::Bin/../environment.json";
my $remote_dev  = '/home/dotcloud/environment.json';
my $environment = do { -e $remote_dev ? $remote_dev : $local_dev };

# TODO Switch to Mojo::Plugin::JSONConfig
# For now, override with the environment.json if it exists
my $json < io $environment;
my $env         = decode_json( $json );
my $db_user     = $env->{'DOTCLOUD_DB_MONGODB_LOGIN'};
my $db_pass     = $env->{'DOTCLOUD_DB_MONGODB_PASSWORD'};
my $db_host     = $env->{'DOTCLOUD_DB_MONGODB_HOST'};
my $db_port     = $env->{'DOTCLOUD_DB_MONGODB_PORT'};
my $db_name      = $env->{'db_name'};

#mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]
my $mango = Mango->new( "mongodb://$db_user:$db_pass\@$db_host:$db_port" );

# Find Tweets with URLs that haven't been extracted yet
my $results = $mango->db( $db_name )->collection( 'tweets' )->find(
    {   'extracted' => { '$nin' => ['1'] },
        'entities.urls.url' => { '$exists' => 'true' },
    }
)->all;

for my $tweet ( @$results ) {

    # Update the Tweet as having been extracted/processed
    my $tw_result
        = $mango->db( $db_name )->collection( 'tweets' )->update( 
            { _id => $tweet->{'_id'} },
            { '$set' => 
                { extracted => '1' } 
            }
        );

    # Fetch the URLs out of each tweet
    my $urls = $tweet->{'entities'}{'urls'};
    for my $url ( @$urls ) {
        my $u = $url->{'expanded_url'};           # Get the original URL
        $u = $ua->get( $u )->req->url->to_abs;    # Canonical
        my $r = $ua->get( $u )->res;              # Get the resource

        # Make sure we've got a response that is HTML
        if ( !$r->error && $r->headers->content_type =~ 'text/html' ) {
            
            # Look up URL
            my $query = { 'url' => $u, };
            my $url_obj = $mango->db( $db_name )->collection( 'links' )
                ->find_one( $query );

            # Do we have it already? If so, update with Tweet
            if ( $url_obj ) {
                # Debugging
                say $url_obj->{'title'};
                say $url_obj->{'url'};
                my $result
                    = $mango->db( $db_name )->collection( 'links' )->update(
                        { _id     => $url_obj->{'_id'} },
                        { 
                            '$push' => { tweets => $tweet },
                            '$inc'  => { tweet_count => 1 }, 
                        }
                    );
            }
            else {    # If not, let's add it
                my $title
                    = $r->dom->at( 'title' ) ? $r->dom->at( 'title' )->text
                    : $r->dom->at( 'h1' )    ? $r->dom->at( 'h1' )->text
                    :                          'No title found for URL';
                my $tweets = [];
                push @$tweets, $tweet;
                my $url_data = {
                    'url'    => $u,
                    'title'  => $title,
                    'tweets' => $tweets,
                    'tweet_count' => 1,
                };
                my $oid = $mango->db( $db_name )->collection( 'links' )
                    ->insert( $url_data );
                # Debugging
                say $u;
                say $title;
            }
        }
    }
};
