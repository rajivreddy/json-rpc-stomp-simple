<?php

require_once("JSON-RPC-Common.php");
require_once("Stomp.php");
$json_rpc_stompserver = '';
$json_rpc_stompconn = null;
$json_rpc_tempqueue = '';
$json_rpc_call_timeout = 10;
$json_rpc_opt = null;

function json_rpc_stomp_init($server = '',$connopt = null, $subopt = null) {
	global $json_rpc_opt,$json_rpc_error,$json_rpc_errormsg,$json_rpc_stompconn,$json_rpc_tempqueue;
	$opt = array('ack'=>'client', //See Work around.
		'activemq.prefetchSize' => 1,
		'activemq.dispatchAsync' => 'true' );
	if ($json_rpc_stompconn)
		$json_rpc_stompconn->disconnect();
	if (is_array($subopt))
		$opt = array_merge($opt,$supopt);
	$json_rpc_opt = $opt;
	if(empty($server))
		$server = $json_rpc_stompserver;
	$json_rpc_stompconn = new StompConnection($server);
	// connect
	if(!$json_rpc_stompconn->connect($connopt['login'],$connopt['passcode'])) {
		$json_rpc_error = JSON_RPC_ERR_CONNECT_TRANSPORT;
		$json_rpc_errormsg = $json_rpc_stompconn->error . "\n" .$json_rpc_stompconn->exception;
		return false;
	}
	//Automatic generate tempqueue name;
	$json_rpc_tempqueue = uniqid('client');
	if (!$json_rpc_stompconn->subscribe("/temp-queue/$json_rpc_tempqueue",$opt)) {
		$json_rpc_error = JSON_RPC_ERR_INIT_TRANSPORT;
		$json_rpc_errormsg = $json_rpc_stompconn->error . "\n" .$json_rpc_stompconn->exception;
		return false;
	}
	register_shutdown_function('json_rpc_stomp_destroy');
	return true;
}

function json_rpc_call($queue,$method, $params,$setid = true,$persistent = false) {
	global $json_rpc_opt,$json_rpc_stompconn,$json_rpc_tempqueue,$json_rpc_error,$json_rpc_call_timeout;
	if (empty($queue)) {
		$json_rpc_error = JSON_RPC_ERR_CALL_NULL_ENDPOINT;
		return null;
	}
	if(empty($method)) {
		$json_rpc_error = JSON_RPC_ERR_CALL_METHOD;
		return null;
	}
	$id = null;
	if($setid)
		$id = uniqid('call');
	$request = json_rpc_create_request($method,$params,$id);
	if ($request == null) {
		$json_rpc_error = JSON_RPC_ERR_INVALID_REQUEST;
		return null;
	}
	if (!isset($json_rpc_stompconn)){
		$json_rpc_error = JSON_RPC_ERR_CALL_NULL_TRANSPORT;
		return null;
	}
	//trigger_error("Sending request: ".$request);
	if (!$json_rpc_stompconn->send("/queue/$queue",
	$request,array( 'reply-to' => "/temp-queue/$json_rpc_tempqueue",true))) {
		$json_rpc_error = JSON_RPC_ERR_CALL_SEND;
		$json_rpc_errormsg = $json_rpc_stompconn->error ."\n".$json_rpc_stompconn->exception;
		return null;
	}
	//Now wait for reply, blocked mode.
	$msg = $json_rpc_stompconn->readFrame(true,$json_rpc_call_timeout);
	//Work around: Hang while waiting for receipt.
	//slower, but stable.
	//ack mode must be client.
	if(isset($msg) && $json_rpc_opt['ack'] == 'client')
		$json_rpc_stompconn->ack($msg);
	if (is_object($msg)) {
		//trigger_error("Reply: ".$msg->body);
		$response = json_rpc_parse_response($msg->body,$id);
		if (!isset($response))
			return null;
		return $response;
	} else {
		if ($msg == null) {
			$json_rpc_error = JSON_RPC_ERR_CALL_TIMEOUT;
			trigger_error("Timed out");
		} else
			$json_rpc_error = JSON_RPC_ERR_CALL_RECEIVE;
		return null;
	}
}

function json_rpc_stomp_destroy() {
	global $json_rpc_stompconn,$json_rpc_tempqueue;
	if (isset($json_rpc_stompconn)) {
		$json_rpc_stompconn->unsubscribe("/temp-queue/$json_rpc_tempqueue");
		$json_rpc_stompconn->disconnect();
	}
	$json_rpc_stompconn = null;
	$json_rpc_tempqueue = '';
	//error_log("Exiting...",0);
}

?>
