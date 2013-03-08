#!/usr/bin/env perl

use Modern::Perl;
use Mojolicious::Lite;
use FindBin;
use utf8::all;
use IO::All;
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
my $search_terms = $env->{'search_terms'};

my $mango = Mango->new("mongodb://$db_user:$db_pass\@$db_host:$db_port");

get '/' => sub {
  my $self = shift;
  # Need sort
  my $cursor = $mango->db('fomo')->collection('links')->find()->limit(50);
  my @urls;
  while ( my $url = $cursor->next ) {
    push @urls, $url;
  }
  $self->stash(
    urls => \@urls,
    terms => $search_terms,
  );
  $self->render('index');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title "FoMo (Fear Of Missing Out): $terms";

%= $terms


<ul>
% for my $u ( @$urls ) {
% my $count = scalar @{ $u->{'tweets'} };
    <li><%= $u->{'title'} %>( <%= $count %> )</li>
% }
</ul>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>

