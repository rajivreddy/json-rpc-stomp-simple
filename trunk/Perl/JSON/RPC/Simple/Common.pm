package JSON::RPC::Simple::Common;

use strict;
use warnings;
use JSON;

BEGIN {
   use Exporter   ();
   our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

   # set the version for version checking
   $VERSION     = 1.01;
   # if using RCS/CVS, this may be preferred
   $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;

   @ISA         = qw(Exporter);
   @EXPORT      = qw(
    $version $json_rpc_error $json_rpc_errormsg %json_rpc_errormsgdefine $json_rpc_debug
   	$json_rpc_current_request_id $json_rpc_current_response_id $json_rpc_secure_mode $json_rpc_call_timeout

    &json_rpc_create_error
   	&json_rpc_create_request &json_rpc_parse_request
   	&json_rpc_create_response &json_rpc_parse_response);
   %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

   # your exported package globals go here,
   # as well as any optionally exported functions
   @EXPORT_OK   = qw();
}
our @EXPORT_OK;

# exported package globals go here
our $version = '2.0';
our $versionstr = 'jsonrpc';
our $json_rpc_debug = 0;
our $json_rpc_error = 0;
our $json_rpc_call_timeout = 0;
our $json_rpc_errormsg = '';
our $json_rpc_current_request_id = '';
our $json_rpc_current_response_id = '';
our $json_rpc_secure_mode = 0;

use constant {
JSON_RPC_ERR_INVALID_REQUEST => 1,
JSON_RPC_ERR_INVALID_VERSION => 2,
JSON_RPC_ERR_INVALID_FUNCTION => 3,
JSON_RPC_ERR_INVALID_METHODNAME => 4,
JSON_RPC_ERR_UNLISTED_FUNCTION => 5,
JSON_RPC_ERR_INTERNAL_ERROR => 6,
JSON_RPC_ERR_INVALID_RESPONSE => 7,
JSON_RPC_ERR_REMOTE_ERROR => 8,
JSON_RPC_ERR_CONNECT_TRANSPORT => 9,
JSON_RPC_ERR_INIT_TRANSPORT => 10,
JSON_RPC_ERR_CALL_NULL_TRANSPORT => 11,
JSON_RPC_ERR_CALL_SEND => 12,
JSON_RPC_ERR_CALL_RECEIVE => 13,
JSON_RPC_ERR_CALL_TIMEOUT => 14,
JSON_RPC_ERR_CALL_METHOD => 15,
JSON_RPC_ERR_CALL_PARAM => 16,
JSON_RPC_ERR_INVALID_RESPONSEID => 17,
JSON_RPC_ERR_APPLICATION_ERROR => 255,
};

our %json_rpc_errormsgdefine = (
JSON_RPC_ERR_INVALID_REQUEST() => 'Invalid request',
JSON_RPC_ERR_INVALID_VERSION() => 'Invalid version',
JSON_RPC_ERR_INVALID_FUNCTION() => 'Invalid function',
JSON_RPC_ERR_INVALID_METHODNAME() => 'Invalid methodname',
JSON_RPC_ERR_UNLISTED_FUNCTION() => 'The function is not in function list.',
JSON_RPC_ERR_INTERNAL_ERROR() => 'Internal Error',
JSON_RPC_ERR_APPLICATION_ERROR() => 'Application error',
JSON_RPC_ERR_INVALID_RESPONSE() => 'Invalid Response',
JSON_RPC_ERR_CONNECT_TRANSPORT() => 'Transport Connecting failed or error',
JSON_RPC_ERR_INIT_TRANSPORT() => 'Transport Initiation failed or error',
JSON_RPC_ERR_CALL_NULL_TRANSPORT() => 'Transport for RPC call is null',
JSON_RPC_ERR_CALL_SEND() => 'Error while sending request.',
JSON_RPC_ERR_CALL_RECEIVE() => 'Error while receive response.',
JSON_RPC_ERR_CALL_TIMEOUT() => 'Time out while call function.',
JSON_RPC_ERR_CALL_METHOD() => 'Call method is not valid type.',
JSON_RPC_ERR_CALL_PARAM() => 'Call param is not valid type.',
JSON_RPC_ERR_INVALID_RESPONSEID() => 'Response ID is not same as requested ID',
JSON_RPC_ERR_REMOTE_ERROR() => 'Remote Server Error Returned Code'
);

sub json_rpc_set_version {
	my $v = shift;
	if($v eq '1.1') {
		$versionstr = 'version';
		$version = '1.1';
	} elsif($v eq '2.0') {
		$versionstr = 'jsonrpc';
		$version = '2.0';
	} else {
		return -1;
	}
	return 0;
}

sub json_rpc_create_error {
	my ($code,$msg) = @_;
	return {
        'name' => "JSONRPCError",
        'code' => $code,
        'message' => ($msg ? $msg : ($json_rpc_errormsgdefine{$code} ?
			$json_rpc_errormsgdefine{$code} : 'Unknown error code '.$code))
	};
}

sub json_rpc_create_request {
	my ($method,$params,$id) = @_;
	if (ref($method)) { #Method must be scalar.
		$json_rpc_error = JSON_RPC_ERR_CALL_METHOD;
		return undef;
	}
	if (ref($params) ne 'HASH' && ref($params) ne 'ARRAY') { #params must be array/object.
		$json_rpc_error = JSON_RPC_ERR_CALL_PARAM;
		$json_rpc_errormsg = "Param ".ref($params)." is not valid";
		return undef;
	}

	my $json = new JSON;
	my $request = $json->encode({
		$versionstr => $version,
		'method' => $method,
		'params' => $params,
		'id' => $id
		});
	return $request;
}

sub json_rpc_create_response {
	my ($result,$error,$id) = @_;

	$id = $json_rpc_current_request_id if(!defined($id) && $json_rpc_current_request_id);
	$error = undef if(defined($result));
	my $json = new JSON;
	return $json->encode({
		$versionstr => $version,
		'id' => $id,
		'result' => $result,
		'error' => $error
	});
}

sub json_rpc_parse_request {
	my $requestdata = shift;
	my	$json = new JSON;
	unless($requestdata) {
		return {
			'id' => undef,
			'method' => undef,
			'params' => undef,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_REQUEST)
		};
	}
	my $request = eval('$json->decode($requestdata)');

	($@ or !$request or ref($request) ne 'HASH')
		and return {
			'id' => undef,
			'method' => undef,
			'params' => undef,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_REQUEST,$@)
		};

	(!defined($request->{$versionstr}) or $request->{$versionstr} ne $version)
		and return {
			'id' => ($request->{'id'} or undef),
			'method' => undef,
			'params' => undef,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_VERSION)
		};
	(!$request->{'method'} || $request->{'method'} !~ /^[a-zA-Z]\w*$/)
		and return {
			'id' => ($request->{'id'} or undef),
			'method' => undef,
			'params' => undef,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_METHODNAME)
		};

	if (defined($request->{'params'})) {
		return {
			'id' => ($request->{'id'} or undef),
			'method' => $request->{'method'},
			'params' => $request->{'params'},
			'error' => undef,
		}
	}
	return {
		'id' => ($request->{'id'} or undef),
		'method' => $request->{'method'},
		'params' => undef,
		'error' => undef,
	};
}

sub json_rpc_parse_response {
	my ($responsedata,$requestid) = @_;

	my $json = new JSON;
	unless ($responsedata) { #empty message
		$json_rpc_error = JSON_RPC_ERR_INVALID_RESPONSE;
		return undef;
	}
	my $response = eval('$json->decode($responsedata)');
	if ($@ || !$response || ref($response) ne 'HASH') {
		$json_rpc_error = JSON_RPC_ERR_INVALID_RESPONSE;
		$json_rpc_errormsg = $@;
		return undef;
	}
	if (!defined($response->{$versionstr}) || $response->{$versionstr} ne $version) {
		$json_rpc_error = JSON_RPC_ERR_INVALID_VERSION;
		return undef;
	}
	if ($response->{'error'}) {
		if ($response->{'error'}->{'code'}) {
			$json_rpc_error = $response->{'error'}->{'code'};
			$json_rpc_errormsg = $response->{'error'}->{'message'};
		}
		else {
			$json_rpc_error = JSON_RPC_ERR_REMOTE_ERROR;
			$json_rpc_errormsg = $response->{'error'};
		}
		return undef;
	}
	if ($requestid && $response->{'id'} && $response->{'id'} ne $requestid) {
		$json_rpc_error = JSON_RPC_ERR_INVALID_RESPONSE;
		return undef;
	}


	return {
		result => $response->{'result'},
		id => $response->{'id'},
	};
}

1;
