/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file was derived from the equivalent actionscript PushButton Engine 
 * source file:
 * http://code.google.com/p/pushbuttonengine/
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.engine.time; 

import com.pblabs.engine.time.IAnimatedObject;
import com.pblabs.engine.time.IProcessManager;
import com.pblabs.engine.time.ITickedObject;
import com.pblabs.util.MathUtil;
import com.pblabs.util.ReflectUtil;
import com.pblabs.util.ds.Tuple;
using com.pblabs.util.NumberUtil;

/** 
 * It provides mechanisms for performing actions every frame, every tick, or
 * at a specific time in the future.
 * 
 * <p>A tick happens at a set interval defined by the TICKS_PER_SECOND constant.
 * Using ticks for various tasks that need to happen repeatedly instead of
 * performing those tasks every frame results in much more consistent output.
 * However, for animation related tasks, frame events should be used so the
 * display remains smooth.</p>
 * 
 * @see ITickedObject
 * @see IAnimatedObject
 */
class ProcessManager implements IProcessManager 
{
	/**
	 * Integer identifying this frame. Incremented by one for every frame.
	 */
	public var frameCounter(get_frameCounter, null) : Int;
	/**
	 * Used to determine how far we are between ticks. 0.0 at the start of a tick, and
	 * 1.0 at the end. Useful for smoothly interpolating visual elements.
	 */
	public var interpolationFactor(get_interpolationFactor, null) : Float;
	public var isRunning(get_isRunning, set_isRunning) : Bool;
	public var listenerCount(get_listenerCount, null) : Int;
	/**
	 * Current time reported by haxe.Timer.stamp(), updated every frame. Use this to avoid
	 * costly calls to getTimer(), or if you want a unique number representing the
	 * current frame.  Time is in milliseconds.
	 */
	public var platformTime(get_platformTime, set_platformTime) : Int;
	/**
	 * The scale at which time advances. If this is set to 2, the game
	 * will play twice as fast. A value of 0.5 will run the
	 * game at half speed. A value of 1 is normal.
	 */
	public var timeScale(get_timeScale, set_timeScale) : Float;
	/**
	 * The amount of time that has been processed by the process manager. This does
	 * take the time scale into account. Time is in milliseconds.
	 */
	public var virtualTime (get_virtualTime, set_virtualTime) : Int;
	
	/**
	 * Process managers can be under external control.
	 */
	public var isUsingInternalTimer :Bool;
	
	/**
	 * If true, disables warnings about losing ticks.
	 */
	public var disableSlowWarning :Bool;
	
	/**
	 * The number of ticks that will happen every second.
	 */
	public var TICKS_PER_SECOND :Int;
	
	/**
	 * The number of seconds between each tick.
	 */
	public var SECONDS_PER_TICK :Float;
	
	/**
	 * The number of milliseconds between each tick.
	 */
	public var MS_PER_TICK :Int;
	
	/**
	 * The maximum number of ticks that can be processed in a frame.
	 * 
	 * <p>In some cases, a single frame can take an extremely long amount of
	 * time. If several ticks then need to be processed, a game can
	 * quickly get in a state where it has so many ticks to process
	 * it can never catch up. This is known as a death spiral.</p>
	 * 
	 * <p>To prevent this we have a safety limit. Time is dropped so the
	 * system can catch up in extraordinary cases. If your game is just
	 * slow, then you will see that the ProcessManager can never catch up
	 * and you will constantly get the "too many ticks per frame" warning,
	 * if you have disableSlowWarning set to true.</p>
	 */
	public var MAX_TICKS_PER_FRAME :Int;
	
	public function new (?ticksPerSecond :Int = 30, useInternalTimer :Bool = true) 
	{ 
		disableSlowWarning = true;
		TICKS_PER_SECOND = ticksPerSecond;
		SECONDS_PER_TICK = 1.0 / TICKS_PER_SECOND;
		MS_PER_TICK = Std.int(SECONDS_PER_TICK * 1000);
		MAX_TICKS_PER_FRAME = 5;
		virtualTime = 0;
		_interpolationFactor = 0;
		timeScale = 1.0;
		_lastTime = -1.0;
		_elapsed = 0;
		_animatedObjects = [];
		_tickedObjects = [];
		_deferredCallbacks = [];
		_deferredObjects = [];
		_needPurgeEmpty = false;
		_platformTime = 0;
		_frameCounter = 0;
		_duringAdvance = false;
		_isRunning = false;
		isUsingInternalTimer = useInternalTimer;
	}
	
	public function startup():Void
	{
	}
	
	public function shutdown():Void
	{
		stop();
		_animatedObjects = [];
		_tickedObjects = [];
		_deferredCallbacks = [];
		_deferredObjects = [];
	}
	
	/**
	  * Defer a function until after objects are ticked and animated for the 
	  * current update loop.
	  */
	public function callLater (f :Void->Dynamic) :Void
	{
		_deferredCallbacks.push(f);
	}
	
	/**
	 * Starts the process manager. This is automatically called when the first object
	 * is added to the process manager. If the manager is stopped manually, then this
	 * will have to be called to restart it.
	 */
	function start ():Void
	{
		com.pblabs.util.Log.info("Starting ProcessManager");
		
		if (_isRunning) {
			com.pblabs.util.Log.warn("The ProcessManager is already started.");
			return;
		}
		
		_lastTime = -1.0;
		_elapsed = 0;
		
		if (isUsingInternalTimer) {
			if (_timer == null) {
				#if flash
				_timer = new flash.utils.Timer(untyped flash.Lib.current.stage["frameRate"]);
				#else
				com.pblabs.util.Log.info("Assuming a frame rate of 30fps");
				_timer = new com.pblabs.engine.time.Timer(Std.int(1000/30));
				_timer.run = onFrame;
				#end
			}
			#if flash
			_timer.addEventListener(flash.events.TimerEvent.TIMER, onFrame);
			#end
			_timer.start();
		}
		
		_isRunning = true;
		#if flash
		com.pblabs.util.Log.info("Started at " + (untyped flash.Lib.current.stage["frameRate"]) + "Hz");
		#end
	}
	
	/**
	 * Stops the process manager. This is automatically called when the last object
	 * is removed from the process manager, but can also be called manually to, for
	 * example, pause the game.
	 */
	function stop():Void
	{
		if (!_isRunning) {
			com.pblabs.util.Log.warn("The ProcessManager isn't started.");
			return;
		}
		_isRunning = false;
		
		com.pblabs.util.Log.info("Stopping ProcessManager");
		
		if (isUsingInternalTimer) {
			_timer.stop();
			#if flash
			_timer.removeEventListener(flash.events.TimerEvent.TIMER, onFrame);
			#end
		}
	}
	
	/**
	 * Registers an object to receive frame callbacks.
	 * 
	 * @param object The object to add.
	 * @param priority The priority of the object. Objects added with higher priorities
	 * will receive their callback before objects with lower priorities. The highest
	 * (first-processed) priority is Math.POSITIVE_INFINITY. The lowest (last-processed) 
	 * priority is -Math.POSITIVE_INFINITY.
	 */
	public function addAnimatedObject(object:IAnimatedObject, ?priority:Float = 0.0):Void
	{
		addObject(object, priority, _animatedObjects, false);
	}
	
	/**
	 * Registers an object to receive tick callbacks.
	 * 
	 * @param object The object to add.
	 * @param priority The priority of the object. Objects added with higher priorities
	 * will receive their callback before objects with lower priorities. The highest
	 * (first-processed) priority is Math.POSITIVE_INFINITY. The lowest (last-processed) 
	 * priority is -Math.POSITIVE_INFINITY.
	 */
	public function addTickedObject(object:ITickedObject, ?priority:Float = 0.0):Void
	{
		addObject(object, priority, _tickedObjects, true);
	}
	
	/**
	 * Unregisters an object from receiving frame callbacks.
	 * 
	 * @param object The object to remove.
	 */
	public function removeAnimatedObject(object:IAnimatedObject):Void
	{
		if (!removeFromDeferredObjects(object)) {
			removeObject(object, _animatedObjects);
		}
	}
	
	/**
	 * Unregisters an object from receiving tick callbacks.
	 * 
	 * @param object The object to remove.
	 */
	public function removeTickedObject(object:ITickedObject):Void
	{
		if (!removeFromDeferredObjects(object)) {
			removeObject(object, _tickedObjects);
		}
	}
	
	/**
	 * Forces the process manager to advance by the specified amount. This should
	 * only be used for unit testing.
	 * 
	 * @param amount Time in seconds to advance
	 */
	public function testAdvance(amount:Float):Void
	{
		advanceInternal(amount * _timeScale, true);
	}
	
	/**
	 * Forces the process manager to seek its virtualTime by the specified amount.
	 * This moves virtualTime without calling advance and without processing ticks or frames.
	 * WARNING: USE WITH CAUTION AND ONLY IF YOU REALLY KNOW THE CONSEQUENCES!
	 */
	public function seek(amount :Int):Void
	{
		_virtualTime += amount;
	}
	
	/**
	 * @return How many objects are depending on the ProcessManager right now?
	 */
	function get_listenerCount():Int
	{
		return _tickedObjects.length + _animatedObjects.length;
	}
	
	/**
	 * Internal function add an object to a list with a given priority.
	 * @param object Object to add.
	 * @param priority Priority; this is used to keep the list ordered.
	 * @param list List to add to.
	 */
	function addObject(object:Dynamic, priority:Float, list:Array<Dynamic>, isTickedObject :Bool):Void
	{
		// If we are in a tick, defer the add.
		if(_duringAdvance)
		{
			_deferredObjects.push(new Tuple(object, priority));
			return;
		}
		
		var position:Int = -1;
		for (i in 0...list.length)
		{
			if(!list[i])
				continue;
			
			if (list[i].listener == object)
			{
				com.pblabs.util.Log.warn("This object has already been added to the process manager.");
				return;
			}
			
			if (list[i].priority < priority)
			{
				position = i;
				break;
			}
		}
		
		//Code duplication, but this way it's typed.
		if (isTickedObject) {
			var processObject = new ProcessObjectTicked();
			processObject.listener = object;
			processObject.priority = priority;
			#if profiler
			processObject.profilerKey = ReflectUtil.getClassName(object);
			#end
			
			if (position < 0 || position >= list.length)
				list.push(processObject);
			else
				list.insert(position, processObject);
		} else {
			var processObject = new ProcessObjectAnimated();
			processObject.listener = object;
			processObject.priority = priority;
			#if profiler
			processObject.profilerKey = ReflectUtil.getClassName(object);
			#end
			
			if (position < 0 || position >= list.length)
				list.push(processObject);
			else
				list.insert(position, processObject);
		}
		
	}
	
	/**
	 * Peer to addObject; removes an object from a list. 
	 * @param object Object to remove.
	 * @param list List from which to remove.
	 */
	function removeObject(object:Dynamic, list:Array<Dynamic>):Void
	{
		com.pblabs.util.Assert.isNotNull(object, com.pblabs.util.Log.getStackTrace());
		
		if (listenerCount == 1) {
			com.pblabs.util.Log.debug("Stopping because listener count == 1");	
			stop();
		}
		
		for (i in 0...list.length) {
			if(list[i] == null)
				continue;
			
			if (list[i].listener == object) {
				if(_duringAdvance) {
					list[i] = null;
					_needPurgeEmpty = true;
				} else {
					list.splice(i, 1);
				}
				
				return;
			}
		}
		
		com.pblabs.util.Log.warn(ReflectUtil.getClassName(object) + " " + object + ": object has not been added to the process manager.\n" + com.pblabs.util.Log.getStackTrace());
	}
	
	/**
	 * Main callback; this is called every frame and allows game Logic to run. 
	 */
	public function onFrame (#if flash event:flash.events.TimerEvent #end):Void
	{
		// This is called from a system event, so it had better be at the 
		// root of the profiler stack!
		com.pblabs.engine.debug.Profiler.ensureAtRoot();
		
		// Safety for when we've stop()'ed.
		if (!isRunning) {
			_lastTime = haxe.Timer.stamp();
			return;
		}
		
		// Track current time.
		var currentTime = haxe.Timer.stamp();
		if (_lastTime < 0)
		{
			_lastTime = currentTime;
			com.pblabs.util.Log.debug("_lastTime < 0");
			return;
		}
		
		_timer.stop();
		
		// Bump the frame counter.
		_frameCounter++;
		
		// Calculate time since last frame and advance that much.
		var deltaTime = (currentTime - _lastTime) * _timeScale;
		advanceInternal(deltaTime);
		
		// Note new last time.
		_lastTime = currentTime;
		
		// Rejigger our events so we get called back soon.
		_timer.start();
		#if flash
		event.updateAfterEvent();
		untyped flash.Lib.current.stage.invalidate();
		#end
	}
	
	/**
	  * @param deltaTime Time in seconds
	  */
	public function advance (deltaTime:Float):Void
	{
		advanceInternal(deltaTime);
	}
	
	/**
	  * @param deltaTime Time in seconds
	  */
	function advanceInternal (deltaTime :Float, ?suppressSafety:Bool = false):Void
	{
		// Update platform time, to avoid lots of costly calls to getTimer.
		_platformTime = Std.int(haxe.Timer.stamp() * 1000);
		
		// Note virtual time we started advancing from.
		var startTime = _virtualTime;
		// Add time to the accumulator.
		_elapsed += Std.int(deltaTime * 1000);
		
		// Perform ticks, respecting tick caps.
		var tickCount:Int = 0;
		while (_elapsed >= MS_PER_TICK && (suppressSafety || tickCount < MAX_TICKS_PER_FRAME))
		{
			// Ticks always happen on interpolation boundary.
			_interpolationFactor = 0.0;
			
			// Process pending events at this tick.
			// This is done in the loop to ensure the correct order of events.
			// processScheduledObjects();
			
			// Do the onTick callbacks, noting time in profiler appropriately.
			com.pblabs.engine.debug.Profiler.enter("Tick");
			
			_duringAdvance = true;
			var object :ProcessObjectTicked;
			for(j in 0..._tickedObjects.length)
			{
				object = _tickedObjects[j];
				if(object == null)
					continue;
				
				#if profiler 
				com.pblabs.engine.debug.Profiler.enter(object.profilerKey);
				#end
				object.listener.onTick(SECONDS_PER_TICK);
				// (cast( object.listener, ITickedObject)).onTick(SECONDS_PER_TICK);
				#if profiler
				com.pblabs.engine.debug.Profiler.exit(object.profilerKey);
				#end
			}
			_duringAdvance = false;
			
			com.pblabs.engine.debug.Profiler.exit("Tick");
			
			// Update virtual time by subtracting from accumulator.
			_virtualTime += MS_PER_TICK;
			_elapsed -= MS_PER_TICK;
			tickCount++;
		}
		
		// Safety net - don't do more than a few ticks per frame to avoid death spirals.
		if (tickCount >= MAX_TICKS_PER_FRAME && !suppressSafety && !disableSlowWarning)
		{
			// By default, only show when profiling.
			com.pblabs.util.Log.warn(["advance", "Exceeded maximum number of ticks for frame (" + _elapsed.toFixed(1) + "ms dropped) ."]);
		}
		
		// Make sure that we don't fall behind too far. This helps correct
		// for short-term drops in framerate as well as the scenario where
		// we are consistently running behind.
		_elapsed = MathUtil.clamp(_elapsed, 0, 300);
		
		// Make sure we don't lose time to accumulation error.
		// Not sure this gains us anything, so disabling -- BJG
		//virtualTime = startTime + deltaTime;
		
		// We process scheduled items again after tick processing to ensure between-tick schedules are hit
		// Commenting this out because it can cause too-often calling of callLater methods. -- BJG
		// processScheduledObjects();
		
		// Update objects wanting OnFrame callbacks.
		com.pblabs.engine.debug.Profiler.enter("frame");
		_duringAdvance = true;
		_interpolationFactor = _elapsed / MS_PER_TICK;
		var animatedObject :ProcessObjectAnimated;
		for(i in 0..._animatedObjects.length) {
			animatedObject = _animatedObjects[i];
			if(animatedObject == null)
				continue;
			
			#if profiler
			com.pblabs.engine.debug.Profiler.enter(animatedObject.profilerKey);
			#end
			// (cast( animatedObject.listener, IAnimatedObject)).onFrame(deltaTime);
			animatedObject.listener.onFrame(deltaTime);
			#if profiler
			com.pblabs.engine.debug.Profiler.exit(animatedObject.profilerKey);
			#end
		}
		_duringAdvance = false;
		com.pblabs.engine.debug.Profiler.exit("frame");
		
		//Add the deferred objects
		while(_deferredObjects.length > 0) {
			var deferredObject = _deferredObjects.pop();
			if (Std.is(deferredObject.v1, ITickedObject)) {
				addTickedObject(cast deferredObject.v1, deferredObject.v2); 
			} else {
				addAnimatedObject(cast deferredObject.v1, deferredObject.v2);
			}
		}
		
		com.pblabs.util.Assert.isTrue(_deferredObjects.length == 0);
			
		// Pump the call later queue.
		com.pblabs.engine.debug.Profiler.enter("callLater_postFrame");
		while (_deferredCallbacks.length > 0) {
			_deferredCallbacks.pop()();
		}
		com.pblabs.engine.debug.Profiler.exit("callLater_postFrame");
		
		// Purge the lists if needed.
		if(_needPurgeEmpty)
		{
			_needPurgeEmpty = false;
			
			com.pblabs.engine.debug.Profiler.enter("purgeEmpty");
			
			var j :Int = 0;
			while (j < _animatedObjects.length) {
				if(_animatedObjects[j] != null) {
					j++;
					continue;
				}
				_animatedObjects.splice(j, 1);
			}
			
			j = 0;
			while (j < _tickedObjects.length) {
				if(_tickedObjects[j] != null) {
					j++;
					continue;
				}
				_tickedObjects.splice(j, 1);
			}
			com.pblabs.engine.debug.Profiler.exit("purgeEmpty");
		}
		
		com.pblabs.engine.debug.Profiler.ensureAtRoot();
	}
	
	inline function get_timeScale():Float
	{
		return _timeScale;
	}
	
	inline function set_timeScale(value:Float):Float
	{
		_timeScale = value;
		return value;
	}

	function get_interpolationFactor():Float
	{
		return _interpolationFactor;
	}
	
	function get_virtualTime () :Int
	{
		return _virtualTime;
	}
	
	function set_virtualTime (time :Int) :Int
	{
		_virtualTime = time;
		return time;
	}
	
	function get_platformTime():Int
	{
		return _platformTime;
	}
	
	function set_platformTime (time :Int) :Int
	{
		throw "Cannot set platform time in this version";
		return time;
	}
	
	function get_frameCounter():Int
	{
		return _frameCounter;
	}
	
	function removeFromDeferredObjects (object :Dynamic) :Bool
	{
		if (_deferredObjects.length == 0) {
			return false;
		}
		for (tup in _deferredObjects) {
			if (tup.v1 == object) {
				_deferredObjects.remove(tup);
				return true;
			}
		}
		return false;
	}
	
	function get_isRunning():Bool
	{
		return _isRunning;
	}
	
	function set_isRunning(val :Bool):Bool
	{
		if (_isRunning != val) {
			if (val) {
				start();
			} else {
				stop();
			}
		}
		return val;
	}
	
	
	var _timer :#if flash flash.utils.Timer; #else com.pblabs.engine.time.Timer; #end
	var _virtualTime :Int;
	var _platformTime :Int;
	var _timeScale :Float;
	var _isRunning :Bool;
	var _interpolationFactor :Float;
	var _lastTime :Float;
	var _elapsed :Int;
	var _animatedObjects:Array<ProcessObjectAnimated>;
	var _tickedObjects:Array<ProcessObjectTicked>;
	var _needPurgeEmpty:Bool;
	var _deferredCallbacks :Array<Void->Dynamic>;
	var _deferredObjects :Array<Tuple<Dynamic, Float>>;
	var _frameCounter :Int;
	var _duringAdvance :Bool;
}

class ProcessObjectTicked
{
	public function new () 
	{
		#if profiler
		profilerKey = null;
		#end
		priority = 0.0;
		listener = null;
	}
	
	#if profiler
	public var profilerKey :String;
	#end
	public var listener :ITickedObject;
	public var priority :Float;
}

class ProcessObjectAnimated
{
	public function new () 
	{
		#if profiler
		profilerKey = null;
		#end
		priority = 0.0;
		listener = null;
	}
	
	#if profiler
	public var profilerKey :String;
	#end
	public var listener :IAnimatedObject;
	public var priority :Float;
}
