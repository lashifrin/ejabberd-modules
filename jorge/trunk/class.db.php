<?
/*
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
*/

class db_manager {

	protected $db_host;
	protected $db_name;
	protected $db_user;
	protected $db_password;
	protected $db_driver;
	protected $xmpp_host;
	private $is_error = false;
	public $result;

	public function __construct($db_host,$db_name,$db_user,$db_password,$db_driver,$xmpp_host = null) {
		$this->setData($db_host,$db_name,$db_user,$db_password,$db_driver,$xmpp_host);
	}


	protected function setData($db_host,$db_name,$db_user,$db_password,$db_driver,$xmpp_host) {
		$this->db_host = $db_host;
		$this->db_name = $db_name;
		$this->db_user = $db_user;
		$this->db_password = $db_password;
		$this->db_driver = $db_driver;
		$this->xmpp_host = $xmpp_host;
		try { 
			$this->db_connect();
			}
		catch(Exception $e) {
        		echo "Exception: ".$e->getMessage();
        		echo ", Code: ".$e->getCode();
		}
			
	}

	protected function db_mysql() {

		$conn = mysql_connect("$this->db_host", "$this->db_user", "$this->db_password");
		if (!$conn) {

				return false;

			}
		if (mysql_select_db($this->db_name)) {
				
				return true;

				}

			else {

				return false;
			
			}

	}

	protected function db_query($query) {

		$result = mysql_query($query);
		if ($result === false ) {
					
					$this->is_error = true;
					throw new Exception("Query error",2);

				}
			else {

					return $result;
		}

	}

	private function db_connect() {

		if ($this->db_driver === "mysql") {
			
				if ($this->db_mysql() === true) {

						return true;
					}
				else {
						$this->is_error = true;
						throw new Exception("DB Connection failed!",1);
				}
		}
	
	return false;

	}


	public function begin() {

			if($this->db_query("begin")) {
					return true;
				}
			else{
					return false;
			}
			
	}
	
	public function commit() {
			
			if($this->db_query("commit")) {
					return true;
				}
			else{
					return false;
			}
	}

	public function rollback() {

			if($this->db_query("rollback")) {
					return true;
				}
			else {
					return false;
			}
	}

	public function select($query,$return_type = null) {

		if (strpos(strtolower($query),"select") === 0) {

			try{
				$this->result = $this->db_query($query);
			}
                	catch(Exception $e) {
                        	echo "Exception: ".$e->getMessage();
                        	echo ", Code: ".$e->getCode();
			}

			if($this->is_error===false) {

					if($return_type === null) {

							$this->result = mysql_fetch_object($this->result);

					}
					elseif($return_type === "raw") {

							return true;
				
					}

					return true;	

				}

				else{
					
					return false;
				
				}

		}

		else {

			return false;
		
		}
	}

	public function get_user_id($user) {
	
		$user = $this->sql_validate($user,"string");
		$table_name = "`logdb_users_".$this->xmpp_host."`";
		$query="SELECT
				user_id 
			FROM 
				$table_name 
			WHERE 
				username = '$user'
				
			";
		
		return $this->select($query);

	}

	public function get_user_name($user_id) {

		$user_id = $this->sql_validate($user_id,"integer");
		$table_name = "`logdb_users_".$this->xmpp_host."`";
		$query="SELECT
				username
			FROM 
				$table_name 
			WHERE 
				user_id = '$user_id'
				
			";
		
		return $this->select($query);

	}

	public function get_server_id($server) {
	
		$server = $this->sql_validate($server,"string");
		$table_name = "`logdb_servers_".$this->xmpp_host."`";
		$query="SELECT
				server_id 
			FROM 
				$table_name 
			WHERE 
				server = '$server'
				
			";
		
		return $this->select($query);

	}

	public function get_server_name($server_id) {
	
		$server_id = $this->sql_validate($server_id,"integer");
		$table_name = "`logdb_servers_".$this->xmpp_host."`";
		$query="SELECT
				server
			FROM 
				$table_name 
			WHERE 
				server_id = '$server_id'
				
			";
		
		return $this->select($query);

	}


	public function get_resource_name($resource_id) {
	
		$resource_id = $this->sql_validate($resource_id,"integer");
		$table_name = "`logdb_resources_".$this->xmpp_host."`";
		$query="SELECT
				resource
			FROM 
				$table_name 
			WHERE 
				resource_id = '$resource_id'
				
			";
		
		return $this->select($query);
	}

	public function get_resource_id($resource) {
	
		$resource = $this->sql_validate($resource,"string");
		$table_name = "`logdb_resources_".$this->xmpp_host."`";
		$query="SELECT
				resource_id
			FROM 
				$table_name 
			WHERE 
				resource = '$resource'
				
			";
		
		return $this->select($query);

	}

	public function get_user_stats($user_id,$talker_id,$talker_server_id){

		$user = $this->sql_validate($user_id,"integer");
		$talker = $this->sql_validate($talker_id,"integer");
		$talker_server = $this->sql_validate($talker_server_id,"string");

		$table_name = "`logdb_stats_".$this->xmpp_host."`";
		$query="SELECT
				at 
			FROM 
				$table_name
			WHERE 
				owner_id='$user' 
			AND 
				peer_name_id='$talker' 
			AND 
				peer_server_id='$talker_server' 
			ORDER BY 
				str_to_date(at,'%Y-%m-%d') 
			ASC
			
			";
		
		$this->select($query,"raw");
		$result = $this->result;
		
		settype($i, "integer");	
		
		while($row = mysql_fetch_object($result)) {
			
			$i++;
			$items[$i] = $row->at;

		}

		$this->result = $items;
		return true;
	}

	public function db_error() {

		return $this->is_error;

	}

	public function db_close() {

		mysql_close();

	}

	protected function sql_validate($val,$type) {

		if($this->db_driver === "mysql") {

			if ($type==="integer") {

				if(ctype_digit($val)) {
					
						return $val;

					}
				else{
						$this->is_error = true;
						return false;
				}
			}
			elseif($type==="string") {

				return mysql_escape_string($val);

			}
			else{
				$this->is_error = true;
				return false;
			}


		}

	return false;

	}


}

?>
