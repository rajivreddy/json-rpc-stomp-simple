package JSON::RPC::Simple::StompClient;

use strict;
use Net::Stomp;
use JSON::RPC::Simple::Common;

BEGIN {
   use Exporter   ();
   our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

   # set the version for version checking
   $VERSION     = 1.01;
   # if using RCS/CVS, this may be preferred
   $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;

   @ISA         = qw(Exporter);
   @EXPORT      = qw(&json_rpc_stomp_init &json_rpc_call);
   %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

   # your exported package globals go here,
   # as well as any optionally exported functions
   @EXPORT_OK   = qw();
}
our @EXPORT_OK;

our $stomp = undef;
our $queuename = undef;
our $defsubopt = {
		'ack'=>'auto',
		'activemq.prefetchSize' => 10,
		'activemq.dispatchAsync' => 'false'};

END {
	$stomp->disconnect() if ($stomp);
}

sub json_rpc_stomp_init {
	my ($stompserver,$connopt,$subopt) = @_;
	$queuename = 'client'.$$.'.'.rand(100000);
	my $opt = { %{$defsubopt},
		'destination' => '/temp-queue/'.$queuename,
	};
	if (ref($subopt) eq 'HASH') {
		$opt->{$_} = $subopt->{$_} foreach (keys %{$subopt});
	}
	return undef unless($stompserver =~ m|^(tcp://)?([\w\.\-]+):(\d+)\??.*$|);
	#warn "Server $2:$3";
	$stomp = Net::Stomp->new( { hostname => $2, port => $3 } );
	$connopt = { } unless ($connopt);
    $stomp->connect($connopt)
	and $stomp->subscribe($opt)
	and return 1;
	return undef;
}

sub json_rpc_call {
	my ($queue,$method, $params,$nosetid,$persistent) = @_;
	return undef unless ($queue && $method);

	my $id = undef;
	$id = 'call'.$$.'.'.scalar(time()).'.'.int(rand()*100000)
		unless($nosetid);

	my $request = json_rpc_create_request($method,$params,$id);

	return undef unless ($request);

	print STDERR "Sending request: ".$request."\n" if($json_rpc_debug);
	$stomp->send(
		{
		    'destination' => "/queue/$queue",
		    'body' => $request,
		    'reply-to' => "/temp-queue/$queuename"} );

	#Now wait for reply, blocked mode.
	my $msg;
	if($json_rpc_call_timeout) {
			print STDERR "Call $method with timeout $json_rpc_call_timeout\n" if($json_rpc_debug);
			unless($stomp->can_read({ timeout => $json_rpc_call_timeout })) {
					print STDERR "Call $method timeout\n" if($json_rpc_debug);
					$json_rpc_error = JSON::RPC::Simple::Common::JSON_RPC_ERR_CALL_TIMEOUT;
					return undef;
			}
	}
	$msg = $stomp->receive_frame();
	if ($msg) {
			print STDERR "Reply: ".$msg->body."\n" if($json_rpc_debug);
			my $response = json_rpc_parse_response($msg->body,$id);
			return undef unless ($response);
			return $response;
	}
	$json_rpc_error = JSON::RPC::Simple::Common::JSON_RPC_ERR_CALL_RECEIVE;
	return undef;
}

1;
