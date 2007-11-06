<?
/*
Jorge - frontend for mod_logdb - ejabberd server-side message archive module.

Copyright (C) 2007 Zbigniew Zolkiewski

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
require ("headers.php");
include ("upper.php");
print '<h2>'.$menu_item7[$lang].'</h2>';
print '<small>'.$trash_desc[$lang].'</h2>';

$action=$_GET['a'];

if ($action) {

	// decompose link
	$variables = decode_url2($action,$token,$url_key);
	$tslice = $variables[tslice];
	$talker = $variables[talker];
	$server = $variables[server];
	$action = $variables[action];
	$lnk = $variables[lnk];
	// validation
	$talker=mysql_escape_string($talker);
	$server=mysql_escape_string($server);
	if (validate_date($tslice) == "f") { unset ($tslice); unset($action); unset($talker); exit; }

	// undelete chat
	$query="update `logdb_messages_$tslice"."_$xmpp_host` set ext = NULL where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server'";
	$result=mysql_query($query) or die ("Ooops...Error");
	// remove from pending table
	$query="delete from pending_del where owner_id='$user_id' and peer_name_id='$talker' and date='$tslice' and peer_server_id='$server'";
	$result=mysql_query($query) or die ("Ooops...Error1");
	// recount message stats for user
	$query="select count(body) from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$user_id' and ext is NULL";
	$result=mysql_query($query) or die ("Ooops...Error1");
	$row=mysql_fetch_row($result);
	$new_stats=$row[0];
	mysql_free_result($result);

	$query="select * from `logdb_stats_$xmpp_host` where owner_id = '$user_id' and at = '$tslice'";
	$result=mysql_query($query) or die("Ooops...Error1");
	if (mysql_num_rows($result) < 1 ) {
			$query="insert into `logdb_stats_$xmpp_host` (owner_id,at,count) values ('$user_id','$tslice','$new_stats')";
			mysql_query($query) or die ("Ooops...Error2.0");
			mysql_free_result($result);
		}
		else
		{
			$query="update `logdb_stats_$xmpp_host` set count='$new_stats' where owner_id='$user_id' and at='$tslice'";
			$result=mysql_query($query) or die ("Ooops...Error2");
			mysql_free_result($result);
		}

	// undelete saved links
	$query="update jorge_mylinks set ext=NULL where owner_id ='$user_id' and peer_name_id='$talker' and link like '$lnk%'";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);
	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">'.$trash_recovered[$lang].'</a></div></center><br><br>';


}



$result = mysql_query("select * from pending_del where owner_id = '$user_id'");

if (mysql_num_rows($result)==0) {
	print '<center>'.$trash_empty[$lang].'</center>';
	}

	else

	{
		print '<table class="ff" align="center" border="0"  cellspacing="0">';
		print '<tr style="background-image: url(img/bar_bg.png); background-repeat:repeat-x; font-weight: bold;"><td style="padding-right: 15px;">'.$my_links_chat[$lang].'</td><td style="padding-right: 15px;">'.$logger_from_day[$lang].'</td><td style="padding-right: 15px;">'.$trash_link[$lang].':</td></tr>';
		print '<tr class="spacer"><td colspan="3"></td></tr>';

		while ($entry=mysql_fetch_array($result)) {


			$talker = get_user_name($entry["peer_name_id"],$xmpp_host);
			$server_name = get_server_name($entry["peer_server_id"],$xmpp_host);
			$tslice = $entry["date"];
			$nickname = query_nick_name($bazaj,$token,$talker,$server_name);
			print '<tr><td style="padding-left: 10px; padding-right: 10px;"><b>'.htmlspecialchars($nickname).'</b> (<i>'.htmlspecialchars($talker).'@'.htmlspecialchars($server_name).'</i>)</td><td style="text-align: center;">'.$tslice.'</td>';
		
			$reconstruct_link = encode_url("$tslice@$entry[peer_name_id]@$entry[peer_server_id]@", $token,$url_key); // try to reconstruct oryginal link
			$undelete_link = "$tslice@$entry[peer_name_id]@$entry[peer_server_id]@@@$reconstruct_link@undelete@";
			$undelete_link = encode_url($undelete_link,$token,$url_key);
			print '<td style="padding-left: 10px;"><a href="trash.php?a='.$undelete_link.'">'.$trash_undel[$lang].'</a></td></tr>';

		}
		print '<tr class="spacer"><td colspan="3"></td></tr>';
		print '<tr style="background-image: url(img/bar_bg.png); background-repeat:repeat-x; font-weight: bold;"><td colspan="3" height="15"></td></tr>';
		print '</table>';
	




	}






include("footer.php");
?>
