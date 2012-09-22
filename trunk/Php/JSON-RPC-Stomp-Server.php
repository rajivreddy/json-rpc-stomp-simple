<?php

require_once("JSON-RPC-Common.php");
require_once("Stomp.php");
$json_rpc_stompconn = null;
$json_rpc_rpcqueue = '';

function json_rpc_stomp_handle($stompserver,$queuename, $funclist, ,$connopt = null, $subopt = null) {
	global $json_rpc_error,$json_rpc_errormsg,$json_rpc_stompconn,$json_rpc_rpcqueue;
	$opt = array('ack'=>'auto','activemq.prefetchSize' => 10,
		'activemq.dispatchAsync' => 'false' );
	if (is_array($subopt))
		$opt = array_merge($opt,$supoption);
	$json_rpc_stompconn = new StompConnection($stompserver);
	// connect
	if(!$json_rpc_stompconn->connect($connopt['login'],$connopt['passcode'])) {
		$json_rpc_error = JSON_RPC_ERR_CONNECT_TRANSPORT;
		$json_rpc_errormsg = $json_rpc_stompconn->error . "\n" .$json_rpc_stompconn->exception;
		return false;
	}
	if (!$json_rpc_stompconn->subscribe("/queue/$queuename",$opt)) {
		$json_rpc_error = JSON_RPC_ERR_INIT_TRANSPORT;
		$json_rpc_errormsg = $json_rpc_stompconn->error . "\n" .$json_rpc_stompconn->exception;
		return false;
	}
	register_shutdown_function("json_rpc_stomp_server_destroy");
	$json_rpc_rpcqueue = $queuename;
	while(1) {
		$msg = $json_rpc_stompconn->readFrame();
		if (isset($msg) && $msg === false)
			break;
		if (!is_object($msg) || $msg->command != 'MESSAGE')
			continue;
		if (!empty($msg->headers['reply-to'])) {
			//&& preg_match('/^\/temp-queue\//i',$msg->headers['reply-to'])) { // la loi goi ham
			error_log("Request from:". $msg->headers['reply-to'].": $msg->body",0);
			$retval = json_rpc_handle_msg($funclist,$msg->body);
			if(!empty($retval)) { //reply
				error_log("Got reply: $retval",0);
				$json_rpc_stompconn->send($msg->headers['reply-to'], $retval);
			}
		} else {
			error_log("Invalid RPC message:",0);
			var_dump($msg);
		}
	}
}

function json_rpc_stomp_server_destroy() {
	global $json_rpc_stompconn,$json_rpc_rpcqueue;
	error_log("Exiting...",0);
	if (!isset($json_rpc_stompconn))
		return;
	$json_rpc_stompconn->unsubscribe("/queue/$json_rpc_rpcqueue");
	$json_rpc_stompconn->disconnect();
	$json_rpc_stompconn = null;
	$json_rpc_rpcqueue = '';
}
?>
