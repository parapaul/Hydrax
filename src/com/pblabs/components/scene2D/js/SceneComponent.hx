/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.components.scene2D.js;

import com.pblabs.components.scene2D.BaseSceneComponent;
import com.pblabs.components.scene2D.BaseSceneLayer;
import com.pblabs.engine.time.IAnimatedObject;
import com.pblabs.util.ReflectUtil;

import js.Dom;

/**
  * Base JS SceneComponent class.  Can be rendering on a Canvas layer, or 
  * rendered in a DOM based scene and transformed via CSS (currently much faster on iOs).
  */
class SceneComponent extends BaseSceneComponent<JSLayer>,
	implements IAnimatedObject
{
	public static function createDiv () :HtmlDom
	{
		var div :HtmlDom = cast js.Lib.document.createElement("div");
		//The default origin for css elements is the center, but change it to the top left to be consistent
		//with other platforms.
		//Why -webkit-transform:translateZ(0px)?  It triggers gpu acceleration on iOs
		//http://sebleedelisle.com/2011/04/html5javascript-platform-game-optimised-for-ipad/
		//But then the image is cached, and looks blurry if scaled.
		//;-webkit-transform:translateZ(0px)
		div.style.cssText = "overflow:visible;position:absolute;-webkit-transform-origin:0% 0%;-moz-transform-origin:0% 0%;cursor:default";
		return div;
	}
	
	static function createCanvas () :Canvas
	{
		var canvas :Canvas = cast js.Lib.document.createElement("canvas");
		canvas.style.cssText = "position:relative;left:0px;top:0px;-webkit-transform:translateZ(0px)";
		return canvas;
	}
	
	public var priority :Int;
	/** Set this when added to the parent */
	public var isOnCanvas(default, null) :Bool;
	public var div (default, null) :HtmlDom;
	// public var displayObject (get_displayObject, set_displayObject) :HtmlDom;
	public var cacheAsBitmap (get_cacheAsBitmap, set_cacheAsBitmap) :Bool;
	var _displayObject :HtmlDom;
	
	private var _isContentsDirty :Bool;
	private var _backBuffer :Canvas;
	
	public function new () :Void
	{
		super();
		priority = 0;
		isOnCanvas = false;
		_isContentsDirty = true;
		//Create the image and containing div element
		//Why put it in a div?
		//http ://dev.opera.com/articles/view/css3-transitions-and-2d-transforms/#transforms
		div = createDiv();
	}
	
	public function onFrame (dt :Float) :Void
	{
		if (isOnCanvas && _isContentsDirty && !isTransformDirty) {
			isTransformDirty = true;
		}
		if (isOnCanvas) {
		} else {
			if (parent != null && isTransformDirty) {
				updateTransform();
				isTransformDirty = false;
				SceneUtil.applyTransform(div, _transformMatrix);
			}
		}
	}
	
	public inline function dirtyContents ()
	{
		_isContentsDirty = true;
	}
	
	override public function addedToParent () :Void
	{
		super.addedToParent();
		
		isOnCanvas = Std.is(parent, com.pblabs.components.scene2D.js.canvas.SceneLayer);
		
		#if debug
		if (isOnCanvas)
			com.pblabs.util.Assert.isNotNull(div);
		#end
		
		if (isOnCanvas) {
		} else {
			cast(layer, JSLayer).div.appendChild(div);
			com.pblabs.util.Assert.isNotNull(div.parentNode);
		}
	}
	
	override public function removingFromParent () :Void
	{
		super.removingFromParent();
		#if debug
		com.pblabs.util.Assert.isNotNull(div);
		#end
		
		if (isOnCanvas) {
		} else {
			parent.div.removeChild(div);
		}
	}
	
	override function set_isTransformDirty (val :Bool) :Bool
	{
		if (val && layer != null) {
			cast(layer, JSLayer).isDirty = true;
		}
		return super.set_isTransformDirty(val);
	}
	
	function set_cacheAsBitmap (val :Bool) :Bool
	{
		if (val) {
			redrawBackBuffer();
		} else {
			_backBuffer = null;
		}
		return val;
	}
	
	function get_cacheAsBitmap () :Bool
	{
		return _backBuffer != null;
	}
	
	private function redrawBackBuffer ()
	{
		if (_backBuffer == null) {
			_backBuffer = cast js.Lib.document.createElement("canvas");
			_backBuffer.width = 300;
			_backBuffer.height = 300;
			_backBuffer.style.position = "absolute";
			_backBuffer.style.visibility = "hidden";
			_backBuffer.style.display = "block";
			//Add to the div display object, so it can be rendered to either CSS or Canvas layers.
			com.pblabs.util.Assert.isNotNull(div);
			div.appendChild(_backBuffer);
		}
		_backBuffer.width = Std.int(width);
		_backBuffer.height = Std.int(height);
		var ctx = _backBuffer.getContext("2d");
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.save();
		_isContentsDirty = false;
		drawPixels(ctx);
		ctx.restore();
	}
	
	public function render (ctx :CanvasRenderingContext2D) :Void
	{
		com.pblabs.util.Assert.isNotNull(ctx, "Null Context2d?");
		if (visible && alpha > 0) {
			ctx.save();
			if (isTransformDirty) {
				updateTransform();
			}
			if (_isContentsDirty && cacheAsBitmap) {
				redrawBackBuffer();
			}
			com.pblabs.util.Assert.isNotNull(_transformMatrix, "Null _transformMatrix?");
			untyped ctx.transform(
				_transformMatrix.a.toFixed(4), 
				_transformMatrix.b.toFixed(4), 
				_transformMatrix.c.toFixed(4), 
				_transformMatrix.d.toFixed(4), 
				_transformMatrix.tx.toFixed(4), 
				_transformMatrix.ty.toFixed(4));

			if (alpha < 1) {
				ctx.globalAlpha *= alpha;
			}
			if (cacheAsBitmap) {
				renderCachedBuffer(ctx);
			} else {
				drawPixels(ctx);
			}
			ctx.restore();
		}
	}
	
	function renderCachedBuffer (ctx :CanvasRenderingContext2D) :Void
	{
		#if haxedev
		ctx.drawImage(_backBuffer, 0, 0);
		#else
		ctx.drawImage(cast _backBuffer, 0, 0);
		#end
	}
	
	public function drawPixels (ctx :CanvasRenderingContext2D)
	{
		throw "Subclasses must override";	
	}
	
	override function set_visible (val :Bool) :Bool
	{
		super.set_visible(val);
		_isContentsDirty = true;
		div.style.visibility = _visible ? "visible" : "hidden";
		return val;
	}
	
	override function set_scaleX (val :Float) :Float
	{
		_isContentsDirty = true;
		return super.set_scaleX(val);
	}
	
	override function set_scaleY (val :Float) :Float
	{
		_isContentsDirty = true;
		return super.set_scaleY(val);
	}
	
	override function set_angle (val :Float) :Float
	{
		_isContentsDirty = true;
		return super.set_angle(val);
	}
}
