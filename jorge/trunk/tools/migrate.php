<?
/*

Run this script if you are upgrading from pre-1.5 version (short links)

*/


include ("../class.db.php");
include ("../class.helper.php");
include ("../func.php");
include ("../config.php");

$db = new db_manager(MYSQL_HOST,MYSQL_NAME,MYSQL_USER,MYSQL_PASS,"mysql","$xmpp_host");
$enc = new url_crypt(ENC_KEY);
$do_query = mysql_query("select * from jorge_mylinks");
mysql_query("begin");

echo "Updating:";

while ($row = mysql_fetch_array($do_query)) {

	$extra = strstr($row[link], "&start");
	$lnk = $enc->crypt_url("tslice=$row[datat]&peer_name_id=$row[peer_name_id]&peer_server_id=$row[peer_server_id]");
	$new_link = $lnk.$extra;
	if (!mysql_query("update jorge_mylinks set link='$new_link' where id_link='$row[id_link]'")) {

		mysql_query("rollback");
		echo "\nError in query!\n";
		exit;
	
	}
	echo "+";


}

mysql_query("commit");
echo "\nDone!\n";

?>
