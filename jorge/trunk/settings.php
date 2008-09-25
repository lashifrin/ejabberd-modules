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

$tgle=$_POST['toggle'];
$del_a=$_POST['del_all'];
$close=$_POST['close_acc'];

require_once("upper.php");

// toggle message saving
if ($tgle) { 
	
	if ($tgle === $arch_on[$lang]) {
				
				if($db->set_log(true) === true) {

						$sess->set('log_status',true);
						$db->set_logger("7","1");
						$html->status_message($status_msg2[$lang]);
					
					}
					else{
						
						$html->alert_message($oper_fail[$lang]);
					
					}

		}
		elseif($tgle === $arch_off[$lang]) {
				
				if($db->set_log(false) === true) {

						$sess->set('log_status',false);
						$db->set_logger("6","1");
						$html->status_message($status_msg3[$lang]);
					
					}
					else{

						$html->alert_message($oper_fail[$lang]);

					}

		}
}

// delete entire archive
if ($del_a) {

	$result=remove_messages($user_id,$xmpp_host);
	if ($result=="t") {

		$html->status_message($deleted_all[$lang]);
		$db->set_logger("9","2");

	}
	elseif($result=="0"){

		$html->status_message($delete_nothing[$lang]);

	}
	elseif($result=="f"){
	
		$html->alert_message($delete_error[$lang]);

	}

}

// close account
if ($close === $close_commit[$lang])	{

	$close_now=rpc_close_account($user_id,$xmpp_host,$ejabberd_rpc);
	if ($close_now === false) { 

			$html->alert_message($close_failed[$lang]);
		
		}

	elseif($close_now === true) {

			if(GAPPS === true) {

				set_include_path('lib');
	        		require_once 'lib/Zend/Loader.php';
        			Zend_Loader::loadClass('Zend_Gdata');
        			Zend_Loader::loadClass('Zend_Gdata_ClientLogin');
        			Zend_Loader::loadClass('Zend_Gdata_Gapps');

	        		try {
        	        		$client = Zend_Gdata_ClientLogin::getHttpClient(GAPPS_ACCOUNT, GAPPS_PASSWORD, Zend_Gdata_Gapps::AUTH_SERVICE_NAME);
                			$service = new Zend_Gdata_Gapps($client, GAPPS_DOMAIN);

        			} catch (Zend_Gdata_App_HttpException $e) {
                		
					$html->alert_message('Removal of Google Apps account failed. Please report it to admin!');
					exit;

        			}

				$user = $service->retrieveUser(TOKEN);
                                $gapps_token = $user->login->username;
	
				if ($gapps_token === TOKEN) {
						
						debug(DEBUG,"Deleting user: $gapps_token");
						$service->deleteUser(TOKEN);
				
					}
			}
			
		$sess->finish();
		header("Location: index.php?act=logout");
		exit;
	}

}

// this is horrible! must be fixed:
$html->set_body('<h2>'.$settings_desc[$lang].'</h2><center><table><form action="settings.php" method="post">
		<tr style="font-size: x-small;"><td>'.$setting_d1[$lang].'</td><td><input class="btn_set" type="submit" name="toggle" value="
	');
$db->is_log_enabled();
if ($db->result->is_enabled === false) { 
		
		$html->set_body($arch_on[$lang]);
		
	} 
	else { 
		
		$html->set_body($arch_off[$lang]);
		
	}

$html->set_body('
	"></td></tr></form>
	<form action="settings.php" method="post">
	<tr style="font-size: x-small;"><td>'.$setting_d2[$lang].'</td>
	<td><input class="btn_set" type="submit" name="del_all" value="'.$settings_del[$lang].'" onClick="if (!confirm(\''.$del_all_conf[$lang].'\')) return false;"></form></td></tr>
	<form action="settings.php" method="get" name="save_pref">
	<tr style="font-size: x-small;"><td>'.$select_view[$lang].'</td>
	<td><select style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="v" size="0" onchange="javascript:document.save_pref.submit();">
');

if ($sess->get('view_type') == "1") { 

		$std="selected"; 
		
	} 
	else { 
	
		$cal="selected"; 
		
}
$html->set_body('
	<option '.$std.' value="1">'.$view_standard[$lang].'</option>
	<option '.$cal.' value="2">'.$view_calendar[$lang].'</optin>
	</select>
	<input name="set_pref" type="hidden" value="1">
	</td></tr>
	</form>
	<form action="settings.php" method="get" name="save_pref_lang">
	<tr style="font-size: x-small;"><td>'.$sel_language[$lang].'</td>
	<td><select style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="v" size="0" onchange="javascript:document.save_pref_lang.submit();">
');

if ($sess->get('language') == "pol") { 

		$pol_sel="selected"; 
	
	} 
	else { 
	
		$eng_sel="selected"; 
		
}

$html->set_body('
	<option '.$pol_sel.' value="1">'.$lang_sw[eng].'</option>
	<option '.$eng_sel.' value="2">'.$lang_sw[pol].'</optin>
	</select>
	<input name="set_pref" type="hidden" value="2">
	<input name="sw_lang" type="hidden" value="t">
	</td></tr></form>
	<form action="settings.php" method="post" name="close_account">
	<tr><td colspan="2" height="40"><hr size="1"/></td></tr>
	<tr>
	<td style="font-size: x-small;">'.$close_account[$lang].'</td>
	<td><input name="close_acc" class="btn_set" type="submit" value="'.$close_commit[$lang].'" onClick="if (!confirm(\''.$close_warn[$lang].'\')) return false;"></td>
	</tr></form>
');

if (GAPPS === true) {

		$html->set_body('<tr><td colspan="2" style="color: red; font-size: xx-small; text-align: center;">'.$close_info[$lang].'</small></td></tr>');
	
	}

$html->set_body('</table><hr size="1" noshade="noshade" style="color: #c9d7f1;"><br><small><b>'.$stats_personal_d[$lang].'</b></small>');
$total_messages=number_format($total_messages=do_sel_quick("select sum(count) from `logdb_stats_$xmpp_host` where owner_id='$user_id'"));
if ($total_messages=="f") { 

	$total_messages="0"; 
	
}
$html->set_body('<p style="font-size: x-small;">'.$stats_personal[$lang].'<b> '.$total_messages.'</b></p><small><b>'.$stats_personal_top[$lang].'</b></small><br><br>');

$top_ten_personal=do_sel("select peer_name_id,peer_server_id,at,count from `logdb_stats_$xmpp_host` where owner_id='$user_id' and peer_name_id!='".IGNORE_ID."' and ext is NULL order by count desc limit 10");
if (mysql_num_rows($top_ten_personal)!=0) {

		$html->set_body('<table bgcolor="#ffffff" class="ff" cellspacing="0" cellpadding="3">
				<tr style="background-image: url(img/bar_new.png); background-repeat:repeat-x; color: #fff; font-weight: bold;">
				<td>'.$stats_personal_count[$lang].'</td><td style="text-align: center;">'.$stats_peer[$lang].'</td><td>'.$stats_when[$lang].'</td></tr>
			');

		while ($result=mysql_fetch_array($top_ten_personal)) {

			$nickname=query_nick_name($ejabberd_roster,get_user_name($result[peer_name_id],$xmpp_host), get_server_name($result[peer_server_id],$xmpp_host));
			$to_base = $enc->crypt_url("tslice=$result[at]&peer_name_id=$result[peer_name_id]&peer_server_id=$result[peer_server_id]");
			$html->set_body('
				<tr><td style="text-align: center; font-weight: bold;">'.$result[count].'</td><td><b>'.$nickname.'</b>&nbsp;
				<small>('.htmlspecialchars(get_user_name($result[peer_name_id],$xmpp_host)).'@'.htmlspecialchars(get_server_name($result[peer_server_id],$xmpp_host)).')</small>
				</td><td><a id="pretty" title="'.$stats_see[$lang].'" href="'.$view_type.'?a='.$to_base.'"><u>'.$result[at].'</u></a></td></tr>
			');

		}

		$html->set_body('<tr height="15" style="background-image: url(img/bar_new.png); background-repeat:repeat-x; color: #fff;"><td colspan="3"></td></tr></table>');

	}
	else {

		$html->set_body('<div class="message">'.$no_archives[$lang].'</div>');

}

$html->set_body('</center>');
require_once("footer.php");
?>
