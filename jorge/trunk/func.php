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

if (__FILE__==$_SERVER['SCRIPT_FILENAME']) {

	header("Location: index.php?act=logout");
	exit;

}


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

function decode_url_simple($url,$token,$url_key) {

	$key=$url_key;
	$url = str_replace("kezyt2s0", "+",$url);
	$uri_d=decrypt_aes($key,$url);
	$uri_d = strrev($uri_d);
	return $uri_d;
	
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



function check_registered_user ($sess,$xmpp_host_dotted,$rpc_host,$rpc_port) {

	if (!$sess->is_registered('login')) 
		{
			return "f";
  		}
	else {

		if (rpc_auth($sess->get('uid_l'),$sess->get('uid_p'),$xmpp_host_dotted,$rpc_host,$rpc_port) === true) {

			return "t";

		}
		else {
			return "f";
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


function db_q($user_id,$server="",$tslice_table="",$talker="",$search_p="",$type,$start="",$xmpp_host,$num_lines_bro="",$time_s="",$end_s="",$res_id="") {

	$start_set=$start;
	if ($start_set=="") { $start_set="0"; }
	$end_set=$start+$num_lines_bro;

	if ($time_s AND $end_s) {

		$add_tl = " and str_to_date(at,'%Y-%m-%d') >= str_to_date('$time_s','%Y-%m-%d') and str_to_date(at,'%Y-%m-%d') <= str_to_date('$end_s','%Y-%m-%d')";

	}

	// chat list
	if ($type=="1") {

		$query="select distinct(at) from `logdb_stats_$xmpp_host` where owner_id='$user_id' $add_tl order by str_to_date(at,'%Y-%m-%d') asc";
	}

	// chat list - specific day
	if ($type=="2") {

		$query="select a.username, b.server as server_name, c.peer_name_id as todaytalk, c.peer_server_id as server, c.count as lcount from `logdb_users_$xmpp_host` a, `logdb_servers_$xmpp_host` b, `logdb_stats_$xmpp_host` c where c.owner_id = '$user_id' and a.user_id=c.peer_name_id and b.server_id=c.peer_server_id and c.at = '$tslice_table' and username!='' order by lower(username)";
	
	}

	// chat with user
	if ($type=="3") {

		if ($res_id>1) { $sel_resource="and (peer_resource_id='$res_id' OR peer_resource_id='1')"; }
		$query="select from_unixtime(timestamp+0) as ts,direction, peer_name_id, peer_server_id, peer_resource_id, body from `$tslice_table` where owner_id = '$user_id' and peer_name_id='$talker' and peer_server_id='$server' $sel_resource and ext is NULL order by ts limit $start_set,$end_set";

	}

	// phase search
	if ($type=="4") {
		$query="select timestamp as ts, peer_name_id, peer_server_id, direction, ext, body, match(body) against('$search_p' IN BOOLEAN MODE) as score from `logdb_messages_$tslice_table"."_$xmpp_host` where match(body) against('$search_p' IN BOOLEAN MODE) and owner_id='$user_id' limit $start_set,10000";
	}

	// user phase search
	if ($type=="5" OR $type=="7") {

		if ($type=="5") {
				$addq = "match(body) against('$search_p' IN BOOLEAN MODE) and";
				$adds = ",match(body) against('$search_p' IN BOOLEAN MODE) as score";
				$tcon = "timestamp as ts,";
			}
			else { 
				$addq=""; 
				$tcon="from_unixtime(timestamp+0) as ts,";
			}

		$query="select $tcon peer_name_id, peer_server_id, direction, ext, body $adds from `logdb_messages_$tslice_table"."_$xmpp_host` where $addq owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' limit $start_set,10000";
	}

	// limited search
	if ($type=="6") {
		$query="select distinct(at) from `logdb_stats_$xmpp_host` where owner_id='$user_id' $add_tl order by str_to_date(at,\"%Y-%m-%d\") asc limit $start_set,10000";
		}


	// optimized user chat list
	if ($type=="8") {

		$query="select at from `logdb_stats_$xmpp_host` where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' order by str_to_date(at,'%Y-%m-%d') asc";
	}


	# uncomment to debug query
	#print "<span style=\"font-size:x-small;\">Query: ".htmlspecialchars($query)." [end] in query type: $type</span><br>";
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

function get_resource_name ($resource_id,$xmpp_host) {

	$result=mysql_query("select resource from `logdb_resources_$xmpp_host` where resource_id = '$resource_id'");
	$row=mysql_fetch_row($result);
	$resource=$row[0];
	if ($resource) { return $resource; } else { return FALSE; }

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
	$string=mb_convert_encoding($string,"UTF-8","ISO-8859-2");
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

  $result = mysql_query("select sum(count) from `logdb_stats_$xmpp_host`");
  $count = mysql_fetch_row($result);
  $m_count = $count[0]; 
  return $m_count;

}

function total_chats($xmpp_host) {

  $result = mysql_query("select count(owner_id) from `logdb_stats_$xmpp_host`");
  $count = mysql_fetch_row($result);
  $m_count = $count[0]; 
  return $m_count;

}



function get_do_log_list($user_id,$xmpp_host) {

	$result = mysql_query("select donotlog_list from logdb_settings_$xmpp_host where owner_id = '$user_id'");
	$row = mysql_fetch_row($result);
	$splited_list = explode("\n", $row[0]);
	return $splited_list;

}


function new_parse_url($text) {

	$text = ereg_replace("([[:alpha:]]+://www|[[:alpha:]]+://)[^<>[:space:]]+[[:alnum:]/]",

                     "<a class=\"clickl\" href=\"\\0\" target=\"_blank\">\\0</a>", $text);

	// disabled for now
	#$text = ereg_replace("[^://]?www[^<>[:space:]]+[[:alnum:]/]",
        #            "<a class=\"clickl\" href=\"http://\\0\" target=\"_blank\">\\0</a>", $text);
	
	return $text;
}

function calendar($user_id,$xmpp_host,$y,$m,$days,$token,$url_key,$months_name_eng,$left,$right,$selected,$lang,$view_type,$c_type,$name_peer=0,$server_peer=0,$cal_days=0) {
	
	$days=$days;
	$month = $m;
	$year = $y;

//create arrays for the calendar

    $months_days = array("31","28","31","30","31","30","31","31",
                         "30","31","30","31");

	$days_array = array("Mon","Tue","Wed","Thu","Fri","Sat","Sun");

//removes the 0 from start of month - can't find array key with 0

    if(strlen($month)==1){
        $month= str_replace("0","",$month);
    }
    else{
        $month=$month;
    }

//reset month to the array key match (array starts at 0)

    $month= $month-1;

//find the days in the month

    $days_in_month = $months_days[$month];

//And convert the month number to name

    $month_name = $months_name_eng[$month];

//$m is used to find month

    $m = $month+1;

//find the first day of the month     
 
    $time = date("M D Y H:i:s", mktime(0, 0, 0, $m, 1, $year));
    $first_day = explode(" ",$time);
    $time = $first_day[1];

//create the links to next and previous months

    $next = $month+2;
    $x = $year;

//if month is 13 then new year

    if($next==13){
        $next=1;
        $x = $x+1;
    }
    $prev = $month;
    $y = $year;

//if month is 0, then previous year

    if($prev==0){
        $prev=12;
        $y=$y-1;
    }

    $calendar = "";

//Build the calendar with css
//links to next and previous month only for browser
if ($c_type=="1") {
	// encode links
	$link_left= encode_url("$y-$prev",$token,$url_key);
	$link_right= encode_url("$x-$next",$token,$url_key);

	// check if we have chats in prev and next mo
	$is_left="select at from `logdb_stats_$xmpp_host` where owner_id='$user_id' and at like '$y-$prev%' limit 1";
	$is_right="select at from `logdb_stats_$xmpp_host` where owner_id='$user_id' and at like '$x-$next%' limit 1";

	$i_left=mysql_num_rows(mysql_query($is_left));
	$i_right=mysql_num_rows(mysql_query($is_right));

	}
	else {

		$i_left=0;
		$i_right=0;

	}

    $calendar .='
	<table width="200"  border="0" cellpadding="0" cellspacing="0" class="calbck">
      	<tr>
        <td><img src="img/cal_corn_11.png" width="15" height="7"></td>
        <td background="img/cal_bck_top.gif"></td>
        <td><img src="img/cal_corn_12.png" width="14" height="7"></td>
      	</tr>
      	<tr>
        <td width="15" valign="top" class="calbckleft"><img src="img/cal_bck_left.png" width="15" height="116">
      	</td>
        <td width="100%" valign="top">
        <table width="100%"  border="0" cellspacing="0" cellpadding="0">
        <tr>
        <td height="15" align="center" class="caldays">
	';

if ($i_left!=0) { $calendar.='<a href="?left='.$link_left.'"><<<</a>'; }

$verb_date = "$year-$m-1";

	    $calendar.='
	    	
		&nbsp;</td>
            	<td colspan="5" align="center" class="calhead">'.verbose_mo($verb_date,$lang).'</td>
            	<td align="center" class="caldays">&nbsp;
		
		';
	  if ($i_right!=0) { $calendar.='<a href="?right='.$link_right.'">>>></a>'; }
	    $calendar.='

	    	</td>
	  	</tr>
          	<tr align="center" class="calweek">
            	<td width="14%" height="15">'.$cal_days[$lang][1].'</td>
            	<td width="14%">'.$cal_days[$lang][2].'</td>
            	<td width="14%">'.$cal_days[$lang][3].'</td>
            	<td width="14%">'.$cal_days[$lang][4].'</td>
            	<td width="14%">'.$cal_days[$lang][5].'</td>
            	<td width="14%">'.$cal_days[$lang][6].'</td>
            	<td width="14%">'.$cal_days[$lang][7].'</td>
          	</tr>
	    
	    ';
               
    //checks for leap years and add 1 to February

    if(($year % 4 =="") && ($month==1)){
        $days_in_month=$days_in_month+1;
    }

    else{
        $days_in_month=$days_in_month;
    }

    $new_time="";
     
    //find how many blank spaces at beginning of the month
     
    foreach($days_array as $key=>$value){
     
        if($value == $time){
            $new_time .= $key+1;
        }
        else{
            $new_time .="";
        }
    }
     
    //loop through the days in the month
	$c=0;

    for($k=1;$k<($days_in_month+$new_time);$k++){   

	$c++;
	if ($c==1) { $calendar.='<tr align="center" class="caldays">'; }


 
            //blank space
     
        if($k<$new_time){
            $calendar.='<td height="15">&nbsp;</td>
            ';
            continue;
        }
         
        //start the actual days
              
        $n = $k-$new_time+1;

        if(in_array($n,$days)){
	
	if ($c_type=="1") {
			$to_base = "$year-$m-$n@";
			$loc_orign="";
		}
		elseif($c_type=="2") {
			$to_base = "$year-$m-$n@$name_peer@$server_peer@";
			$loc_orign="&loc=2";
		}
	$to_base = encode_url($to_base,$token,$url_key);

	    if ($selected==$n) { $bgcolor = 'bgcolor="#6daae7"'; } else { $bgcolor=""; }
            $calendar .= '<td height="15" '.$bgcolor.' onclick="window.location=\''.$view_type.'?a='.$to_base.$loc_orign.'\'"><b><a class="caldays2" href="'.$view_type.'?a='.$to_base.$loc_orign.'">'.$n.'</a></b></td>
                         ';   
        }
        else{
            $calendar .= '<td height="15">'.$n.'</td>
                         ';
        }     

	if ($c==7) { $calendar.='</tr>'; $c=0; }


    }
    $calendar .= '

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

    return($calendar);
}

function save_pref($user_id, $pref_id,$pref_value) {
	if (mysql_num_rows(mysql_query("select pref_id from jorge_pref where owner_id='$user_id' and pref_id='$pref_id'"))!="0" ) {
		mysql_query("update jorge_pref set pref_value='$pref_value' where owner_id='$user_id' and pref_id='$pref_id'") or die;
		return "t";

	}

	else {
		mysql_query("insert into jorge_pref(owner_id,pref_id,pref_value) values ('$user_id','$pref_id','$pref_value')") or die;
		return "t";

	}

return "f";

}

function delete_chat($talker,$server,$xmpp_host,$user_id,$tslice,$token,$url_key,$lnk) {

        if (!ctype_digit($talker) OR !ctype_digit($server)) { return "f"; }
        $query="update `logdb_messages_$tslice"."_$xmpp_host` set ext = '1' where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server'";
        $result=mysql_query($query) or die ("Ooops...Error");
        $query="insert into pending_del(owner_id,peer_name_id,date,peer_server_id) values ('$user_id', '$talker','$tslice','$server')";
        $result=mysql_query($query) or die ("Ooops...Error");
        $jid_date = ' '.get_user_name($talker,$xmpp_host).'@'.get_server_name($server,$xmpp_host).' ('.$tslice.')';
        $query="insert into jorge_logger (id_user,id_log_detail,id_log_level,log_time,extra) values ('$user_id',4,1,NOW(),'$jid_date')";
        mysql_query($query) or die;
	// remove user stats
        $query="delete from `logdb_stats_$xmpp_host` where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' and at='$tslice' limit 1";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);
        // also if there were some saved links - we clean them up from mylinks as well. We are so nice...
        $query="update jorge_mylinks set ext='1' where owner_id ='$user_id' and peer_name_id='$talker' and link like '$lnk%'";
        $result=mysql_query($query) or die ("Ooops...Error");
        mysql_free_result($result);
	// delete from favorites
	$query="update jorge_favorites set ext='1' where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' and tslice='$tslice'";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);
	// links
        $undelete_link = "$tslice@$talker@$server@@@$lnk@undelete@";
        $undelete_link = encode_url($undelete_link,$token,$url_key);
	
return $undelete_link;


}

function undo_deleted_chat($talker,$server,$user_id,$tslice,$xmpp_host,$lnk) {

	if (!ctype_digit($talker) OR !ctype_digit($server)) { return "f"; }
	// undelete chat
	$query="update `logdb_messages_$tslice"."_$xmpp_host` set ext = NULL where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server'";
	$result=mysql_query($query) or die ("Ooops...Error");
	// remove from pending table
	$query="delete from pending_del where owner_id='$user_id' and peer_name_id='$talker' and date='$tslice' and peer_server_id='$server'";
	$result=mysql_query($query) or die ("Ooops...Error");
	// recount message stats for user
	$query="select count(body) from `logdb_messages_$tslice"."_$xmpp_host` where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' and ext is NULL";
	$result=mysql_query($query) or die ("Ooops...Error");
	$row=mysql_fetch_row($result);
	$new_stats=$row[0];
	mysql_free_result($result);

	$query="select * from `logdb_stats_$xmpp_host` where owner_id = '$user_id' and peer_name_id='$talker' and peer_server_id='$server' and at = '$tslice'";
	$result=mysql_query($query) or die("Ooops...Error");
	if (mysql_num_rows($result) < 1 ) {
			$query="insert into `logdb_stats_$xmpp_host` (owner_id,peer_name_id,peer_server_id,at,count) values ('$user_id','$talker','$server','$tslice','$new_stats')";
			mysql_query($query) or die ("Ooops...Error");
			mysql_free_result($result);
		}
		else
		{
			$query="update `logdb_stats_$xmpp_host` set count='$new_stats' where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' and at='$tslice'";
			$result=mysql_query($query) or die ("Ooops...Error");
			mysql_free_result($result);
		}

	// undelete saved links
	$query="update jorge_mylinks set ext=NULL where owner_id ='$user_id' and peer_name_id='$talker' and link like '$lnk%'";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);
	// undelete favorites
	$query="update jorge_favorites set ext=NULL where owner_id='$user_id' and peer_name_id='$talker' and peer_server_id='$server' and tslice='$tslice'";
	$result=mysql_query($query) or die ("Ooops...Error");
	mysql_free_result($result);

return "t";

}

function do_sel_quick($query) {

	$do_query=mysql_query($query);
	if (mysql_errno($do_query)>0) { return "f"; }
	if (mysql_num_rows($do_query)<1) { return "0"; }
	$result=mysql_fetch_row($do_query);
	$m_val=$result[0];
	return $m_val;

}

function do_sel($query) {

	$do_query=mysql_query($query);
	if (mysql_errno($do_query)>0) { return "f"; }
	return $do_query;
	
}

function prev_c_day ($xmpp_host,$tslice, $user_id, $talker, $server) {

	$query="select at from logdb_stats_$xmpp_host where owner_id='$user_id' and peer_name_id = '$talker' and peer_server_id = '$server' and str_to_date(at, '%Y-%m-%d') < str_to_date('$tslice', '%Y-%m-%d') order by str_to_date(at,'%Y-%m-%d') desc limit 1";
	$prev_c_day = mysql_query($query);
	$prev_c_day_m = mysql_fetch_row($prev_c_day);
	$prev_day_c = $prev_c_day_m[0];
	if ($prev_day_c) { return $prev_day_c; } else { return FALSE; }

}


function next_c_day ($xmpp_host,$tslice, $user_id, $talker, $server) {

	$query="select at from logdb_stats_$xmpp_host where owner_id='$user_id' and peer_name_id = '$talker' and peer_server_id = '$server' and str_to_date(at, '%Y-%m-%d') > str_to_date('$tslice', '%Y-%m-%d') order by str_to_date(at,'%Y-%m-%d') asc limit 1";
	$next_c_day = mysql_query($query);
	$next_c_day_m = mysql_fetch_row($next_c_day);
	$next_day_c = $next_c_day_m[0];
	if ($next_day_c) { return $next_day_c; } else { return FALSE; }

}

function ch_favorite($user_id,$tslice,$talker,$server) {

	$check=do_sel_quick("select count(*) from jorge_favorites where owner_id='$user_id' and tslice='$tslice' and peer_name_id='$talker' and peer_server_id='$server'");
	if ($check=="f") { return "f"; }
	elseif($check>0) { return "1"; }
	elseif($check==0) { return "0"; }

}

function remove_messages($user_id,$xmpp_host) {

	// check user_id one more
	if (!ctype_digit($user_id)OR!$xmpp_host) { return "f"; }

	$result=mysql_query("select distinct(at) from `logdb_stats_$xmpp_host` where owner_id='$user_id'");
	if (mysql_num_rows($result)!=0) {
		while ($row=mysql_fetch_array($result)) {
	
			mysql_query("delete from `logdb_messages_$row[at]_$xmpp_host` where owner_id='$user_id'");
			if (mysql_errno()>0) {
					
					// return f on any error
					return "f";
				
				}
	
		}
	
		// remove stats
		mysql_query("delete from `logdb_stats_$xmpp_host` where owner_id='$user_id'");
		// remove mylinks
		mysql_query("delete from jorge_mylinks where owner_id='$user_id'");
		// remove favorites
		mysql_query("delete from jorge_favorites where owner_id='$user_id'");
		// remove from pending_del
		mysql_query("delete from pending_del where owner_id='$user_id'");
		return "t";
	
		}

	else

		{

		return "0";

		}

return "f";

}

function check_thread($user_id,$peer_name_id,$peer_server_id,$at,$xmpp_host,$dir=NULL) {

	#adjust this hours as needed, we assume if chat is +/- 1 hour on the edge of day, then chat is related
	if ($dir=="1") {
		$day="+1 day";
		$bhour="00:00:00";
		$ehour="00:30:00";
	}
	elseif($dir=="2"){
		$day="-1 day";
		$bhour="23:30:00";
		$ehour="23:59:59";
	}

	$get_date = date("Y-n-j", strtotime($day, strtotime(date("$at"))));
	$query="SELECT 1 
		FROM 
			`logdb_messages_".$get_date."_".$xmpp_host."` 
		WHERE 
			owner_id='$user_id' 
		AND 
			peer_name_id='$peer_name_id' 
		AND 
			peer_server_id='$peer_server_id' 
		AND 
			from_unixtime(timestamp) >= str_to_date('$get_date $bhour','%Y-%m-%d %H:%i:%s') 
		AND 
			from_unixtime(timestamp) <= str_to_date('$get_date $ehour','%Y-%m-%d %H:%i:%s')
		ORDER BY 
			from_unixtime(timestamp)";
	$result=mysql_query($query);
	if (mysql_num_rows($result)>0) { 

			mysql_free_result($result);
			return TRUE;
		
		}

		else{
			return FALSE;
		}

return FALSE;

}

function rpc_close_account($user_id,$xmpp_host_dotted,$xmpp_host,$sess,$rpc_host,$rpc_port) {

	$un=$sess->get('uid_l');
	$up=$sess->get('uid_p');
	$parms=array("user"=>"$un","host"=>"$xmpp_host_dotted","password"=>"$up");
	$call=send_rpc_request("delete_account",$parms,$rpc_host,$rpc_port);
	# we need to check weather user exist or not, since ejabberd:remove_user() always return true...
	$parms=array("user"=>"$un","host"=>"$xmpp_host_dotted");
	$call=send_rpc_request("check_account",$parms,$rpc_host,$rpc_port);
	if ($call===1) {
	
		// this is to be removed some day as mod_logdb should use hook for ejabberd_auth:remove(), but for now it does not.
		$result=remove_messages($user_id,$xmpp_host);
		if ($result=="t") {
				
				if (jorge_cleanup($user_id,$xmpp_host)===true) {
						return true; 
					}
					else{
						return false;
					}

				}
			elseif($result=="f") {
				return false;
				}
			else{
				// remove_messages() can return other status beside error
				if (jorge_cleanup($user_id,$xmpp_host)===true) {
						return true; 
					}
					else{
						return false;
					}

				}
			
	}
	elseif($call===0) {

		return false;

	}

return false;

}

function rpc_auth($uid_l,$uid_p,$xmpp_host_dotted,$rpc_host,$rpc_port) {

	$parms=array("user"=>"$uid_l","host"=>"$xmpp_host_dotted","password"=>"$uid_p");
	$call=send_rpc_request("check_password",$parms,$rpc_host,$rpc_port);
	if ($call===0) {
			return true;
		}
		else{
			return false;
		}

return false;

}

function send_rpc_request($method,$parms,$rpc_host,$rpc_port) {

	$request = xmlrpc_encode_request($method,$parms);
	$context = stream_context_create(array('http' => array(
    		'method' => "POST",
    		'header' => "Content-Type: text/xml; charset=utf-8\r\n" .
                "User-Agent: XMLRPC::Client JorgeRPCclient",
    		'content' => $request
	)));

	$file = file_get_contents("http://$rpc_host".":"."$rpc_port", false, $context);
	$response = xmlrpc_decode($file);
	if (xmlrpc_is_fault($response)) {

    		#trigger_error("xmlrpc: $response[faultString] ($response[faultCode])");
		return false;

	} else {

		return $response;
	}

return false;

}

function jorge_cleanup($user_id,$xmpp_host) {

	if (!ctype_digit($user_id)) { return false; }
	$query="delete from jorge_pref where owner_id='$user_id'";
	mysql_query($query);
	if (mysql_errno()>0) { return false; }
	$query="delete from `logdb_settings_".$xmpp_host."` where owner_id='$user_id'";
	mysql_query($query);
	if (mysql_errno()>0) { return false; }
	return true;

}






?>
