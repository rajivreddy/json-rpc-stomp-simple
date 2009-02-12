<?php
	require_once("JSON-RPC-Stomp-Client.php");
	error_reporting(E_ERROR | E_WARNING | E_PARSE);
	//error_reporting(E_ALL);
	if(!json_rpc_stomp_init("tcp://localhost:61613"))
		die("Error: $json_rpc_error ($json_rpc_errormsg ${json_rpc_errormsgdefine[$json_rpc_error]})\n");
$start = time();
for ($i = 0; $i < 1; $i++) {
	$ret = json_rpc_call("jsonrpc","subtract",
		array($i,5) );
	if ($ret == null) {
		print "Error: $json_rpc_error ($json_rpc_errormsg ${json_rpc_errormsgdefine[$json_rpc_error]})\n";
	}
	else {
		print "Result:\n";
		var_dump($ret);
	}
}
$stop = time();
echo "Run time: ".($stop-$start)."\n";
?>
