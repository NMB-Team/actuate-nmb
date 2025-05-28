package motion.easing;

/**
 * @author Joshua Granick
 * @author Philippe / https://philippe.elsass.me
 * @author Robert Penner / http://www.robertpenner.com/easing_terms_of_use.html
 */
class Linear {
	static public var easeNone(get, never):IEasing;

	#if commonjs
	@:noCompletion static function __init__ () {
		untyped Object.defineProperties (Linear, {"easeNone": {get: () -> return Linear.get_easeNone()}});
	}
	#end

	@:noCompletion static function get_easeNone():IEasing {
		return new LinearEaseNone();
	}
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