/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.components.input;

import com.pblabs.engine.core.EntityComponent;
import com.pblabs.engine.core.PropertyReference;
import com.pblabs.engine.core.SignalBondManager;

import hsl.haxe.DirectSignaler;
import hsl.haxe.Signaler;

/**
 * Convenient class for interacting with input pointers, as an alternative to 
 * interacting with the InputManager.
 */
class MouseInputComponent extends EntityComponent
{
	
	//For MouseInputComponent
	// public static function compareMouseComponents (a :com.pblabs.components.input.MouseInputComponent, b :com.pblabs.components.input.MouseInputComponent) :Int
	// {
	//     if (a.owner.isSquad() && b.owner.isUnit()) {
	//     	return 1;
	//     } else if (b.owner.isSquad() && a.owner.isUnit()) {
	//     	return -1;
	//     } else {
	//     	return 1;
	//     }
	// }
	
	public static function makeReactiveButton (mouse :MouseInputComponent) :Void
	{
		var spatial = mouse.owner.lookupComponent(com.pblabs.components.spatial.SpatialComponent);
		var input = mouse.context.getManager(com.pblabs.components.input.InputManager);
		com.pblabs.util.Assert.isNotNull(spatial);
		com.pblabs.util.Assert.isNotNull(input);
		var downOnThisButton = false;
		var move :com.pblabs.components.input.IInputData->Void = null;
		var bond :hsl.haxe.Bond = null;
		var down = function () :Void {
			if (!mouse.isRegistered) {
				return;
			}
			spatial.y += 5;
			if (bond != null) {
				bond.destroy();
			}
			bond = input.deviceMove.bind(move);
			downOnThisButton = true;
		}
		var up = function () :Void {
			if (!mouse.isRegistered) {
				return;
			}
			if (downOnThisButton) {
				spatial.y -= 5;
				if (bond != null) {
					bond.destroy();
				}
				bond = null;
				downOnThisButton = false;
				// mouse.clicked();
			}
		}
		move = function (data :com.pblabs.components.input.IInputData) :Void {
			if (!mouse.isRegistered) {
				return;
			}
			//Check if the mouse moves out
			if (data.firstObjectUnderPoint(mouse.bounds.objectMask) != mouse.bounds) {
				spatial.y -= 5;
				input.deviceMove.unbind(move);
				downOnThisButton = false;
			}
		}
		mouse.bindDeviceDown(down);
		mouse.bindDeviceUp(up);
		
		mouse.owner.destroyedSignal.bind(function (ignored :Dynamic) :Void {
			if (bond != null) {
				bond.destroy();
			}
		}, true);
	}
	
	
	/**
	  * If there is an IInteractiveComponent in the Entity, you don't have to explicity set the properties.
	  */
	public var boundsProperty :PropertyReference<IInteractiveComponent>;
	public var bounds (get_bounds, set_bounds) :IInteractiveComponent;
	var _bounds :IInteractiveComponent;
	
	var deviceDownSignaler (get_deviceDownSignaler, null) :Signaler<Void>;
	var _deviceDownSignaler :Signaler<Void>;
	function get_deviceDownSignaler () :Signaler<Void>
	{
		if (_deviceDownSignaler == null) {
			_deviceDownSignaler = new DirectSignaler(this);
		}
		return _deviceDownSignaler;
	}
	
	var deviceUpSignaler (get_deviceUpSignaler, null) :Signaler<Void>;
	var _deviceUpSignaler :Signaler<Void>;
	function get_deviceUpSignaler () :Signaler<Void>
	{
		if (_deviceUpSignaler == null) {
			_deviceUpSignaler = new DirectSignaler(this);
		}
		return _deviceUpSignaler;
	}
	
	var deviceClickSignaler (get_deviceClickSignaler, null) :Signaler<Void>;
	var _deviceClickSignaler :Signaler<Void>;
	function get_deviceClickSignaler () :Signaler<Void>
	{
		if (_deviceClickSignaler == null) {
			_deviceClickSignaler = new DirectSignaler(this);
		}
		return _deviceClickSignaler;
	}
	
	function clicked () :Void
	{
		if (_deviceClickSignaler != null) {
			_deviceClickSignaler.dispatch();
		}
	}
	
	// public var deviceMoveSignaler (get_deviceUpSignaler, null) :Signaler<Void>;
	
	public var isScalable :Bool;
	public var isRotatable :Bool;
	/** Moveable in the x/y? */
	public var isTranslatable :Bool;
	
	var _bonds :Array<hsl.haxe.Bond>;
	var _mouseDownThis :Bool;
	
	public function new ()
	{
		super();
		//The default is not movable, rotatable, or scalable.
		isScalable = isRotatable = isTranslatable = false;
		_bonds = [];
		_mouseDownThis = false;
	}
	
	public function bindDeviceDown (callBack :Void->Void) :Void
	{
		com.pblabs.util.Assert.isNotNull(callBack);
		com.pblabs.util.Assert.isNotNull(deviceDownSignaler);
	    _bonds.push(deviceDownSignaler.bindVoid(callBack));
	}
	
	public function bindDeviceUp (callBack :Void->Void) :Void
	{
		com.pblabs.util.Assert.isNotNull(callBack);
		com.pblabs.util.Assert.isNotNull(deviceUpSignaler);
	    _bonds.push(deviceUpSignaler.bindVoid(callBack));
	}
	
	public function bindDeviceClick (callBack :Void->Void) :Void
	{
		com.pblabs.util.Assert.isNotNull(callBack);
		com.pblabs.util.Assert.isNotNull(deviceClickSignaler);
	    _bonds.push(deviceClickSignaler.bindVoid(callBack));
	}
	
	public function clearListeners () :Void
	{
		for (bond in _bonds) {
			bond.destroy();
		}
		_bonds = [];
	}
	
	override function onReset () :Void
	{
		super.onReset();
		
		if (boundsProperty != null) {
			_bounds = owner.getProperty(boundsProperty);
		}
		
		_bounds = _bounds == null ? owner.lookupComponentByType(IInteractiveComponent) : _bounds;
		
		com.pblabs.util.Assert.isNotNull(_bounds, "bounds is null, There's no IInteractiveComponent by type and the boundsProperty is null.  How are we supposed to work?");
		
		var input = context.getManager(InputManager);
		com.pblabs.util.Assert.isNotNull(input, "No InputManager?");

		SignalBondManager.bindSignal(this, input.deviceDown, onMouseDownInternal);
		SignalBondManager.bindSignal(this, input.deviceUp, onMouseUpInternal);
	}
	
	override function onRemove () :Void
	{
		super.onRemove();
		isScalable = isRotatable = isTranslatable = false;
		boundsProperty = null;
		_bounds = null;
		_mouseDownThis = false;
		clearListeners();
	}
	
	function get_bounds () :IInteractiveComponent
	{
		return _bounds;
	}
	
	function set_bounds (bounds :IInteractiveComponent) :IInteractiveComponent
	{
		_bounds = bounds;
		return bounds;
	}
	
	function onMouseDownInternal (data :IInputData) :Void
	{
		_mouseDownThis = false;
		if (isTranslatable || (_deviceDownSignaler != null || _deviceClickSignaler != null)) {
			if (data.firstObjectUnderPoint(bounds.objectMask) == _bounds) {
				
				_mouseDownThis = true;
				if (_deviceDownSignaler != null) {
					_deviceDownSignaler.dispatch();
				}
				
				if (isTranslatable) {
					var dragger = context.getManager(com.pblabs.components.input.PanManager);
					if (dragger != null) {
						dragger.panComponent(cast _bounds);
					}
				}
			}
		}
	}
	
	function onMouseUpInternal (data :IInputData) :Void
	{
		if (data.firstObjectUnderPoint(bounds.objectMask) == _bounds) {
			if (_deviceUpSignaler != null) {
				_deviceUpSignaler.dispatch();
			}
			if (_mouseDownThis) {
				onClickInternal(data);
			}
		} 
		_mouseDownThis = false;
	}
	
	function onClickInternal (data :IInputData) :Void
	{
		if (_deviceClickSignaler != null && data.firstObjectUnderPoint(bounds.objectMask) == _bounds) {
			_deviceClickSignaler.dispatch();
		}
	}
	
	#if debug
	public function toString () :String
	{
		return cast(owner, com.pblabs.engine.core.Entity).toString();
	}
	
	override public function postDestructionCheck () :Void
	{
		super.postDestructionCheck();
		if (_deviceDownSignaler != null) {
			com.pblabs.util.Assert.isFalse(deviceDownSignaler.isListenedTo);
		}
		if (_deviceUpSignaler != null) {
			com.pblabs.util.Assert.isFalse(_deviceUpSignaler.isListenedTo);
		}
		
		if (_deviceClickSignaler != null) {
			com.pblabs.util.Assert.isFalse(_deviceClickSignaler.isListenedTo);
		}
	}
	#end
}
