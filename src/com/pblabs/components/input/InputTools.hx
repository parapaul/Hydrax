/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.components.input;

import com.pblabs.components.input.MouseInputComponent;
import com.pblabs.components.scene2D.BaseSceneComponent;
import com.pblabs.engine.core.IEntity;
import com.pblabs.engine.core.IEntityComponent;
import com.pblabs.engine.core.ObjectType;
import com.pblabs.engine.core.PropertyReference;
import com.pblabs.util.Comparators;
import com.pblabs.util.Preconditions;

using Lambda;

/**
  * "using" functions for input, e.g. mouse, touch.
  */
class InputTools
{
	public static function makeReactiveButton (e :IEntity) :IEntity
	{
		ensureMouseInputComponent(e);
		var mouse = e.getComponent(MouseInputComponent);
		makeReactiveButtonInternal(mouse);
		return e;
	}
	
	public static function setOnClick (e :IEntity, onClick :Void->Void) :IEntity
	{
		if (onClick == null) return e;
		ensureMouseInputComponent(e);
		var mouse = e.getComponent(MouseInputComponent);
		mouse.bindDeviceClick(onClick);
		return e;
	}
	
	public static function setOnDeviceDown (e :IEntity, onDown :Void->Void) :IEntity
	{
		if (onDown == null) return e;
		
		ensureMouseInputComponent(e);
		var mouse = e.getComponent(MouseInputComponent);
		mouse.bindDeviceDown(onDown);
		return e;
	}
	
	public static function setOnDeviceHeldDown (e :IEntity, onHeldDown :Void->Void) :IEntity
	{
		if (onHeldDown == null) return e;
		
		ensureMouseInputComponent(e);
		var mouse = e.getComponent(MouseInputComponent);
		mouse.bindDeviceHeldDown(onHeldDown);
		return e;
	}
	
	public static function ensureMouseInputComponent (e :IEntity) :IEntity
	{
		if (e.getComponent(MouseInputComponent) == null) {
			e.addComponent(e.context.allocate(MouseInputComponent));
		}
		return e;
	}
	
		/** Grabs two BaseSceneComponent components and makes them into the two button states */
	public static function makeTwoStateButton (e :IEntity, ?isToggle = false) :IEntity
	{
		com.pblabs.util.Assert.isNotNull(e, ' e is null');
		InputTools.ensureMouseInputComponent(e);
		var mouse = e.getComponent(MouseInputComponent);
		
		var sceneComponents = e.getComponents(BaseSceneComponent).array();
		// trace('sceneComponents=' + sceneComponents);
		com.pblabs.util.Assert.isTrue(sceneComponents.length >= 2, "You need at least two BaseSceneComponent types");
		sceneComponents.sort(function (c1 :IEntityComponent, c2 :IEntityComponent) :Int {
			return Comparators.compareStrings(c1.name, c2.name);
		});
		
		var state1 = sceneComponents[0];
		var state2 = sceneComponents[1];
		
		state2.objectMask = ObjectType.NONE;
		//Explicitly bind the mouse events to the first image, so the 
		//MouseInputComponent doesn't get confused (and bind to the 2nd image)
		mouse.boundsProperty = new PropertyReference("@" + state1.name);
		
		state1.visible = true;
		state2.visible = false;
		
		var sm = e.context.getManager(com.pblabs.engine.core.SignalBondManager);
		com.pblabs.util.Assert.isNotNull(sm);
		if (isToggle) {
			mouse.bindDeviceDown(function () :Void {
				state1.visible = state2.visible;
				state2.visible = !state1.visible;
			});
		} else {
			mouse.bindDeviceDown(function () :Void {
				state1.visible = false;
				state2.visible = true;
				var bond = e.context.getManager(com.pblabs.components.input.InputManager).deviceUp.bind(function (?e :Dynamic) :Void {
					state1.visible = true;
					state2.visible = false;
				}).destroyOnUse();
				
				sm.set(mouse.key, bond);
			});
		}
		return e;
	}
	
	/**
	  * Moves button down a few pixels on divice-down.
	  */
	static function makeReactiveButtonInternal (mouse :MouseInputComponent) :MouseInputComponent
	{
		var spatial = mouse.owner.getComponent(com.pblabs.components.spatial.SpatialComponent);
		var input = mouse.context.getManager(com.pblabs.components.input.InputManager);
		com.pblabs.util.Assert.isNotNull(spatial);
		com.pblabs.util.Assert.isNotNull(input);
		var downOnThisButton = false;
		var move :com.pblabs.components.input.IInputData->Void = null;
		var bond :hsl.haxe.Bond = null;
		var down = function () :Void {
			if (!mouse.isRegistered) {
				com.pblabs.util.Log.warn("Mouse not registered");
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
		}).destroyOnUse();
		
		return mouse;
	}
}