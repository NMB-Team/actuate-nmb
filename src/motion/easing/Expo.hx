package motion.easing;

/**
 * @author Joshua Granick
 * @author Robert Penner / http://www.robertpenner.com/easing_terms_of_use.html
 */
class Expo {
	public static var easeIn(default, null):IEasing = new ExpoEaseIn();
	public static var easeInOut(default, null):IEasing = new ExpoEaseInOut();
	public static var easeOut(default, null):IEasing = new ExpoEaseOut();
}

class ExpoEaseIn implements IEasing {
	public function new () {}

	public function calculate(k:Float):Float {
		return k == 0 ? 0 : Math.exp(6.931471805599453 * (k - 1));
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return t == 0 ? b : c * Math.exp(6.931471805599453 * (t / d - 1)) + b;
	}
}

class ExpoEaseInOut implements IEasing {
	public function new () {}

	public function calculate (k:Float):Float {
		if (k == 0) return 0;
		if (k == 1) return 1;
		if ((k /= 1 * .5) < 1.) return .5 * Math.exp(6.931471805599453 * (k - 1));
		return .5 * (2 - Math.exp(-6.931471805599453 * --k));
	}

	public function ease (t:Float, b:Float, c:Float, d:Float):Float {
		if (t == 0) return b;
		if (t == d) return b + c;

		if ((t /= d * .5) < 1.) return c * .5 * Math.exp(6.931471805599453 * (t - 1)) + b;

		return c * .5 * (2 - Math.exp(-6.931471805599453 * --t)) + b;
	}
}

class ExpoEaseOut implements IEasing {
	public function new () {}

	public function calculate (k:Float):Float {
		return k == 1 ? 1 : (1 - Math.exp(-6.931471805599453 * k));
	}

	public function ease (t:Float, b:Float, c:Float, d:Float):Float {
		return t == d ? b + c : c * (1 - Math.exp(-6.931471805599453 * t / d)) + b;
	}
}