window.DEBUG = false
# window.DEBUG = true

# window.USEMAP = false
window.USEMAP = true

window.VARYLATLNG = false
window.MapBoxBadZoomOffset=3 #because mapbox can't zoom in all the way, but we use maxZoom to determine resolution

Configuration = class Configuration #(spec) 
  constructor: (spec = {}) ->
    @tileSize = -> spec.tileSize ? {x: 192, y: 256} #been using THIS one
    @tileServeUrl = -> spec.tileServeUrl ? "http://{s}.tiles.mapbox.com/v3/zischwartz.map-ei57zypj/{z}/{x}/{y}.png" 
    @maxZoom = -> spec.maxZoom ? 20 # this is super important and sets the resolution. was 18, current image tiles are only 18
    @minZoom = -> spec.maxZoom ? 15 # was 16
    @defZoom = -> spec.maxZoom ? 17
    @defaultChar = -> spec.defaultChar ? " "
    @inputRateLimit = -> spec.inputRateLimit ? 40
    @maxDistanceFromOfficial = -> spec.maxDistanceFromOfficial ? 10000 # from official City, for rollout, see below
    @maxJumpDistance = spec.maxJumpDistance ? 0 # 0 no max, -1=no jumps, units are cells I supose 
#ratio of row/cols in WW was .77.. (14/18)

window.config = new Configuration

window.officialCities =
  'New York City': new L.LatLng(40.73037270272987, -73.99361729621887)
  'Washington DC': new L.LatLng(38.898715, -77.037655)

# key is number of rites
userLevels =
  0:
    showLotsOfAnimations: false
    colorsAvailable: ['c0', 'c1', 'c2', 'c3']

# Thoughts!
# <- is a link. the arrow, not the hash. hash for location maybe. hover for url, location name
# get a limited number of those. 3? 1? regenerates over time/typing?
# also for links to locations in world. generate hash, link your friends

window.prefs =
  animate:
    ever:true
    writing:false



# attempt to hide address bar iOS
# window.addEventListener "load", ->
#   setTimeout ->
#     console.log 'trying to scroll yo'
#     window.scrollTo(0,0)
#   , 0


  # ALT TILE SIZES/RATIO
  # @tileSize = -> spec.tileSize ? {x: 128, y: 256} #the best powers of 2
  # @tileSize = -> spec.tileSize ? {x: 128, y: 196}
  # @tileSize = -> spec.tileSize ? {x: 128, y: 160} #this one is good, but 160 isn't a power of 2
  # @tileSize = -> spec.tileSize ? {x: 256, y: 256}
  # @tileSize = -> spec.tileSize ? {x: 192, y: 224} #liking this one


  # tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png' # tileServeUrl = 'http://ec2-107-20-56-118.compute-1.amazonaws.com/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png' # tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/999/256/{z}/{x}/{y}.png'

