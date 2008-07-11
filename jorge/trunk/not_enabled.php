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
$action = $_POST[activate];
$user_name = $sess->get('uid_l');

if ($action === $activate_m[$lang]) {  


		if ($db->get_user_id($user_name) === true) {

				if (!$db->result->user_id) {

						$db->insert_user_id($user_name);

				}

				if ($db->insert_new_settings($user_name) === true) {

						$html->set_body('<center><b>'.$act_su[$lang].'</b><br><small>'.$act_su2[$lang].'</small><hr>
								<form action="calendar_view.php" method="get"><input class="red" type="submit" name="logout" value="'.$log_out_b[$lang].'"></form></center>
							');
				
						if ($db->get_user_id($user_name) === true) {

								$user_id = $db->result->user_id;
								$db->set_user_id($user_id);
								$sess->set('enabled','t');
								$db->set_logger("7","1",$rem_adre);
						
							}
							else {

								$html->alert_message('Ooops something goes wrong...its still beta...');

						}
			
					}
					else {

						$html->alert_message('Ooops something goes wrong...its still beta...');
				}	

			}
			else {

				$html->alert_message('Ooops something goes wrong...its still beta...');
		}
	}
	else {

		$user_name=htmlspecialchars($user_name);
		$html->set_body($act_info[$lang].'<b>'.$user_name.'</b> (<i>'.$user_name.'@'.$xmpp_host_dotted.'</i>)<hr><br><br>
				<center>
					<form action="not_enabled.php" method="post">
						<input class="red" type="submit" name="activate" value="'.$activate_m[$lang].'">
					</form>
				<br><br><b>'.$warning2[$lang].'</b> '.$warning1[$lang].'<br><u>'.$devel_info[$lang].'</u></center><br><br>
				<center>
					<form action="index.php" method="get">
						<input type="hidden" name="act" value="logout">
						<input class="red" type="submit" name="destroy" value="'.$log_out_b[$lang].'">
					</form>
				</center>
		');
}

require_once("footer.php");
?>

