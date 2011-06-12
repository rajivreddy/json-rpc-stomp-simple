package JSON::RPC::Simple::StompServer;

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
	my ($stompserver,$queuename,$connopt,$subopt) = @_;
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
	$connopt = { } unless ($connopt);
    $stomp->connect($connopt)
	and $stomp->subscribe($opt)
	and return 1;
	return undef;
}

sub json_rpc_stomp_handle_callback {
	my ($stompserver,$queuename,$dispatchfunc,$connopt,$subopt,$idle_proc) = @_;

	return undef unless(defined($dispatchfunc) && ref($dispatchfunc) eq 'CODE'); # CODE

	unless(json_rpc_stomp_init($stompserver,$queuename,$connopt,$subopt)) {
		warn "Can not create connection";
		return undef;
	}

	while (1) {
		if($json_rpc_call_timeout) {
			unless($stomp->can_read({ timeout => $json_rpc_call_timeout })) {
					print STDERR "Wait for request timeout, run idle proc.\n" if($json_rpc_debug);
					&{$idle_proc} if($idle_proc && ref($idle_proc) eq 'CODE');
				next;
			}
		}
		my $msg = $stomp->receive_frame();

		last if(!$msg);
		next if($msg->{command} ne 'MESSAGE');

		if ($msg->headers->{'reply-to'}) {
			my $response = undef;
			print STDERR "Request from:". $msg->headers->{'reply-to'}.":". $msg->body."\n" if($json_rpc_debug);
			my $request = json_rpc_parse_request($msg->body);
			if(defined($request) && $request->{'method'}) { #call

				my ($retval,$error,$errormsg) = &{$dispatchfunc}($request->{'method'},$request->{'params'},$request->{'id'});
				$response = json_rpc_create_response($retval,
					($error ? json_rpc_create_error($error,$errormsg):undef),$request->{'id'});
				print STDERR "Got reply: $response\n" if($json_rpc_debug);

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
	my ($stompserver,$queuename,$hashfunc,$connopt,$subopt,$idle_proc) = @_;

	return undef unless(defined($hashfunc) && ref($hashfunc) eq 'HASH'); # HASH of CODE

	my $callback = sub {
		my ($method,$params,$id) = @_;

		my ($retval,$error,$errormsg);
		$retval = undef;
		if (!defined($hashfunc->{$method})
			|| ref($hashfunc->{$method}) ne 'CODE' ) { #No function
			$error = JSON::RPC::Simple::Common::JSON_RPC_ERR_INVALID_FUNCTION;
			$errormsg = "Function $method not found";

		} else {
			($retval,$error,$errormsg) = &{$hashfunc->{$method}}(@{$params});
			if($error) {
				$errormsg .= $error;
				$error = JSON::RPC::Simple::Common::JSON_RPC_ERR_APPLICATION_ERROR;
			}
		}
		return ($retval,$error,$errormsg);
	};

	return json_rpc_stomp_handle_callback($stompserver,$queuename,$callback,$connopt,$subopt,$idle_proc);
}

sub json_rpc_stomp_handle {
	my ($stompserver,$queuename,$module,$funclist,$connopt,$subopt,$idle_proc) = @_;

	$module = 'main' unless($module);
	my %f;
	%f = map { $_ => 1 } split(/[,\s\;]/,$funclist) if(defined($funclist));

	my $callback = sub {
		my ($method,$params,$id) = @_;

		my ($retval,$error,$errormsg);
		$retval = undef;
		if (!defined($f{$method})) {
			return (undef,JSON::RPC::Simple::Common::JSON_RPC_ERR_UNLISTED_FUNCTION,"Function $method unlisted");
		}

		if(@{$params}) {
			$retval = eval ($module.'::'.$method.'(@{$params})');
		}
		else {
			$retval = eval ($module.'::'.$method.'();');
		}
		return ($retval,$error,$errormsg);
	};

	return json_rpc_stomp_handle_callback($stompserver,$queuename,$callback,$connopt,$subopt,$idle_proc);
}

1;
