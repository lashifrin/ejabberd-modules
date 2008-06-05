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
	private $messages_table = "logdb_messages_";
	private $is_error = false;
	private $id_query;
	private $is_debug = false;
	private $user_id = null;
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

	protected function do_query($query) {

		$this->show_debug_info($query);
		$result = mysql_query($query);
		if ($result === false ) {
					
					$this->is_error = true;
					throw new Exception("Query error in QueryID:".$this->id_query,2);
					return false;

				}
			else {

					return $result;
		}

	}

	private function db_query($query) {

		try {

				$result = $this->do_query($query);
			
			}
		catch (Exception $e) {

				echo "Exception: ".$e->getMessage();
				echo ", Code: ".$e->getCode();
				return false;
		}

		return $result;
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

		$this->id_query = "Q001";

			if($this->db_query("begin")) {
					
					return true;
				
				}
			else{

					return false;
			
			}
			
	}
	
	public function commit() {
		
		$this->id_query = "Q002";
			
			if($this->db_query("commit")) {
					return true;
				}
			else{
					return false;
			}
	}

	public function rollback() {

		$this->id_query = "Q003";

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

	public function mylinks_count() {

		$this->id_query = "Q004";
		$this->vital_check();
		$user_id = $this->user_id;
		$query="SELECT 
				count(id_link) as cnt
			FROM 
				jorge_mylinks 
			WHERE 
				owner_id='$user_id' 
			AND 
				ext is NULL
		
		";
		
		return $this->select($query);
	}

	public function trash_count() {
	
		$this->id_query = "Q005";
		$this->vital_check();
		$user_id = $this->user_id;
		$query="SELECT 
				count(*) as cnt
			FROM 
				pending_del 
			WHERE 
				owner_id='$user_id'
		";

		return $this->select($query);
		
	}

	public function get_num_lines($tslice,$talker_id,$server_id) {
		
		$this->id_query = "Q015";
		$this->vital_check();
		$user_id = $this->user_id;
		$talker_id = $this->sql_validate($talker_id,"integer");
		$server_id = $this->sql_validate($server_id,"integer");
		$table = $this->construct_table($tslice);

		$query="SELECT 
				count(timestamp) as cnt
			FROM 
				`$table` 
			WHERE 
				owner_id = '$user_id' 
			AND 
				peer_name_id='$talker_id' 
			AND 
				peer_server_id='$server_id'
				
		";
		
		return $this->select($query);

	}

	public function is_log_enabled() {

		$this->id_query = "Q016";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="SELECT 
				dolog_default as is_enabled
			FROM 
				`logdb_settings_$xmpp_host` 
			WHERE 
				owner_id='$user_id'
		";

		return $this->select($query);

	}

	public function total_messages() {
	
		$this->id_query = "Q017";
		$xmpp_host = $this->xmpp_host;
		$query="SELECT 
				sum(count) as total_messages
			FROM 
				`logdb_stats_$xmpp_host`
		";
		return $this->select($query);

	}

	public function total_chats() {

		$this->id_query = "Q018";
		$xmpp_host = $this->xmpp_host;
		$query="SELECT 
				count(owner_id) as total_chats
			FROM 
				`logdb_stats_$xmpp_host
		";
		return $this->select($query);

	}

	public function get_log_list() {

		$this->id_query = "Q019";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="SELECT 
				donotlog_list as donotlog
			FROM 
				logdb_settings_$xmpp_host 
			WHERE 
				owner_id = '$user_id'
		";

		$this->select($query);
		$split = explode("\n",$this->result->donotlog);
		$this->result = $split;
		return true;

	}


	protected function row_count($query) {

		$this->id_query = "Q006";
		$result = mysql_num_rows($this->db_query($query));
		if ($result === false) {
				return false;
			}
			else{
				$this->result = $result;
				return true;
		}
		
	}

	public function get_user_id($user) {
		
		$this->id_query = "Q007";	
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

		$this->id_query = "Q008";
		$user_id = $this->sql_validate($user_id,"integer");
		if ($user_id === false) { 
				
				return false; 
				
			}
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

		$this->id_query = "Q009";
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

		$this->id_query = "Q010";
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

		$this->id_query = "Q012";
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
	
		$this->id_query = "Q013";
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

	public function get_user_stats($talker_id,$talker_server_id){

		$this->id_query = "Q014";
		$this->vital_check();
		$user_id = $this->user_id;
		$talker = $this->sql_validate($talker_id,"integer");
		$talker_server = $this->sql_validate($talker_server_id,"string");

		$table_name = "`logdb_stats_".$this->xmpp_host."`";
		$query="SELECT
				at 
			FROM 
				$table_name
			WHERE 
				owner_id='$user_id' 
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

	public function set_user_id($user_id) {

		$this->user_id = $this->sql_validate($user_id,"integer");

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

	private function construct_table($tslice) {
		
		return $tslice_table = $this->messages_table.''.$tslice.'_'.$this->xmpp_host;

	}

	private function vital_check() {

		if($this->user_id === false OR !$this->user_id) {

				print "<br><br><small>Operation aborted! Can't continue.</small><br><br>";
				exit; // abort all, user_id MUST be set.
		}
		return true;

	}

	public function set_debug($bool) {

		if($bool === true) { $this->is_debug = true; }
		if($bool === false) { $this->is_debug = false; }

	}

	private function show_debug_info($query) {

		if ($this->is_debug === true) {
			
			print "<br><small>QueryID: ".$this->id_query.": ".htmlspecialchars($query)."</small><br>";
		
		}
	}


}

?>
