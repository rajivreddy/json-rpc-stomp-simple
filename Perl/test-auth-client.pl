#!/usr/bin/perl
use strict;
use JSON::RPC::Simple::Common;
use JSON::RPC::Simple::StompClient;

json_rpc_stomp_init('localhost:61613');

my ($ret,$tokenid);
=cut
$ret = json_rpc_call('web.auth','WebLogin',{
	WEBUSER => 'test',
	WEBHASHPASS => 'ABCDEF',
	IP => '127.0.0.1',
	USERAGENT => 'Fedora Firefox',
	});

print "$json_rpc_error $json_rpc_errormsgdefine{$json_rpc_error} $json_rpc_errormsg\n" unless ($ret);
print "$ret->{result}, call-id:$ret->{id}\n";

sleep 60;
=cut
$tokenid = '3433074d8159d86d36f1bdd7f27e1fe7';
json_rpc_call('web.auth','WebLogout',{
	WEBUSER => 'test',
	TOKENID => $tokenid,
	});

