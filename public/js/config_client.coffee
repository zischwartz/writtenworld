window.DEBUG = false
window.NOMAP = false
window.VARYLATLNG = false
window.MapBoxBadZoomOffset=3 #3 for mapbox, 2 for a ts with max zoom of 18

s3Url= "http://s3.amazonaws.com/ww-tiles/wwtiles/{z}/{x}/{y}.png"
mapBoxUrl = "http://{s}.tiles.mapbox.com/v3/zischwartz.map-ei57zypj/{z}/{x}/{y}.png" # set offset to 3 if use this one

tileServeUrl = "http://23.23.200.225/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png"

colorOptions=[
   '73A5FF'
   '20FE00'
   '6716F7'
   '3EC8B9'
   '0500FF'
   'EC535A'
   'D64BA2'
   'D91D27' ]

Configuration = class Configuration
  constructor: (spec = {}) ->
    @tileSize = -> spec.tileSize ? {x: 192, y: 256} #been using THIS one
    # @tileServeUrl = -> spec.tileServeUrl ? tileServeUrl # @tileServeUrl = -> s3Url 
    @tileServeUrl = -> mapBoxUrl #spec.tileServeUrl ? mapBoxUrl # tileServeUrl

    @maxZoom = -> spec.maxZoom ? 20 # this is super important and sets the resolution. was 18, current image tiles are only 18
    @minZoom = -> spec.minZoom ? 11 # was 16
    @defZoom = -> spec.defZoom ? 16 # was 17 till weds night before thesis
    @minLayerZoom = -> spec.minLayerZoom ? 16 # was 16. turn off the interactive layer
    @minCircleZoom = -> spec.minCircleZoom ? 13

    @defaultChar = -> spec.defaultChar ? " "
    @inputRateLimit = -> spec.inputRateLimit ? 80# was 20 # actually for arrowkey, not input
    @maxDistanceFromOfficial = -> spec.maxDistanceFromOfficial ? 15000 # from official City, for rollout, see below

    # leaflet
    @scrollWheelZoom= -> true#false
    @updateWhenIdle = -> false
  
    @autoPan = -> true

    initialPosReal=initialPos
    @initialPos= ->
      if initialPosReal == 'false' #sigh
        return false
      else
        # l = {x:parseFloat(initialPosReal.x), y: parseFloat(initialPosReal.y)}
        return initialPosReal

    isReallyAuth= isAuth
    @isAuth = -> isReallyAuth ? false

    @maxJumpDistance = -> 100
    @colorOptions= colorOptions

window.config = new Configuration(window.worldSpec)


window.officialCities =
  'New York City': new L.LatLng(40.73037270272987, -73.99361729621887)
  # 'Washington DC': new L.LatLng(38.898715, -77.037655)
  # 'Boston': new L.LatLng(42.358431,-71.059773)
  # 'Columbus': new L.LatLng( 39.961176,-82.998794)
  # 'San Francisco': new L.LatLng(37.77493,-122.419415)


