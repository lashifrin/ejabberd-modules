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
$db->check_thread;											$db->result; 

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
					throw new Exception("<br>Query error in QueryID:".$this->id_query,2);
					return false;

				}
			else {

					if ($this->query_type === "select") {

								return $result;
							}
						elseif($this->query_type === "update" OR $this->query_type === "insert") {

								return mysql_affected_rows();
						}
						elseif($this->query_type === "delete") {

								return $result;

						}
						elseif($this->query_type === "transaction") {

								return $result;

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
						throw new Exception("<br>DB Connection failed!",1);
				}
		}
	
	return false;

	}

	public function begin() {

		$this->id_query = "Q001";
		$this->query_type = "transaction";
		return $this->db_query("begin");

	}
	
	public function commit() {
		
		$this->id_query = "Q002";
		$this->query_type = "transaction";
		return $this->db_query("commit");
	
	}

	public function rollback() {

		$this->id_query = "Q003";
		$this->query_type = "transaction";
		$this->is_error = false;
		return $this->db_query("rollback");

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

	private function delete($query) {

		$this->query_type = "delete";
		if (strpos(strtolower($query),"delete") === 0) {

			try{
				$this->result = $this->db_query($query);
			}
			catch(Exception $e) {
				echo "Exception: ".$e->getMessage();
				echo ", Code: ".$e->getCode();
			}

			if ($this->is_error===false) {

					return true;

				}
				else {

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

	public function check_thread($tslice,$peer_name_id,$peer_server_id,$begin_hour,$end_hour) {

		$this->id_query = "Q027";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$tslice = $this->sql_validate($tslice,"date");
		$tslice_table = $this->construct_table($tslice);
        	$query="SELECT 
				1 
                	FROM 
                        	`$tslice_table`
                	WHERE 
                        	owner_id='$user_id' 
                	AND 
                        	peer_name_id='$peer_name_id' 
                	AND 
                        	peer_server_id='$peer_server_id' 
                	AND 
                        	from_unixtime(timestamp) >= str_to_date('$tslice $begin_hour','%Y-%m-%d %H:%i:%s') 
                	AND 
                        	from_unixtime(timestamp) <= str_to_date('$tslice $end_hour','%Y-%m-%d %H:%i:%s')
                	ORDER BY 
                        	from_unixtime(timestamp)

		";
		
		return $this->row_count($query);

	}

	public function get_chat_map($peer_name_id,$peer_server_id) {

		$this->id_query = "Q028";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$query="SELECT 
				substring(at,1,7) as at 
			FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			GROUP BY 
				substring(at,1,7) 
			ORDER BY 
				str_to_date(at,'%Y-%m-%d') 
			ASC
			
		";
		
		$this->select($query,"raw");
		return $this->commit_select(array("at"));

	}

	public function get_chat_map_specyfic($peer_name_id,$peer_server_id,$month) {

		$this->id_query = "Q029";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$mo = $this->sql_validate($month,"string");
		$query="SELECT 
				at 
			FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				at like '$mo%'
				
		";

		$this->select($query,"raw");
		return $this->commit_select(array("at"));

	}

	public function add_mylink($peer_name_id,$peer_server_id,$link_date,$link,$desc) {

		$this->id_query = "Q030";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$datat = $this->sql_validate($link_date,"string");
		$lnk = $this->sql_validate($link,"string");
		$desc = $this->sql_validate($desc,"string");
		$query="INSERT INTO
				jorge_mylinks (owner_id,peer_name_id,peer_server_id,datat,link,description) 
			VALUES (
					'$user_id',
					'$peer_name_id',
					'$peer_server_id',
					'$datat',
					'$lnk',
					'$desc'
				)
				
		";

		return $this->insert($query);

	}

	public function del_mylink($link_id) {

		$this->id_query = "Q031";
		$this->vital_check();
		$user_id = $this->user_id;
		$link_id = $this->sql_validate($link_id,"integer");
		$query="DELETE FROM 
				jorge_mylinks 
			WHERE 
				owner_id='$user_id' 
			AND 
				id_link='$link_id'
				
		";

		return $this->delete($query);

	}

	public function get_mylink() {

		$this->id_query = "Q032";
		$this->vital_check();
		$user_id = $this->user_id;
		$query="SELECT
				id_link,
				peer_name_id,
				peer_server_id,
				datat,
				link,
				description,
				ext
			FROM 
				jorge_mylinks 
			WHERE 
				owner_id='$user_id' 
			AND 
				ext is NULL 
			ORDER BY 
				str_to_date(datat,'%Y-%m-%d') 
			DESC
			
		";

		$this->select($query,"raw");
		return $this->commit_select(array("id_link","peer_name_id","peer_server_id","datat","link","description","ext"));


	}

	public function update_log_list($log_list) {

		$this->id_query = "Q033";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$log_list = $this->sql_validate($log_list,"string");
		$query="UPDATE 
				logdb_settings_$xmpp_host 
			SET 
				donotlog_list='$log_list' 
			WHERE 
				owner_id='$user_id'
		";
		return $this->update($query);

	}

	public function logger_get_events($event_id = null,$level_id = null, $offset = null) {

		$this->id_query = "Q034";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$offset = $this->sql_validate($offset,"integer");
		if ($event_id !== null) {
				
				$event_id = $this->sql_validate($event_id,"integer");
				$sql_1 = "and id_log_detail='$event_id'";

		}
		if ($level_id !== null) {

				$level_id = $this->sql_validate($level_id,"integer");
				$sql_2 = "and id_log_level='$level_id'";
		
		}
		$query="SELECT 
				b.id_event, 
				b.event AS event,
				c.level AS level, 
				c.id_level, 
				a.log_time,
				a.extra
			FROM 
				jorge_logger a,
				jorge_logger_dict b,
				jorge_logger_level_dict c
			WHERE 
				a.id_log_detail=b.id_event 
			AND 
				c.id_level=a.id_log_level 
			AND 
				id_user='$user_id' 

			$sql_1 
			$sql_2

			ORDER BY 
				log_time 
			DESC LIMIT 
				$offset,300
		";
		
		$this->select($query,"raw");
		return $this->commit_select(array("id_event","event","level","id_level","log_time","extra"));

	}

	public function get_num_events($event_id = null,$level_id = null) {

		$this->id_query = "Q035";
		$this->vital_check();
		$user_id = $this->user_id;
		if ($event_id !== null) {
				
				$event_id = $this->sql_validate($event_id,"integer");
				$sql_1 = "and id_log_detail='$event_id'";
		}
		if ($level_id !== null) {

				$level_id = $this->sql_validate($level_id,"integer");
				$sql_2 = "and id_log_level='$level_id'";
		}
		$query="select 
				count(id_user) as cnt
			from 
				jorge_logger 
			where 
				id_user='$user_id' 
			
			$sql_1 
			$sql_2
		";

		return $this->select($query);

	}

	public function get_trashed_items() {

		$this->id_query = "Q036";
		$this->vital_check();
		$user_id = $this->user_id;
		$query="SELECT 
				peer_name_id,
				peer_server_id,
				date,
				timeframe
			FROM 
				pending_del 
			WHERE 
				owner_id = '$user_id' 
			ORDER BY 
				str_to_date(date,'%Y-%m-%d') 
			DESC
		";

		$this->select($query,"raw");
		return $this->commit_select(array("peer_name_id","peer_server_id","date","timeframe"));

	}

	public function move_chat_to_trash($peer_name_id,$peer_server_id,$tslice,$link) {

		$this->id_query = "Q037";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$tslice = $this->sql_validate($tslice,"date");
		$table = $this->construct_table($tslice);

		$this->begin();
		if ($this->set_undo_table($peer_name_id,$peer_server_id,$tslice) === false) {

				$this->rollback();
				return false;

		}

		if ($this->remove_user_stats($peer_name_id,$peer_server_id,$tslice) === false) {

				$this->rollback();
				return false;

		}

		if ($this->move_mylink_to_trash($peer_name_id,$link) === false) {

				$this->rollback();
				return false;

		}

		if ($this->move_fav_to_trash($peer_name_id,$peer_server_id,$tslice) === false) {

				$this->rollback();
				return false;

		}

		$query="UPDATE 
				`$table` 
			SET 
				ext = '1' 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id'
				
		";
		
		if ($this->update($query) === false) {
				
				$this->rollback();
				return false;

			}
			else{

				$this->commit();
				$this->set_logger("4","1");
				return true;
		}
	}

	private function remove_user_stats($peer_name_id,$peer_server_id,$tslice) {

		$this->id_query = "Q038";
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="DELETE FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				at='$tslice'
		";

		return $this->delete($query);
	
	}

	public function move_mylink_to_trash($peer_name_id,$link) {

		$this->id_query = "Q039";
		$this->vital_check();
		$user_id = $this->user_id;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$lnk = $this->sql_validate($link,"string");
		$query="UPDATE 
				jorge_mylinks 
			SET 
				ext='1' 
			WHERE 
				owner_id ='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				link like '$lnk%'
		";

		return $this->update($query);

	}

	public function move_fav_to_trash($peer_name_id,$peer_server_id,$tslice) {

		$this->id_query = "Q040";
		$this->vital_check();
		$user_id = $this->user_id;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$tslice = $this->sql_validate($tslice,"date");
		$query="UPDATE 
				jorge_favorites 
			SET 
				ext='1' 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				tslice='$tslice'
		";
	
		return $this->update($query);

	}

	private function set_undo_table($peer_name_id,$peer_server_id,$tslice,$type = null) {

		$this->id_query = "Q041";
		$user_id = $this->user_id;
		$query="INSERT INTO 
				pending_del(owner_id,peer_name_id,date,peer_server_id) 
			values (
				'$user_id', 
				'$peer_name_id',
				'$tslice',
				'$peer_server_id'
				)
				
		";

		return $this->insert($query);

	}

	private function unset_undo_table($peer_name_id,$peer_server_id,$tslice) {

		$this->id_query = "Q042";
		$user_id = $this->user_id;
		$query="DELETE FROM 
				pending_del 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				date='$tslice' 
			AND 
				peer_server_id='$peer_server_id'
		";
		
		return $this->delete($query);
	}

	public function move_chat_from_trash($peer_name_id,$peer_server_id,$tslice,$link) {

		$this->id_query = "Q043";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$peer_name_id = $this->sql_validate($peer_name_id,"integer");
		$peer_server_id = $this->sql_validate($peer_server_id,"integer");
		$tslice = $this->sql_validate($tslice,"date");
		$table = $this->construct_table($tslice);

		// Message tables are not transactional, so this make some trouble for us to control all error conditions :/
		$query="UPDATE 
				`$table` 
			SET 
				ext = NULL 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id'
		";

		if ($this->update($query) === false) {

				return false; 

		}

		$this->begin();
		if ($this->unset_undo_table($peer_name_id,$peer_server_id,$tslice) === false) {

				$this->rollback();
				return false;

		}

		if ($this->recount_messages($peer_name_id,$peer_server_id,$tslice) === true) {

				$stats = $this->result->cnt;

			}
			else {

				$this->rollback();
				return false;
		}

		if ($this->if_chat_exist($peer_name_id,$peer_server_id,$tslice) === true) {


					if ($this->result->cnt == 1) {

							if ($this->update_stats($peer_name_id,$peer_server_id,$tslice,$stats) === false) {

									$this->rollback();
									return false;
							}

						}
						else {

							if ($this->insert_stats($peer_name_id,$peer_server_id,$tslice,$stats) === false) {

									$this->rollback();
									return false;

							}
						}

			}
			else{

					$this->rollback();
					return false;
		}

		if ($this->move_mylink_from_trash($peer_name_id,$link) === false) {

				$this->rollback();
				return false;

		}

		if ($this->move_fav_from_trash($peer_name_id,$peer_server_id,$tslice) === false) {

				$this->rollback();
				return false;
		}

		$this->commit();
		return true;
	
	
	}

	private function if_chat_exist($peer_name_id,$peer_server_id,$tslice) {

		$this->id_query = "Q044";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="SELECT 
				1 as cnt
			FROM 
				`logdb_stats_$xmpp_host` 
			WHERE 
				owner_id = '$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				at = '$tslice'
				
		";

		return $this->select($query);

	}

	private function insert_stats($peer_name_id,$peer_server_id,$tslice,$stats) {
	
		$this->id_query = "Q045";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="insert into 
				`logdb_stats_$xmpp_host` (owner_id,peer_name_id,peer_server_id,at,count) 
			values 
				(
				'$user_id',
				'$peer_name_id',
				'$peer_server_id',
				'$tslice',
				'$stats
				')
				
		"; 
		
		return $this->insert($query);
	}

	private function update_stats($peer_name_id,$peer_server_id,$tslice,$stats) {

		$this->id_query = "Q046";
		$this->vital_check();
		$user_id = $this->user_id;
		$xmpp_host = $this->xmpp_host;
		$query="UPDATE 
				`logdb_stats_$xmpp_host` 
			SET 
				count='$stats' 
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				at='$tslice'
				
		";

		return $this->update($query);
	}

	private function recount_messages($peer_name_id,$peer_server_id,$tslice) {
	
		$this->id_query = "Q047";
		$this->vital_check();
		$user_id = $this->user_id;
		$table = $this->construct_table($tslice);
		$query="SELECT
				count(timestamp) as cnt 
			FROM 
				`$table`
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				ext is NULL
		";
		
		return $this->select($query);

	}



	private function move_mylink_from_trash($peer_name_id,$link) {

		$this->id_query = "Q048";
		$this->vital_check();
		$user_id = $this->user_id;
		$lnk = $this->sql_validate($link,"string");
		$query="UPDATE 
				jorge_mylinks 
			SET 
				ext = NULL 
			WHERE 
				owner_id ='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				link like '$link%'
		";

		return $this->update($query);

	}

	private function move_fav_from_trash($peer_name_id,$peer_server_id,$tslice) {

		$this->id_query = "Q049";
		$this->vital_check();
		$user_id = $this->user_id;
		$query="UPDATE 
				jorge_favorites 
			SET 
				ext = NULL
			WHERE 
				owner_id='$user_id' 
			AND 
				peer_name_id='$peer_name_id' 
			AND 
				peer_server_id='$peer_server_id' 
			AND 
				tslice='$tslice'
		";
	
		return $this->update($query);

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

			elseif($type==="date") {

				list($ye, $mo, $da) = split("-", $val);
				if (!ctype_digit($ye) || !ctype_digit($mo) || !ctype_digit($da)) { 
		
						$this->is_error = true;
						return false;
						
					} 
					else { 
					
						return $val;
						
				}

				$this->is_error = true;
				return false;
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
