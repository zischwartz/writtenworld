window.DEBUG = false
# window.DEBUG = true
window.USEMAP = false
# window.USEMAP = true

window.addEventListener "load", ->
  setTimeout ->
    console.log 'trying to scroll yo'
    window.scrollTo(0,0)
  , 0



window.Configuration = class Configuration
  constructor: (spec = {}) ->
    # @tileSize = -> spec.tileSize ? {x: 128, y: 256} #the best powers of 2
    # @tileSize = -> spec.tileSize ? {x: 128, y: 196}
    # @tileSize = -> spec.tileSize ? {x: 128, y: 160} #this one is good, but 160 isn't a power of 2
    @tileSize = -> spec.tileSize ? {x: 192, y: 256} #been using THIS one
    # @tileSize = -> spec.tileSize ? {x: 256, y: 256}
    # @tileSize = -> spec.tileSize ? {x: 192, y: 224} #liking this one
    @maxZoom = -> spec.maxZoom ? 20 # was 18, current image tiles are only 18
    @minZoom = -> spec.maxZoom ? 16
    @defaultChar = -> spec.defaultChar ? " "
    @inputRateLimit = -> spec.inputRateLimit ? 40

#ratio of row/cols in WW was .77.. (14/18)

window.config = new Configuration
