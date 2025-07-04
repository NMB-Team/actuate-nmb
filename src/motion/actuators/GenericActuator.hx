﻿package motion.actuators;

import motion.easing.IEasing;
import motion.Actuate;

@:keepSub class GenericActuator<T> implements IGenericActuator {
	public var timeScale(get, set):Float;

	var _timeScale = 1.;
	var duration:Float;
	var id:String;
	var properties:Dynamic;
	var target:T;
	var _autoVisible:Bool;
	var _delay:Float;
	var _ease:IEasing;
	var _onComplete:Dynamic;
	var _onCompleteParams:Array<Dynamic>;
	var _onRepeat:Dynamic;
	var _onRepeatParams:Array<Dynamic>;
	var _onUpdate:Dynamic;
	var _onUpdateParams:Array<Dynamic>;
	var _onResume:Dynamic;
	var _onResumeParams:Array<Dynamic>;
	var _onPause:Dynamic;
	var _onPauseParams:Array<Dynamic>;
	var _reflect:Bool;
	var _repeat:Int;
	var _reverse:Bool;
	var _smartRotation:Bool;
	var _snapping:Bool;
	var special:Bool;

	public function new(target:T, duration:Float, properties:Dynamic) {
		_timeScale = Actuate.timeScale;

		_autoVisible = true;
		_delay = 0;
		_repeat = 0;
		_reflect = _reverse = _smartRotation = _snapping = special = false;

		this.target = target;
		this.properties = properties;
		this.duration = duration;

		_ease = Actuate.defaultEase;
	}

	private function apply():Void {
		for (i in Reflect.fields (properties)) {
			#if (haxe_209 || haxe3)
			if (Reflect.hasField(target, i)) Reflect.setField(target, i, Reflect.field(properties, i));
			else Reflect.setProperty(target, i, Reflect.field(properties, i));
			#else
			Reflect.setField(target, i, Reflect.field(properties, i));
			#end
		}
	}

	/**
	 * autoVisible toggles automatically based on alpha values
	 * @param	value		Whether autoVisible should be enabled (Default is true)
	 * @return		The current actuator instance
	 */
	public function autoVisible(?value:Null<Bool>):GenericActuator<T> {
		if (value == null) value = true;

		_autoVisible = value;

		return this;
	}

	private inline function callMethod(method:Dynamic, params:Array<Dynamic> = null):Dynamic {
		if (params == null) params = [];

		return Reflect.callMethod(#if hl null #else method #end, method, params);
	}

	private function change():Void {
		if (_onUpdate != null) callMethod(_onUpdate, _onUpdateParams);
	}

	private function complete(sendEvent = true):Void {
		if (sendEvent) {
			change();

			if (_onComplete != null)
				callMethod(_onComplete, _onCompleteParams);
		}

		Actuate.unload(this);
	}

	/**
	 * Increases the delay before a tween is executed
	 * @param	duration		The amount of seconds to delay
	 * @return		The current actuator instance
	 */
	public function delay(duration:Float):GenericActuator<T> {
		_delay = duration;
		return this;
	}

	/**
	 * Sets the easing which is used when running the tween
	 * @param	easing		An easing equation, like Elastic.easeIn or Quad.easeOut
	 * @return		The current actuator instance
	 */
	public function ease(easing:IEasing):GenericActuator<T> {
		_ease = easing;
		return this;
	}

	private function move():Void {}

	/**
	 * Defines a function which will be called when the tween finishes
	 * @param	handler		The function you would like to be called
	 * @param	parameters		Parameters you would like to pass to the handler function when it is called
	 * @return		The current actuator instance
	 */
	public function onComplete(handler:Dynamic, parameters:Array<Dynamic> = null):GenericActuator<T> {
		_onComplete = handler;
		_onCompleteParams = (parameters == null) ? [] : parameters;

		if (duration == 0) complete();

		return this;
	}

	/**
	 * Defines a function which will be called when the tween repeats
	 * @param	handler		The function you would like to be called
	 * @param	parameters		Parameters you would like to pass to the handler function when it is called
	 * @return		The current actuator instance
	 */
	public function onRepeat(handler:Dynamic, parameters:Array<Dynamic> = null):GenericActuator<T> {
		_onRepeat = handler;
		_onRepeatParams = (parameters == null) ? [] : parameters;

		return this;
	}

	/**
	 * Defines a function which will be called when the tween updates
	 * @param	handler		The function you would like to be called
	 * @param	parameters		Parameters you would like to pass to the handler function when it is called
	 * @return		The current actuator instance
	 */
	public function onUpdate(handler:Dynamic, parameters:Array<Dynamic> = null):GenericActuator<T> {
		_onUpdate = handler;
		_onUpdateParams = (parameters == null) ? [] : parameters;

		return this;
	}

	/**
	 * Defines a function which will be called when the tween is paused
	 * @param	handler		The function you would like to be called
	 * @param	parameters		Parameters you would like to pass to the handler function when it is called
	 * @return		The current actuator instance
	 */
	public function onPause(handler:Dynamic, parameters:Array<Dynamic> = null):GenericActuator<T> {
		_onPause = handler;
		_onPauseParams = (parameters == null) ? [] : parameters;

		return this;
	}

	/**
	 * Defines a function which will be called when the tween resumed after pause
	 * @param	handler		The function you would like to be called
	 * @param	parameters		Parameters you would like to pass to the handler function when it is called
	 * @return		The current actuator instance
	 */
	public function onResume(handler:Dynamic, parameters:Array<Dynamic> = null):GenericActuator<T> {
		_onResume = handler;
		_onResumeParams = (parameters == null) ? [] : parameters;

		return this;
	}

	private function pause():Void {
		if (_onPause == null) return;
		callMethod(_onPause, _onPauseParams);
	}

	/**
	 * Automatically changes the reverse value when the tween repeats. Repeat must be enabled for this to have any effect
	 * @param	value		Whether reflect should be enabled (Default is true)
	 * @return		The current actuator instance
	 */
	public function reflect(?value:Null<Bool>):GenericActuator<T> {
		if (value == null) value = true;

		_reflect = value;
		special = true;

		return this;
	}

	/**
	 * Repeats the tween after it finishes
	 * @param	times		The number of times you would like the tween to repeat, or -1 if you would like to repeat the tween indefinitely (Default is -1)
	 * @return		The current actuator instance
	 */
	public function repeat(?times:Null<Int>):GenericActuator<T> {
		if (times == null) times = -1;

		_repeat = times;

		return this;
	}


	private function resume():Void {
		if (_onResume == null) return;
		callMethod(_onResume, _onResumeParams);
	}

	/**
	 * Sets if the tween should be handled in reverse
	 * @param	value		Whether the tween should be reversed (Default is true)
	 * @return		The current actuator instance
	 */
	public function reverse(?value:Null<Bool>):GenericActuator<T> {
		if (value == null) value = true;

		_reverse = value;
		special = true;

		return this;
	}

	/**
	 * Enabling smartRotation can prevent undesired results when tweening rotation values
	 * @param	value		Whether smart rotation should be enabled (Default is true)
	 * @return		The current actuator instance
	 */
	public function smartRotation(?value:Null<Bool>):GenericActuator<T> {
		if (value == null) value = true;

		_smartRotation = value;
		special = true;

		return this;
	}

	/**
	 * Snapping causes tween values to be rounded automatically
	 * @param	value		Whether tween values should be rounded (Default is true)
	 * @return		The current actuator instance
	 */
	public function snapping(?value:Null<Bool>):GenericActuator<T> {
		if (value == null) value = true;

		_snapping = value;
		special = true;

		return this;
	}

	private function stop(properties:Dynamic, complete:Bool, sendEvent:Bool):Void {}

	@:noCompletion inline function get_timeScale():Float {
		return _timeScale;
	}

	@:noCompletion inline function set_timeScale(value:Float):Float {
		return _timeScale = value;
	}
}