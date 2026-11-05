# ESP Highlight API

ESP version 6 retains the box API and adds independent highlight, highlightName, highlightHealth, highlightWeapon, highlightDistance and highlightFlags features.

Native Roblox Highlights have owned lifecycle cleanup. Labels use a separate layout lane: above/below anchors sit near the object's projected center with a bounded extent; flags/items may sit left/right. They do not consume box seating. Controller highlightLabelExtent defaults to 48 pixels.

Configure each feature with controller:setFeature or handle:setFeature. Highlight settings: enabled, adornee, fillColor, outlineColor, fillTransparency, outlineTransparency, depthMode. Controller options include highlightParent and instanceFactory.

Highlight labels accept normal text styling plus side (above, below, left, right). highlightFlags takes values or state.flags: an ordered array of strings or {text, enabled} entries. state.labelPosition overrides the world label anchor. Missing health is hidden, never fabricated.

Use features={box=false,name=false,distance=false,healthbar=false,highlight=true,highlightName=true,highlightDistance=true,highlightFlags={enabled=true,side="right"}} in ESP.new for object visuals. Add entities and start normally.

Filtering, distance/offscreen culling, model replacement, stop and destroy apply to Highlights and labels. Native engine Highlight limits apply. Box controls never enable Highlight labels implicitly.

For moving objects use resolveInterval=0 with a resolver that updates position/labelPosition from a cached root part. projectionMode="anchor" uses a single object-center projection and cached label anchors instead of projecting the eight bounding-box corners. The default projection mode is unchanged. Feature settings are cached until setFeature is called; update settings through controller:setFeature or handle:setFeature, not by mutating feature tables in place. Inactive handles hide once and reuse their native Highlight when enabled again.
