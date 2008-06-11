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
require_once("headers.php");
require_once("upper.php");

print '<h2>'.$chat_map[$lang].'</h2>';
print '<small>'.$chat_select[$lang].'</small><br><br>';
if ($_POST['chat_map']) {
	$con_map=decode_url_simple($_POST['chat_map'],TOKEN,$url_key);
	}
	elseif ($_GET['chat_map']) {
	$con_map=decode_url_simple($_GET['chat_map'],TOKEN,$url_key);
	}

// prepare roster object
$ejabberd_roster->sort_by_nick("az");
$roster_chat = $ejabberd_roster->get_roster();

print '<form action="chat_map.php" method="post" name="chat_map_form">'."\n";
print '<span style="padding-right: 20px">'.$chat_m_select[$lang].'</span>'."\n";
print '<select id="c_map" style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="chat_map" size="0" onchange="javascript:document.chat_map_form.submit();">'."\n";
print '<option value="null">'.$chat_c_list[$lang].'</option>';

	while (array_keys($roster_chat)) {
		
		$jid = key($roster_chat);
		$roster_item = array_shift($roster_chat);
		$name = $roster_item[nick];
		$grp  = $roster_item[group];
		if ($con_map==$jid) { $selected="selected"; } else { $selected=""; }
		print '<option '.$selected.' value=\''.encode_url($jid,TOKEN,$url_key).'\'>'.htmlspecialchars($name).' ('.htmlspecialchars($grp).')</option>'."\n";

	}

print '</select>';
print '</form>'."\n";

if ($con_map AND $_POST['chat_map'] != "null") {

	print "<h2>".$cal_head[$lang].":</h2>";

	// split username and server name
	list($name_peer,$server_peer) = split("@",$con_map);

	// get the id's of user and server
	$db->get_user_id($name_peer);
	$peer_name_id = $db->result->user_id;
	$db->get_server_id($server_peer);
	$peer_server_id = $db->result->server_id;

	if ($peer_name_id !== null AND $peer_server_id !== null) {
	
		//first get the months
		$db->get_chat_map($peer_name_id,$peer_server_id);
		$result1 = $db->result;
		$cc_cmp = count($result1);
		foreach ($result1 as $row_m) {

			// hack for proper date parsing
			list($y,$m) = split("-",$row_m[at]);
			$mo="$y-$m";
		
			// now get the days in with user was talking
			$db->get_chat_map_specyfic($peer_name_id,$peer_server_id,$mo);
			$result2 = $db->result;
			
			foreach($result2 as $row_day) {

					// now scan day for chats, yep thats weak, but as long as we dont have right stats table this will work...
					$i++;
					list($y,$m,$d) = split("-",$row_day[at]);
					$days[$i] = $d;
			}

			if (count($days)>=1) {
				
					print '<div style="float: left;">';
					echo pl_znaczki(calendar($user_id,$xmpp_host,$y,$m,$days,TOKEN,$url_key,$months_name_eng,$left,$right,$selected,$lang,$view_type,2,$peer_name_id,$peer_server_id,$cal_days));
					unset($days);
					print '</div>';
				
				}
			else {
			
				$score++;

			}
		$i=0;

		}

	}

	else {

		$cc_cmp = $score;
	}


if ($score==$cc_cmp) { print '<span style="text-align: center;"><h2>'.$chat_no_chats[$lang].'</h2></span>'; }

}

require_once("footer.php");
?>
