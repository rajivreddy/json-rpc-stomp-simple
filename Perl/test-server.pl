#!/usr/bin/perl
use strict;
use JSON::RPC::Simple::Common;
use JSON::RPC::Simple::StompServer;

$json_rpc_call_timeout = 20;
$json_rpc_debug = 1;

json_rpc_stomp_handle_hashcode('localhost:61613','jsonrpc',
{
	'Test' => \&Test,
	'subtract' => \&subtract },undef,undef,\&Idle);

sub Idle {
	print "Idle connection\n";
}

sub Test {
	print 'Param: '.join(',',@_)."\n";
	return [ @_ ];
}

sub subtract {
	my ($a,$b) = @_;
	return ($a-$b);
}
