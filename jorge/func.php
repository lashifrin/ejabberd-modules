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
function getmicrotime(){
list($usec, $sec) = explode(" ",microtime());
return ((float)$usec + (float)$sec);
}



function db_connect($mod_logdb)
{
$conn=mysql_connect("$mod_logdb[host]", "$mod_logdb[user]", "$mod_logdb[pass]") or die ("Us³uga chwilowo niedostêpna. Spróbuj za chwile. We're sorry but service is currently unavailable. Please try in few seconds.");
mysql_select_db ("$mod_logdb[name]") or die ("Oops...");
return $conn;
}


function db_e_connect($db_ejabberd)
	{
		$bazaj = pg_pconnect("host=$db_ejabberd[host] port=5432 dbname=$db_ejabberd[name] user=$db_ejabberd[user]");
		return $bazaj;
	}



function auth($bazaj,$uid,$puid) {


$uid_s=pg_escape_string($uid);
$puid_s=pg_escape_string($puid);


$res = pg_query($bazaj, "select username, password from users where username='$uid_s' and password='$puid_s'");
if (!$res) {
	print "<h2>STOP: Internal system error. Please refresh this page.</h2>";
	exit;
}

if ((pg_num_rows($res))!=1) { return "f"; }

$row=pg_fetch_row($res);
$j_uid=$row[0];
$j_puid=$row[1];



if ($j_uid!=$uid) 
	{ 
		pg_close($bazaj);
		return "f";
	} 
	
	else 
	{ 
		if ($puid_s===$j_puid) {
			return "t";
			}
			else
			{
			return "f";
			}
	}


return "f";

}

function query_nick_name($bazaj,$token, $talker, $server="") {

	$res = pg_query($bazaj, "select nick from rosterusers where username='$token' and jid = '$talker@$server'");
		if (!$res) {
		print "<h2>STOP: Internal system error(1.1)</h2>";
		exit;
	}
	$row=pg_fetch_row($res);
	$nickname = $row[0];
	if ($nickname=="") { $nickname=$talker; }
	return $nickname;

}

function spool_count($bazaj,$token) {

	$res=pg_query($bazaj,"select count(xml) from spool where username = '$token'");
		if (!$res) {
		print "<h2>STOP: Internal system error(1.2)";
		exit;
	}

	$row=pg_fetch_row($res);
	$spool = $row[0];
	return $spool;

}

function validate_date($tslice) {

	if ($tslice) {
		list($ye, $mo, $da) = split("-", $tslice);
		if (!ctype_digit($ye) || !ctype_digit($mo) || !ctype_digit($da)  ) { return "f"; } else { return "t"; }
	}

}

function encode_url($url,$token,$url_key) {

	$key=$url_key;
	$uri_e = strrev($url);
	$uri_e=encrypt_aes($key,$uri_e);
	$uri_e = str_replace("+", "kezyt2s0", $uri_e); 

return $uri_e;

}

function decode_url2($url,$token,$url_key) {

	$key=$url_key;
	$url = str_replace("kezyt2s0", "+",$url);
	$uri_d=decrypt_aes($key,$url);
	$uri_d = strrev($uri_d);
	list($tslice,$talker,$server,$ismylink,$linktag,$lnk,$action,$strt) = split("@",$uri_d);
	$variables[tslice] = $tslice;
	$variables[talker] = $talker;
	$variables[server] = $server;
	$variables[ismylink] = $ismylink;
	$variables[linktag] = $linktag;
	$variables[lnk] = $lnk;
	$variables[action] = $action;
	$variables[strt] = $strt;
	return $variables;

}


function decode_search_url($url,$token,$url_key) {

	$key=$url_key;
	$url = str_replace("kezyt2s0", "+",$url);
	$uri_d=decrypt_aes($key,$url);
	$uri_d = strrev($uri_d);
	list($tslice,$offset_arch,$offset_day,$search_phase,$url_prev,$tag_count) = split("@",$uri_d);
	$s_variables[tslice] = $tslice;
	$s_variables[offset_arch] = $offset_arch;
	$s_variables[offset_day] = $offset_day;
	$s_variables[search_phase] = $search_phase;
	$s_variables[url_prev] = $url_prev;
	$s_variables[tag_count] = $tag_count;
	return $s_variables;

}

function decode_trange($url,$token,$url_key) {

	$key=$url_key;
	$url = str_replace("kezyt2s0", "+",$url);
	$uri_d=decrypt_aes($key,$url);
	$uri_d = strrev($uri_d);
	list($time2_start,$time2_end) = split("@",$uri_d);
	$time2s[0] = $time2_start;
	$time2s[1] = $time2_end;
	return $time2s;

}


function decode_predefined($url,$token,$url_key) {
	$key=$url_key;
	$url = str_replace("kezyt2s0", "+",$url);
	$uri_d=decrypt_aes($key,$url);
	$uri_d = strrev($uri_d);
	return $uri_d;

}




function encrypt_aes($key, $plain_text) {
  $plain_text = trim($plain_text);
  $iv = substr(md5($key), 0,mcrypt_get_iv_size (MCRYPT_RIJNDAEL_256,MCRYPT_MODE_CFB));
  $c_t = mcrypt_cfb (MCRYPT_RIJNDAEL_256, $key, $plain_text, MCRYPT_ENCRYPT, $iv);
  return base64_encode($c_t);
}

function decrypt_aes($key, $c_t) {
  $c_t = base64_decode($c_t);
  $iv = substr(md5($key), 0,mcrypt_get_iv_size (MCRYPT_RIJNDAEL_256,MCRYPT_MODE_CFB));
  $p_t = mcrypt_cfb (MCRYPT_RIJNDAEL_256, $key, $c_t, MCRYPT_DECRYPT, $iv);
  return trim($p_t);
}



function check_registered_user ($bazaj,$sess) {

	if (!$sess->is_registered('login')) 
		{
			return "f";
  		}
	else {

		if (auth($bazaj,$sess->get('uid_l'),$sess->get('uid_p')) != "t") { 

			return "f";

		}
		else {
			return "t";
			}


	}

return "f";

}

function is_query_from($query) {

	list($from,$talker,$query_p) = split(":",$query);
	$from=trim($from);
	if ($from=="from") {
				$qquery[from] = "t";
				$qquery[talker] = trim($talker);
				$qquery[talker] = str_replace("//","@",$qquery[talker]); // hack for parametrized search
				if ($query_p) {
					$qquery[query] = $query_p;
					$qquery[words] = "t";
					return $qquery;
					}
					else
					{
					$qquery[words] = "f";
					return $qquery;
					}
	}

	else {

	// normal search
	return "f";

	}


}


function db_q($user_id,$server="",$tslice_table="",$talker="",$search_p="",$type,$start="",$xmpp_host,$num_lines_bro="",$time_s="",$end_s="") {

	$start_set=$start;
	if ($start_set=="") { $start_set="0"; }
	$end_set=$start+$num_lines_bro;

	if ($time_s AND $end_s) {

		$add_tl = " and str_to_date(at,'%Y-%m-%d') >= str_to_date('$time_s','%Y-%m-%d') and str_to_date(at,'%Y-%m-%d') <= str_to_date('$end_s','%Y-%m-%d')";

	}

	// archiwa rozmów: przegl±danie:
	if ($type=="1") {

		$query="select at from `logdb_stats_$xmpp_host` where owner_id='$user_id' $add_tl order by str_to_date(at,'%Y-%m-%d') asc";
		#select * from `logdb_stats_jabber_autocom_pl` where owner_id='1' and str_to_date(at,'%Y-%m-%d') >= str_to_date('2007-6-21','%Y-%m-%d') and str_to_date(at,'%Y-%m-%d') < str_to_date('2007-7-1','%Y-%m-%d') order by str_to_date(at,'%Y-%m-%d') desc;
	}

	// rozmowy w danym dniu
	if ($type=="2") {
		$query = "select peer_name_id as todaytalk, peer_server_id as server from `$tslice_table` where owner_id='$user_id' group by peer_name_id,peer_server_id";
	}

	// rozmowy z danym u¿ytkownikiem
	if ($type=="3") {
		$query="select from_unixtime(timestamp+0) as ts,direction, peer_name_id, peer_server_id, body from `$tslice_table` where owner_id = '$user_id' and peer_name_id='$talker' and peer_server_id='$server' order by ts limit $start_set,$end_set";
	}

	// wyszukiwanie frazy
	if ($type=="4") {
		$query="select from_unixtime(timestamp+0) as ts, peer_name_id, peer_server_id, direction, body, match(body) against('$search_p' IN BOOLEAN MODE) as score from `logdb_messages_$tslice_table"."_$xmpp_host` where match(body) against('$search_p' IN BOOLEAN MODE) and owner_id='$user_id' limit $start_set,10000";
	}

	// wyszukiwanie wszystkich rozmów z danym userem
	if ($type=="5" OR $type=="7") {

		if ($type=="5") {
			$addq = "match(body) against('$search_p' IN BOOLEAN MODE) and";
			$adds = ",match(body) against('$search_p' IN BOOLEAN MODE) as score";
			}
			else { $addq=""; }

		$query="select from_unixtime(timestamp+0) as ts, peer_name_id, peer_server_id, direction, body $adds from `logdb_messages_$tslice_table"."_$xmpp_host` where $addq owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' limit $start_set,10000";
	}

	// limited search
	if ($type=="6") {
		$query="select at from `logdb_stats_$xmpp_host` where owner_id='$user_id' $add_tl order by str_to_date(at,\"%Y-%m-%d\") asc limit $start_set,10000";
		}



	#print htmlspecialchars($query)."<br>";
	$result=mysql_query($query) or die;
	if (mysql_errno()) { return "f"; }
	return $result;

}


function get_user_id($token,$xmpp_host) {
	$result = mysql_query("select user_id from `logdb_users_$xmpp_host` where username='$token'");
	$row = mysql_fetch_row($result);
	$user_id=$row[0];
	if ($user_id) { return $user_id; } else { return "f";}

}

function get_user_name($user_id,$xmpp_host) {

	$result=mysql_query("select username from `logdb_users_$xmpp_host` where user_id='$user_id'");
	$row=mysql_fetch_row($result);
	$user_name = $row[0];
	if ($user_name) { return $user_name; } else { return "f";}

}

function get_num_lines($tslice_table,$user_id,$talker,$server) {

	$result=mysql_query("select count(timestamp) from `$tslice_table` where owner_id = '$user_id' and peer_name_id='$talker' and peer_server_id='$server'");
	$row=mysql_fetch_row($result);
	$num=$row[0];
	return $num;
}

function get_server_name ($server_id,$xmpp_host) {


	$result=mysql_query("select server from `logdb_servers_$xmpp_host` where server_id ='$server_id'");
	$row=mysql_fetch_row($result);
	$server_name = $row[0];
	if ($server_name) { return $server_name; } else { return "f";}

}


function get_stats($user_id,$tslice,$xmpp_host) {

	$result=mysql_query("select count from `logdb_stats_$xmpp_host` where owner_id='$user_id' and at='$tslice'");
	$row=mysql_fetch_row($result);
	$stats=$row[0];
	mysql_free_result($result);
	return $stats;

}


function get_server_id ($server_name,$xmpp_host) {

	$result=mysql_query("select server_id from `logdb_servers_$xmpp_host` where server ='$server_name'");
	$row=mysql_fetch_row($result);
	$server_id=$row[0];
	if ($server_id) { return $server_id; } else { return "f";}

}


function get_my_links_count ($user_id) {

	$result=mysql_query("select count(id_link) from jorge_mylinks where owner_id='$user_id'");
	$row=mysql_fetch_row($result);
	$my_links_count=$row[0];
	if ($my_links_count) { return $my_links_count; } else { return "0";}

}


function set_log_t($token,$xmpp_host) {


	$result=mysql_query("select user_id from `logdb_users_$xmpp_host` where username = '$token'");
	$row=mysql_fetch_row($result);
	$user_id = $row[0];
	if (!$user_id) {
		$query="insert into `logdb_users_$xmpp_host` set username='$token'";
		$result = mysql_query($query) or die ("Error2");

	}

	$query="insert into `logdb_settings_$xmpp_host` (owner_id,dolog_default) values ((select user_id from `logdb_users_$xmpp_host` where username='$token'), '1')";
	$result = mysql_query($query) or die ("Error");
	return "t";
}


function update_set_log_tgle($user_id,$xmpp_host) {

	$result = mysql_query("select dolog_default from `logdb_settings_$xmpp_host` where owner_id='$user_id'");
	$row = mysql_fetch_row($result);
	if ($row[0] == "0") { $settings="1"; } elseif ($row[0] == "1") { $settings="0"; }

	$query = "update `logdb_settings_$xmpp_host` set dolog_default = '$settings' where owner_id = '$user_id'";
	$result = mysql_query($query) or die ("Error");
	if ($settings=="1") { return "on"; } elseif ($settings=="0") { return "off"; } 
	return "f";
}

function is_log_enabled($user_id,$xmpp_host) {

	$result=mysql_query("select dolog_default from `logdb_settings_$xmpp_host` where owner_id='$user_id'");
	$row=mysql_fetch_row($result);
	$is_enabled=$row[0];

	if ($is_enabled == "1" || $is_enabled == "0") 
			{ 
				if ($is_enabled=="1") { $log_status="1"; } else { $log_status="0"; }
				$ret_v[0] = "t";
				$ret_v[1] = $log_status;
				return $ret_v;
			} 

			else 
				{ return "f";}

}


function turn_red($haystack,$needle)
{
     $h=strtoupper($haystack);
     $n=strtoupper($needle);
     $pos=strpos($h,$n);
     if ($pos !== false)
         {
        $var=substr($haystack,0,$pos)."<span class=\"hlt\">".substr($haystack,$pos,strlen($needle))."</span>";
        $var.=substr($haystack,($pos+strlen($needle)));
        $haystack=$var;
        }
     return $haystack;
}


function parse_urls($text, $maxurl_len = 40, $target = '_blank')
{
    if (preg_match_all('/((ht|f)tps?:\/\/([\w\.]+\.)?[\w-]+(\.[a-zA-Z]{2,4})?[^\s\r\n\(\)"\'<>\!]+)/si', $text, $urls))
    {
        $offset1 = ceil(0.65 * $maxurl_len) - 2;
        $offset2 = ceil(0.30 * $maxurl_len) - 1;
       
        foreach (array_unique($urls[1]) AS $url)
        {
            if ($maxurl_len AND strlen($url) > $maxurl_len)
            {
                $urltext = substr($url, 0, $offset1) . '...' . substr($url, -$offset2);
            }
            else
            {
                $urltext = $url;
            }
           
            $text = str_replace($url, '<a href="'. $url .'" target="'. $target .'" title="'. $url .'" class="menue">'. htmlspecialchars($urltext) .'</a>', $text);
        }
    }

    return $text;
} 

function verbose_date($dd,$lang="",$t="") {
	// this function need to be changed!
	if ($t=="m") {
		$dd=strftime("%e.%m (%A)",strtotime("$dd")); }
		else {
		$dd=strftime("%e.%m.%Y, %A", strtotime("$dd")); }
	$ee = array("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday");
	$ee_pol = array("Pon","Wto","¦ro","Czw","Pi±","Sob","Nie");
	$ee_eng = array("Mon","Tue","Wed","Thu","Fri","Sat","Sun");
	$ss_eng = array("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	$ss = array("January","February", "March", "April", "May","June","July","August","September","October", "November","December");
	$ss_pol=array("Stycznia","Luty","Marca","Kwietnia","Maja","Czerwca","Lipca","Sierpnia","Wrzesnia","Pazdziernika","Listopada","Grudnia");
	if ($lang=="pol") { $repl1=$ee_pol; } elseif($lang=="eng") { $repl1=$ee_eng; } elseif($lang=="") { $repl1=$ee_eng; }
	$g=str_replace($ee,$repl1,$dd);
	$ss_r="";
	return str_replace($ss,$ss_r,$g);

}

function verbose_mo($dd,$lang) {
	// this function need to be changed!
	 $dd=strftime("%b %Y",strtotime($dd));
	 $ss_eng = array("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"); // replace patern
	 $ss = array("January","February", "March", "April", "May","June","July","August","September","October", "November","December"); // to verb eng
	 $ss_pol=array("Styczeñ","Luty","Marzec","Kwiecieñ","Maj","Czerwiec","Lipiec","Sierpieñ","Wrzesieñ","Pa¼dziernik","Listopad","Grudzieñ"); // to verb pol
	 if ($lang=="pol") { $repl1=$ss_pol; } elseif($lang=="eng") { $repl1=$ss; } elseif($lang=="") { $repl1=$ss; }
	 $g=str_replace($ss_eng,$repl1,$dd);
	 return $g;
}



function pl_znaczki($string) {
	$string=iconv("iso-8859-2","UTF-8", "$string");
	return $string;
}




function validate_start($start) {

	if (!ctype_digit($start)) { return "f"; }
	if (fmod($start,10)=="0") { return "t"; } else { return "f"; }

}

function db_size() {

  $result = mysql_query("show table status");
  $size = 0;
  while($row = mysql_fetch_array($result)) {
      $size += $row["Data_length"];
  }
  $size = round(($size/1024)/1024, 1);
  return $size;

}

function verbose_split_line($in_minutes,$lang,$verb_h,$in_min) {

	if ($in_minutes>60) {
		return $verb_h[$lang];
	}
	elseif ($in_minutes<60)  {
		return $in_minutes." ".$in_min[$lang];
	}

}

function cut_nick($nick) {

	if (strlen($nick)> 25) {
		$nick=substr($nick,0,25)."...";

	}
	
	return $nick;
}

function total_messages($xmpp_host) {

  $result = mysql_query("select count from `logdb_stats_$xmpp_host`");
  $m_count = 0;
  while($row = mysql_fetch_array($result)) {
      $m_count += $row["count"];
  }
  
  return $m_count;

}


function get_do_log_list($user_id,$xmpp_host) {

	$result = mysql_query("select donotlog_list from logdb_settings_$xmpp_host where owner_id = '$user_id'");
	$row = mysql_fetch_row($result);
	$splited_list = explode("\n", $row[0]);
	return $splited_list;

}
?>
