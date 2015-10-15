Changes for PHP (on 23th Dec 2012):
  * Fixed with login/passcode
  * Upgrade to use json\_decode and json\_encode of PHP5.2, remove JSON.php completely.

Changes (on 22th Jan 2010):
  * JSONRPC 2.0 now is default.
  * Add debug flag to supress debug message.
  * Add support of call time out (Perl, require Net::Stomp 0.39 or more. 0.38 is buggy).
  * Add connection option (login, passcode ...)

Change (on 19th Nov 2010): added support JSONRPC 2.0 (optional).

This is an implementation of JSON-RPC 1.1/2.0 over Stomp protocol in Perl and PHP. It's designed to work with ActiveMQ version 5.2 or more (mainly).

It works very fast, synchronous or asynchronous. It provides reliable RPC call. I use it for both PHP and Perl, PHP is web front-end (presentation and form), makes call to the back-end Perl process (bussiness processing), connect to the Database (Oracle).

Helping by ActiveMQ infrastructure, you can make a completely high available, load balancing, distributed system.