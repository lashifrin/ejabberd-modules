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

$action=$_POST[activate];
print $sess->get('log_status');

$user_name = mysql_escape_string($sess->get('uid_l'));

if ($action==$activate_m[$lang]) {  


	if (set_log_t($user_name,$xmpp_host) == "t") {

		print '<center><b>'.$act_su[$lang].'</b><br />';
		print '<small>'.$act_su2[$lang].'</small><hr>';
		print '<form action="index.php?act=logout" method="post"><input class="red" type="submit" name="logout" value="'.$log_out_b[$lang].'"></form></center>';
		}
		else {
				print 'Ooops something goes wrong...its still beta...';
				exit;
		}	

}


else {

$user_name=htmlspecialchars($user_name);
print $act_info[$lang]."<b>".$user_name."</b> (<i>$user_name@".str_replace("_",".",$xmpp_host)."</i>)";
print "<hr><br /><br />";
print '<center><form action="not_enabled.php" method="post"><input class="red" type="submit" name="activate" value="'.$activate_m[$lang].'"></form>';
print '<br /><br />';
print '<b>'.$warning2[$lang].'</b> '.$warning1[$lang].'<br />';
print '<u>'.$devel_info[$lang].'</u></center>';
print '<br /><br />';
print '<form action="index.php?act=logout" method="post"><input class="red" type="submit" name="logout" value="'.$log_out_b[$lang].'"></form>';
}

include ("footer.php");


?>

