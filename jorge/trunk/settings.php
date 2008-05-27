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
$close=$_POST['close_acc'];

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

	$result=remove_messages($user_id,$xmpp_host);
	if ($result=="t") {

		print '<center><div class="message" style="width: 250pt;">'.$deleted_all[$lang].'</div></center>';
		//log event
		mysql_query("insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time) values ('$user_id',9,2,NOW())");

	}
	elseif($result=="0"){

		print '<center><div class="message" style="width: 250pt;">'.$delete_nothing[$lang].'</div></center>';

	}
	elseif($result=="f"){
	
		print '<center><div class="message" style="width: 250pt;">'.$delete_error[$lang].'</div></center>';

	}

}

// close account
if($close)	{

	$close_now=rpc_close_account($user_id,$xmpp_host,$ejabberd_rpc);
	if ($close_now === false) { 

			print '<center><p class="message">'.$close_failed[$lang].'</p></center>'; 
		
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
                		
					print "<center><b>Removal of Google Apps account failed. Please report it to admin!</b></center>";
					exit;

        			}

				$user = $service->retrieveUser($token);
                                $gapps_token = $user->login->username;
	
				if ($gapps_token === $token) {
						
						debug(DEBUG,"Deleting user: $gapps_token");
						$service->deleteUser($token);
				
					}
			}
			
		$sess->finish();
		header("Location: index.php?act=logout");
		exit;
	}

}

// this is horrible! must be fixed:
print '<h2>'.$settings_desc[$lang].'</h2>';
print '<center>'."\n";
print '<table>';
print '<form action="settings.php" method="post">';
print '<tr style="font-size: x-small;"><td>'.$setting_d1[$lang].'</td><td><input class="btn_set" type="submit" name="toggle" value="';
if ($sess->get('log_status') == "0") { print $arch_on[$lang]; } else { print $arch_off[$lang]; }
print '"></td></tr></form>'."\n";
print '<form action="settings.php" method="post">';
print '<tr style="font-size: x-small;"><td>'.$setting_d2[$lang].'</td>';
print '<td><input class="btn_set" type="submit" name="del_all" value="'.$settings_del[$lang].'" onClick="if (!confirm(\''.$del_all_conf[$lang].'\')) return false;"></form></td></tr>'."\n";
print '<form action="settings.php" method="get" name="save_pref">';
print '<tr style="font-size: x-small;"><td>'.$select_view[$lang].'</td>';
print '<td><select style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="v" size="0" onchange="javascript:document.save_pref.submit();">'."\n";
if ($sess->get('view_type') == "1") { $std="selected"; } else { $cal="selected"; }
print '<option '.$std.' value="1">'.$view_standard[$lang].'</option>'."\n";
print '<option '.$cal.' value="2">'.$view_calendar[$lang].'</optin>'."\n";
print '</select>';
print '<input name="set_pref" type="hidden" value="1">';
print '</td></tr>';
print '</form>';
print '<form action="settings.php" method="get" name="save_pref_lang">';
print '<tr style="font-size: x-small;"><td>'.$sel_language[$lang].'</td>';
print '<td><select style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="v" size="0" onchange="javascript:document.save_pref_lang.submit();">'."\n";
if ($sess->get('language') == "pol") { $pol_sel="selected"; } else { $eng_sel="selected"; }
print '<option '.$pol_sel.' value="1">'.$lang_sw[eng].'</option>'."\n";
print '<option '.$eng_sel.' value="2">'.$lang_sw[pol].'</optin>'."\n";
print '</select>';
print '<input name="set_pref" type="hidden" value="2">';
print '<input name="sw_lang" type="hidden" value="t">';
print '</td></tr></form>';
print '<form action="settings.php" method="post" name="close_account">';
print '<tr><td colspan="2"><hr size="1"/></td></tr>';
print '<tr>';
print '<td style="font-size: x-small;">'.$close_account[$lang].'</td>';
print '<td><input name="close_acc" class="btn_set" type="submit" value="'.$close_commit[$lang].'" onClick="if (!confirm(\''.$close_warn[$lang].'\')) return false;"></td>';
print '</tr></form>';

if (GAPPS === true) {
		print '<tr><td colspan="2" style="color: red; font-size: xx-small; text-align: center;">'.$close_info[$lang].'</small></td></tr>';
	}

print '</table>';
print '<hr size="1" noshade="" color="#c9d7f1"/>';
// personal stats
print '<br><small><b>'.$stats_personal_d[$lang].'</b></small>';
$total_messages=number_format($total_messages=do_sel_quick("select sum(count) from `logdb_stats_$xmpp_host` where owner_id='$user_id'"));
if ($total_messages=="f") { $total_messages="0"; }
print '<p style="font-size: x-small;">'.$stats_personal[$lang].'<b> '.$total_messages.'</b></p>';
$top_ten_personal=do_sel("select peer_name_id,peer_server_id,at,count from `logdb_stats_$xmpp_host` where owner_id='$user_id' and peer_name_id!='$ignore_id' and ext is NULL order by count desc limit 10");
print '<small><b>'.$stats_personal_top[$lang].'</b></small><br><br>';
if (mysql_num_rows($top_ten_personal)!=0) {
print '<table bgcolor="#ffffff" class="ff" cellspacing="0" cellpadding="3"><tr style="background-image: url(img/bar_new.png); background-repeat:repeat-x; color: #fff; font-weight: bold;"><td>'.$stats_personal_count[$lang].'</td><td style="text-align: center;">'.$stats_peer[$lang].'</td><td>'.$stats_when[$lang].'</td></tr>';
while ($result=mysql_fetch_array($top_ten_personal)) {

	print '<tr><td style="text-align: center; font-weight: bold;">';
	print $result[count];
	print '</td><td>';
	$nickname=htmlspecialchars(query_nick_name(mysql_escape_string(get_user_name($result[peer_name_id],$xmpp_host)),mysql_escape_string(get_server_name($result[peer_server_id],$xmpp_host))));
	print '<b>'.$nickname.'</b>';
	print '&nbsp;<small>('.htmlspecialchars(get_user_name($result[peer_name_id],$xmpp_host)).'@'.htmlspecialchars(get_server_name($result[peer_server_id],$xmpp_host)).')</small>';
	print '</td><td>';
	$to_base = "$result[at]@$result[peer_name_id]@$result[peer_server_id]@";
	$to_base = encode_url($to_base,$token,$url_key);
	print '<a id="pretty" title="'.$stats_see[$lang].'" href="'.$view_type.'?a='.$to_base.'"><u>'.$result[at].'</u></a>';
	print '</td></tr>';

}
print '<tr height="15" style="background-image: url(img/bar_new.png); background-repeat:repeat-x; color: #fff;"><td colspan="3"></td></tr>';
print '</table>';

}
else {

	print '<div class="message">'.$no_archives[$lang].'</div>';

}
print '</center>'."\n";
print '<br /><br /><br />';
include("footer.php");
?>
