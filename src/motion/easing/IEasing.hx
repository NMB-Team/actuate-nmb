package motion.easing;

/**
 * @author Joshua Granick
 * @author Philippe / https://philippe.elsass.me
 */
interface IEasing {
	function calculate(k:Float):Float;
	function ease(t:Float, b:Float, c:Float, d:Float):Float;
}