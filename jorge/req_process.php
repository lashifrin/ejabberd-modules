<?
header("content-type: text/html; charset=utf-8");
// includes
require("func.php");
require("sessions.php");
require("config.php");
require("lang.php");
// sessions and db connections
$sess = new session;
$bazaj=db_e_connect($db_ejabberd);
db_connect($mod_logdb);
$xmpp_host_dotted=str_replace("_",".",$xmpp_host);
$token=$sess->get('uid_l');

// check user session
if (check_registered_user($bazaj,$sess) != "t") { header("Location: index.php?act=logout"); exit; }
$user_id=get_user_id($token,$xmpp_host);
if (!ctype_digit($user_id)) { print 'Service unavailable'; exit; }

// language
$lang=$sess->get('language');

// get POST data
$request=$_POST['a'];
$process_id=$_POST['req'];

// processing ...
if ($process_id=="1") {

	// processing favorites request

	// decompose link
	$variables = decode_url2($request,$token,$url_key);
	$tslice = $variables[tslice];
	$talker = $variables[talker];
	$server = $variables[server];
	// validate
	if (validate_date($tslice) == "f" OR !ctype_digit($talker) OR !ctype_digit($server)) { print '<div class="message">'.$ajax_error[$lang].'<br><a href="#" onClick="$(\'#fav_result\').fadeOut(\'slow\');" ><u>'.$fav_discard[$lang].'</u></a></div>'; exit; }

	//insert data
	$check=ch_favorite($user_id,$tslice,$talker,$server);
	if ($check=="f") {
		print '<div class="message">'.$ajax_error[$lang].'<br><a style="font-weight: normal;" href="#" onClick="$(\'#fav_result\').fadeOut(\'slow\');" ><u>'.$fav_discard[$lang].'</u></a></div>'; exit;
		}
	elseif($check=="1") {
		print '<div class="message">'.$fav_exist[$lang].'<br><a style="font-weight: normal;" href="#" onClick="$(\'#fav_result\').fadeOut(\'slow\');" ><u>'.$fav_discard[$lang].'</u></a></div>'; exit;
		}
	elseif($check=="0") {

		mysql_query("insert into jorge_favorites(owner_id,peer_name_id,peer_server_id,tslice) values(
			'$user_id',
			'$talker',
			'$server',
			'$tslice')") or die;
		echo "qqqqq:$check";
		echo '<div class="message">'.$fav_success[$lang].'<br><a style="font-weight: normal;" href="#" onClick="$(\'#fav_result\').fadeOut(\'slow\');" ><u>'.$fav_discard[$lang].'</u></a></div>'; 

	}

}


mysql_close();

?>
