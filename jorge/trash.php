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
print '<h2>'.$trash_name[$lang].'</h2>';
print '<small>'.$trash_desc[$lang].'</small></h2>';

$action=$_GET['a'];

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
if (validate_date($tslice)=="f") { unset($action); $unset($tslice); }

if ($action=="undelete") {

        	if (undo_deleted_chat($talker,$server,$user_id,$tslice,$xmpp_host,$lnk)=="t") {

			$back_link="$tslice@$talker@$server@";
			$back_link=encode_url($back_link,$token,$url_key);
                	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">'.$undo_info[$lang].'<br>';
			print '<a href="'.$view_type.'?a='.$back_link.'" style="color: blue;">'.$trash_vit[$lang].'</a></div></center><br>';

        		}

        	else

        	{

                	unset($talker);
                	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">';
                	print 'Unusual error accured during processing your request. Please report it (Code:JUF).</div></center>';

        	}

}

if ($action=="delete") {

	// this is additional check - if fail, do nothing
	if (ctype_digit($talker) OR ctype_digit($server)) {
		if ((mysql_query("delete from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' and ext = '1'")==TRUE)) {
			// cleanup, unfortunately we are not operating on transactions :/
			mysql_query("delete from jorge_mylinks where owner_id='$user_id' and ext='1' and peer_name_id = '$talker' and peer_server_id='$server' and datat = '$tslice'");
			mysql_query("delete from pending_del where owner_id='$user_id' and peer_name_id = '$talker' and peer_server_id='$server' and date='$tslice'");
			print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">'.$del_info[$lang].'</div></center><br>';
		}
		else {

			print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">';
			print 'Unusual error accured during processing your request. Please report it (Code:JTD).</div></center>';	
		}

	}

}


$result = mysql_query("select * from pending_del where owner_id = '$user_id' order by str_to_date(date,'%Y-%m-%d') desc");

if (mysql_num_rows($result)==0) {
	print '<center>'.$trash_empty[$lang].'</center>';
	}

	else

	{
		print '<table class="ff" align="center" border="0"  cellspacing="0">';
		print '<tr style="background-image: url(img/bar_new.png); background-repeat:repeat-x; font-weight: bold; color: #fff;"><td style="padding-right: 15px;">'.$my_links_chat[$lang].'</td><td style="padding-right: 15px;">'.$logger_from_day[$lang].'</td><td>'.$del_time[$lang].'</td></tr>';
		print '<tr class="spacer"><td colspan="5"></td></tr>';

		while ($entry=mysql_fetch_array($result)) {


			$talker = get_user_name($entry["peer_name_id"],$xmpp_host);
			$server_name = get_server_name($entry["peer_server_id"],$xmpp_host);
			$tslice = $entry["date"];
			$nickname = query_nick_name($bazaj,$token,$talker,$server_name);
			print '<tr><td style="padding-left: 10px; padding-right: 10px;"><b>'.htmlspecialchars($nickname).'</b> (<i>'.htmlspecialchars($talker).'@'.htmlspecialchars($server_name).'</i>)</td><td style="text-align: center;">'.$tslice.'</td>';
			print '<td style="padding-left: 5px; padding-right: 5px; font-size: x-small;">'.$entry[timeframe].'</td>';	
			$reconstruct_link = encode_url("$tslice@$entry[peer_name_id]@$entry[peer_server_id]@", $token,$url_key); // try to reconstruct oryginal link
			$undelete_link = "$tslice@$entry[peer_name_id]@$entry[peer_server_id]@@@$reconstruct_link@undelete@";
			$undelete_link = encode_url($undelete_link,$token,$url_key);
			$delete_link = "$tslice@$entry[peer_name_id]@$entry[peer_server_id]@@@$reconstruct_link@delete@";
			$delete_link = encode_url($delete_link,$token,$url_key);
			print '<td style="padding-left: 10px;"><a href="trash.php?a='.$undelete_link.'">'.$trash_undel[$lang].'</a></td>';
			print '<td style="padding-left: 10px;"><a href="trash.php?a='.$delete_link.'" onClick="if (!confirm(\''.$del_conf[$lang].'\')) return false;">'.$trash_del[$lang].'</a></td>';
			print '</tr>';

		}
		print '<tr class="spacer"><td colspan="5"></td></tr>';
		print '<tr style="background-image: url(img/bar_new.png); background-repeat:repeat-x; font-weight: bold;"><td colspan="5" height="15"></td></tr>';
		print '</table>';
	}
include("footer.php");
?>
