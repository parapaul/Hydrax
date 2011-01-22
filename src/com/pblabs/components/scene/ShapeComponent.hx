/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.components.scene;
class ShapeComponent
#if flash
 extends com.pblabs.components.scene.flash.Scene2DComponent
#elseif js
    #if css
 extends com.pblabs.components.scene.js.css.Base2DComponent
    #else
 extends com.pblabs.components.scene.js.canvas.Canvas2DComponent   
    #end
#end
{
    public var fillColor (get_fillColor, set_fillColor) :Int;
    public var borderColor (get_borderColor, set_borderColor) :Int;
    public var borderWidth (get_borderWidth, set_borderWidth) :Float;
    
    public function new (?fillcolor :Int = 0xff0000, ?borderWidth :Float = 1, ?borderColor :Int = 0x000000)
    {
        super();
        _fillColor = fillcolor;
		_borderColor = borderColor;
		_borderWidth = borderWidth;
        #if flash
        _displayObject = new flash.display.Sprite();
        cast(_displayObject, flash.display.Sprite).mouseChildren = cast(_displayObject, flash.display.Sprite).mouseEnabled = false;
        #end
        
    }
    
    #if css
    override public function onFrame (dt :Float) :Void
    {
        com.pblabs.util.Assert.isNotNull(parent);
        
        if (isTransformDirty) {
            isTransformDirty = false;
            var xOffset = parent.xOffset - (width / 2);
            var yOffset = parent.yOffset- (height / 2);
            untyped div.style.webkitTransform = "translate(" + (_x + xOffset) + "px, " + (_y + yOffset) + "px) rotate(" + _angle + "rad)";
        }
    }
    #end
    
    #if flash
    override function addedToParent () :Void
	{
		com.pblabs.util.Log.debug("");
		super.addedToParent();
		parent.parent.zoomSignal.bind(onZoomChange);
		redraw();
		com.pblabs.util.Log.debug("finished");
	}
	
	override function removingFromParent () :Void
	{
		super.removingFromParent();
		parent.parent.zoomSignal.unbind(onZoomChange);
	}
	
	function onZoomChange (zoom :Float) :Void
	{
		trace("redrawing from zoom change");
		 redraw();
	}
    #end
    
    override function onReset () :Void
    {
    	com.pblabs.util.Log.debug("");
        super.onReset();
        redraw();
        com.pblabs.util.Log.debug("finished");
    }
    
    override function set_width (val :Float) :Float
    {
        super.set_width(val);
        redraw();
        return val;
    }
    
    override function set_height (val :Float) :Float
    {
        super.set_height(val);
        redraw();
        return val;
    }
    
    public function redraw () :Void
    {
        throw "Subclasses must override";
    }
    
    function get_fillColor () :Int
    {
        return _fillColor;
    }
    
    function set_fillColor (val :Int) :Int
    {
        _fillColor = val;
        redraw();
        return val;
    }
    
    function get_borderColor () :Int
    {
        return _borderColor;
    }
    
    function set_borderColor (val :Int) :Int
    {
        _borderColor = val;
        redraw();
        return val;
    }
    
    function get_borderWidth () :Float
    {
        return _borderWidth;
    }
    
    function set_borderWidth (val :Float) :Float
    {
        _borderWidth = val;
        redraw();
        return val;
    }
    
    var _fillColor :Int;
    var _borderColor :Int;
    var _borderWidth :Float;

}
