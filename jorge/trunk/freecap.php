<?
#session_start();

class session {

    var $id;

    function session ($lifetime=10800) { // czas ¿ycia sesji
          @session_start();
    }

    function unregister($name) {
        unset($HTTP_SESSION_VARS[$name]);
    }

    function is_registered($name) {
        if (isset($_SESSION[$name])) return true;
          else return false;
    }

    function get($name) {
        return $_SESSION[$name];
    }

    function set($name,$value) {
        $_SESSION[$name]=$value;
    }

    // zwraca id sesji uzytkownika
    function id() {
          return(@session_id());
    }

    // ubija sesje - logout
    function finish() {
          //$id_session = $this->id();
          @session_unset();
          @session_destroy();
    }

}

$sess = new session;

header ("Content-type: image/png");

// if false, generates quasi-random string (harder for humans to read, though)
$use_dict = true;

// true=transparent background, false=white
$bg_trans = true;

// colour of word
$text_r = rand(50,150);
$text_g = rand(50,150);
$text_b = rand(50,150);

// get word
if($use_dict==true)
{
	// load dictionary and choose random word
	// keep dictionary in non-web accessible folder, or htaccess it
	// or modify so word comes from a database; SELECT word FROM words ORDER BY rand() LIMIT 1
	// took 0.11 seconds when 'words' had 10,000 records

	$words = file("./urutyew231434sd.txt");
	$word = strtolower($words[rand(0,sizeof($words)-1)]);
	// cut off line endings/other possible odd chars
	$word = ereg_replace("[^a-z]","",$word);
	// might be large file so forget it now
	unset($words);
} else {
// modified from code by breakzero at hotmail dot com
// (http://uk.php.net/manual/en/function.rand.php)
// doesn't use easily mistaken chars like ij1lo0
	$consonant = 'bcdfghkmnpqrstuvwx2345789';
	$vowel = 'aeyu';
	$word = "";

	$wordlen = rand(5,6);

	for($i=0 ; $i<$wordlen ; $i++)
	{
		// don't allow to start with 'vowel'
		if(rand(0,2)==1 && $i!=0)
		{
			$word .= substr($vowel,rand(1,strlen($vowel))-1,1);
		} else {
			$word .= substr($consonant,rand(1,strlen($consonant))-1,1);
		}
	}
}

// save word for comparison
// $_SESSION['freecap_word'] = $word;

$sess->set('image_w',$word);

// modify width depending on maximum possible length of word
// you shouldn't need to use words > 6 chars in length though.
$width = 250;
$height = 60;

$im = ImageCreate($width, $height);
if(!$bg_trans)
{
	// blends colours, but is a pain to get nice transparency if true colour
	$im2 = ImageCreateTrueColor($width, $height);
} else {
	$im2 = ImageCreate($width, $height);
}

// set background colour (can change to any colour not in 50-150 range)
$bg = ImageColorAllocate($im, 255, 255, 255);

// set text colour
$text_color = ImageColorAllocate($im, $text_r, $text_g, $text_b);

// write word in random position, in random font size
$word_start_x = rand(1,30);
$word_start_y = rand(1,3);
$font_size = rand(2,5);
ImageString($im, $font_size, $word_start_x, $word_start_y, $word, $text_color);

// enlarge itself
// (could be acheived by using larger font; for compatibility, leave as is for now)
// randomly scale between 2 and 3 times orig size
$scale = "2.".rand(1,9999);
$scale = floatval($scale);
$width_scaled = $width*$scale;
$height_scaled = $height*$scale;
ImageCopyResampled($im2, $im, 0, 0, 0, 0, $width_scaled, $height_scaled, $width, $height);

// blank original image out
ImageFilledRectangle($im,0,0,$width,$height,$bg);

// randomly morph each character on x-axis
// copies enlarged text back to original image
$morph_factor = 2;
$y_chunk = 1;
for($i=0 ; $i<=$height_scaled ; $i+=$y_chunk)
{
	// change amount of y_chunk
	$y_chunk = rand(1,3);

	for($j=0 ; $j<=strlen($word) ; $j++)
	{
		$orig_x = ($word_start_x+$j*($font_size+4))*$scale;
		$morph_x = $orig_x + rand(-$morph_factor,$morph_factor);
		ImageCopy($im, $im2, $morph_x, $i, $orig_x, $i, 21, $y_chunk);
	}
}

// randomly morph word along y-axis
$word_start_x *= $scale;
$x_chunk = rand(5,10);
$word_pix_size = $word_start_x+(strlen($word)*($font_size+4)*$scale);

for($i=$word_start_x ; $i<=$word_pix_size ; $i+=$x_chunk)
{
	ImageCopy($im2, $im, $i, rand(-1,1), $i, 0, $x_chunk+1, $height);
}

if($bg_trans==true)
{
	// make background transparent
	ImageColorTransparent($im2,$bg);
}

// tag it (feel free to remove/change (but if it's not essential I'd appreciate you leaving it))
$lt_grey = ImageColorAllocate($im2,128,128,128);

// ensure tag is right-aligned
#$tag_str = "freeCap v1.00 - puremango.co.uk";
#$tag_width = strlen($tag_str)*6;

// write tag
ImageString($im2, 2, $width-$tag_width, 45, $tag_str, $lt_grey);

// output image
ImagePNG($im2);

// kill GD images (removes from memory)
ImageDestroy($im);
ImageDestroy($im2);
exit();
?>
