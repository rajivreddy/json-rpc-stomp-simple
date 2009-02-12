<?php

/* JSON-RPC Client/Server Common Handle.
 * */

require_once("JSON.php"); #PHP version 5.1 or less.
$version = '1.1';
$json_rpc_error = 0;
$json_rpc_errormsg = '';
$json_rpc_current_request_id = '';
$json_rpc_current_response_id = '';
$json_rpc_secure_mode = 0;

$err_count = 1;
define("JSON_RPC_ERR_INVALID_REQUEST", $err_count++);
define("JSON_RPC_ERR_INVALID_VERSION", $err_count++);
define("JSON_RPC_ERR_INVALID_FUNCTION", $err_count++);
define("JSON_RPC_ERR_INVALID_METHODNAME", $err_count++);
define("JSON_RPC_ERR_UNLISTED_FUNCTION", $err_count++);
define("JSON_RPC_ERR_INTERNAL_ERROR", $err_count++);
define("JSON_RPC_ERR_INVALID_RESPONSE", $err_count++);
define("JSON_RPC_ERR_REMOTE_ERROR", $err_count++);
define("JSON_RPC_ERR_CONNECT_TRANSPORT", $err_count++);
define("JSON_RPC_ERR_INIT_TRANSPORT", $err_count++);
define("JSON_RPC_ERR_CALL_NULL_TRANSPORT", $err_count++);
define("JSON_RPC_ERR_CALL_SEND", $err_count++);
define("JSON_RPC_ERR_CALL_RECEIVE", $err_count++);
define("JSON_RPC_ERR_CALL_TIMEOUT", $err_count++);
define("JSON_RPC_ERR_CALL_METHOD", $err_count++);
define("JSON_RPC_ERR_CALL_PARAM", $err_count++);
define("JSON_RPC_ERR_INVALID_RESPONSEID", $err_count++);
define("JSON_RPC_ERR_APPLICATION_ERROR", 255);

$json_rpc_errormsgdefine = array(
JSON_RPC_ERR_INVALID_REQUEST => 'Invalid request',
JSON_RPC_ERR_INVALID_VERSION => 'Invalid version',
JSON_RPC_ERR_INVALID_FUNCTION => 'Invalid function',
JSON_RPC_ERR_INVALID_METHODNAME => 'Invalid methodname',
JSON_RPC_ERR_UNLISTED_FUNCTION => 'The function is not in function list.',
JSON_RPC_ERR_INTERNAL_ERROR => 'Internal Error',
JSON_RPC_ERR_APPLICATION_ERROR => 'Application error',
JSON_RPC_ERR_INVALID_RESPONSE => 'Invalid Response',
JSON_RPC_ERR_CONNECT_TRANSPORT=> 'Transport Connecting failed or error',
JSON_RPC_ERR_INIT_TRANSPORT => 'Transport Initiation failed or error',
JSON_RPC_ERR_CALL_NULL_TRANSPORT => 'Transport for RPC call is null',
JSON_RPC_ERR_CALL_SEND => 'Error while sending request.',
JSON_RPC_ERR_CALL_RECEIVE => 'Error while receive response.',
JSON_RPC_ERR_CALL_TIMEOUT => 'Time out while call function.',
JSON_RPC_ERR_CALL_METHOD => 'Call method is not valid type.',
JSON_RPC_ERR_CALL_PARAM => 'Call param is not valid type.',
JSON_RPC_ERR_INVALID_RESPONSEID => 'Response ID is not same as requested ID',
JSON_RPC_ERR_REMOTE_ERROR => 'Remote Server Error Returned Code'
);

function json_rpc_get_errstr() {
	global $json_rpc_error,$json_rpc_errormsg,$json_rpc_errormsgdefine;
	return "$json_rpc_error ($json_rpc_errormsg ${json_rpc_errormsgdefine[$json_rpc_error]})";
}

function json_rpc_create_error($code,$msg = '') {
	global $json_rpc_errormsgdefine;
	return array(
        'name' => "JSONRPCError",
        'code' => $code,
        'message' => (empty($msg) ? (empty($json_rpc_errormsgdefine[$code]) ? 'Unknown error code '.$code : $json_rpc_errormsgdefine[$code] )
			: $msg )
	);
}

function json_rpc_handle_msg($funclist,$requestdata) {
	global $version,$json_rpc_current_request_id;
	$json = new Services_JSON(SERVICES_JSON_LOOSE_TYPE | SERVICES_JSON_SUPPRESS_ERRORS);
	if (empty($requestdata))
		return $json->encode(array(
			'version' => $version,
			'id' => null,
			'result' => null,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_REQUEST)
		));
	$request = $json->decode($requestdata);
	if (empty($request) || !is_array($request))
		return $json->encode(array(
			'version' => $version,
			'id' => null,
			'result' => null,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_REQUEST)
		));
	if (empty($request['version']) || $request['version'] != $version)
		return $json->encode(array(
			'version' => $version,
			'id' => (empty($request['id']) ? null : $request['id']),
			'result' => null,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_VERSION)
		));
	if (empty($request['method']) || !preg_match('/^[a-zA-Z]\w*$/',$request['method']))
		return $json->encode(array(
			'version' => $version,
			'id' => (!empty($request['id']) ? $request['id'] : null),
			'result' => null,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_METHODNAME)
		));
	if(!empty($funclist) && empty($funclist[$request['method']]))
		return $json->encode(array(
			'version' => $version,
			'id' => (empty($request['id']) ? null : $request['id']),
			'result' => null,
			'error' => json_rpc_create_error(JSON_RPC_ERR_UNLISTED_FUNCTION)
	));

	if(!function_exists($request['method']))
		return $json->encode(array(
			'version' => $version,
			'id' => (empty($request['id']) ? null : $request['id']),
			'result' => null,
			'error' => json_rpc_create_error(JSON_RPC_ERR_INVALID_FUNCTION)
	));
	try {
		if (is_array($request['params'])) {
			if (!empty($request['id']))
				$json_rpc_current_request_id = $request['id']; //Assgin ID
			$keylist = array_keys($request['params']);
			if (is_numeric($keylist[0])) //Numeric
				$result = @call_user_func_array($request['method'],array_values($request['params']));
			else
				$result = @call_user_func($request['method'],$request['params']);
			$json_rpc_current_request_id = ''; //Remove ID
			if (!empty($request['id']))
				return $json->encode(array (
					'version' => $version,
					'id' => $request['id'],
					'result' => $result,
					'error' => NULL
				));
			else
				return '';
		}
		else {
			if (!empty($request['id']))
				$json_rpc_current_request_id = $request['id']; //Assgin ID
			$result = @call_user_func($request['method'],$request['params']);
			$json_rpc_current_request_id = ''; //Remove ID
			if (!empty($request['id']))
				return $json->encode(array(
					'version' => $version,
					'id' => $request['id'],
					'result' => $result,
					'error' => null
				));
			else
				return '';
		}
	} catch (Exception $e) {
		if (!empty($request['id']))
			return $json->encode(array (
				'version' => $version,
				'id' => $request['id'],
				'result' => null,
				'error' => json_rpc_create_error(JSON_RPC_ERR_APPLICATION_ERROR,$e->getMessage())
			));
		else {
			error_log('Notification Error:'.$e->getMessage(),0);
			return '';
		}
	}
	return $json->encode(array(
		'version' => $version,
		'id' => null,
		'result' => null,
		'error' => json_rpc_create_error(JSON_RPC_ERR_INTERNAL_ERROR)
	));
}

function json_rpc_create_request($method,$params,$id = null) {
	global $version,$json_rpc_error;
	if (!is_scalar($method)) { #Method must be scalar.
		$json_rpc_error = JSON_RPC_ERR_CALL_METHOD;
		return null;
	}
	if (!is_object($params) && !is_array($params)) { #params must be array/object.
		$json_rpc_error = JSON_RPC_ERR_CALL_PARAM;
		return null;
	}

	$json = new Services_JSON();
	$request = $json->encode(array(
		'version' => $version,
		'method' => $method,
		'params' => $params,
		'id' => $id
		));
	return $request;
}

function json_rpc_parse_response($responsedata,$requestid = null) {
	global $version,$json_rpc_error,$json_rpc_errormsg,$json_rpc_errormsgdefine,
		$json_rpc_current_response_id;
	$json = new Services_JSON(SERVICES_JSON_LOOSE_TYPE | SERVICES_JSON_SUPPRESS_ERRORS);
	if (empty($responsedata)) {//empty message
		$json_rpc_error = JSON_RPC_ERR_INVALID_RESPONSE;
		return null;
	}
	$response = $json->decode($responsedata);
	if (empty($response) || (!is_array($response) && !is_object($response))) {
		$json_rpc_error = JSON_RPC_ERR_INVALID_RESPONSE;
		return null;
	}
	if (empty($response['version']) || $response['version'] != $version) {
		$json_rpc_error = JSON_RPC_ERR_INVALID_VERSION;
		return null;
	}
	if (!empty($response['error'])) {
		if (!empty($response['error']['code'])) {
			$json_rpc_error = $response['error']['code'];
			$json_rpc_errormsg = $response['error']['message'];
		}
		else if (is_numeric($response['error'])) {
			$json_rpc_error = $response['error'];
			$json_rpc_errormsg = $json_rpc_errormsgdefine[JSON_RPC_ERR_REMOTE_ERROR];
		}
		else {
			$json_rpc_error = JSON_RPC_ERR_REMOTE_ERROR;
			$json_rpc_errormsg = $response['error'];
		}
		return null;
	}
	if (isset($requestid) && !empty($response['id']) && $response['id'] != $requestid) {
		$json_rpc_error = JSON_RPC_ERR_INVALID_RESPONSE;
		return null;
	}
	$json_rpc_current_response_id = $response['id'];

	return $response['result'];
}

?>
