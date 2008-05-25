<?
/*
PHP XML-RPC class

Copyright (C) 2008 Zbigniew Zolkiewski

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


/*##################################################

PHP XML-RPC clss for mod_xmlrpc
-------------------------------

Author: Zbyszek Zolkiewski (zbyszek@jabster.pl)
TEST VERSION, NOT ALL CALLS INCLUDED! THERE IS NO DOCUMENTATION YET.

Example:

$ejabberd_rpc = new rpc_connector("127.0.0.1","4666","test","123","example.com");


Test if RPC is working:

try {
	echo $ejabberd_rpc->test_rpc();
}
catch(Exception $e) {
	echo "Exception: ".$e->getMessage();
	echo ", Code: ".$e->getCode();
}


Authenticate:

try {
	if($ejabberd_rpc->auth() === true) {

				print "OK";
			}
			else {
				print "Not Ok";
			}
}
catch(Exception $e) {
        echo "Exception: ".$e->getMessage();
	echo ", Code: ".$e->getCode();
}


Get roster:

print_r($ejabberd_rpc->get_roster());


*/##################################################
error_reporting(E_ALL);

class rpc_connector {

	protected $rpc_server;
	protected $rpc_port;
	public $username;
	public $password;
	protected $vhost;
	protected $parms;
	protected $method;

	public function __construct($rpc_server, $rpc_port, $username,$password, $vhost) {
		$this->setData($rpc_server, $rpc_port, $username, $password,$vhost);
	}


	public function setData($rpc_server, $rpc_port, $username, $password,$vhost) {
		$this->rpc_server = $rpc_server;
		$this->rpc_port = $rpc_port;
		$this->username = $username;
		$this->password = $password;
		$this->vhost = $vhost;
	}

	protected function commit_rpc() {

		$request = xmlrpc_encode_request($this->method,$this->parms);
		$context = stream_context_create(array('http' => array(
    			'method' => "POST",
    			'header' => "Content-Type: text/xml; charset=utf-8\r\n" .
                	"User-Agent: XMLRPC::Client JorgeRPCclient",
    			'content' => $request
			)));

		$file = file_get_contents("http://$this->rpc_server".":"."$this->rpc_port", false, $context);
		$response = xmlrpc_decode($file);
			if (xmlrpc_is_fault($response)) {

				throw new Exception("XML-RPC Call Failed. Unrecoverable condition",0);

			} else {

				return $response;
			}

	}

	public function auth() {

		$this->method = "check_password";
		$this->parms = array("user"=>"$this->username","host"=>"$this->vhost","password"=>"$this->password");
		if ($this->commit_rpc() === 0 ) {
				
				#password ok
				return true;

				}
			else{

				#bad password
				return false;

			} 


	}

	public function get_roster() {

		$this->method = "get_roster";
		$this->parms = array("user"=>"$this->username","server"=>"$this->vhost");
		return $this->commit_rpc();
	}

	public function check_account() {

		$this->method = "check_account";
		$content = array("user"=>"$this->username","host"=>"$this->vhost");
		$this->parms = $content;
		if ($this->commit_rpc() === 1) {
					
					#not existing
					return false;

				}
				else{

					#existing				
					return true;
				
				}	

	}

	public function test_rpc() {

		$this->method = "echothis";
		$this->parms = "If you can read this then RPC is working...";
		return $this->commit_rpc();

	}

	public function create_account() {

		$this->method = "create_account";
		$this->parms = array("user"=>"$this->username","host"=>"$this->vhost","password"=>"$this->password");
		$call = $this->commit_rpc();
		if ($call === 0) {

						return true;
				}
				elseif($call === 409) {
						return "exist";
					}
					elseif($call = 1) {
						return false;
					}

	}

	public function delete_account() {

		$this->method = "delete_account";
		$this->parms = array("user"=>"$this->username","host"=>"$this->vhost","password"=>"$this->password");
		$this->commit_rpc();
		if ($this->check_account() === false) {

						return true;

						}
					else {
						
						return false;
					}
	}

}

?>
