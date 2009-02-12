package JSON::RPC::Simple::StompServer;

use strict;
use Net::Stomp;
use JSON::RPC::Simple::Common;

BEGIN {
   use Exporter   ();
   our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

   # set the version for version checking
   $VERSION     = 1.00;
   # if using RCS/CVS, this may be preferred
   $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;

   @ISA         = qw(Exporter);
   @EXPORT      = qw(&json_rpc_stomp_handle &json_rpc_stomp_handle_callback &json_rpc_stomp_handle_hashcode);
   %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

   # your exported package globals go here,
   # as well as any optionally exported functions
   @EXPORT_OK   = qw();
}
our @EXPORT_OK;

our $stomp = undef;
our $subqueuename = undef;
our $defsubopt = {
		'ack'=>'auto',
		'activemq.prefetchSize' => 10,
		'activemq.dispatchAsync' => 'false'};

END {
	if ($stomp) {
		$stomp->unsubscribe({ destination => $subqueuename }) if ($subqueuename);
		$stomp->disconnect();
	}
}

sub json_rpc_stomp_init {
	my ($stompserver,$queuename,$subopt) = @_;
	my $opt = { %{$defsubopt},
		'destination' => '/queue/'.$queuename,
	};
	$subqueuename = '/queue/'.$queuename;
	if (ref($subopt) eq 'HASH') {
		$opt->{$_} = $subopt->{$_} foreach (keys %{$subopt});
	}
	return undef unless($stompserver =~ m|^(tcp://)?([\w\.\-]+):(\d+)\??.*$|);
	#warn "Server $2:$3";
	$stomp = Net::Stomp->new( { hostname => $2, port => $3 } );
	$stomp->connect()
	and $stomp->subscribe($opt)
	and return 1;
	return undef;
}

sub json_rpc_stomp_handle_callback {
	my ($stompserver,$queuename, $dispatchfunc, $subopt) = @_;

	return undef unless(defined($dispatchfunc) && ref($dispatchfunc) eq 'CODE'); # CODE

	unless(json_rpc_stomp_init($stompserver,$queuename,$subopt)) {
		warn "Can not create connection";
		return undef;
	}

	while (1) {
		my $msg = $stomp->receive_frame();

		last if(!$msg);
		next if($msg->{command} ne 'MESSAGE');

		if ($msg->headers->{'reply-to'}) {
			my $response = undef;
			print STDERR "Request from:". $msg->headers->{'reply-to'}.":". $msg->body."\n";
			my $request = json_rpc_parse_request($msg->body);
			if(defined($request) && $request->{'method'}) { #call
				my ($retval,$error,$errormsg) = &{$dispatchfunc}($request->{'method'},$request->{'params'},$request->{'id'});
				$response = json_rpc_create_response($retval,
					($error ? json_rpc_create_error($error,$errormsg):undef),$request->{'id'});
				print STDERR "Got reply: $response\n";
			} elsif(defined($request) && $request->{'error'}) { #error
				$response = json_rpc_create_response(undef,$request->{'error'},$request->{'id'});
			}
			$response and $stomp->send({ destination => $msg->headers->{'reply-to'}, body => $response });
		} else {
			warn "Invalid RPC reply-to:".$msg->body;
		}
	}
	return 1;
}

sub json_rpc_stomp_handle_hashcode {
	my ($stompserver,$queuename, $hashfunc, $subopt) = @_;

	return undef unless(defined($hashfunc) && ref($hashfunc) eq 'HASH'); # HASH of CODE

	unless(json_rpc_stomp_init($stompserver,$queuename,$subopt)) {
		warn "Can not create connection";
		return undef;
	}

	while (1) {
		my $msg = $stomp->receive_frame();

		last if(!$msg);
		next if($msg->{command} ne 'MESSAGE');

		if ($msg->headers->{'reply-to'}) {
			my $response = undef;
			print STDERR "Request from:". $msg->headers->{'reply-to'}.":". $msg->body."\n";
			my $request = json_rpc_parse_request($msg->body);
			if(defined($request) && $request->{'method'}) { #call
				if (!defined($hashfunc->{$request->{'method'}})
					|| ref($hashfunc->{$request->{'method'}}) ne 'CODE' ) { #No function
					$response = json_rpc_create_response(undef,
						json_rpc_create_error(JSON::RPC::Simple::Common::JSON_RPC_ERR_INVALID_FUNCTION),$request->{'id'});
				} else {
					my ($retval,$error,$errormsg) = &{$hashfunc->{$request->{'method'}}}(@{$request->{'params'}});
					$response = json_rpc_create_response($retval,
						($error ? json_rpc_create_error($error,$errormsg):undef),$request->{'id'});
					print STDERR "Got reply: $response\n";
				}
			} elsif(defined($request) && $request->{'error'}) { #error
				$response = json_rpc_create_response(undef,$request->{'error'},$request->{'id'});
			}
			$response and $stomp->send({ destination => $msg->headers->{'reply-to'}, body => $response });
		} else {
			warn "Invalid RPC reply-to:".$msg->body;
		}
	}
	return 1;
}

sub json_rpc_stomp_handle {
	my ($stompserver,$queuename, $module,$funclist, $subopt) = @_;
	unless(json_rpc_stomp_init($stompserver,$queuename,$subopt)) {
		warn "Can not create connection";
		return undef;
	}

	while (1) {
		my $msg = $stomp->receive_frame();

		last if(!$msg);
		next if($msg->{command} ne 'MESSAGE');

		if ($msg->headers->{'reply-to'}) {
			print STDERR "Request from:". $msg->headers->{'reply-to'}.":". $msg->body."\n";
			my $retval = json_rpc_handle_msg($module,$funclist,$msg->body);
			if(defined($retval)) { #//reply
				print STDERR "Got reply: $retval\n";
				$stomp->send({ destination => $msg->headers->{'reply-to'}, body => $retval });
			}
		} else {
			warn "Invalid RPC Invalid RPC reply-to:".$msg->body;
		}
	}
	warn "Return";
	return 1;
}

1;
