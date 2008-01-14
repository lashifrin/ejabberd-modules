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
include ("upper.php");
print '<h2>'.$cal_head[$lang].'</h2>';
print '<small>'.$cal_notice[$lang].'. <a href="main.php?set_pref=1&v=1"><u>'.$change_view[$lang].'</u></a></small><br><br>';

// fetch some get and posts
if (isset($_GET['left'])) { $left=decode_url_simple($_GET['left'],$token,$url_key); }
if (isset($_GET['right'])) { $right=decode_url_simple($_GET['right'],$token,$url_key) ; }
$jump_to=$_POST['jump_box'];
$resource_id=mysql_escape_string($_GET['b']);

// validate resource_id
if (!ctype_digit($resource_id)) { unset($resource_id); }

$start=$_GET['start'];

if ($jump_to!="") { $mo=$jump_to; }
if ($mo=="jump") { unset($mo); }

$e_string=mysql_escape_string($_GET['a']);

// decompose link
if ($e_string) {
$variables = decode_url2($e_string,$token,$url_key);
$tslice = $variables[tslice];
$talker = $variables[talker];
$server = $variables[server];
$action = $variables[action];
$lnk = $variables[lnk];
}

// validation
$talker=mysql_escape_string($talker);
$server=mysql_escape_string($server);
if (validate_date($tslice) == "f") { unset ($tslice); unset($e_string); unset($talker); unset($left); unset($right); unset($mo); unset($action); }

// some validation things...
if ($start) { if ((validate_start($start))!="t") { $start="0";  }  }

// undo delete
if ($action=="undelete") {

	if (undo_deleted_chat($talker,$server,$user_id,$tslice,$xmpp_host,$lnk)=="t") {

		print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">'.$undo_info[$lang].'</div></center>';

	}

	else

	{

		unset($talker);
		print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">';
		print 'Unusual error accured during processing your request. Please report it (Code:JUF).</div></center>';

	}
	



}

// chat deletion
if ($action=="del") {

	$del_result=delete_chat($talker,$server,$xmpp_host,$user_id,$tslice,$token,$url_key,$lnk);
	if ($del_result!="f") {

		unset($talker);
		print '<center><div style="background-color: #fad163; text-align: center; width: 240pt;">'.$del_moved[$lang];
		print '<a href="'.$view_type.'?a='.$del_result.'"> <span style="color: blue; font-weight: bold;"><u>Undo</u></span></a></div></center>';

	}

	else

	{

		unset($talker);
		print '<center><div style="background-color: #fad163; text-align: center; font-weight: bold; width: 200pt;">';
		print 'Unusual error accured during processing your request. Please report it (Code:JDF).</div></center>';

	}
		
}

// check few condition, what we're doing...
if ($tslice!="") {

	list($y,$m,$selected) = split("-", $tslice);
	$mo="$y-$m";

	}

	else {

		if (isset($left)) {

			$mo=$left;

		}

		if (isset($right)) {

			$mo=$right;

		}

}

if (!isset($mo)) {

			$mo = date("Y-n");

		}

// validate mo if fail, silently fallback to current date
if (validate_date($mo."-1") == "f") { unset ($tslice); unset($e_string); unset($talker); $mo=date("Y-m");  }

$get_chats="select substring(at,1,7) as at_send, at from `logdb_stats_$xmpp_host` where owner_id = '$user_id' group by substring(at,1,7) order by str_to_date(at,'%Y-%m-%d') desc";
$ch_mo=mysql_query($get_chats);

// master div
print '<div>'."\n";

// calendar div
if ($talker) { $float="left;"; } else { $float="none;"; }

print '<div style="text-align: center; width: 200px; float: '.$float.'">'."\n";

// lets generate quick jump list
print '<form id="t_jump" action="calendar_view.php" method="post" name="t_jump">'."\n";
print '<select style="text-align: center; border: 0px; background-color: #6daae7; color:#fff; font-size: x-small;" name="jump_box" size="0" onchange="javascript:document.t_jump.submit();">'."\n";
print '<option value="jump">'.$jump_to_l[$lang].'</option>'."\n";

while ($mo_sel=mysql_fetch_array($ch_mo)) {

	list($s_y,$s_m) = split("-",$mo_sel[at_send]);
	$sym="$s_y-$s_m";

	if ($jump_to!="" AND $sym==$mo) { $sel_box="selected"; } else { $sel_box=""; }
	print '<option value="'.$sym.'" '.$sel_box.'>'.pl_znaczki(verbose_mo($mo_sel[at],$lang)).'</option>'."\n";

}
print '</select>'."\n";
print '</form>'."\n";
// now generate claendar, the peer_name_id is hard-coded - this avoids of displaying chats with no-username
$query_days="select distinct(substring(at,8,9)) as days from `logdb_stats_$xmpp_host` where owner_id = '$user_id' and at like '$mo%' and peer_name_id!='$ignore_id' order by str_to_date(at,'%Y-%m-%d') desc";
$result_for_days=mysql_query($query_days);
$i=0;

// array of days
while ($row_d=mysql_fetch_array($result_for_days)) {

	$i++;
	$days[$i] = str_replace("-","",$row_d[days]); // hack for bad parsing

}

// display calendar
list($y,$m) = split("-", $mo);
echo pl_znaczki(calendar($user_id,$xmpp_host,$y,$m,$days,$token,$url_key,$months_name_eng,$left,$right,$selected,$lang,$view_type,1,$null_a=0,$null_b=0,$cal_days));
unset($days);

// generate table name
$tslice_table='logdb_messages_'.$tslice.'_'.$xmpp_host;

// if we got day, lets display chats from that day...
if ($tslice) {
	
        $result=db_q($user_id,$server,$tslice,$talker,$search_p,"2",$start,$xmpp_host);
        if ($result=="f") { header ("Location: calendar_view.php");  }
        print '<td valign="top" style="padding-top: 15px;">'."\n";
        print '<table width="200" border="0" cellpadding="0" cellspacing="0" class="calbck_con">'."\n";
	print '
      		<tr>
        		<td><img src="img/cal_corn_11.png" width="15" height="7"></td>
        		<td background="img/cal_bck_top.gif"></td>
        		<td><img src="img/cal_corn_12.png" width="14" height="7"></td>
      		</tr>
      		<tr>
        		<td width="15" height="226" valign="top" class="calbckleft"><img src="img/cal_bck_left.png" width="15" height="116"></td>
        		<td width="100%" valign="top">
				<table width="100%"  border="0" cellspacing="0" cellpadding="0">
        				<tr>
						<td align="center" class="calhead">'.$chat_list_l[$lang].'</td>
					</tr>
					<tr><td height="5"></td></tr>
		';
	print '<tr align="center" class="caldays">'."\n";
	print '<td><div style="vertical-align: middle; overflow: auto; height: 210; border-left: 0px; border-bottom: 0px; padding:0px; margin: 0px;">'."\n";

	// select chatters
        while ($entry = mysql_fetch_array($result))
        {
                $user_name = $entry[username];
                $server_name = $entry[server_name];
                if ($talker==$entry["todaytalk"] AND $server==$entry[server]) { $bold_b="<font color=\"#FFCC00\"><b>"; $bold_e="</b></font>"; $mrk=1; } else { $bold_b=""; $bold_e=""; $mrk=0; }
                        $nickname = query_nick_name($bazaj,$token,$user_name,$server_name);
                        if ($nickname=="f") { $nickname=$not_in_r[$lang]; }
			// this is hack for not displaying chats with jids without names...
			if ($user_name!="") {
				if ($mrk==1) { 
					$previous_t = prev_c_day($xmpp_host,$tslice,$user_id,$entry[todaytalk],$entry[server]); 
					$to_base_prev = "$previous_t@$entry[todaytalk]@$entry[server]@";
					$to_base_prev = encode_url($to_base_prev,$token,$url_key);

					$next_t = next_c_day($xmpp_host,$tslice,$user_id,$entry[todaytalk],$entry[server]);
					$to_base_next = "$next_t@$entry[todaytalk]@$entry[server]@";
					$to_base_next = encode_url($to_base_next,$token,$url_key);
				}

                        	$to_base2 = "$tslice@$entry[todaytalk]@$entry[server]@";
                        	$to_base2 = encode_url($to_base2,$token,$url_key);
				if ($mrk==1 AND $previous_t != NULL) { 
						print '<a class="nav_np" id="pretty" title="'.$jump_to_prev[$lang].': '.$previous_t.'" href="calendar_view.php?a='.$to_base_prev.'"><<< </a>'; 
					}
				print '<a class="caldays3" id="pretty" href="?a='.$to_base2.'" title="JabberID:;'.htmlspecialchars($user_name).'@'.htmlspecialchars($server_name).';---;<b>'.$chat_lines[$lang].$entry[lcount].'</b>">'.$bold_b.cut_nick(htmlspecialchars($nickname)).$bold_e.'</a>';
				if ($mrk==1 AND $next_t != NULL) { 
						print '<a class="nav_np" id="pretty" title="'.$jump_to_next[$lang].': '.$next_t.'" href="calendar_view.php?a='.$to_base_next.'"> >>></a>'; 
					}

				print '<br>'."\n";
			}

        }
	print '</div>';
	print '</td></tr>'."\n";
	print '

	</table>
        </td>
        <td width="14" valign="top" class="calbckright"><img src="img/cal_bck_right.png" width="14" height="116"></td>
      	</tr>
      	<tr>
        <td><img src="img/cal_corn_21.png" width="15" height="16"></td>
        <td background="img/cal_bck_bot.png"></td>
        <td><img src="img/cal_corn_22.png" width="14" height="16"></td>
      	</tr>
    	</table>
	
	';

	mysql_free_result ($result);

}

print '</div>';
print '<div>';


// Chat thread:
if ($talker) {

        print '<td valign="top"><table border="0" class="ff"><tr>'."\n";
        if (!$start) { $start="0"; } // are we in the first page?
        $nume=get_num_lines($tslice_table,$user_id,$talker,$server); // number of chat lines
        if ($start>$nume) { $start=$nume-$num_lines_bro; } // checking start variable
        $result=db_q($user_id,$server,$tslice_table,$talker,$search_p,"3",$start,$xmpp_host,$num_lines_bro,$time_s="",$end_s="",$resource_id);
        if ($result=="f") { header ("Location: main.php");  }
        $talker_name = get_user_name($talker,$xmpp_host);
        $server_name = get_server_name($server,$xmpp_host);
        $nickname = query_nick_name($bazaj,$token,$talker_name,$server_name);
        if ($nickname=="f") { $nickname=$not_in_r[$lang]; }
	$predefined="$talker_name@$server_name";
	$predefined=encode_url($predefined,$token,$url_key);
	$predefined_s="from:$talker_name@$server_name";
	$predefined_s=encode_url($predefined_s,$token,$url_key);
        print '<table id="maincontent" border="0" cellspacing="0" class="ff">'."\n";
	// if we come from chat maps put the link back...its the same link as "show all chats" but, it is more self explaining
	if ($_GET['loc'] == "2") {
		print '<tr>';
		print '<td colspan="2" style="background-color: #fad163; color: #fff; font-size: x-small; text-align: center;"><a href="chat_map.php?chat_map='.$predefined.'">'.$chat_map_back[$lang].'</a></td>';
		print '<td></td></tr>'."\n";
	}
        if ($resource_id) {
        	$res_display=get_resource_name($resource_id,$xmpp_host);
        	print '<tr><td colspan="4"><div style="background-color: #fad163; text-align: center; font-weight: bold;">'.$resource_warn[$lang].cut_nick(htmlspecialchars($res_display)).'. ';
        	print $resource_discard[$lang].'<a class="export" href="?a='.$e_string.'">'.$resource_discard2[$lang].'</a>';
        	print '</div></td></tr>';
        }
        print '<tr style="background-image: url(img/bar_new.png); background-repeat:repeat-x; color: #fff;">'."\n";
        print '<td><b> '.$time_t[$lang].' </b></td><td><b> '.$user_t[$lang].' </b></td><td><b> '.$thread[$lang].'</b></td>'."\n";
        $server_id=get_server_id($server_name,$xmpp_host);
        $loc_link = $e_string;
        $action_link = "$tslice@$talker@$server_id@0@null@$loc_link@del@";
        $action_link = encode_url($action_link,$token,$url_key);
        print '<td align="right" style="padding-right: 5px;"><a id="pretty" title="'.$tip_export[$lang].'" class="menu_chat" href="export.php?a='.$e_string.'">'.$export_link[$lang].'</a>&nbsp; | &nbsp;';
	print $all_for_u[$lang];
        print '<a id="pretty" title="'.$all_for_u_m2_d[$lang].'" class="menu_chat" href="chat_map.php?chat_map='.$predefined.'"><u>'.$all_for_u_m2[$lang].'</u></a>';
	print '&nbsp;<small>|</small>&nbsp;';
	print '<a id="pretty" title="'.$all_for_u_m_d[$lang].'" class="menu_chat" href="search_v2.php?b='.$predefined_s.'"><u>'.$all_for_u_m[$lang].'</u></a>';
	print '&nbsp; | &nbsp;';
        print '<a id="pretty" title="'.$tip_delete[$lang].'" class="menu_chat" href="calendar_view.php?a='.$action_link.'">'.$del_t[$lang].'</a></td></tr>';
        print '<tr class="spacer"><td colspan="5"></td></tr>';
        print '<tbody id="searchfield">'."\n";
        while ($entry = mysql_fetch_array($result))
                {

                $resource=get_resource_name($entry[peer_resource_id],$xmpp_host);
                $licz++;        
                if ($entry["direction"] == "to") { $col="main_row_a"; } else { $col="main_row_b"; }

                $ts=strstr($entry["ts"], ' ');
                // time calc 
                $pass_to_next = $entry["ts"];
                $new_d = $entry["ts"];
                $time_diff = abs((strtotime("$old_d") - strtotime(date("$new_d"))));
                $old_d = $pass_to_next;
                // end time calc
                if ($time_diff>$split_line AND $licz>1) { 
                                $in_minutes = round(($time_diff/60),0);
                                print '<tr class="splitl">';
                                print '<td colspan="5" style="font-size: 10px;"><i>'.verbose_split_line($in_minutes,$lang,$verb_h,$in_min).'</i><hr size="1" noshade="" color="#cccccc"/></td></tr>';

                        } // splitting line - defaults to 900s = 15min

                print '<tr class="'.$col.'">'."\n";
                print '<td class="time_chat" style="padding-left: 10px; padding-right: 10px;";>'.$ts.'</td>'."\n";

                if ($entry["direction"] == "from")
                        {
                                $out=$nickname;
                                $tt=$tt+1;
                                $aa=0;
                        }
                        else
                        {
                                $out = $token;
                                $aa=$aa+1;
                                $tt=0;
                        }



                if ($aa<2 AND $tt<2) {

                                print '<td style="padding-left: 5px; padding-right: 10px; nowrap="nowrap">'.cut_nick(htmlspecialchars($out));
                                print '<a name="'.$licz.'"></a>';

                                if ($out!=$token) {

                                print '<br><div style="text-align: left; padding-left: 5px;"><a class="export" id="pretty" title="'.$resource_only[$lang].'" href="?a='.$e_string.'&b='.$entry[peer_resource_id].'">';
                                print '<small><i>'.cut_nick(htmlspecialchars($resource)).'</i></small></a></div>';

                                }

                                print '</td>'."\n";

                                $here="1";
                        }
                        else
                        {
                                print '<td style="text-align: right; padding-right: 5px">-</td>'."\n"; $here="0";
                        }

                $new_s=htmlspecialchars($entry["body"]);
                $to_r = array("\n");
                $t_ro = array("<br>");
                $new_s=str_replace($to_r,$t_ro,$new_s);
                $new_s=wordwrap($new_s,107,"<br>",true);
                $new_s=new_parse_url($new_s);
                print '<td width="800" colspan="2">'.$new_s.'</td>'."\n";
                $lnk=encode_url("$tslice@$entry[peer_name_id]@$entry[peer_server_id]@",$ee,$url_key);
                $to_base2 = "$tslice@$entry[peer_name_id]@$entry[peer_server_id]@1@$licz@$lnk@NULL@$start@";
                $to_base2 = encode_url($to_base2,$token,$url_key);
                if ($here=="1") { print '<td colspan="2" style="padding-left: 2px; font-size: 9px;"><a style="color: #1466bc" href="my_links.php?a='.$to_base2.'">'.$my_links_save[$lang].'</a></td>'."\n"; } else { print '<td></td>'."\n"; }
                if ($t=2) { $c=1; $t=0; }
                print '</tr>'."\n";
                }
	        print '</tbody>'."\n";



// limiting code
print '<tr class="spacer" height="1px"><td colspan="5"></td></tr>';
print '<tr style="background-image: url(img/bar_new.png); background-repeat:repeat-x;"><td style="text-align: center;" colspan="9">';
for($i=0;$i < $nume;$i=$i+$num_lines_bro){

        if ($i!=$start) {

            if ($resource_id) { $add_res="&b=$resource_id"; } else { $add_res=""; }
            print '<a class="menu_chat" href="?a='.$e_string.$add_res.'&start='.$i.'"> <b>['.$i.']</b> </font></a>';
            }
            else { print ' <span style="color: #fff;">-'.$i.'-</span> '; }

    }
print '</td></tr>';
// limiting code - end

        if (($nume-$start)>40) { print '<tr><td colspan="5" style="text-align: right; padding-right: 5px;"><a href="#top"><small>'.$back_t[$lang].'</small></a></td></tr>'."\n"; }
        print '</table>'."\n";

        print '</tr></table></td>'."\n";
}

print '</div>'."\n";


// end master div
print '</div>';

include ("footer.php");


?> 
