/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.engine.resource;

import haxe.io.BytesData;

enum Source {
	url (u :String);
	bytes (b :BytesData);
	text (t :String);
	embedded (name :String);
	// base64 (data :String); //??Maybe
}