#!/usr/bin/perl
use strict;
use JSON::RPC::Simple::Common;
use JSON::RPC::Simple::StompClient;

json_rpc_stomp_init('localhost:61613');

for (1..2) {
my $ret = json_rpc_call('jsonrpc','subtract',[52,49]);

print "$json_rpc_error $json_rpc_errormsgdefine{$json_rpc_error} $json_rpc_errormsg\n" unless ($ret);
print "$ret->{result}, call-id:$ret->{id}\n";
}
