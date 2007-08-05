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

$tgle=$_POST['toggle'];

// czy archiwizacja w³±czona?
if ($sess->get('enabled') == "f") { header ("Location: not_enabled.php"); }

include("upper.php");

// zmiana w profilu logowania
if ($tgle) { 
	$rres=update_set_log_tgle($user_id,$xmpp_host);
	if ($rres=="on") {
				$sess->set('log_status','1');
				$query="insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time) values ('$user_id',7,1,NOW())";
				mysql_query($query) or die;
				print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 400pt;">'.$status_msg2[$lang].'</div></center>';

		}
		elseif($rres=="off") {
				$sess->set('log_status','0');
				$query="insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time) values ('$user_id',6,1,NOW())";
				mysql_query($query) or die;
				print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 400pt;">'.$status_msg3[$lang].'</div></center>';

		}
}

print '<center>';
print '<br><b>'.$menu_item4[$lang].'</b><br /><br />';

print '<form action="settings.php" method="post"><input class="btn" type="submit" name="toggle" value="';
if ($sess->get('log_status') == "0") { print $arch_on[$lang]; } else { print $arch_off[$lang]; }
print '"></form>'."\n";


print '<input class="btn" type="button" value="'.$change_pass[$lang].'"><br /><br />';
print '<input class="btn" type="button" value="'.$settings_del[$lang].'"><br />';

print '</center>';
print '<br /><br /><br />';
include("footer.php");
?>
