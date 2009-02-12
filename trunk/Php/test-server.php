<?php
	require_once("JSON-RPC-Stomp-Server.php");
	//error_reporting(E_ALL);
	error_reporting(E_ERROR | E_WARNING | E_PARSE);

function subtract($a,$b) {
	global $json_rpc_current_request_id;
	print "$json_rpc_current_request_id: subtract($a,$b)\n";
	//sleep(1);
	usleep(700);
	if (is_array($a)) {
		print_r($a);
		return array('a' => $a['subtrahend'], 'b' => $a['minuend'],
			'result' => ($a['subtrahend'] - $a['minuend']));
	}
	else {
		if ($a == 0)
			throw new Exception('a must be non-zero.');
		return array('a' => $a, 'b' => $b, 'result' => ($a - $b));
	}
}

function add($a,$b) {
	global $json_rpc_current_request_id;
	print "$json_rpc_current_request_id: add($a,$b)\n";
	//sleep(1);
	//sleep(5);
	if (is_array($a)) {
		print_r($a);
		return array('a' => $a['a'], 'b' => $a['b'],
			'result' => ($a['a'] + $a['b']));
	}
	else {
		return array('a' => $a, 'b' => $b, 'result' => ($a + $b));
	}
}
	if(!json_rpc_stomp_handle("tcp://10.36.14.205:61613","jsonrpc",
		array(
			'add' => 'a:int,b:int',
			'subtract' => 'a:int,b:int' ) ))
		die("Error: $json_rpc_error ($json_rpc_errormsg ${json_rpc_errormsgdefine[$json_rpc_error]})\n");

?>
