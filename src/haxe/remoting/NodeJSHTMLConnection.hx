/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package haxe.remoting;

import haxe.remoting.Context;

import js.Node;

/**
  * Haxe HTTP remoting connection for node.js
  */
class NodeJSHTMLConnection
{
	static var context :Context;
	
	public static function connect (ctx :Context) :Void
	{
		if (context != null) throw "Context is already set";
		context = ctx;
	}
	
	public static function handleRequest (req :ServerRequest, res :ServerResponse) :Bool 
	{
		if (req.headers == null || Reflect.field(req.headers, "x-haxe-remoting") == null) {
			return false;
		}
		
		//Get the POST data
		req.setEncoding("utf8");
		var content = "";
		
		req.addListener("data", function(chunk) {
			content += chunk;
		});

		req.addListener("end", function() {
			req.removeAllListeners("data");
			req.removeAllListeners("end");
			var result = processRequest(content, context, function (result :String) :Void {
				var hdrs = {};
				Reflect.setField(hdrs,"Content-Type", "text/plain");
				Reflect.setField(hdrs,"x-haxe-remoting", 1);
				res.writeHead(200, hdrs);
				res.write(result);
				res.end();
			});
		});
		
		return true;
	}
	
	static function processRequest(requestData :String, context :Context, cb :String->Void) :Void 
	{
		try {
			var params = requestData;
			var h :Hash<String> = new Hash();
			if( params == "" )
				cb("");
			for( p in ~/[;&]/g.split(params) ) {
				var a = p.split("=");
				var n = a.shift();
				h.set(StringTools.urlDecode(n),StringTools.urlDecode(a.join("=")));
			}
			
			requestData = h.get("__x");
			var u = new haxe.Unserializer(requestData);
			var path = u.unserialize();
			var args :Array<Dynamic> = u.unserialize();
			args.push(function (?data :Dynamic = null) :Void {
				var s = new haxe.Serializer();
				s.serialize(data);
				cb("hxr" + s.toString());
			});
			context.call(path, args);
		} catch( e :Dynamic ) {
			var s = new haxe.Serializer();
			s.serializeException(e);
			cb("hxr" + s.toString());
		}
	}	
}
