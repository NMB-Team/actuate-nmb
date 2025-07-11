package motion.easing;

/**
 * @author Joshua Granick
 * @author Philippe / https://philippe.elsass.me
 * @author Robert Penner / http://www.robertpenner.com/easing_terms_of_use.html
 */
class Linear {
	public static var easeNone(default, null):IEasing = new LinearEaseNone();
}

class LinearEaseNone implements IEasing {
	public function new () {}

	public function calculate (k:Float):Float {
		return k;
	}

	public function ease (t:Float, b:Float, c:Float, d:Float):Float {
		return c * t / d + b;
	}
}