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

// sorting options
$get_sort = $_GET['sort'];
$get_dir = $_GET['o'];

// validate
if (!ctype_digit($get_sort) AND !ctype_digit($get_dir)) { unset($get_sort); unset($get_dir); }

if ($get_dir=="1") {
		$dir="za";
		$get_dir="2";
	}
	elseif($get_dir=="2"){
		$dir="az";
		$get_dir="1";
	}
	else{
		$dir="az";
		$get_dir="2";
	}

if ($get_sort=="1") {
		$ejabberd_roster->sort_by_jid($dir);
	}
	elseif($get_sort=="2") {
		$ejabberd_roster->sort_by_nick($dir);
	}
	elseif($get_sort=="3") {

		$ejabberd_roster->sort_by_group($dir);
	}
	else{
		$ejabberd_roster->sort_by_nick_group();
	}


$roster_con = $ejabberd_roster->get_roster();

if ($roster_con) {

	$do_notlog_list = get_do_log_list($user_id,$xmpp_host);

	print '<center>';
	print '<form action="contacts.php" method="post">'."\n";
	print '<table id="maincontent" border="0" class="ff" cellspacing="0">'."\n";
	// show "reset sorting" only when sorting
	if ($get_sort) {
		print '<tr><td colspan="5" style="text-align: right; font-size: x-small;"><a href="contacts.php">'.$reset_sort[$lang].'</a></td></tr>';
		}
	print '<tr class="header">
		<td><a href="?sort=2&o='.$get_dir.'"><span style="color: white;">'.$con_tab2[$lang].'&nbsp;&#8593;&#8595;</span></a></td>
		<td><a href="?sort=1&o='.$get_dir.'"><span style="color: white;">'.$con_tab3[$lang].'&nbsp;&#8593;&#8595;</span></a></td>
		<td style="text-align: center;"><a href="?sort=3&o='.$get_dir.'"><span style="color: white;">'.$con_tab6[$lang].'&nbsp;&#8593;&#8595;</span></a></td>
		<td>'.$show_chats[$lang].':</td>
		<td style="padding-left: 10px;">'.$con_tab4[$lang].'</td>
		</tr>'."\n";
	print '<tr class="spacer"><td colspan="5"></td></tr>';
	print '<tbody id="searchfield">';

	while (array_keys($roster_con)) {

		$jid = key($roster_con);
		$roster_item = array_shift($roster_con);
		$nick = $roster_item[nick];
		$grp  = $roster_item[group];
		if ($col=="e0e9f7") { $col="e8eef7"; } else { $col="e0e9f7"; }
		$predefined="$jid";
		$predefined=encode_url($predefined,$token,$url_key);
		$predefined_s="from:$jid";
		$predefined_s=encode_url($predefined_s,$token,$url_key);
		if (in_array($jid,$do_notlog_list) == TRUE ) { $selected="selected"; } else { $selected=""; }
		if ($selected!="") { $col="b7b7b7"; }
		print '<tr bgcolor="'.$col.'" onMouseOver="this.bgColor=\'c3d9ff\';" onMouseOut="this.bgColor=\'#'.$col.'\';">'."\n";
		print '<td title="'.$con_title[$lang].'" style="padding-left:7px" onclick="window.location=\'chat_map.php?chat_map='.$predefined.'\';"><b>'.cut_nick(htmlspecialchars($nick)).'</b></td>'."\n";
		print '<td>(<i>'.htmlspecialchars($jid).'</i>)</td>'."\n";
		print '<td style="text-align: center;">'.cut_nick(htmlspecialchars($grp)).'</td>'."\n";
		print '<td style="text-align: center;"><a href="chat_map.php?chat_map='.$predefined.'"><u>'.$show_chat_as_map[$lang].'</u></a>|<a href="search_v2.php?b='.$predefined_s.'"><u>'.$show_chat_stream[$lang].'</u></a></td>';
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

	print '<tr class="spacer"><td colspan="5"></td></tr>'."\n";
	print '</tbody>'."\n";
	print '<tr class="foot"><td colspan="5" style="text-align: center;">'."\n";
	print '<input class="submit" type="submit" value="'.$con_tab_submit[$lang].'"></td></tr>'."\n";
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
