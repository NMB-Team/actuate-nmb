[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE.md)

<div align="center">

# Actuate-NMB

### the best library for animating Haxe projects. Power through your everyday needs using no-nonsense, lightweight tweens, then extend when you need more, through the swappable custom actuator system
#

</div>

> [!WARNING]
> This library does not support `flash`, `nme`, or `neko` targets. <br/>
> For best compatibility and performance, we recommend using the latest stable version of Haxe. <br/>
> If you need those, please use the [original version](https://github.com/openfl/actuate) of the library instead. <br/>

## Installation

To install a build:
	
	git clone https://github.com/NMB-Team/actuate-nmb
	haxelib dev actuate actuate

To include Actuate in an OpenFL project, add `<haxelib name="actuate" />` to your project.xml.

To add Actuate to a standard Haxe project, use `-lib actuate` in your HXML


## Usage


It's simple to get started!

```haxe
Actuate.tween(mySprite, 1, {alpha: 1});
```

Actuate is designed to be simple to use and to take advantage strong code completion support in code editors like FlashDevelop, which means no more "reserved" keywords or "special" properties

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).onComplete(trace, "Hello World!");
```

Instance-based tweens can be a pain. When you don't keep track of each tween instance, you run the risk of creating conflicting tweens, which almost never turns out well. With first-class tween overwrite support, Actuate manages your tweens so you don't have to. Actuate also makes it simple to disable overwriting when you need to sequence multiple animations

```haxe
Actuate.tween(mySprite, 1, {alpha: 1});
Actuate.tween(mySprite, 1, {alpha: 0}, false).delay(1);
```

It's also easy to stop, pause or resume your tweens, too

```haxe
Actuate.stop(mySprite);
Actuate.stop(mySprite, "alpha");
Actuate.pauseAll();
Actuate.pause(mySprite);
Actuate.pause(mySprite, myOtherSprite);
Actuate.resumeAll();
Actuate.resume(mySprite);
Actuate.resume(mySprite, myOtherSprite);
Actuate.reset();
```

There also are additional shortcuts you can use to help you be even more productive. For example, you can use Actuate to create quick tween-based timers for sequencing events

```haxe
Actuate.timer(1).onComplete(trace, "Hello World!");
```

Or you can use the "apply" method to stop conflicting tweens and instantly set an object's properties

```haxe
Actuate.apply(MySprite, {alpha: 1});
```

## Advanced Features

For advanced animations, you can also tween function calls instead of properties

```haxe
Actuate.update(customResize, 1, [100, 100], [300, 300]);
```

Actuate also includes shortcuts for some special types of animation. Here is how you might apply a 50% tint using a color transform

```haxe
Actuate.transform(mySprite, 1).color(0xFF0000, 0.5);
```

You can also control the volume and pan of a sound transform as well

```haxe
Actuate.transform(mySprite, 1).sound(0.5, 1);
Actuate.transform(mySoundChannel, 1).sound(0.5, 1);
```

You can also tween filters. You can reference the filter by its class, or by the value of its index in the filter array, whichever is easier

```haxe
Actuate.effects(mySprite, 1).filter(BlurFilter, {blurX: 10, blurY: 10});
```

You even can create bezier curves, and complete motion paths, like in the Flash IDE. Chain multiple path commands together to create one solid path you can tween your objects across using the MotionPathActuator

```haxe
final path = new MotionPath()
  .bezier(100, 100, 50, 50)                 // quadratic, 1 control point
  .bezierN(200, 200, [50, 100], [50, 100])  // general, any number of control points
  .bezierSpline([100, 100], [50, 50])       // spline, passing through the given points
  .line(20, 20);                            // linear
Actuate.motionPath(mySprite, 1, {x: path.x, y: path.y});
```

## Tween Modifiers

Each tween Actuate creates can be modified with many different tween modifiers. You can link tween modifiers to add delay, complete handlers, or configure many different options about the way your tween behaves

### autoVisible

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).autoVisible(false);
```

Changing the visible property results in better performance than only an alpha of zero, so the autoVisible modifier toggles the visible property automatically based upon the alpha value of the target. It is enabled by default, but it can be disabled if you choose

### delay

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).delay(1);
```

Controls how many seconds should pass before your animation begins

### ease

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).ease(Quad.easeOut);
```

Defines a custom easing equation for your animation. Actuate includes many popular easing functions in both standard and optimized formats. The default is Expo.easeOut, but you can change the default equation through Actuate.defaultEase

### onComplete

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).onComplete(trace, "Tween finished");
```

Calls a function when the tween is finished. You can also define parameters to be used when calling the function

### onRepeat

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).repeat().onRepeat(trace, ["Tween finished"]);
```

Calls a function when the tween repeats. You can also define parameters to be used when calling the function

### onPause

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).repeat().onPause(trace, ["Tween paused"]);
```

Calls a function when the tween is paused. You can also define parameters to be used when calling the function

### onResume

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).repeat().onResume(trace, ["Tween resumed"]);
```

Calls a function when the tween is resumed after being paused. You can also define parameters to be used when calling the function

### onUpdate

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).onUpdate(trace, ["Tween updated"]);
```

Calls a function every time the tween updates. You can also define parameters to be used when calling the function

### reflect

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).repeat().reflect();
```

Automatically reverses the animation every other time it is repeated. You must enable repeat in order to see any effect

### repeat

```haxe
Actuate.tween(MySprite, 1, {alpha: 1}).repeat(10);
```

Runs your animation multiple times before it finishes. You can make your tween repeat indefinitely by passing no value, or you can define the number of times it should repeat

### reverse

```haxe
Actuate.tween(MySprite, 1, {alpha: 1}).reverse();
```

Reverses the direction of your tween

### smartRotation

```haxe
Actuate.tween(mySprite, 1, {rotation: 180}).smartRotation();
```

Rotation is circular, so it can be strange to animate. What should be positive one moment is negative the next. As a result, treating rotation like a standard tween will result in jerking once the signs change. Smart rotation always applies rotation in the nearest direction, alleviating this issue.

### snapping

```haxe
Actuate.tween(mySprite, 1, {alpha: 1}).snapping();
```

Rounds all of your tween values
