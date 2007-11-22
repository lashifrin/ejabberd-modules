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
print '<h2>'.$con_head[$lang].'</h2>';
print '<small>'.$con_notice[$lang].'</small>';

if ($_POST) {

	// get all post data...
	while (array_keys($_POST)) {

		$jid = base64_decode(str_replace("kezyt2s0", "+", key($_POST)));
		$val = array_shift($_POST);

		if ($val=="n") {
			$do_not_log_list .=$jid."\n";
			}



	}
	$do_not_log_list = mysql_escape_string($do_not_log_list);
	$query="update logdb_settings_$xmpp_host set donotlog_list='$do_not_log_list' where owner_id='$user_id'";
	mysql_query($query) or die ("Error");
	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 150pt;">'.$con_saved[$lang].'</div></center><br>';

}

// clear _post data
$_POST="";

$res = pg_query($bazaj, "select a.nick, a.jid, b.grp from rosterusers a left outer join rostergroups b on (a.jid=b.jid and a.username=b.username) where a.username='$token' and a.nick !='' order by b.grp,lower(a.nick)");
if (!$res) {
	print "Ooops...";
	pg_close($jmon);
	exit;
}

if (pg_num_rows($res)!=0) {

	$do_notlog_list = get_do_log_list($user_id,$xmpp_host);

	print '<center>';
	print '<form action="contacts.php" method="post">'."\n";
	print '<table id="maincontent" border="0" class="ff" cellspacing="0">'."\n";
	print '<tr style="background-image: url(img/bar_bg.png); background-repeat:repeat-x; font-weight: bold;"><td>'.$con_tab2[$lang].'</td><td>'.$con_tab3[$lang].'</td><td>'.$con_tab6[$lang].'</td><td>'.$con_tab4[$lang].'</td></tr>'."\n";
	print '<tr class="spacer"><td colspan="4"></td></tr>';
	print '<tbody id="searchfield">';

	for ($lt = 0; $lt < pg_numrows($res); $lt++) {
		$nick = pg_result($res, $lt, 0);
		$jid = pg_result($res,$lt,1);
		$grp = pg_result($res,$lt,2);
		if ($grp=="") { $grp=$con_no_g[$lang]; }
		if ($col=="e0e9f7") { $col="e8eef7"; } else { $col="e0e9f7"; }
		$predefined="$jid";
		$predefined=encode_url($predefined,$token,$url_key);
		if (in_array($jid,$do_notlog_list) == TRUE ) { $selected="selected"; } else { $selected=""; }
		if ($selected!="") { $col="b7b7b7"; }
		print '<tr style="cursor: pointer;" bgcolor="'.$col.'" onMouseOver="this.bgColor=\'c3d9ff\';" onMouseOut="this.bgColor=\'#'.$col.'\';">'."\n";
		print '<td title="'.$con_title[$lang].'" style="padding-left:7px" onclick="window.location=\'chat_map.php?chat_map='.$predefined.'\';"><b>'.cut_nick(htmlspecialchars($nick)).'</b></td>'."\n";
		print '<td title="'.$con_title[$lang].'" onclick="window.location=\'chat_map.php?chat_map='.$predefined.'\';">(<i>'.htmlspecialchars($jid).'</i>)</td>'."\n";
		print '<td title="'.$con_title[$lang].'" onclick="window.location=\'chat_map.php?chat_map='.$predefined.'\';" style="text-align: center;">'.cut_nick(htmlspecialchars($grp)).'</td>'."\n";
		print '<td style="text-align: center;">'."\n";
		// temporary solution we should put integers here instead of full jids
		$prepared_jid=str_replace("+", "kezyt2s0", base64_encode($jid)); 
		print '<select class="cc2" name="'.$prepared_jid.'">'."\n";
		print '<option value="y">'.$con_tab_act_y[$lang].'</option>'."\n";
		print '<option value="n" '.$selected.' >'.$con_tab_act_n[$lang].'</option>'."\n";
		print '</select>'."\n";
		print '</td>'."\n";
		print '</tr>'."\n";

	}

	print '<tr class="spacer"><td colspan="4"></td></tr>'."\n";
	print '</tbody>'."\n";
	print '<tr class="maint"><td colspan="4" style="text-align: center;">'."\n";
	print '<input class="red" type="submit" value="'.$con_tab_submit[$lang].'"></td></tr>'."\n";
	print '<tr class="spacer"><td colspan="4"></td></tr>'."\n";
	print '</table>'."\n";
	print '</form>'."\n";
	print '</center>'."\n";

	}

	else

	{

	print '<p align="center"><b>'.$no_contacts[$lang].'</b></p>';

	}

include ("footer.php");
?>
