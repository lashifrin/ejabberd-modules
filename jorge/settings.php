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
$del_a=$_POST['del_all'];

include("upper.php");

// toggle message saving
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

// delete entire archive
if ($del_a) {

	$result=mysql_query("select at from `logdb_stats_$xmpp_host` where owner_id='$user_id'");
		if (mysql_num_rows($result)!=0) {
		while ($row=mysql_fetch_array($result)) {
		
			mysql_query("delete from `logdb_messages_$row[at]_$xmpp_host` where owner_id='$user_id'");
		}
		mysql_query("delete from `logdb_stats_$xmpp_host` where owner_id='$user_id'");
		mysql_query("delete from jorge_mylinks where owner_id='$user_id'");
		mysql_query("insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time) values ('$user_id',9,2,NOW())");
		print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 250pt;">'.$deleted_all[$lang].'</div></center>';
	
	}

	else

	{

	print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 250pt;">'.$delete_nothing[$lang].'</div></center>';

	}

}

print '<h2>'.$settings_desc[$lang].'</h2>';
print '<center>'."\n";
print '<form action="settings.php" method="post"><input class="btn" type="submit" name="toggle" value="';
if ($sess->get('log_status') == "0") { print $arch_on[$lang]; } else { print $arch_off[$lang]; }
print '"></form>'."\n";
print '<hr size="1" width="100px" noshade="" color="#cccccc"/>'."\n";
print '<form action="settings.php" method="post"><input class="btn" type="submit" name="del_all" value="'.$settings_del[$lang].'" onClick="if (!confirm(\''.$del_all_conf[$lang].'\')) return false;"></form>'."\n";
print '</center>'."\n";
print '<br /><br /><br />';
include("footer.php");
?>
