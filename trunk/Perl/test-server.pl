#!/usr/bin/perl
use strict;
use JSON::RPC::Simple::StompServer;


json_rpc_stomp_handle_hashcode('localhost:61613','jsonrpc',
{
	'Test' => \&Test,
	'subtract' => \&subtract } );

sub Test {
	print 'Param: '.join(',',@_)."\n";
	return [ @_ ];
}

sub subtract {
	my ($a,$b) = @_;
	return ($a-$b);
}
