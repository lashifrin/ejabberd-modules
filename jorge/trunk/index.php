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

// all we need is header.php file - be sure to include it in all Jorge files! as it containg authentication futures.
require_once("headers.php");

// if already logged in (session active), move to main screen according to user preferences
if ($sess->get('uid_l')) { 

	if ($sess->get('view_type') == "1") { 

			header ("Location: main.php");

		}
		else {

			header ("Location: calendar_view.php");
	
	}
}

// get post data
$inpLogin = $_POST[inpLogin];
$inpPass = $_POST[inpPass];
$wo_sess = $_POST[word];
$lng_sw = $_GET['lng_sw'];
$inpLogin = strtolower($inpLogin);

// language selection
if ($lng_sw=="pol") {

		$sess->set('language','pol'); }

	elseif($lng_sw=="eng") { 
		
		$sess->set('language','eng'); 
}

// defaults to english
if (!$sess->get('language')) { $sess->set('language',$lang_def); }
$lang=$sess->get('language');

if ($wo_sess || $inpLogin || $inpPass) {

	if ($wo_sess != $sess->get('image_w')) { 

			unset($inpPass);
			unset($inpLogin);
			$html->system_message($wrong_data2[$lang]);
		
	}


}

if ($_GET['act']=='logout') {

		$ui = get_user_id($sess->get('uid_l'),$xmpp_host);
		$db->set_user_id($ui);
		$db->set_logger("2","1",$rem_adre);
		$sess->finish();
		header("Location: index.php");
	
	} 
	
	else {

		if ($inpLogin!="" || $inpPass!="") {

			$ejabberd_rpc->set_user($inpLogin,$inpPass);
			if ($ejabberd_rpc->auth() === true) {

	          		$sess->set('login',$inpLogin);
		  		$sess->set('uid_l',$inpLogin);
		  		$sess->set('uid_p',$inpPass);
		  		$sess->set('host',$xmpp_host);
		  		$ret_v=is_log_enabled(get_user_id($sess->get('uid_l'),$xmpp_host),$xmpp_host);
		  		if (($ret_v[0]) == "t") {

		  			$sess->set('enabled','t');
		  			$sess->set('log_status',$ret_v[1]);
		  			$sess->set('image_w','');
		  			$ui = get_user_id($sess->get('uid_l'),$xmpp_host);
					$db->set_user_id("$ui");
					$db->set_logger("1","1",$rem_adre);
					// get preferences, if not set, fallback to standard view.
					$get_pref_menu="select pref_id, pref_value from jorge_pref where owner_id='$ui'";
					$q_pref=mysql_query($get_pref_menu);

					while ($res_pref=mysql_fetch_array($q_pref)) {

							if ($res_pref[pref_id]=="1") {

									if ($res_pref[pref_value] == "2") {

											$view_type="2"; $tmp_v="calendar_view.php"; 
									
									}
										elseif($res_pref[pref_value] == "1") {

											$view_type="1"; $tmp_v="main.php"; 
								
									}
								
								$sess->set('view_type',$view_type);
							}
			
						if ($res_pref[pref_id] == "2") {

								if ($res_pref[pref_value] == "1") {
					
									$s_lang="pol";
							
								}
								elseif($res_pref[pref_value] == "2") {
					
									$s_lang="eng";
							
								}
							$sess->set('language',$s_lang);
						}
					}

					// if pref not set fall to defaults
					if ($s_lang=="") { 
							
							$sess->set('language',$lang); 
							
						}
					if ($tmp_v=="") { 

							$sess->set('view_type',2); 
							$tmp_v="calendar_view.php"; 
						}

					header("Location: $tmp_v");
					exit; // lets break script at this point...
				
				}
		  		
				else {
				
					$sess->set('enabled','f');
					$sess->set('log_status',$ret_v[1]);
					$sess->set('image_w','');
					header("Location: not_enabled.php"); }

			}

		$html->system_message($wrong_data[$lang]);
		$db->get_user_id($inpLogin);
		$ui_fail = $db->result->user_id;
		$query = "select count(id_user) as log_number from jorge_logger where id_user = '$ui_fail' and log_time > date_sub(now(),interval 1 minute)";
		$result = mysql_query($query);
		$row=mysql_fetch_row($result);

		// bump log_level if more then 3 log attempts in one minute
		if ($row[0]>"3") { 

				$log_level="3"; 
		
		} 
		else { 

			$log_level="2";
		
		} 

		if ($ejabberd_rpc->check_account() === true) {

			$db->set_user_id($ui_fail);
			$db->set_logger("3",$log_level,$rem_adre);
		
		}

	}
 
}


$html->set_body('

		<script language="javascript">
		<!--
		function new_freecap()
			{
			if(document.getElementById)
				{
				thesrc = document.getElementById("freecap").src;
				thesrc = thesrc.substring(0,thesrc.lastIndexOf(".")+4);
				document.getElementById("freecap").src = thesrc+"?"+Math.round(Math.random()*10000);
				} else {
				alert("Ups...");
				}
			}
		//-->
		</script>
	');

if ($lang=="eng") { 

		$lang_o="pol"; 
	} 
	elseif($lang=="pol") { 
	
		$lang_o="eng"; 
		
}

$html->set_body('
		<br><div align="center" style="height: 110;"><br><a href="index.php"><img border="0" alt="Branding logo" src="img/'.$brand_logo.'"></a></div>
		<table class="ff" cellspacing="0" width="100%">
		<tr style="background-image: url(img/bell-bak.png); height: 24;">
		<td style="text-align: left; padding-left: 10px; color: white;">'.$welcome_1[$lang].'</td><td style="text-align: right;">
		<a class="mmenu" href="index.php?lng_sw='.$lang_o.'">'.$ch_lan2[$lang].$lang_sw[$lang].'</a></td>
		</tr></table>
		<center>
		<form action="index.php" method="post">
		<br><br><table class="ff" border="0" cellspacing="0" cellpadding="0">
		<tr><td align="right">'.$login_w[$lang].'&nbsp;</td><td><input name="inpLogin" value="'.$_POST[inpLogin].'" class="log" ></td><td>@'.$xmpp_host_dotted.'</td></tr>
		<tr height="3" ><td></td></tr>
		<tr><td align="right">'.$passwd_w[$lang].'&nbsp;</td><td><input name="inpPass" type="password" class="log"></td></tr>
		<tr height="10"><td></td></tr>
		<tr><td></td><td colspan="2"><img src="freecap.php" id="freecap" name="pic"></td></tr>
		<tr height="3" ><td></td></tr>
		<tr><td></td><td colspan="2" style="text-align: center;"><a href="#" onClick="new_freecap();return false;"><small>'.$cap_cant[$lang].'</small></a></td></tr>
		<tr height="3" ><td></td></tr>
		<tr><td align="right">'.$cap_w[$lang].'&nbsp;</td><td><input name="word" type="text" class="log" ></td>
		<tr height="15" ><td></td></tr>
		<tr><td colspan="2" align="right"><input class="red" type="submit" name="sublogin" value="'.$login_act[$lang].'"></td></tr>
		</table></form></center>	
	');

require_once("footer.php");
?>
