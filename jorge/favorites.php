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

require("headers.php");
require("upper.php");

print '<h2>'.$fav_main[$lang].'</h2>';
print '<small>'.$fav_desc[$lang].'</small>';
?>
<script language="javascript" type="text/javascript">

// prepare the form when the DOM is ready 
$(document).ready(function() { 
    // bind form using ajaxForm 
    $('#fav_form').ajaxForm({ 
        // target identifies the element(s) to update with the server response 
        target: '#fav_result', 
 
        // success identifies the function to invoke when the server response 
        // has been received; here we apply a fade-in effect to the new content 
        success: function() { 
            $('#fav_result').fadeIn('slow'); 
        } 
    }); 
});
</script>

<?




// fetch results
$result=do_sel("select * from jorge_favorites where owner_id='$user_id' order by tslice desc");
if (mysql_num_rows($result)>0) {

	print '<center>';
	print '<span id="fav_result"></span>';
	print '<form style="margin-bottom: 0;" id="fav_form" action="req_process.php" method="post">';
	print '<input type="hidden" name="req" value="2">';
	print '<table id="maincontent" bgcolor="#ffffff" class="ff" cellspacing="0" cellpadding="3">';
	print '<tr class="header"><td>'.$fav_contact[$lang].'</td><td>'.$fav_when[$lang].'</td><td>'.$fav_comment[$lang].'</td><td>'.$fav_remove[$lang].'</td></tr>';
	print '<tr class="spacer" height="1px"><td colspan="4"></td></tr>';
	print '<tbody id="searchfield">';
	$i=0;
	while($row=mysql_fetch_array($result)) {
		$i++;
		$username=get_user_name($row[peer_name_id],$xmpp_host);
		$server=get_server_name($row[peer_server_id],$xmpp_host);
		$nickname=htmlspecialchars(query_nick_name($bazaj,$token,pg_escape_string($username),pg_escape_string($server)));
		$to_base = "$row[tslice]@$row[peer_name_id]@$row[peer_server_id]@";
		$to_base = encode_url($to_base,$token,$url_key);
		print '<tr id="'.$i.'"><td> <a href="'.$view_type.'?a='.$to_base.'&loc=3"><u><b>'.$nickname.'</b> (<i>'.htmlspecialchars($username).'@'.htmlspecialchars($server).'</i>)</u></a></td>';
		print '<td>'.$row[tslice].'</td>';
		if ($row[comment]==NULL) {
				print '<td>Add comment</td>';
			}
			else {
				print '<td>'.$row[comment].'</td>';
			}
		print '<td style="text-align: center;">';
		print '<input name="'.$i.'" type="checkbox" value="'.$to_base.'" />';
		print '</td>';
		print '</tr>';

	}
	print '</tbody>';
	print '<tr class="foot"><td height="14px" colspan="4" style="text-align: right;"><input class="fav" type="Submit" value="'.$fav_remove[$lang].'"></td></tr>';
	print '</table></center>';
	print '</form>';
}

else {
	print '<center>';
	print '<div class="message" style="width: 450px;">'.$fav_empty[$lang].'</div>';
	print '</center>';
	}


include("footer.php");
?>
