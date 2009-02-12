<?php
require_once("JSON.php"); #PHP version 5.1 or less.
#$json = '{"version": "1.1", "method": "subtract", "params": [23, 42], "id": 2}';
#$json = '{"version": "1.1", "method": "subtract", "params": [99, 34], "id": 2}';
#$json = '{"version": "1.1", "method": "add", "params": [99, 34], "id": 3}';
#$json = '{"version": "1.1", "method": "subtract", "params": {"minuend": 42, "subtrahend": 23}, "id": 4}';

//error_reporting(E_ERROR | E_WARNING | E_PARSE);
error_reporting(E_ALL);
// include a library
require_once("Stomp.php");
// make a connection
$con = new StompConnection("tcp://localhost:61613");
// connect
$con->connect();
$con->subscribe("/temp-queue/clientreply",array('ack'=>'auto'));
$start = time();
$i = 33;
//for ($i = 0;$i<100;$i++) {
print "Sending request:";
print $con->send("/queue/jsonrpc",
	'{"version": "1.1", "method": "add", "params": ['.$i.', 2009], "id": '.($i+100).'}',
	array( 'reply-to' => '/temp-queue/clientreply' ))."\n";
//sleep(3);
$msg = $con->readFrame(true,10);
if (is_object($msg)) {
	print "Reply:\n";
	print $msg->body."\n";
} else {
	print "Time out or Error\n";
}
//}
/*print "Reply:\n";
for ($i = 0;$i<2;$i++) {
	$msg = $con->readFrame();
	print $msg->body."\n";
}*/
$stop = time();
echo "Run time: ".($stop-$start)."\n";
// disconnect
$con->disconnect();
?>

