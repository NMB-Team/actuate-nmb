package motion.easing;

/**
 * @author Erik Escoffier
 * @author Robert Penner / http://www.robertpenner.com/easing_terms_of_use.html
 */
class Bounce {
	public static var easeIn(default, null):IEasing = new BounceEaseIn();
	public static var easeInOut(default, null):IEasing = new BounceEaseInOut();
	public static var easeOut(default, null):IEasing = new BounceEaseOut();
}

class BounceEaseIn implements IEasing {
	public function new() {}

	public function calculate(k:Float):Float {
		return BounceEaseIn._ease(k, 0, 1, 1);
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return BounceEaseIn._ease(t, b, c, d);
	}

	public static inline function _ease(t:Float, b:Float, c:Float, d:Float):Float {
		return c - BounceEaseOut._ease(d - t, 0, c, d) + b;
	}
}

class BounceEaseInOut implements IEasing {
	public function new() {}

	public function calculate(k:Float):Float {
		return (k < .5) ? BounceEaseIn._ease(k * 2, 0, 1, 1) * .5 : BounceEaseOut._ease(k * 2 - 1, 0, 1, 1) * .5 + 1 * .5;
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return (t < d * .5) ? BounceEaseIn._ease(t * 2, 0, c, d) * .5 + b : BounceEaseOut._ease(t * 2 - d, 0, c, d) * .5 + c * .5 + b;
	}
}

class BounceEaseOut implements IEasing {
	static final B1 = 1 / 2.75;
	static final B2 = 2 / 2.75;
	static final B3 = 1.5 / 2.75;
	static final B4 = 2.5 / 2.75;
	static final B5 = 2.25 / 2.75;
	static final B6 = 2.625 / 2.75;
	static final B7 = 7.5625;

	public function new() {}

	public function calculate(k:Float):Float {
		return BounceEaseOut._ease(k, 0, 1, 1);
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return BounceEaseOut._ease(t, b, c, d);
	}

	public static inline function _ease(t:Float, b:Float, c:Float, d:Float):Float {
		if ((t /= d) < B1)
			return c * (B7 * t * t) + b;
		else if (t < B2)
			return c * (B7 * (t -= B3) * t + .75) + b;
		else if (t < B4)
			return c * (B7 * (t -= B5) * t + .9375) + b;
		else
			return c * (B7 * (t -= B6) * t + .984375) + b;
	}
}
