'use strict'

global = exports ? window
# Includes Backbone & Underscore if the environment is NodeJS
_         = (unless typeof exports is 'undefined' then require 'underscore' else global)._
Backbone  = unless typeof exports is 'undefined' then require 'backbone' else global.Backbone

global.bbui ?= {}
bbui.Util ?= {}
bbui.Util.encodeLatLng ?= (ll)->
  if ll instanceof google.maps.LatLng then ll.toUrlValue 13 else null
bbui.Util.decodeLatLng ?= (str)->
  if typeof str == 'string' and str.indexOf ',' > 8 then new google.maps.LatLng (ll =str.split ',')[0], ll[1] else null
# Backbone.controls.MapView
class Backbone.controls.MapView extends Backbone.CompositeView
  __muted:false
  setNear:(near, radius=25)->
    Backbone.controls.MapView.GeoCode near, (res,stat)=>
      @__muted = true
      loc    = new GeoPoint res[0].geometry.location.lat(), res[0].geometry.location.lng()
      swDest = new google.maps.LatLng (d = loc.destinationPoint 225, radius).lat(), d.lon()
      neDest = new google.maps.LatLng (d = loc.destinationPoint 45, radius).lat(), d.lon()
      @$el.gmap('get', 'map').fitBounds new google.maps.LatLngBounds swDest, neDest
  addMarkers:(value)->
    @clearMarkers()
    _.each (if _.isArray value then value else [value]), (itm, idx) =>
      @$el.gmap 'addMarker', itm, ((map, marker) => 
        $(marker).mouseover (evt)=> @trigger 'mouseover', selected:idx
        $(marker).click (evt)=> @trigger 'click', selected:idx
        ), bounds: false
    if @__map?
      @fitMarkers() 
    @
  getMarkers:->
    @$el.gmap 'get', 'markers'
  clearMarkers:-> 
    @$el.gmap 'clear', 'markers'
    @
  setZoom:(zoom)->
    @__map?.setZoom zoom
  setCenter:(latlon)->
    @__map?.setCenter latlon
  panTo:(latlon)->
    @__map?.panTo latlon
  panToBounds:(bounds)->
    @__map?.panToBounds bounds
  getBounds:->
    @__map?.getBounds()
  fitBounds:(bounds)->
    @__map?.fitBounds bounds
  inBounds:(latlon)->
    b.contains latlon if (b = @getBounds())?
  fitMarkers:->
    bounds = @getBounds()
    update = false
    for marker in @getMarkers()
      unless @inBounds marker.position
        update = true
        bounds.extend marker.position
    @fitBounds bounds if update
  setOptions:(o)->
    p = {}
    _.each o, (v,k) =>  p[k] = v if @model.attributes.hasOwnProperty k
    @model.set p, {silent:true} 
    if @__map?
      @__muted = true 
      $(@__map).bind 'bounds_changed', =>
        @_muted = false
        $(@__map).unbind 'bounds_changed'
      @$el.gmap( 'get', 'map' ).fitBounds bounds if (bounds = @model?.getBounds?())?
    else
      @__pendingOpts = @model.attributes
    @
  zoomHandler:->
    if !@__muted
      @trigger 'zoom_changed', 
        zoom : @__map.getZoom() #@$el.gmap 'get', 'zoom'
    @__muted = false
  init:(o)->
    @model = new (Backbone.Model.extend
      __map: @
      defaults:
        # center:new google.maps.LatLng 37.037778, -95.626389
        # latLngNe:null
        # latLngSw:null
        zoom:18
        panControl:false
        streetViewControl:false
        mapTypeControl:false
        navigationControl: false
        disableDefaultUI: true
        backgroundColor:"#fff"
      initialize:(o)->
        @on 'change', (evt)=>
          @attributes.center = m.center if (m = @getBounds())?
    )
    @setOptions o if o?
    @$el.gmap( @model.attributes ).bind 'init', (evt, map) =>
      @__map = map
      # add EventListener for 'zoom_changed' -- because the idjit who created jquery-ui-map didn't
      $.fn[(name='zoom_changed')] = (a, b)-> $(map).addEventListener name, a, b
      $(map).zoom_changed (=> @zoomHandler())
      if typeof @__pendingOpts != 'undefined'
        @setOptions @__pendingOpts
        delete @__pendingOpts
        @__muted = false
      $(map).dragend =>
        @trigger 'dragend', Backbone.controls.MapView.formatBounds map.getBounds()
      @fitMarkers()
      @trigger 'ready'
Backbone.controls.MapView.formatBounds = (bounds)->
  return null if !(bounds instanceof google.maps.LatLngBounds)
  {
    latLngNe: bbui.Util.encodeLatLng bounds.getNorthEast()
    latLngSw: bbui.Util.encodeLatLng bounds.getSouthWest()
  }
Backbone.controls.MapView.GeoCode = (place, callback)->
  throw new Error 'callback is undefined' if !(callback?)
  if typeof place != 'string'
    if place instanceof google.maps.LatLng
      req = location: new google.maps.LatLng place
    else if place instanceof google.maps.LatLngBounds
      req = bounds: new google.maps.LatLngBounds place
    else
      return null
  else
    req = address:place
  new google.maps.Geocoder().geocode _.extend(req, region:'US'), callback
  null
Backbone.controls.MapView.getBoundsRad = (bounds)->
  throw new Error 'value must be type google.maps.LatLngBounds' if !(bounds instanceof google.maps.LatLngBounds)
  ((new GeoPoint (ll = bounds.getSouthWest()).lat(), ll.lng()).distanceTo new GeoPoint (ll = bounds.getNorthEast()).lat(), ll.lng())/2