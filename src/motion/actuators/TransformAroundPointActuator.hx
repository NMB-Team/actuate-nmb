package motion.actuators;

#if openfl
import Reflect;
import openfl.display.DisplayObject;
import openfl.geom.Matrix;
import openfl.geom.Point;

class TransformAroundPointActuator<T, U> extends SimpleActuator<T, U> {
	var transformMatrix:Matrix;

	var transformPoint:Point;
	var initialTransformPoint:Point;
	var transformedPoint:Point;

	var originX:Float;
	var originY:Float;
	var tweenedOffsetX:Float;
	var tweenedOffsetY:Float;

	public function new(target:T, duration:Float, properties:Dynamic) {
		super(target, duration, properties);

		transformedPoint = new Point();
		transformMatrix = new Matrix();

		originX = getField(target, "x");
		originY = getField(target, "y");

		final transformAroundPointProps = Reflect.field(properties, "transformAroundPoint");
		for (propertyName in Reflect.fields(transformAroundPointProps)) {
			switch (propertyName) {
				case "point":
					final point = Reflect.field(transformAroundPointProps, "point");
					final isLocal = Reflect.hasField(transformAroundPointProps, "pointIsLocal") && Reflect.field (transformAroundPointProps, "pointIsLocal");
					if (Std.isOfType(target, DisplayObject) && !isLocal) transformPoint = Reflect.callMethod(target,  Reflect.field(target, "globalToLocal"), [point]);
					else transformPoint = point;
				case "scale":
					final value = Reflect.field(transformAroundPointProps, "scale");
					Reflect.setField(properties, "scaleX", value);
					Reflect.setField(properties, "scaleY", value);
				case "rotation" | "scaleX" | "scaleY":
					final value = Reflect.field(transformAroundPointProps, propertyName);
					Reflect.setField(properties, propertyName, value);
				default:
			}
		}

		Reflect.deleteField(properties, "transformAroundPoint");

		initialTransformPoint = new Point();
		getTransformedPoint(initialTransformPoint);

		tweenedOffsetX = tweenedOffsetY = 0;
	}

	override function apply():Void {
		for (propertyName in Reflect.fields(properties)) {
			final value = Reflect.field(properties, propertyName);
			setField(target, propertyName, value);

			if (propertyName == "x") tweenedOffsetX = value - originX;
			else if (propertyName == "y") tweenedOffsetY = value - originY;
		}

		updatePosition();
	}

	override function setProperty(details:PropertyDetails<U>, value:Dynamic):Void {
		final propertyName = details.propertyName;

		if (propertyName == "x") tweenedOffsetX = value - originX;
		else if (propertyName == "y") tweenedOffsetY = value - originY;
		else super.setProperty(details, value);
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);

		if (active && !paused) updatePosition();
	}

	inline function getTransformedPoint(result:Point):Void {
		transformMatrix.identity();
		final scaleX = getField(target, "scaleX");
		final scaleY = getField(target, "scaleY");
		final rotation = getField(target, "rotation");
		transformMatrix.scale(scaleX, scaleY);
		transformMatrix.rotate(rotation * .017453292519943295);

		result.copyFrom(transformPoint);
		transform(result, transformMatrix);
	}

	private function updatePosition():Void {
		getTransformedPoint(transformedPoint);
		subtract(initialTransformPoint, transformedPoint, transformedPoint);

		setField(target, "x", originX + transformedPoint.x + tweenedOffsetX);
		setField(target, "y", originY + transformedPoint.y + tweenedOffsetY);
	}

	inline function transform(point:Point, matrix: Matrix):Void {
		final px = point.x;
		final py = point.y;

		point.x = px * matrix.a + py * matrix.c + matrix.tx;
		point.y = px * matrix.b + py * matrix.d + matrix.ty;
	}

	inline function subtract(p1:Point, p2:Point, ?result:Point):Point {
		if (result == null) result = new Point();

		result.x = p1.x - p2.x;
		result.y = p1.y - p2.y;

		return result;
	}
}
#end