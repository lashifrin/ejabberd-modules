<?
/*
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

###########################################################################

Helper classes for Jorge. Performs various operations.


*/

Class url_crypt Extends parser {

	private $td;

	public function __construct($key) {
		
		$td = mcrypt_module_open('rijndael-256', '', 'ecb', '');
		$key = substr($key, 0, mcrypt_enc_get_key_size($td));
		$iv_size = mcrypt_enc_get_iv_size($td);
		$iv = mcrypt_create_iv($iv_size, MCRYPT_RAND);
		mcrypt_generic_init($td, $key, $iv);
		$this->td = $td;
	}

	public function __destruct() {

		mcrypt_generic_deinit($this->td);
		mcrypt_module_close($this->td);

	}

	public function crypt_url($url) {

		return str_replace("+", "kezyt2s0", $this->url_encrypt($url));
	}

	public function decrypt_url($url) {

		$url = str_replace("kezyt2s0", "+",$url);
		$this->decode_string($this->url_decrypt(base64_decode($url)));
		return true;

	}

	private function url_encrypt($url) {

		$prepared_string = "begin&".$url;
		$integrity = md5($prepared_string);
		$url = "integrity=$integrity&".$prepared_string;
		$td = $this->td;
        	$c_t = mcrypt_generic($td, $url);
		return base64_encode($c_t);

	}

	private function url_decrypt($url) {

		$td = $this->td;
		$p_t = mdecrypt_generic($td, $url);
		return trim($p_t);

	}

}


Class parser {

	public $tslice = null;
	public $peer_name_id = null;
	public $peer_server_id = null;
	public $ismylink = null;
	public $linktag = null;
	public $strt = null;
	public $lnk = null;
	public $action = null;

	protected function decode_string($url) {

		parse_str($url);
		$reconstructed = strstr($url,"begin");
		settype($integrity,"string");
		if ($integrity === md5($reconstructed)) { 
				
				if (isset($tslice)) { $this->tslice = $tslice; }
				if (isset($peer_name_id)) { $this->peer_name_id = $peer_name_id; }
				if (isset($peer_server_id)) { $this->peer_server_id = $peer_server_id; }
				if (isset($lnk)) { $this->lnk = $lnk; }
				if (isset($ismylink)) { $this->ismylink = $ismylink; }
				if (isset($linktag)) { $this->linktag = $linktag; }
				if (isset($strt)) { $this->strt = $strt; }
				if (isset($action)) { $this->action = $action; }
				return true;
				
			} 
			else { 
				
				return false;
				
			}

	return false;
	}


}

?>
