package motion.actuators;


import motion.actuators.GenericActuator;
#if openfl
import openfl.display.DisplayObject;
import openfl.events.Event;
import openfl.Lib;
#elseif lime
import lime.app.Application;
import lime.system.System;
#elseif js
import js.Browser;
#else
import haxe.Timer;
#end

class SimpleActuator<T, U> extends GenericActuator<T> {
	#if actuate_manual_time
	public static var getTime:Void -> Float;
	#end

	var timeOffset:Float;

	static var actuators = new Array<SimpleActuator<Dynamic, Dynamic>>();
	static var actuatorsLength = 0;
	static var addedEvent = false;

	#if (!openfl && !lime && !js)
	static var timer:Timer;
	#end

	var active:Bool;
	var cacheVisible:Bool;
	var detailsLength:Int;
	var initialized:Bool;
	var paused:Bool;
	var pauseTime:Float;
	var propertyDetails:Array<PropertyDetails<U>>;
	var sendChange:Bool;
	var setVisible:Bool;
	var startTime:Float;
	var toggleVisible:Bool;

	public function new(target:T, duration:Float, properties:Dynamic) {
		active = true;
		propertyDetails = new Array();
		sendChange = paused = cacheVisible = initialized = setVisible = toggleVisible = false;

		#if !actuate_manual_time
			#if openfl
			startTime = Lib.getTimer() * .001;
			#elseif lime
			startTime = System.getTimer() * .001;
			#elseif js
			startTime = Browser.window.performance.now() * .001;
			#else
			startTime = Timer.stamp();
			#end
		#else
		startTime = getTime();
		#end

		super(target, duration, properties);

		if (!addedEvent) {
			addedEvent = true;
			#if !actuate_manual_update
				#if openfl
				Lib.current.stage.addEventListener(Event.ENTER_FRAME, stage_onEnterFrame);
				#elseif lime
				Application.current.onUpdate.add(stage_onEnterFrame);
				#elseif js
				Browser.window.requestAnimationFrame(stage_onEnterFrame);
				#else
				timer = new Timer(Std.int(1000 / 30));
				timer.run = stage_onEnterFrame;
				#end
			#end
		}
	}

	//For instant transition to start state without shaking
	override function reverse(?value:Null<Bool>):GenericActuator<T> {
		final ga = super.reverse(value);

		var startTime = .0;
		#if !actuate_manual_time
			#if openfl
			startTime = Lib.getTimer() * .001;
			#elseif lime
			startTime = System.getTimer() * .001;
			#elseif js
			startTime = Browser.window.performance.now() * .001;
			#else
			startTime = Timer.stamp();
			#end
		#else
		startTime = getTime();
		#end

		update(startTime);

		return ga;
	}

	/**
	 * @inheritDoc
	 */
	override function apply():Void {
		super.apply();

		if (toggleVisible && Reflect.hasField (properties, "alpha")) {
			if (getField(target, "visible") != null)
				setField(target, "visible", Reflect.field(properties, "alpha") > 0);
		}
	}

	/**
	 * @inheritDoc
	 */
	override function autoVisible(?value:Null<Bool>):GenericActuator<T> {
		if (value == null) value = true;

		_autoVisible = value;

		if (!value) {
			toggleVisible = false;
			if (setVisible) setField(target, "visible", cacheVisible);
		}

		return this;
	}

	/**
	 * @inheritDoc
	 */
	override function delay(duration:Float):GenericActuator<T> {
		_delay = duration;
		timeOffset = startTime + duration;

		return this;
	}

	inline function getField<V>(target:V, propertyName:String):Dynamic {
		#if (haxe_209 || haxe3)
		return Reflect.hasField(target, propertyName) ? Reflect.field(target, propertyName) : Reflect.getProperty(target, propertyName);
		#else
		return Reflect.field(target, propertyName);
		#end
	}

	private function initialize():Void {
		var details:PropertyDetails<U>;
		var start:Dynamic;

		for (i in Reflect.fields(properties)) {
			var isField = true;

			#if (haxe_209 || haxe3)
			#if !hl
			if (Reflect.hasField(target, i) #if js && !(untyped(target).__properties__ && untyped(target).__properties__["set_" + i]) #end)
				start = Reflect.field(target, i);
			else
			#end
			{
				isField = false;
				start = Reflect.getProperty(target, i);
			}
			#else
			start = Reflect.field(target, i);
			#end

			if (Std.isOfType(start, Float)) {
				var value:Dynamic = getField(properties, i);

				#if js
				if (start == null) start = 0;
				if (value == null) value = 0;
				#end

				details = new PropertyDetails(cast target, i, start, value - start, isField);
				propertyDetails.push(details);
			}
		}

		detailsLength = propertyDetails.length;
		initialized = true;
	}

	override function move():Void {
		#if openfl
		toggleVisible = (Reflect.hasField(properties, "alpha") && Std.isOfType(target, DisplayObject));
		#else
		toggleVisible = (Reflect.hasField(properties, "alpha") && Reflect.hasField(properties, "visible"));
		#end

		if (toggleVisible && properties.alpha != 0 && !getField(target, "visible")) {
			setVisible = true;
			cacheVisible = getField(target, "visible");
			setField(target, "visible", true);
		}

		timeOffset = startTime;
		actuators.push(this);
		++actuatorsLength;
	}

	/**
	 * @inheritDoc
	 */
	public override function onUpdate(handler:Dynamic, parameters:Array <Dynamic> = null):GenericActuator<T> {
		_onUpdate = handler;

		if (parameters == null) _onUpdateParams = [];
		else _onUpdateParams = parameters;

		sendChange = true;

		return this;
	}

	override function pause():Void {
		if (!paused) {
			paused = true;

			super.pause();

			#if !actuate_manual_time
				#if openfl
				pauseTime = Lib.getTimer();
				#elseif lime
				pauseTime = System.getTimer();
				#elseif js
				pauseTime = Browser.window.performance.now();
				#else
				pauseTime = Timer.stamp();
				#end
			#else
			pauseTime = getTime();
			#end
		}
	}

	override function resume():Void {
		if (paused) {
			paused = false;

			#if !actuate_manual_time
				#if openfl
				timeOffset += (Lib.getTimer() - pauseTime) * .001;
				#elseif lime
				timeOffset += (System.getTimer() - pauseTime) * .001;
				#elseif js
				timeOffset += (Browser.window.performance.now() - pauseTime) * .001;
				#else
				timeOffset += (Timer.stamp() - pauseTime);
				#end
			#else
			timeOffset += (getTime() - pauseTime);
			#end

			super.resume();
		}
	}


	#if !js @:generic #end inline function setField<V>(target:V, propertyName:String, value:Dynamic):Void {
		if (Reflect.hasField(target, propertyName) #if js && !(untyped (target).__properties__ && untyped(target).__properties__["set_" + propertyName]) #end) {
			Reflect.setField(target, propertyName, value);
		}
		#if (haxe_209 || haxe3)
		else {
			Reflect.setProperty(target, propertyName, value);
		}
		#end
	}

	private function setProperty(details:PropertyDetails<U>, value:Dynamic):Void {
		if (details.isField) {
			Reflect.setField(details.target, details.propertyName, value);
		}
		#if (haxe_209 || haxe3)
		else {
			Reflect.setProperty(details.target, details.propertyName, value);
		}
		#end
	}

	override function stop(properties:Dynamic, complete:Bool, sendEvent:Bool):Void {
		if (active) {
			if (properties == null) {
				active = false;

				if (complete) apply();

				this.complete(sendEvent);
				return;
			}

			for (i in Reflect.fields(properties))
				if (Reflect.hasField(this.properties, i)) {
					active = false;

					if (complete) apply();

					this.complete(sendEvent);
					return;
				}
		}
	}

	private function update(currentTime:Float):Void {
		if (!paused) {
			var details:PropertyDetails<U>;
			var easing:Float;
			var i:Int;

			var tweenPosition = (currentTime - timeOffset) / duration;

			if (tweenPosition > 1) tweenPosition = 1;
			if (!initialized) initialize();

			if (!special) {
				easing = _ease.calculate(tweenPosition);

				for (i in 0...detailsLength) {
					details = propertyDetails[i];
					setProperty(details, details.start + (details.change * easing));
				}
			} else {
				easing = !_reverse ? _ease.calculate(tweenPosition) : _ease.calculate(1 - tweenPosition);

				var endValue:Float;

				for (i in 0...detailsLength) {
					details = propertyDetails[i];

					if (_smartRotation && (details.propertyName == "rotation" || details.propertyName == "rotationX" || details.propertyName == "rotationY" || details.propertyName == "rotationZ")) {
						var rotation = details.change % 360;

						if (rotation > 180) rotation -= 360;
						else if (rotation < -180) rotation += 360;

						endValue = details.start + rotation * easing;
					} else endValue = details.start + (details.change * easing);

					if (!_snapping) setProperty(details, endValue);
					else setProperty(details, Math.round(endValue));
				}
			}

			if (tweenPosition == 1) {
				if (_repeat == 0) {
					active = false;

					if (toggleVisible && getField(target, "alpha") == 0)
						setField(target, "visible", false);

					complete(true);
					return;
				} else {
					if (_onRepeat != null) callMethod(_onRepeat, _onRepeatParams);

					if (_reflect) _reverse = !_reverse;

					startTime = currentTime;
					timeOffset = startTime + _delay;

					if (_repeat > 0) _repeat--;
				}
			}

			if (sendChange) change();
		}
	}

	// Event Handlers
	#if actuate_manual_update public #end static function stage_onEnterFrame(#if openfl event:Event #elseif lime deltaTime:Int #elseif js deltaTime:Float #end):Void {
		#if !actuate_manual_time
			#if openfl
			final currentTime = Lib.getTimer() * .001;
			#elseif lime
			final currentTime = System.getTimer() * .001;
			#elseif js
			final currentTime = deltaTime * .001;
			#else
			final currentTime = Timer.stamp();
			#end
		#else
			final currentTime = getTime();
		#end

		var actuator:SimpleActuator<Dynamic, Dynamic>;

		var j = 0;

		for (i in 0...actuatorsLength) {
			actuator = actuators[j];

			if (actuator != null && actuator.active) {
				if (currentTime >= actuator.timeOffset)
					actuator.update(currentTime);
				j++;
			} else {
				actuators.splice(j, 1);
				--actuatorsLength;
			}
		}

		#if (!openfl && !lime && !actuate_manual_update && js)
		Browser.window.requestAnimationFrame(stage_onEnterFrame);
		#end
	}
}

#if (cpp && (!openfl && !lime))

// Custom haxe.Timer implementation for C++
typedef TimerList = Array<Timer>;

class Timer {
	static var sRunningTimers = new Array<TimerList>();

	var mTime:Float;
	var mFireAt:Float;
	var mRunning:Bool;

	public function new(time:Float) {
		mTime = time;
		sRunningTimers.push (this);
		mFireAt = GetMS() + mTime;
		mRunning = true;
	}

	public static function measure<T>(f:Void -> T, ?pos:haxe.PosInfos):T {
		final t0 = stamp();
		final r = f();
		haxe.Log.trace((stamp() - t0) + "s", pos);
		return r;
	}

	dynamic public function run () {} // Set this with "run=..."

	public function stop():Void {
		if (mRunning) {
			mRunning = false;
			sRunningTimers.remove(this);
		}
	}

	static function GetMS():Float {
		return stamp() * 1000;
	}

  	// From std/haxe/Timer.hx
	public static function delay(f:Void -> Void, time:Int) {
		final t = new Timer(time);

		t.run = () -> {
			t.stop();
			f();
		};

		return t;
	}

	public static function stamp():Float {
		return Date.now().getTime();
	}
}
#end
