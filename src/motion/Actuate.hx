﻿package motion;

import haxe.ds.ObjectMap;
import motion.actuators.FilterActuator;
import motion.actuators.GenericActuator;
import motion.actuators.IGenericActuator;
import motion.actuators.MethodActuator;
import motion.actuators.MotionPathActuator;
import motion.actuators.SimpleActuator;
import motion.actuators.TransformActuator;
import motion.easing.Expo;
import motion.easing.IEasing;

#if openfl
import openfl.display.DisplayObject;
#end

@:access(motion.actuators)
class Actuate {
	#if commonjs
	@:noCompletion private static function __init__() {
		untyped #if haxe4 js.Syntax.code #else __js__ #end ("$global.$haxeUID |= 0;");
	}
	#end

	public static var defaultActuator:Class<IGenericActuator> = SimpleActuator;
	public static var defaultEase:IEasing = Expo.easeOut;

	static var targetLibraries = new ObjectMap<Dynamic, Array<IGenericActuator>>();

	/**
	 * Copies properties from one object to another. Conflicting tweens are stopped automatically
	 * @example		<code>Actuate.apply(MyClip, {alpha: 1});</code>
	 * @param	target		The object to copy to
	 * @param	properties		The object to copy from
	 * @param	customActuator		A custom actuator to use instead of the default (Optional)
	 * @return		The current actuator instance, which can be used to apply properties like onComplete or onUpdate handlers
	 */
	public static function apply<T> (target:T, properties:Dynamic, customActuator:Class<GenericActuator<T>> = null):GenericActuator<T> {
		stop(target, properties);

		if (customActuator == null) customActuator = cast defaultActuator;

		final actuator:GenericActuator<T> = Type.createInstance(customActuator, [target, 0, properties]);
		actuator.apply();

		return actuator;
	}

	#if openfl
	/**
	 * Creates a new effects tween
	 * @param	target		The object to tween
	 * @param	duration		The length of the tween in seconds
	 * @param	overwrite		Sets whether previous tweens for the same target and properties will be overwritten (Default is true)
	 * @return		An EffectsOptions instance, which is used to select the kind of effect you would like to apply to the target
	 */
	public static function effects(target:DisplayObject, duration:Float, overwrite = true):EffectsOptions {
		return new EffectsOptions(target, duration, overwrite);
	}
	#end

	public static var timeScale(get, set):Float;
	static var _timeScale = 1.;

	@:noCompletion static inline function get_timeScale():Float {
		return _timeScale;
	}

	@:noCompletion static inline function set_timeScale(value:Float):Float {
		for (library in targetLibraries)
			for (actuator in library)
				actuator.timeScale = value;

		return _timeScale = value;
	}

	static function getLibrary<T>(target:T, allowCreation = true):Array<IGenericActuator> {
		if (!targetLibraries.exists(target) && allowCreation)
			targetLibraries.set(target, new Array<IGenericActuator>());

		return targetLibraries.get(target);
	}

	/**
	 * Checks if Actuate has any active tweens
	 * @return		Whether Actuate is active
	 */
	public static function isActive():Bool {
		var result = false;
		for (library in targetLibraries) {
			result = true;
			break;
		}

		return result;
	}

	/**
	 * Creates a new MotionPath tween
	 * @param	target		The object to tween
	 * @param	duration		The length of the tween in seconds
	 * @param	properties		An object containing a motion path for each property you wish to tween
	 * @param	overwrite		Sets whether previous tweens for the same target and properties will be overwritten (Default is true)
	 * @return		The current actuator instance, which can be used to apply properties like ease, delay, onComplete or onUpdate
	 */
	public static function motionPath<T>(target:T, duration:Float, properties:Dynamic, overwrite = true):GenericActuator<T> {
		return tween(target, duration, properties, overwrite, MotionPathActuator);
	}

	/**
	 * Pauses tweens for the specified target objects
	 * @param	... targets	The target objects which will have their tweens paused. Passing no value pauses tweens for all objects
	 */
	public static function pause<T>(target:T):Void {
		if (Std.isOfType(target, IGenericActuator)) {
			final actuator:IGenericActuator = cast target;
			actuator.pause();
		} else {
			final library = getLibrary(target, false);

			if (library != null)
				for (actuator in library)
					actuator.pause();
		}
	}

	/**
	 * Pauses all tweens for all objects
	 */
	public static function pauseAll():Void {
		for (library in targetLibraries)
			for (actuator in library)
				actuator.pause();
	}

	/**
	 * Resets Actuate by stopping and removing tweens for all objects
	 */
	public static function reset():Void {
		for (library in targetLibraries) {
			var i = library.length - 1;
			while (i >= 0) {
				library[i].stop(null, false, false);
				i--;
			}
		}

		targetLibraries = new ObjectMap<Dynamic, Array<IGenericActuator>>();
	}

	/**
	 * Resumes paused tweens for the specified target objects
	 * @param	... targets		The target objects which will have their tweens resumed. Passing no value resumes tweens for all objects
	 */
	public static function resume<T>(target:T):Void {
		if (Std.isOfType(target, IGenericActuator)) {
			final actuator:IGenericActuator = cast target;
			actuator.resume();
		} else {
			final library = getLibrary(target, false);

			if (library != null)
				for (actuator in library)
					actuator.resume();
		}
	}

	/**
	 * Resumes all paused tweens for all objects
	 */
	public static function resumeAll():Void {
		for (library in targetLibraries)
			for (actuator in library)
				actuator.resume();
	}

	/**
	 * Stops all tweens for an individual object
	 * @param	target		The target object which will have its tweens stopped, or a generic actuator instance
	 * @param	properties		A string, array or object which contains the properties you wish to stop, like "alpha", [ "x", "y" ] or { alpha: null }. Passing no value removes all tweens for the object (Optional)
	 * @param	complete		If tweens should apply their final target values before stopping. Default is false (Optional)
	 * @param	sendEvent	If a complete() event should be dispatched for the specified target. Default is true (Optional)
	 */
	public static function stop<T>(target:T, properties:Dynamic = null, complete = false, sendEvent = true):Void {
		if (target != null) {
			if (Std.isOfType(target, IGenericActuator)) {
				final actuator:IGenericActuator = cast target;
				actuator.stop(null, complete, sendEvent);
			} else {
				final library = getLibrary(target, false);
				if (library != null) {
					if (Std.isOfType(properties, String)) {
						final temp = {};
						Reflect.setField(temp, properties, null);
						properties = temp;
					} else if (Std.isOfType(properties, Array)) {
						final temp = {};

						for (property in cast (properties, Array <Dynamic>))
							Reflect.setField(temp, property, null);

						properties = temp;
					}

					var i = library.length - 1;
					while (i >= 0) {
						library[i].stop(properties, complete, sendEvent);
						i--;
					}
				}
			}
		}
	}

	/**
	 * Creates a tween-based timer, which is useful for synchronizing function calls with other animations
	 * @example		<code>Actuate.timer (1).onComplete (trace, [ "Timer is now complete" ]);</code>
	 * @param	duration		The length of the timer in seconds
	 * @param	customActuator		A custom actuator to use instead of the default (Optional)
	 * @return		The current actuator instance, which can be used to apply properties like onComplete or to gain a reference to the target timer object
	 */
	public static function timer(duration:Float, customActuator:Class<GenericActuator<TweenTimer>> = null):GenericActuator<TweenTimer> {
		return cast tween(new TweenTimer(0), duration, new TweenTimer(1), false, cast customActuator);
	}

	#if openfl
	/**
	 * Creates a new transform tween
	 * @example		<code>Actuate.transform (MyClip, 1).color (0xFF0000);</code>
	 * @param	target		The object to tween
	 * @param	duration		The length of the tween in seconds
	 * @param	overwrite		Sets whether previous tweens for the same target and properties will be overwritten (Default is true)
	 * @return		A TransformOptions instance, which is used to select the kind of transform you would like to apply to the target
	 */
	public static function transform<T>(target:T, duration = .0, overwrite = true):TransformOptions<T> {
		return new TransformOptions(target, duration, overwrite);
	}
	#end

	/**
	 * Creates a new tween
	 * @example		<code>Actuate.tween (MyClip, 1, { alpha: 1 } ).onComplete (trace, [ "MyClip is now visible" ]);</code>
	 * @param	target		The object to tween
	 * @param	duration		The length of the tween in seconds
	 * @param	properties		The end values to tween the target to
	 * @param	overwrite			Sets whether previous tweens for the same target and properties will be overwritten (Default is true)
	 * @param	customActuator		A custom actuator to use instead of the default (Optional)
	 * @return		The current actuator instance, which can be used to apply properties like ease, delay, onComplete or onUpdate
	 */
	public static function tween<T>(target:T, duration:Float, properties:Dynamic, overwrite = true, customActuator:Class<GenericActuator<T>> = null):GenericActuator<T> {
		if (target != null) {
			if (duration > 0) {
				if (customActuator == null)
					customActuator = cast defaultActuator;

				final actuator:GenericActuator<T> = Type.createInstance(customActuator, [target, duration, properties]);
				var library = getLibrary(actuator.target);

				if (overwrite) {
					var i = library.length - 1;

					while (i >= 0) {
						library[i].stop(actuator.properties, false, false);
						i--;
					}

					library = getLibrary(actuator.target);
				}

				library.push(actuator);
				actuator.move();

				return actuator;
			} else return apply(target, properties, customActuator);
		}

		return null;
	}

	public static function unload<T>(actuator:GenericActuator<T>):Void {
		final target = actuator.target;

		if (targetLibraries.exists(target)) {
			targetLibraries.get(target).remove(actuator);

			if (targetLibraries.get(target).length == 0)
				targetLibraries.remove(target);
		}
	}

	/**
	 * Creates a new tween that updates a method rather than setting the properties of an object
	 * @example		<code>Actuate.update (trace, 1, ["Value: ", 0], ["", 1]).onComplete (trace, [ "Finished tracing values between 0 and 1" ]);</code>
	 * @param	target		The method to update
	 * @param	duration		The length of the tween in seconds
	 * @param	start		The starting parameters of the method call. You may use both numeric and non-numeric values
	 * @param	end		The ending parameters of the method call. You may use both numeric and non-numeric values, but the signature should match the start parameters
	 * @param	overwrite		Sets whether previous tweens for the same target and properties will be overwritten (Default is true)
	 * @return		The current actuator instance, which can be used to apply properties like ease, delay, onComplete or onUpdate
	 */
	public static function update<T>(target:T, duration:Float, start:Array <Dynamic> = null, end:Array <Dynamic> = null, overwrite = true):GenericActuator<T> {
		final properties:Dynamic = {
			start: start,
			end: end
		};

		return tween(target, duration, properties, overwrite, MethodActuator);
	}
}

#if !haxe3
import com.eclecticdesignstudio.motion.actuators.FilterActuator;
import com.eclecticdesignstudio.motion.actuators.GenericActuator;
import com.eclecticdesignstudio.motion.actuators.TransformActuator;
import com.eclecticdesignstudio.motion.Actuate;
import openfl.display.DisplayObject;
import openfl.filters.BitmapFilter;
import openfl.geom.Matrix;
#end

#if openfl
class EffectsOptions {
	var duration:Float;
	var overwrite:Bool;
	var target:DisplayObject;

	public function new(target:DisplayObject, duration:Float, overwrite:Bool) {
		this.target = target;
		this.duration = duration;
		this.overwrite = overwrite;
	}

	/**
	 * Creates a new BitmapFilter tween
	 * @param	reference		A reference to the target's filter, which can be an array index or the class of the filter
	 * @param	properties		The end properties to use for the tween
	 * @return		The current actuator instance, which can be used to apply properties like ease, delay, onComplete or onUpdate
	 */
	public function filter(reference:Dynamic, properties:Dynamic):IGenericActuator {
		properties.filter = reference;
		return Actuate.tween(target, duration, properties, overwrite, FilterActuator);
	}
}

class TransformOptions<T> {
	var duration:Float;
	var overwrite:Bool;
	var target:T;

	public function new(target:T, duration:Float, overwrite:Bool) {
		this.target = target;
		this.duration = duration;
		this.overwrite = overwrite;
	}

	/**
	 * Creates a new ColorTransform tween
	 * @param	color		The color value
	 * @param	strength		The percentage amount of tint to apply (Default is 1)
	 * @param	alpha		The end alpha of the target. If you wish to tween alpha and tint simultaneously, you must do them both as part of the ColorTransform. A value of null will make no change to the alpha of the object (Default is null)
	 * @return		The current actuator instance, which can be used to apply properties like ease, delay, onComplete or onUpdate
	 */
	public function color(value:Int = 0x000000, strength = 1., alpha:Null<Float> = null):IGenericActuator {
		final properties:Dynamic = {
			colorValue: value,
			colorStrength: strength
		};

		if (alpha != null) properties.colorAlpha = alpha;

		return Actuate.tween(target, duration, properties, overwrite, TransformActuator);
	}

	/**
	 * Creates a new SoundTransform tween
	 * @param	volume		The end volume for the target, or null if you would like to ignore this property (Default is null)
	 * @param	pan		The end pan for the target, or null if you would like to ignore this property (Default is null)
	 * @return		The current actuator instance, which can be used to apply properties like ease, delay, onComplete or onUpdate
	 */
	public function sound(volume:Null<Float> = null, pan:Null<Float> = null):IGenericActuator {
		final properties:Dynamic = {};

		if (volume != null) properties.soundVolume = volume;
		if (pan != null) properties.soundPan = pan;

		return Actuate.tween(target, duration, properties, overwrite, TransformActuator);
	}
}
#end

class TweenTimer {
	public var progress:Float;

	public function new(progress:Float):Void {
		this.progress = progress;
	}
}