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
*/

class roster {

        protected $roster_item;
        protected $roster;

        public function add_item($jid,$nick,$group) {

                $get_items = $this->roster;
                $new_item[$jid] = array("nick"=>$nick,"group"=>$group);
                if ($this->roster) {
                                $this->roster = array_merge($get_items,$new_item);
                        }
                        else {
                                $this->roster = $new_item;
                        }

        }

        public function get_roster() {

                return $this->roster;

        }

        public function get_nick($jid) {

		$roster = $this->roster;
		$nick = $roster[$jid][nick];
		return htmlspecialchars($nick);

        }

        public function get_group($jid) {

		$roster = $this->roster;
		$group = $roster[$jid][group];
		return htmlspecialchars($group);
        }

	public function get_nick_group($jid) {

		$roster = $this->roster;
		$result = array($roster[$jid][nick],$roster[$jid][group]);
		return $result;

	}

	public function sort_by_jid($dir) {

		$arr = $this->roster;
		if ($dir==="az") {
				ksort($arr);
			}

		elseif($dir==="za") {
				krsort($arr);
			}
		else{
				return false;
		}
		
		$this->roster = $arr;

	}

	public function sort_by_nick($dir) {

		$this->sort_roster($dir,"nick");
	}


	public function sort_by_group($dir) {

		$this->sort_roster($dir,"group");

	}

	protected function sort_roster($dir,$field) {

		$arr = $this->roster;
		if ($dir ==="az") {

			array_multisort($this->prepare_multisort("$field"),SORT_ASC,$arr);

			}
		elseif($dir==="za") {

			array_multisort($this->prepare_multisort("$field"),SORT_DESC,$arr);

		}
		else{
				return false;
		}

		$this->roster = $arr;

	}

	protected function prepare_multisort($val) {
		$arr = $this->roster;
		foreach ($arr as $key => $row) {
			$field[$key] = $row[$val];
		}
		$ret = array_map('strtolower', $field);
		return $ret;

	}
}

?>
