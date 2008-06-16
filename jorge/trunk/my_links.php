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

$tigger = $_POST['trigger'];
$desc = $_POST['desc'];
$del = $_GET['del'];
$link_id = $_GET['link_id'];

require_once("upper.php");
// decode incomming link
if ($_GET[a]) {

		if ($enc->decrypt_url($_GET[a]) === true) {

				$variables[tslice] = $enc->tslice;
				$variables[peer_name_id] = $enc->peer_name_id;
				$variables[peer_server_id] = $enc->peer_server_id;
				$variables[lnk] = $enc->lnk;
				$variables[linktag] = $enc->linktag;
				$variables[strt] = $enc->strt;
				$variables[ismylink] = $enc->ismylink;

			}
			else {

				unset($variables);

			}

}

if ($del=="t") {

		if ($db->del_mylink($link_id) === true) {
		
				print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 250pt;">'.$my_links_removed[$lang].'</div></center>';
			}

			else {
				
				print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 250pt;">'.$oper_fail[$lang].'</div></center>';
			
			}

}


if ($tigger===$my_links_commit[$lang]) {

		if ($enc->decrypt_url($_POST[hidden_field]) === true) {
			
				$peer_name_id = $enc->peer_name_id;
				$peer_server_id = $enc->peer_server_id;
				$datat = $enc->tslice;
				$lnk = $enc->lnk;
	
		
				if ($desc===$my_links_optional[$lang]) { 
	
						$desc=$my_links_none[$lang]; 
			
					}
		
				$desc=substr($desc,0,120);
				$db->add_mylink($peer_name_id,$peer_server_id,$datat,$lnk,$desc);
				print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 150pt;">'.$my_links_added[$lang];
				print '<br><a href="'.$view_type.'?a='.$lnk.'" style="color: blue;"><b>'.$my_links_back[$lang].'</b></a></div></center>';
	
		}

}

if ($variables[ismylink] === "1") {

	$db->get_server_name($enc->peer_server_id);
	$sname = $db->result->server_name;
	$db->get_user_name($enc->peer_name_id);
	$uname = $db->result->username;
	$nickname=query_nick_name($ejabberd_roster,$uname,$sname);
	$jid=''.$uname.'@'.$sname.'';

	print '<center>'."\n";
	print ''.$my_links_save_d[$lang].'<br />'."\n";
	print '<table class="ff" border="0" cellspacing="0">'."\n";
	print '<form action="my_links.php" method="post">'."\n";
	print '<tr><td height="5"></td></tr>'."\n";
	print '<tr class="main_row_b"><td style="text-align:center;">'.$my_links_chat[$lang].'&nbsp;&nbsp;'."\n";
	print '<b>'.cut_nick($nickname).'</b> (<i>'.htmlspecialchars($jid).'</i>)</td></tr>'."\n";
	print '<tr><td height="5"></td></tr>'."\n";
	print '<tr><td colspan="3" align="center"><textarea class="ccc" name="desc" rows="4">'.$my_links_optional[$lang].'</textarea></td></tr>'."\n";
	print '<tr><td colspan="3" align="center"><input name="trigger" class="red" type="submit" value="'.$my_links_commit[$lang].'">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	print '<input class="red" type="button" value="'.$my_links_cancel[$lang].'" onClick="parent.location=\''.$view_type.'?a='.$enc->lnk.'&start='.htmlspecialchars($enc->strt).'#'.htmlspecialchars($enc->linktag).'\'"></td>';
	print '</tr>'."\n";
	print '<tr><td>'."\n";
	$hidden_fields = $enc->crypt_url("tslice=$enc->tslice&peer_name_id=$variables[peer_name_id]&peer_server_id=$variables[peer_server_id]&lnk=$variables[lnk]&strt=$variables[strt]&linktag=$variables[linktag]");
	print '<input type="hidden" name="hidden_field" value="'.$hidden_fields.'">'."\n";
	print '</form>'."\n";
	print '</table>'."\n";
	print '</center>'."\n";
	print '<br /><br /><br /><br />';

}

// head
print '<h2>'.$my_links_desc_m[$lang].'</h2>';
print '<small>'.$my_links_desc_e[$lang].'</small>';

$db->get_mylinks_count();
if ($db->result->cnt === "0") { 
		
		print '<center><div class="message" style="width: 250px;">'.$my_links_no_links[$lang].'</div></center>'; 
		
		}
	else {

		print '<center>'."\n";
		print '<table id="maincontent" class="ff" cellspacing="0">'."\n";
		print '<tr class="header"><td>'.$my_links_link[$lang].'</td><td>'.$my_links_chat[$lang].'</td><td>'.$my_links_desc[$lang].'</td></tr>'."\n";
		print '<tr class="spacer" height="1px"><td colspan="4"></td></tr>';
		print '<tbody id="searchfield">';
		$db->get_mylink();
		$result = $db->result;
		foreach ($result as $entry) {

			print '<tr style="cursor: pointer;" bgcolor="#e8eef7" onMouseOver="this.bgColor=\'c3d9ff\';" onMouseOut="this.bgColor=\'#e8eef7\';">'."\n";
			print '<td onclick="window.location=\''.$view_type.'?a='.$entry['link'].'\';" style="padding-left: 10px; padding-right: 10px">'.pl_znaczki(verbose_date($entry['datat'],$lang)).'</td>'."\n";
			$nickname=query_nick_name($ejabberd_roster,get_user_name($entry[peer_name_id],$xmpp_host), get_server_name($entry[peer_server_id],$xmpp_host));
			$jid=get_user_name($entry[peer_name_id],$xmpp_host).'@'.get_server_name($entry[peer_server_id],$xmpp_host);
			print '<td onclick="window.location=\''.$view_type.'?a='.$entry['link'].'\';">&nbsp;<b>'.cut_nick(htmlspecialchars($nickname)).'</b> ('.htmlspecialchars($jid).')&nbsp;</td>'."\n";
			$opis=htmlspecialchars($entry[description]);
			print '<td onclick="window.location=\''.$view_type.'?a='.$entry['link'].'\';">&nbsp;'.$opis.'</td>'."\n";
			print '<td><a href="my_links.php?del=t&link_id='.$entry[id_link].'" onClick="if (!confirm(\''.$del_conf_my_link[$lang].'\')) return false;" >&nbsp;'.$del_my_link[$lang].'&nbsp;</a></td>'."\n";
			print '</tr>'."\n";
		}
	print '</tbody>';
	print '<tr class="spacer"><td colspan="4"></td></tr>';
	print '<tr class="foot"><td colspan="4" height="15"></td></tr>';
	print '</table>'."\n";
	print '</center>'."\n";
	}


require_once("footer.php");
?>
