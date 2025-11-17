package motion.easing;

/**
 * @author Joshua Granick
 * @author Philippe / https://philippe.elsass.me
 * @author Robert Penner / http://www.robertpenner.com/easing_terms_of_use.html
 */
class Cubic {
	public static var easeIn(default, null):IEasing = new CubicEaseIn();
	public static var easeInOut(default, null):IEasing = new CubicEaseInOut();
	public static var easeOut(default, null):IEasing = new CubicEaseOut();
}

class CubicEaseIn implements IEasing {
	public function new() {}

	public function calculate(k:Float):Float {
		return k * k * k;
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return c * (t /= d) * t * t + b;
	}
}

class CubicEaseInOut implements IEasing {
	public function new() {}

	public function calculate(k:Float):Float {
		return ((k /= 1 * .5) < 1) ? .5 * k * k * k : .5 * ((k -= 2) * k * k + 2);
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return ((t /= d * .5) < 1) ? c * .5 * t * t * t + b : c * .5 * ((t -= 2) * t * t + 2) + b;
	}
}

class CubicEaseOut implements IEasing {
	public function new() {}

	public function calculate(k:Float):Float {
		return --k * k * k + 1;
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return c * ((t = t / d - 1) * t * t + 1) + b;
	}
}
