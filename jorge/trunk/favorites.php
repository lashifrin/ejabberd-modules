<?
/*
Jorge - frontend for mod_logdb - ejabberd server-side message archive module.

Copyright (C) 2008 Zbigniew Zolkiewski

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

$html->set_body('<h2>'.$fav_main[$lang].'</h2><small>'.$fav_desc[$lang].'</small>

		<script language="javascript" type="text/javascript">
			// prepare the form when the DOM is ready 
			$(document).ready(function() { 
    				// bind form using ajaxForm 
    				$(\'#fav_form\').ajaxForm({ 
        				// target identifies the element(s) to update with the server response 
        				target: \'#fav_result\', 
 
 				       	// success identifies the function to invoke when the server response 
        				// has been received; here we apply a fade-in effect to the new content 
        				success: function() { 
            					$(\'#fav_result\').fadeIn(\'slow\'); 
        				} 
    				}); 
			});
		</script>

		<script type="text/javascript">
		function toggle(box,theId) {
			if(document.getElementById) {
				var cell = document.getElementById(theId);
				if(box.checked) {
					cell.className = "on";
				}
				else {
					cell.className = "off";
				}
			}
		}
		</script>

		<style type="text/css">
			.on {background-color: #84c1df;}
			.off {background-color: #e8eef7;}
		</style>

	');

// fetch results
$result=do_sel("select * from jorge_favorites where owner_id='$user_id' and ext is NULL order by tslice desc");

if (mysql_num_rows($result)>0) {

		$html->set_body('<center>
			<span id="fav_result"></span>
			<form style="margin-bottom: 0;" id="fav_form" action="req_process.php" method="post">
			<input type="hidden" name="req" value="2">
			<table id="maincontent" bgcolor="#e8eef7" class="ff" cellspacing="0" cellpadding="3">
			<tr class="header"><td>'.$fav_contact[$lang].'</td><td>'.$fav_when[$lang].'</td>
			<td><input class="submit" type="Submit" value="'.$fav_remove[$lang].'"></td></tr>
			<tr class="spacer" height="1px"><td colspan="3"></td></tr>
			<tbody id="searchfield">
		');
		$i=0;
		while($row=mysql_fetch_array($result)) {

			$i++;
			$username=get_user_name($row[peer_name_id],$xmpp_host);
			$server=get_server_name($row[peer_server_id],$xmpp_host);
			$nickname=query_nick_name($ejabberd_roster,$username,$server);
			$to_base = $enc->crypt_url("tslice=$row[tslice]&peer_name_id=$row[peer_name_id]&peer_server_id=$row[peer_server_id]");
			$html->set_body('
				<tr id="'.$i.'"><td class="rowspace"> <a href="'.$view_type.'?a='.$to_base.'&loc=3"><u><b>'.$nickname.'</b> (<i>'.htmlspecialchars($username).'@'.htmlspecialchars($server).'</i>)</u></a></td>
				<td class="rowspace">'.$row[tslice].'</td>
				<td style="text-align: center;">
				<input name="'.$i.'" type="checkbox" value="'.$to_base.'" onclick="toggle(this,\''.$i.'\')" />
				</td></tr>
			');

		}
		$html->set_body('</tbody>
			<tr class="foot"><td colspan="2"></td><td height="14px" style="text-align: right;">
			<input class="submit" type="Submit" value="'.$fav_remove[$lang].'"></td></tr>
			</table></center></form>
		');

	}

	else {

		$html->set_bod('<center><div class="message" style="width: 450px;">'.$fav_empty[$lang].'</div></center>');
	
}

require_once("footer.php");
?>
