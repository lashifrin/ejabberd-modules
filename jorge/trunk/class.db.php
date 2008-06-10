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

###########################################################################

EXPERIMENTAL VERSION: DO NOT USE! IT IS NOT FINISHED AND NOT INCLUDE MANY METHODS YET!

This class is for mod_logdb and project jorge. It holds all logic needed for managing messages.
All methods always return TRUE or FALSE. Results are always in:

Query type:					Return type:		Example:
single query (one result)			Object			$db->result->cnt;
single query (multiple results)			Array(multidim)			$db->result;
update						num rows affected	$db->result;
insert						num rows affected	$db->result;
delete						num rows affected	$db->result;

Methods list:

method:			description:									result:

$db->set_debug(bool); // Enable/Disable debug | 							true
$db->set_user_id(integer); // Sets user ID for instance							true|flase
$db->get_user_id(string); // Get user ID								$db->result->user_id;
$db->get_user_name(integer); // Get user name								$db->result->username;
$db->get_server_id(string); // Get server ID								$db->result->server_id;
$db->get_server_name(integer); // Get server name							$db->result->server_name;
$db->get_resource_name(integer); // Get resource name							$db->result->resource_name;
$db->get_resource_id(string); // Get resource ID							$db->result->resource_id;
$db->get_user_talker_stats(user_id integer, server_id integer); // Get array of chats with user		$db->result;
$db->get_mylinks_count(); // Get number of mylinks saved						$db->result->cnt;
$db->get_trash_count(); // Get number of elements in trash						$db->result->cnt; 
$db->get_num_lines(date string, user_id integer, server_id integer); // get number of chat lines	$db->result->cnt;
$db->$is_log_enabled(); // Check if message logging is enabled						$db->result->is_enabled;
$db->total_messages(); // Total messages archivized by server 						$db->result->total_messages;
$db->total_chats(); // Total conversations 								$db->result->total_chats;
$db->get_log_list(); // Get list of users with user dont log messages					$db->result;
$db->set_log(bool); // Enable/Disable message archiving							$db->result (num affected)
$db->db_error(); // If instance is affected by error							true|false
$db->get_user_stats_calendar(YYYY-M string, ignore_id integer) // User chat stats 			$db->result;
$db->get_user_stats_drop_down() ; // User chat stats needed for jorge calendar				$db->result;
$db->get_user_chats(YYYY-M-D string); // Get chat list from day 					$db->result;
$db->get_user_chat(YYYY-M-D,peer_name_id,peer_server_id,peer_resource_id = null, start = null,lines = null); // Get user chat $db->result;
$db->set_logger(event_id,event_level); 									$db->result;
$db->get_uniq_chat_dates($limit_start integer,$limit_end integer);					$db->result;


See documentation for details.

NOTICE: in case of any error (query error, validation error etc.) instance is marked as faulty, all queries are aborted and exception is thrown
remember to handle errors gracefully!


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
	private $query_type;
	private $is_debug = false;
	private $user_id = null;
	private $time_start = null;
	private $time_result = null;
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

		$this->show_debug_info($query, $time = false);
		if ($this->is_error === false) {

				$this->time_start();
				$result = mysql_query($query);
				$this->time_end();
				$this->show_debug_info($query = null, $time = true);

			}
			elseif($this->is_error === true) {

				throw new Exception("Error before queryID:".$this->id_query,3);
				return false;
		}

		if ($result === false ) {
					
					$this->is_error = true;
					throw new Exception("Query error in QueryID:".$this->id_query,2);
					return false;

				}
			else {

					if ($this->query_type === "select") {

								return $result;
							}
						elseif($this->query_type === "update" OR $this->query_type === "insert") {

								return mysql_affected_rows();
						}
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

	private function select($query,$return_type = null) {

		$this->query_type="select";
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

	private function update($query) {

		$this->query_type = "update";
		if (strpos(strtolower($query),"update") === 0) {

			try{
				$this->result = $this->db_query($query);
			}
                	catch(Exception $e) {
                        	echo "Exception: ".$e->getMessage();
                        	echo ", Code: ".$e->getCode();
			}

			if($this->is_error===false) {
					
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

	private function insert($query) {

		$this->query_type = "insert";
		if (strpos(strtolower($query),"insert") === 0) {

			try{
				$this->result = $this->db_query($query);
			}
                	catch(Exception $e) {
                        	echo "Exception: ".$e->getMessage();
                        	echo ", Code: ".$e->getCode();
			}

			if($this->is_error===false) {
					
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


	public function get_mylinks_count() {

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

	public function get_trash_count() {
	
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

	public function set_log($bool) {

		$this->id_query = "Q020";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		if ($bool === true) {

				$val = 1;
			
			}
			elseif($bool === false) {

				$val = 0;
			
			}
			else{

				return false;
		}
		
		$query="UPDATE 
				`logdb_settings_$xmpp_host`
			SET 	
				dolog_default = '$val' 
			WHERE 
				owner_id = '$user_id'
		";

		return $this->update($query);

	}

	public function set_logger($event_id,$event_level,$extra = null) {
		
		$this->id_query = "Q021";
		$this->vital_check();
		$id_log_detail = $this->sql_validate($event_id,"integer");
		$id_log_level = $this->sql_validate($event_level,"integer");
		$extra = $this->sql_validate($extra,"string");
		$user_id = $this->user_id;
		$query="insert into 
				jorge_logger (id_user,id_log_detail,id_log_level,log_time,extra) 
			values 
				('$user_id','$id_log_detail','$id_log_level',NOW(),'$extra')
				
		";

		return $this->insert($query);
	}

	public function get_user_stats_drop_down() {

		$this->id_query = "Q022";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="SELECT 
				substring(at,1,7) as at_send, 
				at 
			FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id = '$user_id' 
			GROUP BY 
				substring(at,1,7) 
			ORDER BY 
				str_to_date(at,'%Y-%m-%d') 
			DESC
		
		";
		
		$this->select($query,"raw");
		return $this->commit_select(array("at_send","at"));
	}

	public function get_user_stats_calendar($mo,$ignore_id) {

		$this->id_query = "Q023";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$mo = $this->sql_validate($mo,"string");
		$ignore_id = $this->sql_validate($ignore_id, "integer");
		$query="SELECT 
				distinct(substring(at,8,9)) as days 
			FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id = '$user_id' 
			AND
				at like '$mo%' 
			AND 
				peer_name_id!='$ignore_id' 
			ORDER BY 
				str_to_date(at,'%Y-%m-%d') 
			DESC
			
		";

		$this->select($query,"raw");
		return $this->commit_select(array("days"));
	}

	public function get_user_chats($tslice) {
		
		$this->id_query = "Q024";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$tslice_table = $this->sql_validate($tslice,"string");
		$query="SELECT 
				a.username, 
				b.server as server_name, 
				c.peer_name_id as todaytalk, 
				c.peer_server_id as server, 
				c.count as lcount 
			FROM 
				`logdb_users_$xmpp_host` a, 
				`logdb_servers_$xmpp_host` b, 
				`logdb_stats_$xmpp_host` c 
			WHERE 
				c.owner_id = '$user_id' 
			AND 
				a.user_id=c.peer_name_id 
			AND 
				b.server_id=c.peer_server_id 
			AND 
				c.at = '$tslice' 
			AND 
				username!='' 
			ORDER BY 
				lower(username)
				
		";
		
		$this->select($query,"raw");
		return $this->commit_select(array("username","server_name","todaytalk","server","lcount"));

	}

	public function get_user_chat($tslice,$talker_id,$server_id,$resource_id = null,$start = null,$num_lines = null) {
	
		$this->id_query = "Q025";
		$this->vital_check();
		$user_id = $this->user_id;
		$tslice = $this->sql_validate($tslice,"string");
		$talker_id = $this->sql_validate($talker_id,"integer");
		$server_id = $this->sql_validate($server_id,"integer");
		if ($resource_id !== null) { 
		
				$resource_id = $this->sql_validate($resource_id,"integer");
				$sql = "AND (peer_resource_id='$resource_id' OR peer_resource_id='1')";

			}
			else{

				settype($sql,"null");
			}

		$offset_start = $start;
		if ($offset_start === null) {

				$offset_start = "0";

			}

		$offset_end = $start + $num_lines;
		$offset_start = $this->sql_validate($offset_start,"integer");
		$offset_end = $this->sql_validate($offset_end,"integer");
		$tslice_table = $this->construct_table($tslice);
		$query="SELECT 
				from_unixtime(timestamp+0) as ts,
				direction, 
				peer_name_id, 
				peer_server_id, 
				peer_resource_id, 
				body 
			FROM 
				`$tslice_table` 
			WHERE 
				owner_id = '$user_id' 
			AND 
				peer_name_id='$talker_id' 
			AND 
				peer_server_id='$server_id' 
				$sql 
			AND 
				ext is NULL 
			ORDER BY 
				ts 
			LIMIT 
				$offset_start,$offset_end
		";

		$this->select($query,"raw");
		return $this->commit_select(array("ts","direction","peer_name_id","peer_server_id","peer_resource_id","body"));

	}

	public function get_uniq_chat_dates($limit_start = null, $limit_end = null) {

		$this->id_query = "Q026";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		if ($limit_start !== null AND $limit_end !== null) {
	
				$this->sql_validate($limit_start,"string");
				$this->sql_validate($limit_end,"string");
				$sql=" and str_to_date(at,'%Y-%m-%d') >= str_to_date('$limit_start','%Y-%m-%d') and str_to_date(at,'%Y-%m-%d') <= str_to_date('$limit_end','%Y-%m-%d')";
				
			}
			else{

				settype($sql,"null");

		}
		
		$query="SELECT 
				distinct(at) 
			FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id='$user_id' $sql 
			ORDER BY 
				str_to_date(at,'%Y-%m-%d') 
			ASC
		";

		$this->select($query,"raw");
		return $this->commit_select(array("at"));

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
				server as server_name
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
				resource as resource_name
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

	public function get_user_talker_stats($talker_id,$talker_server_id){

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
		return $this->commit_select(array("at"));
	}

	public function db_error() {

		return $this->is_error;

	}

	public function set_user_id($user_id) {

		$user_id = $this->sql_validate($user_id,"integer");
		if ($user_id === false) {
				
				return false;

			}
			else {

				$this->user_id = $user_id;
				return true;
		}

		return false;
		

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

	private function commit_select($arr) {

		if ($this->is_error === true) {
				
				return false;

			}

		$this->object_to_array($arr);
		return true;
	
	}

	private function object_to_array($arr) {
		
		settype($i, "integer");
		settype($z, "integer");
		$result = $this->result;
		while($row = mysql_fetch_object($result)) {
			
			$i++;
			foreach ($arr as $key) {
				
				$z++;
				$items[$i][$key] = $row->$key;
		
			}


		}

		return $this->result = $items;
		
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
		return true;

	}

	private function show_debug_info($query = null, $time = null) {

		if ($this->is_debug === true) {
		
			if ($query !== null) {
					
					print "<br><small><b>QueryID:</b> ".$this->id_query.": ".htmlspecialchars($query)."<br>";
				}
			if ($query === null AND $time !== null) {
			
					print "<b>SQL performed in:</b> ".$this->time_result."</small><br><br>";

				}
		
		}
	}

	private function sql_time() {
		
		list($usec, $sec) = explode(" ",microtime());
		return ((float)$usec + (float)$sec);
	}

	private function time_start() {

		if ($this->is_debug === true) {
		
			return $this->time_start = $this->sql_time();
		
		}
	
	}

	private function time_end() {

		if ($this->is_debug === true) {
		
			$start = $this->time_start;
			$end = $this->sql_time();
			return $this->time_result = substr($end - $start, 0, 10);

		}

	}

	public function __destruct() {

		mysql_free_result();
		mysql_close();
		$this->user_id = null;
		$this->result = null;

	}

}

?>
