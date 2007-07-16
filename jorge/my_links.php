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

$tigger=$_POST['trigger'];
$aaa=mysql_escape_string($_POST['aaa']);
$datat=mysql_escape_string($_POST['datat']);
$desc=mysql_escape_string($_POST['desc']);
$peer_user=mysql_escape_string($_POST['peer_user']);
$peer_server=mysql_escape_string($_POST['peer_server']);
$del=$_GET['del'];
$link_id=mysql_escape_string($_GET['link_id']);

// some validation
if (!ctype_digit($user_id)) { print 'Ooops...'; exit; }
if ($peer_user) { if (!ctype_digit($peer_user)) { print 'Ooops...'; exit; } }
if ($peer_server) { if (!ctype_digit($peer_server)) { print 'Ooops...'; exit; } }
if ($link_id) { if (!ctype_digit($link_id)) { print 'Ooops...'; exit; } }

include("upper.php");
$variables = decode_url2($_GET[a],$token,$url_key);

// ...and validation
$talker=mysql_escape_string($talker);
$server=mysql_escape_string($server);
validate_date($tslice);



if ($del=="t") {
	if (!ctype_digit($link_id)) { print 'Dont play with that...'; exit; }
	$query="delete from mylinks where owner_id='$user_id' and id_link='$link_id'";
	$result=mysql_query($query) or die ("Ooops...Error");
	print '<center><p style="background-color: yellow;">'.$my_links_removed[$lang].'</p>';
}


if ($tigger==$my_links_commit[$lang]) {

	$user_id=get_user_id($token,$xmpp_host);
	if ($desc==$my_links_optional[$lang]) { $desc=$my_links_none[$lang]; }
	$desc=substr($desc,0,120);
	$query="insert into mylinks (owner_id,peer_name_id,peer_server_id,datat,link,description) values ('$user_id','$peer_user','$peer_server','$datat','$aaa','$desc')";
	$result = mysql_query($query) or die ("Ooops...Error.");
	print '<center><p style="background-color: yellow;">'.$my_links_added[$lang].'</p>';
	print '<a href="main.php?a='.$aaa.'"><b>'.$my_links_back[$lang].'</b></a></center>';
	print '<br /><br />';
}




if ($variables[ismylink]=="1") {

	$sname = get_server_name($variables[server],$xmpp_host);
	$uname = get_user_name($variables[talker],$xmpp_host);
	$nickname=query_nick_name($bazaj,$token,$uname,$sname);
	$jid=''.$uname.'@'.$sname.'';

	print '<center>'."\n";
	print ''.$my_links_save_d[$lang].'<br />'."\n";
	print '<table class="ff" border="0" cellspacing="0">'."\n";
	print '<form action="my_links.php" method="post">'."\n";
	print '<tr><td colspan="3" align="center">'."\n";
	print '<input name="lynk" style="text-align: center;" class="ccc" disabled="disabled" value="';
	print htmlspecialchars($variables[lnk]).'&start='.htmlspecialchars($variables[strt]).'#'.htmlspecialchars($variables[linktag]).'"></td></tr>'."\n";
	print '<tr><td height="5"></td></tr>'."\n";
	print '<tr class="main_row_b"><td style="text-align:center;">'.$my_links_chat[$lang].'&nbsp;&nbsp;'."\n";
	print '<b>'.htmlspecialchars($nickname).'</b> (<i>'.htmlspecialchars($jid).'</i>)</td></tr>'."\n";
	print '<tr><td height="5"></td></tr>'."\n";
	print '<tr><td colspan="3" align="center"><textarea class="ccc" name="desc" rows="4">'.$my_links_optional[$lang].'</textarea></td></tr>'."\n";
	print '<tr><td colspan="3" align="center"><input name="trigger" class="red" type="submit" value="'.$my_links_commit[$lang].'">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	print '<input class="red" type="button" value="'.$my_links_cancel[$lang].'" onClick="parent.location=\'main.php?a='.htmlspecialchars($variables[lnk]).'&start='.htmlspecialchars($variables[strt]).'#'.htmlspecialchars($variables[linktag]).'\'"></td>';
	print '</tr>'."\n";
	print '<tr><td><input type="hidden" name="peer_user" value="'.$variables[talker].'"><input type="hidden" name="peer_server" value="'.$variables[server].'">';
	print '<input type="hidden" name="aaa" value="'.htmlspecialchars($variables[lnk]).'&start='.htmlspecialchars($variables[strt]).'#'.$variables[linktag].'"><input type="hidden" name="datat" value="'.$variables[tslice].'"> </td></tr>'."\n";
	print '</form>'."\n";
	print '</table>'."\n";
	print '</center>'."\n";
	print '<br /><br /><br /><br />';

	}


$query="select * from mylinks where owner_id='$user_id' order by str_to_date(datat,'%Y-%m-%d') desc";
$result=mysql_query($query);

if (mysql_num_rows($result) == "0") { print '<br /><br /><center><b>'.$my_links_no_links[$lang].'</b></center>'; }
	else {

		print '<center>';
		print '<br /><br />';
		print '<table class="ff">';
		print '<tr class="maint"><td>'.$my_links_link[$lang].'</td><td>'.$my_links_chat[$lang].'</td><td>'.$my_links_desc[$lang].'</td></tr>';
		while ($entry = mysql_fetch_array($result)) {

			print '<tr bgcolor="#e8eef7" onMouseOver="this.bgColor=\'c3d9ff\';"onMouseOut="this.bgColor=\'#e8eef7\';" >';
			print '<td><a href="main.php?a='.$entry['link'].'" target="_blank">'.pl_znaczki(verbose_date($entry['datat'],$lang)).'</a></td>';
			$nickname=query_nick_name($bazaj,  $token,  get_user_name($entry[peer_name_id],$xmpp_host), get_server_name($entry[peer_server_id],$xmpp_host));
			$jid=get_user_name($entry[peer_name_id],$xmpp_host).'@'.get_server_name($entry[peer_server_id],$xmpp_host);
			print '<td>&nbsp;<b>'.htmlspecialchars($nickname).'</b> (<i>'.htmlspecialchars($jid).'</i>)&nbsp;</td>';
			$opis=htmlspecialchars($entry[description]);
			print '<td>&nbsp;'.$opis.'</td>';
			print '<td><a href="my_links.php?del=t&link_id='.$entry[id_link].'" onClick="if (!confirm(\''.$del_conf_my_link[$lang].'\')) return false;" >&nbsp;'.$del_my_link[$lang].'&nbsp;</a></td>';
			print '</tr>';
		}

	print '</table>';
	print '</center>';
	}


include("footer.php");
?>
