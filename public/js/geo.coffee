
window.initializeGeo = ->
  
  $.doTimeout 'GeoPermissionTimer', 10*1000, ->
    # console.log 'User did not respond for a while, switching to alt'
    geoAlternative()
    return false # don't poll

  if (navigator.geolocation)
      window.insertMessage 'Welcome', "If your browser asks you if it's ok to use location, please click <b> allow</b>. Otherwise, we'll try to find you based on your IP in a few seconds. <br> <a href='#' data-dismiss='alert' class='cancelAltGeo btn'>Or click here to stay right here</a>", 'major alert-info geoHelper', 9
      # console.log('Geolocation is supported!')
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed)
      # navigator.geolocation.watchPosition geoWatch #possibly use this for mobile
  else
      # console.log('Geolocation is not supported for this Browser/OS version yet.')
      geoAlternative()
  true

geoFailed = (error) ->
  # $('.geoHelper').remove()
  $.doTimeout 'GeoPermissionTimer', false #cancel timer, exec the cb now
  # console.log error.message
  geoAlternative()
  true

geoSucceeded = (position) ->
  # console.log 'geo succeed'
  # window.clearMessages()
  $('.geoHelper').remove()
  $.doTimeout 'GeoPermissionTimer' #cancel the timer
  geoHasPosition position
  true

# not used
geoWatch = (position) ->
  geoHasPosition position
  # console.log('Moved position, or just the initial')
  # console.log position

geoAlternative = ->
  $.getScript 'http://j.maxmind.com/app/geoip.js', (data, textStatus) ->
    $('.geoHelper').remove()
    geoHasPosition {coords:{latitude: geoip_latitude(), longitude: geoip_longitude(), accuracy:-1}}
    true

# chicago = new L.LatLng(41.878114,-87.629798) # for testing
# nj = new L.LatLng(40.058324,-74.405661) # for testing
# la = new L.LatLng(34.052234,-118.243685) # for testing

geoHasPosition = (position) ->
  inOfficialCity = false
  closest= ''
  distanceToClosest = 10000000000000000000000000000000

  p = new L.LatLng(position.coords.latitude,position.coords.longitude)
  state.geoPos = p
  state.geoAccuracy = position.coords.accuracy
  if position.coords.accuracy > 2000 or position.coords.accuracy is -1
    # console.log 'varying'
    p = varyLatLng(p)
  # console.log "accuracy: #{position.coords.accuracy}"
  # p = la
  state.geoPos = p
  state.initialGeoPos = new L.LatLng(p.lat, p.lng)
  for own key, val of officialCities
    distance = p.distanceTo(val)
    if distance < config.maxDistanceFromOfficial()
      inOfficialCity= true
      # console.log 'inofficial true'
    if distance < distanceToClosest
      distanceToClosest = distance
      closest= key
  if inOfficialCity
    map.setView(p, config.defZoom() )
    window.centerCursor()
    # console.log 'we have the position, one way or the other! and yr in an official city'
  else
    # console.log 'dang you arent in an official city'
    if window.VARYLATLNG
      # console.log 'varying ltlng'
      map.setView(varyLatLng(officialCities[closest]), config.defZoom() )
    else
      # console.log 'not varying ltlng'
      map.setView(officialCities[closest], config.defZoom() )
    window.insertMessage "&quotHey, That's Not Where I Am!&quot", "Written World is still in beta, so we're limiting ourselves to a few cities for now. We took you to <b>#{closest}</b>.<br><br>Want a head start writing on your actual location? It may be kinda empty. And the map itself may take a while to load.<br><br><a href='#' class='goToActualPos btn' data-dismiss='alert'>Click here to go to your location</a>", 'major alert-info', 45
  return true

$('.cancelAltGeo').live 'click', ->
  $.doTimeout 'GeoPermissionTimer' #cancel the timer

$('.goToActualPos').live 'click', ->
  map.setView(state.geoPos, config.defZoom() )
  window.centerCursor()
  true


window.varyLatLng = (l) ->
  latOffset = Math.random()/100
  lngOffset = Math.random()/100
  if Math.random() > 0.5
    latOffset= 0-latOffset
  if Math.random() > 0.5
    lngOffset= 0-lngOffset
  p = new L.LatLng(l.lat+latOffset,l.lng+lngOffset)
  return p
