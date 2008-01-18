<?
#
# This script is used for rebuilding full-text index and maintaining database performance. Run it in following conditions:
# - you changed parameters regarding full-text index
# - there were lot of deletions on tables
# - after longer period of time script was not running (it depends on your DB size)
#
# Refer to MySQL-dev documentation for info how REPAIR and OPTIMIZE statments work.
# NOTE: Edit settings below and replace all CAPSED_TEXT with proper values.
#

error_reporting(E_ERROR);
$conn=mysql_connect("_YOUR_DB_IP_ADDRESS_", "_USER_NAME_", "_PASSWORD_") or die ("DB CONNECT ERROR\n");
mysql_select_db ("_DB_NAME_") or die ("DB SELECT ERROR\n");
$query=mysql_query("show tables");


while ($result=mysql_fetch_array($query)) {

	if (preg_match("/^logdb_messages_.*._REPLACE_THIS_WITH_YOUR_XMPP_HOST/i", $result[Tables_in_REPLACE_THIS_WITH_YOUR_DB_NAME])) { 
		$i++;	
		$repair="REPAIR TABLE `$result[Tables_in_REPLACE_THIS_WITH_YOUR_DB_NAME]` QUICK";
		$res=mysql_query($repair);
		while ($res=mysql_fetch_array($res)) {

			print "Operation: $res[Op],  Table: $res[Table],  Status: $res[Msg_text]"."\n";

		}
		$optimize="OPTIMIZE TABLE `$result[Tables_in_REPLACE_THIS_WITH_YOUR_DB_NAME]`";
		$res=mysql_query($optimize);
		while ($res=mysql_fetch_array($res)) {

			print "Operation: $res[Op],  Table: $res[Table],  Status: $res[Msg_text]"."\n";

		}
		print "--------------\n\n";
	}
}


print "Finish, tables repaired: $i\n";

mysql_close();


?>
