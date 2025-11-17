package motion.actuators;

#if openfl
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.geom.ColorTransform;
import openfl.geom.Transform;
import openfl.media.SoundTransform;

class TransformActuator<T> extends SimpleActuator<T, Dynamic> {
	var endColorTransform:ColorTransform;
	var endSoundTransform:SoundTransform;
	var tweenColorTransform:ColorTransform;
	var tweenSoundTransform:SoundTransform;

	public function new(target:T, duration:Float, properties:Dynamic) {
		super(target, duration, properties);
	}

	override function apply():Void {
		initialize();

		if (endColorTransform != null) {
			final transform:Transform = getField(target, "transform");
			setField(transform, "colorTransform", endColorTransform);
		}

		if (endSoundTransform != null)
			setField(target, "soundTransform", endSoundTransform);
	}

	override function initialize():Void {
		if (Reflect.hasField(properties, "colorValue") && Std.isOfType(target, DisplayObject))
			initializeColor();
		if (Reflect.hasField(properties, "soundVolume") || Reflect.hasField(properties, "soundPan"))
			initializeSound();

		detailsLength = propertyDetails.length;
		initialized = true;
	}

	private function initializeColor():Void {
		endColorTransform = new ColorTransform();

		final color = properties.colorValue;
		final strength = properties.colorStrength;

		if (strength < 1) {
			var multiplier:Float;
			var offset:Float;

			if (strength < .5) {
				multiplier = 1;
				offset = (strength * 2);
			} else {
				multiplier = 1 - ((strength - .5) * 2);
				offset = 1;
			}

			endColorTransform.redMultiplier = endColorTransform.greenMultiplier = endColorTransform.blueMultiplier = multiplier;

			endColorTransform.redOffset = offset * ((color >> 16) & 0xFF);
			endColorTransform.greenOffset = offset * ((color >> 8) & 0xFF);
			endColorTransform.blueOffset = offset * (color & 0xFF);
		} else {
			endColorTransform.redMultiplier = endColorTransform.greenMultiplier = endColorTransform.blueMultiplier = 0;

			endColorTransform.redOffset = ((color >> 16) & 0xFF);
			endColorTransform.greenOffset = ((color >> 8) & 0xFF);
			endColorTransform.blueOffset = (color & 0xFF);
		}

		final propertyNames = [
			"redMultiplier",
			"greenMultiplier",
			"blueMultiplier",
			"redOffset",
			"greenOffset",
			"blueOffset"
		];

		if (Reflect.hasField(properties, "colorAlpha")) {
			endColorTransform.alphaMultiplier = properties.colorAlpha;
			propertyNames.push("alphaMultiplier");
		} else
			endColorTransform.alphaMultiplier = getField(target, "alpha");

		final transform:Transform = getField(target, "transform");
		final begin:ColorTransform = getField(transform, "colorTransform");
		tweenColorTransform = new ColorTransform();

		var details:PropertyDetails<Dynamic>;
		var start:Float;

		for (propertyName in propertyNames) {
			start = getField(begin, propertyName);
			details = new PropertyDetails(tweenColorTransform, propertyName, start, getField(endColorTransform, propertyName) - start);
			propertyDetails.push(details);
		}
	}

	private function initializeSound():Void {
		if (getField(target, "soundTransform") == null)
			setField(target, "soundTransform", new SoundTransform());

		final start:SoundTransform = getField(target, "soundTransform");
		endSoundTransform = getField(target, "soundTransform");
		tweenSoundTransform = new SoundTransform();

		if (Reflect.hasField(properties, "soundVolume")) {
			endSoundTransform.volume = properties.soundVolume;
			propertyDetails.push(new PropertyDetails(tweenSoundTransform, "volume", start.volume, endSoundTransform.volume - start.volume));
		}

		if (Reflect.hasField(properties, "soundPan")) {
			endSoundTransform.pan = properties.soundPan;
			propertyDetails.push(new PropertyDetails(tweenSoundTransform, "pan", start.pan, endSoundTransform.pan - start.pan));
		}
	}

	override function update(currentTime:Float):Void {
		super.update(currentTime);

		if (endColorTransform != null) {
			final transform:Transform = getField(target, "transform");
			setField(transform, "colorTransform", tweenColorTransform);
		}

		if (endSoundTransform != null)
			setField(target, "soundTransform", tweenSoundTransform);
	}
}
#end
