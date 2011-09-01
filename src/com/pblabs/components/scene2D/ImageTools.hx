package com.pblabs.components.scene2D;

import com.pblabs.engine.core.IEntity;
import com.pblabs.engine.core.IEntityComponent;
import com.pblabs.engine.core.NameManager;
import com.pblabs.engine.core.ObjectType;
import com.pblabs.engine.core.PropertyReference;
import com.pblabs.engine.resource.IResourceManager;
import com.pblabs.engine.resource.ResourceToken;
import com.pblabs.engine.resource.ResourceType;
import com.pblabs.engine.resource.SvgResources;
import com.pblabs.util.Comparators;
import com.pblabs.util.svg.SvgData;
import com.pblabs.util.svg.SvgReplace;
using com.pblabs.components.scene2D.SceneUtil;
using com.pblabs.engine.util.PBUtil;

/**
  * "using" methods for adding and setting image data and/or components.
  */
class ImageTools
{
	static var SVG_TEXT = '
		<svg
	   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	   xmlns:svg="http://www.w3.org/2000/svg"
	   xmlns="http://www.w3.org/2000/svg"
	   version="1.1"
	   width="300"
	   height="100"
	   id="svg3759">
	  <text
			x="0"
			y="0"
			id="text3767"
			xml:space="preserve"
			style="font-size:40px;font-style:normal;font-weight:normal;line-height:125%;letter-spacing:0px;word-spacing:0px;fill:#000000;fill-opacity:1;stroke:none;font-family:Bitstream Vera Sans"><tspan
			 x="05"
			 y="0"
			 id="tspan3769">$T</tspan></text>
	</svg>';
	
	public static function getImageComponentForResourceType (type :ResourceType) :Class<Dynamic>
	{
		var compCls :Class<Dynamic> = null;
		switch (type) {
			case IMAGE: 
				#if flash
				compCls = BitmapRenderer;
				#elseif js
				compCls = ImageComponent;
				#end
			case IMAGE_DATA: compCls = BitmapRenderer; 
			case SVG: compCls = BitmapRenderer;
			#if flash
			case CLASS: compCls = com.pblabs.components.scene2D.flash.SceneComponent;
			#end
			default: throw "ResourceType=" + type + " does not have an associated image IEntityComponent"; null; 
		}
		return compCls;
	}
	
	public static function createSvgFromResource (layer :BaseSceneLayer<Dynamic, Dynamic>, 
		token :ResourceToken, ?entityName :String) :IEntity
	{
		var svgData = layer.context.getManager(IResourceManager).get(token);
		com.pblabs.util.Assert.isNotNull(svgData, ' svgData is null from token ' + token);
		return createSvg(layer, svgData, entityName);
	}
	
	public static function createSvg (layer :BaseSceneLayer<Dynamic, Dynamic>, ?svg :String, ?entityName :String) :IEntity 
	{
		var so = layer.context.createBaseSceneEntity();
		
		var svgComp = layer.context.allocate(Svg);
		svgComp.svgData = new SvgData(null, svg);
		svgComp.parentProperty = layer.entityProp();
		so.addComponent(svgComp);
		so.initialize(layer.context.getManager(NameManager).validateName(entityName == null ? "svg" : entityName));
		return so;
	}
	
	/** Converts Svg to Bitmap */
	public static function addSvg (e :IEntity, layer :BaseSceneLayer<Dynamic, Dynamic>, token :ResourceToken, 
		?replacements :Array<SvgReplace>, ?componentName :String, ?cache :Bool = true) :IEntity 
	{
		if (cache) {
			var svgComp = e.context.allocate(BitmapRenderer);
			componentName = componentName != null ? componentName : token.id + "_" + svgComp.key;
			svgComp.parentProperty = layer.entityProp();
			e.addComponent(svgComp, componentName);
			
			com.pblabs.util.svg.SvgRenderQueueManager.getBitmapData(e.context, token, replacements, 
				function (image :com.pblabs.components.scene2D.ImageData) :Void {
					svgComp.bitmapData = image;
					//Notify the display hierarchy that our dimensions may have changed
					if (e.getComponent(com.pblabs.components.minimalcomp.Component) != null) {
						e.getComponent(com.pblabs.components.minimalcomp.Component).invalidate();
					}
				});
		} else {
			
			var svgToken = SvgResources.getSvgResourceToken(e.context, token, replacements);
			var svgData = e.context.getManager(IResourceManager).get(svgToken);
			com.pblabs.util.Assert.isNotNull(svgData, ' svgData is null for ' + svgToken);
			var svgComp = e.context.allocate(Svg);
			svgComp.svgData = svgData;
			svgComp.parentProperty = layer.entityProp();
			e.addComponent(svgComp);
		}
		
		return e;
	}
	
	public static function addImage (e :IEntity, layer :BaseSceneLayer<Dynamic, Dynamic>, ?token :ResourceToken, 
		?componentName :String) :IEntity 
	{
		if (token != null) {
			switch (token.type) {
				case SVG: return addSvg(e, layer, token, null, componentName);
				case IMAGE,IMAGE_DATA: //Ok 
				default: throw "Cannot add image for resource " + token;
			}
		}
		
		var imageComp = e.context.allocate(BitmapRenderer);
		componentName = componentName != null  ? componentName : (token != null ? token.id + "_" + imageComp.key : "BitmapRenderer");
		imageComp.parentProperty = layer.entityProp();
		e.addComponent(imageComp, componentName);
		
		if (token != null) {
			switch (token.type) {
				case IMAGE: 
					var image = e.context.getManager(IResourceManager).get(token);
					com.pblabs.util.Assert.isNotNull(image, ' image is null for token=' + token);
					#if flash
					imageComp.bitmapData = image.bitmapData; 
					#elseif js
					imageComp.drawImage(image);
					#end
					
				case IMAGE_DATA:
					var bd = e.context.getManager(IResourceManager).get(token);
					com.pblabs.util.Assert.isNotNull(bd, ' bd is null');
					imageComp.bitmapData = bd;
				default:
			}
		}
		
		if (e.getComponent(com.pblabs.components.minimalcomp.Component) != null) {
			e.getComponent(com.pblabs.components.minimalcomp.Component).invalidate();
		}
		
		return e;
	}
	
	public static function setImageData (e :IEntity, token :ResourceToken) :IEntity
	{
		var imageComp = e.getComponent(BitmapRenderer);
		if (imageComp != null) {
			if (token != null) {
				switch (token.type) {
					case IMAGE: 
						var image = e.context.getManager(IResourceManager).get(token);
						com.pblabs.util.Assert.isNotNull(image, ' image is null');
						#if flash
						imageComp.bitmapData = image.bitmapData; 
						#elseif js
						imageComp.drawImage(image);
						#end
					case IMAGE_DATA:
						var bd = e.context.getManager(IResourceManager).get(token);
						com.pblabs.util.Assert.isNotNull(bd, ' bd is null');
						imageComp.bitmapData = bd;
					default:
				}
			} else {
				imageComp.bitmapData = null;
			}
		} else {
			com.pblabs.util.Log.warn("setImageData but no BitmapRenderer, token=" + token);
		}
		return e;
	}
	
	public static function setSvg (e :IEntity, svgData :SvgData) :IEntity
	{
		var svgComp = e.getComponent(Svg);
		com.pblabs.util.Assert.isNotNull(svgComp, ' svgComp is null');
		svgComp.svgData = svgData;
		return e;
	}
	
	public static function addText (e :IEntity, layer :BaseSceneLayer<Dynamic, Dynamic>, text :String, ?align :String) :IEntity
	{
		var svgComp = e.context.allocate(Svg);
		svgComp.svgData = new SvgData(null, SVG_TEXT, [new SvgReplace("$T", text)]);
		svgComp.parentProperty = layer.entityProp();
		e.addComponent(svgComp);
		return e;
	}
}