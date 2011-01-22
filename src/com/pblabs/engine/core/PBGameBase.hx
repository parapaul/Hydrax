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
package com.pblabs.engine.core;

import com.pblabs.engine.core.IPBContext;
import com.pblabs.engine.core.IPBGroup;
import com.pblabs.engine.core.IPBManager;
import com.pblabs.engine.core.NameManager;
import com.pblabs.engine.core.PBContext;
import com.pblabs.engine.core.PBGroup;
import com.pblabs.engine.injection.Injector;
import com.pblabs.engine.time.IProcessManager;
import com.pblabs.engine.time.ProcessManager;
import com.pblabs.engine.util.PBUtil;
import com.pblabs.util.Preconditions;
import com.pblabs.util.ReflectUtil;
import com.pblabs.util.ds.Map;
import com.pblabs.util.ds.Maps;

import hsl.haxe.DirectSignaler;
import hsl.haxe.Signaler;

using Lambda;

/**
  * The base game manager.
  * This class inits all the managers, and managers the IPBContexts.
  */
class PBGameBase
{
	public var currentContext(get_currentContext, null) :IPBContext;
	public var newActiveContextSignaler (default, null) :Signaler<IPBContext>;
	var injector :Injector;

	var _contexts :Array<IPBContext>;
	var _contextsDirty :Bool;
	var _managers :Map<String, Dynamic>;
	
	public function new()
	{
	}
	
	public function startup () :Void
	{
		newActiveContextSignaler = new DirectSignaler(this);
		_managers = Maps.newHashMap(String);

		injector = createInjector();
		_contexts = new Array();
		_contextsDirty = false;
		initializeManagers();
	}
	
	public function injectInto(instance:Dynamic):Void
	{
		injector.injectInto(instance);			
	}
	
	public function getManager <T>(cls :Class<T>, ?name :String = null):T
	{
		return injector.getMapping(cls, name);
	}
	
	//Returns manager for convenience
	public function registerManager <T>(clazz:Class<Dynamic>, ?instance:T = null, ?optionalName:String="", ?suppressInject:Bool = false):T
	{
		if (instance == null) {
			instance = allocate(clazz);
		}

		_managers.set(PBUtil.getManagerName(clazz, optionalName), instance);
		
		if(!suppressInject) {
			injector.injectInto(instance);
		}
		
		//Injection mapping is after the injection of this object, 
		//as this object may access the same class as a parent
		//manager
		injector.mapValue(clazz, instance, optionalName);
		
		if(Std.is(instance, IPBManager)) {
			cast(instance, IPBManager).startup();
		}
		return instance;
	}
	
	public function allocate <T>(type :Class<T>) :T
	{
		if (type == IPBContext) {
			untyped type = PBContext;
		}
		
		var i = Type.createInstance(type, EMPTY_ARRAY);
		com.pblabs.util.Assert.isNotNull(i, "allocated'd instance is null, type=" + type);
		
		injector.injectInto(i);
		
		if (Std.is(i, IPBContext) || Std.is(i, PBContext)) {
			var ctx = cast(i, PBContext);
			//On flash Reflect.hasField is sufficient, however on JS
			//Type.getInstanceFields is needed 
			if (Reflect.hasField(ctx, "setInjectorParent") || Type.getInstanceFields(type).has("setInjectorParent")) {
				Reflect.callMethod(ctx, Reflect.field(ctx, "setInjectorParent"), [injector]);
			}
			ctx.startup();
			
			com.pblabs.util.Assert.isTrue(ctx.injector.getMapping(IPBContext) == ctx);
			if (ctx.getManager(IProcessManager) != null && Std.is(ctx.getManager(IProcessManager), ProcessManager)) {
				//The IPBContext starts paused, we control the unpausing.
				cast(ctx.getManager(IProcessManager), ProcessManager).isRunning = false;
			}
		}
		return i;
	}
	
	public function pushContext (ctx :IPBContext) :Void
	{
		Preconditions.checkNotNull(ctx, "Cannot add a null context");
		Preconditions.checkArgument(!_contexts.has(ctx), "Context already added");
		Preconditions.checkArgument(!Std.is(ctx, PBContext) || cast(ctx, PBContext).injector.parent == injector, "PBContext injector has no parent.  Use allocate() to create the PBContext, not new PBContext");
		stopContexts();
		_contexts.push(ctx);
		ctx.getManager(IProcessManager).isRunning = true;
		startTopContext();
	}
	
	public function shutdown () :Void
	{
		getManager(IProcessManager).isRunning = false;
		if (currentContext != null) {
			currentContext.getManager(IProcessManager).isRunning = false;
			currentContext.rootGroup.destroy();
		}
		
		for (context in _contexts) {
			if (context != null) {
				context.shutdown();
			}
		}
		
		for (m in _managers) {
			if (Std.is(m, IPBManager)) {
				cast(m, IPBManager).shutdown();
			}
		}
		_managers = null;
		injector = null;
		_contexts = null;
	}
	
	// Name lookups.
	public function lookup (name:String):Dynamic
	{
		throw "Not implemented";
		return null;
	}
	
	public function lookupEntity (name:String):IEntity
	{
		throw "Not implemented";
		return null;
	}
	
	function stopContexts () :Void
	{
		for (c in _contexts) {
			c.getManager(IProcessManager).isRunning = false;
		}
	}
	
	function startTopContext () :Void
	{
		if (currentContext != null) {
			#if debug
			com.pblabs.util.Assert.isNotNull(currentContext, "How is the top context null?");
			com.pblabs.util.Assert.isNotNull(currentContext.getManager(IProcessManager), "Where is the IProcessManager?");
			#end
			cast(currentContext.getManager(IProcessManager), ProcessManager).isRunning = true;
			newActiveContextSignaler.dispatch(currentContext);
		} 
	}
	
	function get_currentContext() :IPBContext
	{
		return _contexts[_contexts.length - 1];
	}
	
	function createInjector () :Injector
	{
		return new Injector();
	}
	
	public function initializeManagers():Void
	{
		// Mostly will come from subclasses.
	}
	
	inline static var EMPTY_ARRAY :Array<Dynamic> = [];
}
