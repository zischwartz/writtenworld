window.DEBUG = false
window.USEMAP = true
window.VARYLATLNG = false
window.MapBoxBadZoomOffset=3 #3 for mapbox, 2 for a ts with max zoom of 18

s3Url= "http://s3.amazonaws.com/ww-tiles/wwtiles/{z}/{x}/{y}.png"
mapBoxUrl = "http://{s}.tiles.mapbox.com/v3/zischwartz.map-ei57zypj/{z}/{x}/{y}.png" # set offset to 3 if use this one

tileServeUrl = "http://23.23.200.225/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png"

Configuration = class Configuration
  constructor: (spec = {}) ->
    @tileSize = -> spec.tileSize ? {x: 192, y: 256} #been using THIS one
    # @tileServeUrl = -> spec.tileServeUrl ? tileServeUrl # @tileServeUrl = -> s3Url 
    @tileServeUrl = -> mapBoxUrl #spec.tileServeUrl ? mapBoxUrl # tileServeUrl

    @maxZoom = -> spec.maxZoom ? 20 # this is super important and sets the resolution. was 18, current image tiles are only 18
    @minZoom = -> spec.minZoom ? 11 # was 16
    @defZoom = -> spec.defZoom ? 16 # was 17 till weds night before thesis
    @minLayerZoom = -> spec.minLayerZoom ? 16 # was 16. turn off the layer at this zoom

    @defaultChar = -> spec.defaultChar ? " "
    @inputRateLimit = -> spec.inputRateLimit ? 20
    @maxDistanceFromOfficial = -> spec.maxDistanceFromOfficial ? 10000 # from official City, for rollout, see below

    # leaflet
    @scrollWheelZoom= -> false
    @autoPan = -> false
    @updateWhenIdle = -> false
  
    isReallyAuth= isAuth
    @isAuth = -> isReallyAuth ? false

    @maxJumpDistance = -> 100

window.config = new Configuration(window.worldSpec)

window.officialCities =
  'New York City': new L.LatLng(40.73037270272987, -73.99361729621887)
  'Washington DC': new L.LatLng(38.898715, -77.037655)
  # 'Boston': new L.LatLng(42.358431,-71.059773)
  # 'Columbus': new L.LatLng( 39.961176,-82.998794)
  'San Francisco': new L.LatLng(37.77493,-122.419415)


