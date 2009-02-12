<?php
require_once("JSON.php"); #PHP version 5.1 or less.
$json = '{"jsonrpc": "2.0", "method": "subtract", "params": [23, 42], "id": 2}';
#$json = '{"jsonrpc": "2.0", "method": "subtract", "params": {"minuend": 42, "subtrahend": 23}, "id": 4}';

$j = new Services_JSON(SERVICES_JSON_LOOSE_TYPE | SERVICES_JSON_SUPPRESS_ERRORS);
$o = $j->decode($json);
var_dump($o);

print $j->encode($o);
?>

