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

import com.pblabs.engine.core.IEntity;
import com.pblabs.engine.core.IEntityComponent;
import com.pblabs.engine.core.PBObject;
import com.pblabs.engine.core.PropertyReference;
import com.pblabs.engine.serialization.ISerializable;
import com.pblabs.engine.serialization.Serializer;
import com.pblabs.engine.time.IAnimatedObject;
import com.pblabs.engine.time.ITickedObject;
import com.pblabs.engine.util.PBUtil;
import com.pblabs.util.Preconditions;
import com.pblabs.util.ReflectUtil;
import com.pblabs.util.ds.Map;
import com.pblabs.util.ds.Maps;

import hsl.haxe.Bond;
import hsl.haxe.DirectSignaler;
import hsl.haxe.Signaler;

using Lambda;

using com.pblabs.engine.core.SetManager;
using com.pblabs.util.StringUtil;

/**
 * Default implementation of IEntity.
 * 
 * <p>Please use allocateEntity() to get at instances of Entity; this allows
 * us to pool Entities at a later date if needed and do other tricks. Please
 * program against IEntity, not Entity, to avoid dependencies.</p>
 */
class Entity extends PBObject, 
	implements IEntity
{
	public var destroyedSignal (get_destroyedSignal, null):Signaler<IEntity>;
	function get_destroyedSignal () :Signaler<IEntity>
	{
		//Lazily create
		if (this.destroyedSignal == null) {
			this.destroyedSignal = new DirectSignaler(this);
		}
		return this.destroyedSignal;
	}
	
	public function new() 
	{
		super();
		_deferring = false;
		_components = Maps.newHashMap(String);
		_deferredComponents = new Array();
	}
	
	/** Iterate over components */
	public function iterator () :Iterator<IEntityComponent>
	{
		return _components.iterator();
	}
	
	public var deferring(get_deferring, set_deferring) : Bool;
	
	public function get_deferring():Bool
	{
		return _deferring;
	}
	
	public function set_deferring(value:Bool):Bool
	{
		if(_deferring == true && value == false) {
			// Resolve everything, and everything that that resolution triggers.
			var needReset:Bool = _deferredComponents.length > 0;
			while(_deferredComponents.length > 0) {
				var pc = _deferredComponents.shift();
				
				//Add the timed components here rather than forcing
				//each implementing class to add itself.
				if (Std.is(pc.item, ITickedObject)) {
					_context.processManager.addTickedObject(cast(pc.item));
				}
				if (Std.is(pc.item, IAnimatedObject)) {
					_context.processManager.addAnimatedObject(cast(pc.item));
				}
				pc.item.register(this, pc.name);
			}
			
			// Mark deferring as done.
			_deferring = false;
			
			// Fire off the reset.
			if(needReset) {
				doResetComponents();
			}				
		}
		_deferring = value;
		return value;
   }
	
	public override function initialize (?name :String = null) :Void
	{			
		// Pass control up.
		super.initialize(name);

		// Resolve any pending components.
		deferring = false;
	}
	
	public override function destroy():Void
	{
		// Give listeners a chance to act before we start destroying stuff.
		destroyedSignal.dispatch(this);
		//The context destruction dispatcher
		cast(context, PBContext).dispatchObjectDestroyed(this);
		
		// Unregister our components.
		for (c in _components)
		{
			if(c.isRegistered) {
				c.unregister();
			}
			if (Std.is(c, ITickedObject)) {
				_context.processManager.removeTickedObject(cast(c));
			}
			if (Std.is(c, IAnimatedObject)) {
				_context.processManager.removeAnimatedObject(cast(c));
			}
		}
		
		// And remove their references from the dictionary.
		for (c in _components.array()) {
			com.pblabs.util.Assert.isNotNull(c, "How can the component be null?");
			_components.remove(c.name);
			#if debug
			// context.getManager(com.pblabs.engine.time.IProcessManager).callLater(createDestructionCheckCallback(c));
			c.postDestructionCheck();
			// c.postDestructionCheck();
			#end
			
			#if !disable_object_pooling
			com.pblabs.engine.pooling.ObjectPoolMgr.SINGLETON.add(c);
			#end
		}
		
		if (_deferredComponents != null && _deferredComponents.length > 0) {
			for (p in _deferredComponents) {
				p.item.unregister();
			}
		}
		
		// Get out of the NameManager and other general cleanup stuff.
		super.destroy();
		com.pblabs.util.Assert.isFalse(destroyedSignal.isListenedTo);
		_components = null;
		destroyedSignal = null;
		_deferredComponents = null;
	}
	
	#if debug
	//Check the references, etc, etc at the end of the update loop.
	function createDestructionCheckCallback (c :IEntityComponent) :Void->Void
	{
		return function () :Void {
			c.postDestructionCheck();
		}
	}
	#end
	
	/**
	 * Serializes an entity. Pass in the current XML stream, and it automatically
	 * adds itself to it.
	 * @param	xml the <things> XML stream.
	 */
	public function serialize(xml :XML):Void
	{
		var entityXML = Xml.createElement("entity");
		entityXML.set("name", name);
		
		var serializer = context.getManager(Serializer); 
		for (component in _components) {
			var componentXML = Xml.createElement("component");
			componentXML.set("name", component.name);
			componentXML.set("type", ReflectUtil.getClassName(component));			
			serializer.serialize(component, componentXML);
			entityXML.addChild(componentXML);
		}

		xml.addChild(entityXML);			
	}
	
	public function deserialize(xml :XML, ?registerComponents:Bool = true):Void
	{
		// Note what entity we're deserializing to the Serializer.
		context.getManager(Serializer).setCurrentEntity(this);

		// Push the deferred state.
		var oldDefer = deferring;
		deferring = true;
		
		var serializer = context.getManager(Serializer);
		com.pblabs.util.Assert.isNotNull(serializer);
		
		// Process each component tag in the xml.
		for (componentXML in xml.elements())
		{
			// Error if it's an unexpected tag.
			if(componentXML.nodeName.toLowerCase() != "component") {
				com.pblabs.util.Log.error("Found unexpected tag '" + componentXML.nodeName.toString() + "', only <component/> is valid, ignoring tag. Error in entity '" + name + "'.");
				continue;
			}
			
			var componentName = componentXML.get("name");
			var componentClassName = componentXML.get("type");
			var component :IEntityComponent = null;
			
			if (!componentClassName.isBlank()) {
				// If it specifies a type, instantiate a component and add it.
				var type :Class<Dynamic> = Type.resolveClass(componentClassName);
				if (null == type) {
					com.pblabs.util.Log.error("Unable to find type '" + componentClassName + "' for component '" + componentName +"' on entity '" + name + "'.");
					continue;
				}
				
				component = cast(context.allocate(type), IEntityComponent);
				if (null == component) {
					com.pblabs.util.Log.error("Unable to instantiate component " + componentName + " of type " + componentClassName + " on entity '" + name + "'.");
					continue;
				}
				
				if (!addComponent(component, componentName)) {
					continue;
				}
			} else {
				// Otherwise just get the existing one of that name.
				component = lookupComponentByName(componentName);
				if (null == component) {
					com.pblabs.util.Log.error("No type specified for the component " + componentName + " and the component doesn't exist on a parent template for entity '" + name + "'.");
					continue;
				}
			}
			
			// try {
				com.pblabs.util.Log.debug("deserializing component " + componentName);
				// Deserialize the XML into the component.
				serializer.deserialize(context, component, componentXML);
				com.pblabs.util.Log.debug("deserialized component " + componentName);
			// } catch (e :Dynamic) {
			// 	com.pblabs.util.Log.error("Failed deserializing component " + componentName + "'  due to :" + e + "\n" + com.pblabs.util.Log.getStackTrace());
			// 	#if debug
			// 	// com.pblabs.engine.debug.com.pblabs.util.Log.setLevel(Type.getClass(component), com.pblabs.engine.debug.com.pblabs.util.Log.DEBUG);
			// 	com.pblabs.engine.debug.Log.setLevel("", com.pblabs.engine.debug.Log.DEBUG);
			// 	#end
			// }
		}
		
		// Deal with set membership.
		var setsAttr = xml.get("sets");
		if (!setsAttr.isBlank()) {
			// The entity wants to be in some sets.
			var setNames = setsAttr.split(",").map(StringTools.trim);
			if (setNames != null) {
				// There's a valid-ish set string, let's loop through the entries
				var sets = context.getManager(SetManager);
				for (set in setNames) {
					if (!set.isBlank()) {
						this.addToSet(set);
					}
				}
			}
		}			
		
		// Restore deferred state.
		deferring = oldDefer;
	}
	
	public function addComponent (component:IEntityComponent, ?componentName :String) :Bool
	{
		Preconditions.checkNotNull(component, "Cannot add a null component");
		
		componentName = componentName == null ? PBUtil.getDefaultComponentName(Type.getClass(component)) : componentName; 
		// Check the context.
		// Preconditions.checkArgument(component.context != null, "Component has a null context!");
		// Preconditions.checkArgument(context != null, "Entity has a null context!");
		Preconditions.checkArgument(component.context == context, "Component and entity are not from same context!");
		
		// Add it to the dictionary.
		if (!doAddComponent(component, componentName)) {
			return false;
		}

		// If we are deferring registration, put it on the list.
		if (deferring) {
			var p = new PendingComponent();
			p.item = component;
			p.name = componentName;
			_deferredComponents.push(p);
			return true;
		}

		if (Std.is(component, ITickedObject)) {
			_context.processManager.addTickedObject(cast(component));
		}
		if (Std.is(component, IAnimatedObject)) {
			_context.processManager.addAnimatedObject(cast(component));
		}
		
		// We have to be careful w.r.t. adding components from another component.
		component.register(this, componentName);
		
		// Fire off the reset.
		doResetComponents();
		
		return true;
	}
	
	public function removeComponent(component:IEntityComponent):Void
	{
		com.pblabs.util.Assert.isNotNull(component, "Why is the component null?");
		// Update the dictionary.
		if (component.isRegistered && !doRemoveComponent(component))
			return;

		// Deal with pending.
		if(!component.isRegistered)
		{
			// Remove it from the deferred list.
			for(i in 0..._deferredComponents.length)
			{
				if((cast( _deferredComponents[i], PendingComponent)).item != component)
					continue;
				
				// TODO: Forcibly call register/unregister to ensure onAdd/onRemove semantics?
				_deferredComponents.splice(i, 1);
				break;
			}
			
			for (k in _components.keys()) {
				if (_components.get(k) == component) {
					_components.remove(k);
					break;
				}
			}

			return;
		}
		
		component.unregister();
		if (!deferring) {
			doResetComponents();
		}
	}
	
	public function lookupComponentByType <T>(componentType:Class<T>):T
	{
		for (component in _components)
		{
			if (Std.is(component, componentType))
				return cast(component);
		}
		
		return null;
	}
	
	public function lookupComponent <T>(componentType:Class<T>):T
	{
		return lookupComponentByType(componentType);
	}
	
	public function lookupComponentsByType <T>(componentType:Class<T>):Array<T>
	{
		var list = new Array();
		
		for (component in _components)
		{
			if (Std.is(component, componentType))
				list.push(component);
		}
		
		return cast(list);
	}
	
	public function lookupComponentByName <T>(componentName:String):T
	{
		return cast(_components.get(componentName));
	}
	
	public function doesPropertyExist (property :PropertyReference<Dynamic>):Bool
	{
		return _context.getProperty(property, null, this, true) != null;
	}
	
	public function getProperty <T> (property :PropertyReference<T>, ?defaultVal :T = null) :T
	{
		return _context.getProperty(property, defaultVal, this);
	}
	
	public function setProperty (property :PropertyReference<Dynamic>, value :Dynamic) :Void
	{
		_context.setProperty(property, value, this);
	}
	
	function doAddComponent(component:IEntityComponent, componentName:String):Bool
	{
		if (componentName == "") {
			com.pblabs.util.Log.warn(["AddComponent", "A component name was not specified. This might cause problems later."]);
		}
		
		if (component.owner != null) {
			com.pblabs.util.Log.error(["AddComponent", "The component " + componentName + " already has an owner. (" + name + ")"]);
			return false;
		}
		
		if (_components.exists(componentName)) {
			com.pblabs.util.Log.error(["AddComponent", "A component with name " + componentName + " already exists on this entity (" + name + ")."]);
			return false;
		}
		
		component.owner = this;
		component.name = componentName;
		_components.set(componentName, component);
		return true;
	}
	
	function doRemoveComponent(component:IEntityComponent):Bool
	{
		if (component.owner != this)
		{
			com.pblabs.util.Log.error(["doRemoveComponent", "The component " + component.name + " is not owned by this entity. (" + name + ")"]);
			return false;
		}
		
		if (_components.get(component.name) == null)
		{
			com.pblabs.util.Log.error(["doRemoveComponent", "The component " + component.name + " was not found on this entity. (" + name + ")"]);
			return false;
		}
		
		_components.remove(component.name);
		if (Std.is(component, ITickedObject)) {
			_context.processManager.removeTickedObject(cast(component));
		}
		if (Std.is(component, IAnimatedObject)) {
			_context.processManager.removeAnimatedObject(cast(component));
		}
		return true;
	}
	
	/**
	 * Call reset on all the registered components in this entity.
	 */
	function doResetComponents():Void
	{
		com.pblabs.engine.debug.Profiler.enter("doResetComponents");
		var oldDefer:Bool = _deferring;
		deferring = true;
		
		var sm = context.getManager(SignalBondManager);
		sm.destroyBondOnEntity(this);
		
		var sets = context.getManager(SetManager);
		
		com.pblabs.util.Log.debug(name + " started reseting");
		for (component in _components)
		{
			// Skip unregistered entities. 
			if(!component.isRegistered) {
				continue;
			}
			
			//Inject the component fields
			 _context.injectInto(component);
			 //Inject the sets (components annotated with @sets("set1", "set2") at the constructor
			 sets.injectSets(component);
			 
			 //Inject the signal listeners
			 // bonds = cast(_context.injector, ComponentInjector).injectComponentListeners(component , bonds);
			//Reset it!
			com.pblabs.util.Log.debug("    reseting " + component.name);
			com.pblabs.engine.debug.Profiler.enter("reseting " + component.name);
			component.reset();
			com.pblabs.engine.debug.Profiler.exit("reseting " + component.name);
			com.pblabs.util.Log.debug("    done reseting " + component.name);
		}
		com.pblabs.util.Log.debug("  finished reseting");
		// if (bonds != null) {
		// 	sm.setAll(this.name, bonds);
		// }
		com.pblabs.engine.debug.Profiler.exit("doResetComponents");
		deferring = false;
	}
	
	var _deferring :Bool;
	var _components :Map<String, IEntityComponent>;
	var _deferredComponents :Array<PendingComponent>;
}

class PendingComponent
{
	public function new () {}
	
	public var item :IEntityComponent;
	public var name :String;
}
