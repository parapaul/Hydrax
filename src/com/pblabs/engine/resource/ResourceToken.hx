/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.engine.resource;

import com.pblabs.engine.core.IPBContext;
import com.pblabs.util.Equalable;

class ResourceToken
	implements Equalable<ResourceToken>, implements com.pblabs.util.ds.Hashable, implements de.polygonal.ds.Hashable
{
	public var key :Int;
	public var source :Source;
	public var id (default, null) :String;
	public var type (default, null) :ResourceType;
	public var url (get_url, null) :String;

	var _hashCode :Int;
	
	public function new (id :String, source :Source, type :ResourceType)
	{
		this.source = source;
		this.id = id;
		this.type = type;
		//Only hash the id and the type.  The source should not matter for hashing.
		_hashCode = com.pblabs.util.StringUtil.hashCode(id + ":" + Type.enumConstructor(type));
	}
	
	public function equals (other :ResourceToken) :Bool
	{
	    return type == other.type && id == other.id;
	}
	
	inline public function hashCode () :Int
	{
	    return _hashCode;
	}
	
	public function toString () :String
	{
		var sourceStr :String = switch (source) {
			//The compiler doesn't like the 'u'.  Why???
			// case url (ul): "url:" +ul;// + u;
			// case bytes (b): "bytes";
			case text (t): "texthash:" + haxe.Md5.encode(t);
			case embedded (name): "embedded:" + name;
			case linked(data): "linked";
			// case url (u): "url";
			// case none (u): "none";
			// case derived (other): "de
			default: Std.string(source);
		} 
		
		
		return "Resource[id=" + id
		+ ", source=" + sourceStr
		+ ", type=" + 	Type.enumConstructor(type) +", hashCode=" + Std.string(Std.int(_hashCode)) + "]";
	}
	
	function get_url () :String
	{
		switch (source) {
			case Source.url (u): return u; 
			default: com.pblabs.util.Log.error("ResourceType does not have an URL: " + this);
		}
		return null;
	}
}
