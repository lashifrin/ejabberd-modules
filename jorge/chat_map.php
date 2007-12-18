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
print '<h2>'.$chat_map[$lang].'</h2>';
print '<small>'.$chat_select[$lang].'</small><br><br>';
if ($_POST['chat_map']) {
	$con_map=decode_url_simple($_POST['chat_map'],$token,$url_key);
	}
	elseif ($_GET['chat_map']) {
	$con_map=decode_url_simple($_GET['chat_map'],$token,$url_key);
	}

// this is tempory workaround.
$contact_list="select a.nick, a.jid, b.grp from rosterusers a left outer join rostergroups b on (a.jid=b.jid and a.username=b.username) where a.username='$token' and a.nick !='' order by lower(a.nick)";
	$res = pg_query($bazaj, $contact_list);
	if (!$res) {
	        print "Ooops...";
		        pg_close($bazaj);
			        exit;
				}

print '<form action="chat_map.php" method="post" name="chat_map_form">'."\n";
print '<span style="padding-right: 20px">'.$chat_m_select[$lang].'</span>'."\n";
print '<select id="c_map" style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="chat_map" size="0" onchange="javascript:document.chat_map_form.submit();">'."\n";
print '<option value="null">'.$chat_c_list[$lang].'</option>';
	for ($lt = 0; $lt < pg_numrows($res); $lt++) {
		$name = pg_result($res, $lt, 0);
		$jid = pg_result($res,$lt,1);
		$grp = pg_result($res,$lt,2);
		if ($grp=="") { $grp=$map_no_g[$lang]; }
		if ($con_map==$jid) { $selected="selected"; } else { $selected=""; }
		print '<option '.$selected.' value=\''.encode_url($jid,$token,$url_key).'\'>'.htmlspecialchars($name).' ('.htmlspecialchars($grp).')</option>'."\n";
	}
print '</select>';
print '</form>'."\n";
if ($con_map AND $_POST['chat_map'] != "null") {

	print "<h2>".$cal_head[$lang].":</h2>";

	// split username and server name
	list($name_peer,$server_peer) = split("@",$con_map);

	// get the id's of user and server
	$name_peer=get_user_id(mysql_escape_string($name_peer),$xmpp_host);
	$server_peer=get_server_id(mysql_escape_string($server_peer),$xmpp_host);
	//validate, always should be integers
	if (!ctype_digit($name_peer) OR !ctype_digit($server_peer)) { unset($con_map); unset($name_peer); unset($server_peer); }

	//begin
	//first get the months
	$get_months="select substring(at,1,7) as at from `logdb_stats_jabster_pl` where owner_id='$user_id' and peer_name_id='$name_peer' and peer_server_id='$server_peer' group by substring(at,1,7) order by str_to_date(at,'%Y-%m-%d') asc";
	$result_m=mysql_query($get_months);
	$cc_cmp=mysql_num_rows($result_m);
	while($row_m=mysql_fetch_array($result_m)) {
		// hack for proper date parsing
		list($y,$m) = split("-",$row_m[at]);
		$mo="$y-$m";
		
		// now get the days in with user was talking
		$days_to_scan="select at from `logdb_stats_jabster_pl` where owner_id='$user_id' and peer_name_id='$name_peer' and peer_server_id='$server_peer' and at like '$mo%'";

		$result=mysql_query($days_to_scan);

			while($row_day=mysql_fetch_array($result)) {

				// now scan day for chats, yep thats weak, but as long as we dont have right stats table this will work...
					$i++;
					list($y,$m,$d) = split("-",$row_day[at]);
					$days[$i] = $d;
			}

		if (count($days)>=1) {
			print '<div style="float: left;">';
			echo pl_znaczki(calendar($user_id,$xmpp_host,$y,$m,$days,$token,$url_key,$months_name_eng,$left,$right,$selected,$lang,$view_type,2,$name_peer,$server_peer));
			unset($days);
			print '</div>';
			}
			else {
			
				$score++;

			}
		$i=0;

	}


if ($score==$cc_cmp) { print '<span style="text-align: center;"><h2>'.$chat_no_chats[$lang].'</h2></span>'; }


}


include ("footer.php");
?>
