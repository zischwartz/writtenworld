# objects relating to user powers and guides

powers=
  unregistered:
    description: 'not registered'
    colors: ['c0', 'c1', 'c2', 'c3']
  echo0:
    description: 'registered'
    colors: ['c0', 'c1', 'c2', 'c3', 'c4', 'c5']
  echo1:
    description: 'first echo'
    colors: ['c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6',]
  echo5:
    description: 'fifth echo'
    colors: ['c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7']


module.exports=
  getAvailableColors: (echoes) ->
    if echoes<1
      return powers.echo0.colors
    if 1<=echoes<5
      return powers.echo1.colors
    if echoes >=5
      return powers.echo5.colors
    return powers.unregistered.colors

  unregisteredColors: ->
    powers.unregistered.colors

  canLink: (user) ->
    yest = new Date
    yest.setHours(yest.getHours()-24)
    if not user.powers
      return false

    if user.powers.lastLinkOn
      if user.powers.lastLinkOn < yest
        console.log 'cool, link away'
        return true
      else
        console.log 'nope too recent'
        return false
