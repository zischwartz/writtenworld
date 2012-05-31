util = require('util')
events = require('events')

mongoose= require 'mongoose'
mongoose.connect('mongodb://localhost/mapist')

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

exports.ObjectIdFromString = mongoose.Types.ObjectId.fromString

WorldSchema = new Schema
  owner: ObjectId
  ownerlogin: {type: String}
  name: {type: String, unique: true,}
  created: { type: Date, default: Date.now }
  personal: {type: Boolean, default: true} #a personal history world
  public: {type: Boolean, default: false}  # 
  slug: { type: String, lowercase: true, trim: true }
  config:
    maxZoom: {type: Number}
    minZoom: {type: Number}
    defZoom: {type: Number}
    defaultChar: {type: String, default: ' '}
    tileSize:
      x: {type: Number}
      y: {type: Number}
    ruleSet: {type: String}
    tileServeUrl: {type: String}
    props: {type:Schema.Types.Mixed, default:{} }

slugGenerator= (options) ->
  options = options || {}
  key = options.key || 'name'
  return slugGenerator= (schema)->
    schema.path(key).set (v) ->
      this.slug = v.toLowerCase().replace(/[^a-z0-9]/g, '').replace(/-+/g, '')
      return v
    
WorldSchema.plugin slugGenerator()

exports.World = mongoose.model('World', WorldSchema)

exports.World.findOne {name: 'main'}, (err, world)->
  if world
    exports.mainWorldId = world._id
    exports.mainWorld = world
    console.log ' Found main world'
  else
    console.log ' Could not find main world...'
    mainWorld = new exports.World
      name: 'main'
      personal: false
      public: true
      config:
        maxZoom:20
        minZoom:10
        tileSize:
          x: 192
          y: 256
        tileServeUrl: "http://23.23.200.225/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png"  #"http://s3.amazonaws.com/ww-tiles/wwtiles/{z}/{x}/{y}.png"
        ruleSet: false
        props:
          echoes: true

    mainWorld.save (err, world) ->
      console log err if err
      console.log ' So we created the main world'
      exports.mainWorldId = world._id
      exports.mainWorld


exports.World.findOne {name: 'words'}, (err, world)->
  if world
    console.log ' Found word world'
  else
    console.log ' Could not find WORD  world...'
    world = new exports.World
      name: 'words'
      personal: false
      public: true
      config:
        maxZoom:20
        minZoom:10
        tileSize:
          x: 192
          y: 256
        tileServeUrl: "http://23.23.200.225/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png"  #"http://s3.amazonaws.com/ww-tiles/wwtiles/{z}/{x}/{y}.png"
        ruleSet: true
        props:
          echoes: false

    world.save (err, world) ->
      console log err if err
      console.log 'So we created the word world'

RiteSchema = new Schema
  contents: {type: String, default: ' '} #conig TODO
  date: { type: Date, default: Date.now }
  owner: ObjectId
  props: {type:Schema.Types.Mixed, default:{} }

RiteSchema.methods.getOwner= (cb)->
  return this.db.model('User').findById(this.owner).run(cb)

Rite = mongoose.model('Rite', RiteSchema)
exports.Rite = Rite
 
# TileSchema = new Schema
#   world: ObjectId
#   z: {type: Number, required: true}
#   x: {type: Number, required: true}
#   y: {type: Number, required: true}
  

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  # contents: {type: String, default: ' '}
  current: { type: Schema.ObjectId, ref: 'Rite' }
  history: [{ type: Schema.ObjectId, ref: 'Rite' }]

CellSchema.index {world:1, x:1, y:1}, {unique:true}

exports.Cell = mongoose.model('Cell', CellSchema)

#    riteQueue.push {cellPoint: cellPoint, worldId:currentWorldId, rite: rite, commandType: commandType}

asyncReal=(data, callback) ->
  process.nextTick ->
    callback(data)

makeSeedQs = (seed)->
  if not seed then console.log 'NOT SEED in makeseedQs'
  # if not seed then return false
  up= {world: seed.world, x:seed.x, y: seed.y-1}
  right= {world: seed.world, x:seed.x+1, y: seed.y}
  down= {world: seed.world, x:seed.x, y: seed.y+1}
  left= {world: seed.world, x:seed.x-1, y: seed.y}
  result = [up, right, down, left]
  return result


findEditsRecurse = (seed, edit, dir)->
  console.log '...'
  console.log 'recuSeed: ' , seed
  qs = makeSeedQs(seed)
  console.log 'recurse, for ', qs[dir]
  exports.Cell .findOne(qs2[dir]).populate('current').run (err, cell) ->
    if cell?.current
      console.log cell
      console.log 'r: ', cell.current.contents
      findEditsRecurse(qs2[dir], edit, dir)

findEdits= (seed, edit, callback) ->
  qs = makeSeedQs(seed)
  for i in [0..qs.length-1]
    console.log qs[i]
    qs2=clone qs
    exports.Cell .findOne(qs[i]).populate('current').run (err, cell) ->
      if cell?.current
        console.log 'c: ', cell?.current.contents
        console.log 'qs2[i]: ', qs2[i]
        findEditsRecurse(clone qs2[i], edit, i)
        # callback(edit)

    # for i in [0..qs.length]
      #only do it in the direction of writing. so one initial all four, then just go in the two resulting directions
      #

    # exports.Cell .findOne(qs[0]).populate('current').run (err, cell) ->
    #   # console.log cell not in edit
    #   if cell?.current #and cell not in edit
    #      console.log "  "+cell.current.contents
    #      edit.push(cell)
    #      findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
    #   else
    #     if comingFrom isnt 3 then exports.Cell .findOne(qs[1]).populate('current').run (err, cell) ->
    #       if cell?.current
    #          console.log "  "+cell.current.contents
    #          edit.push(cell)
    #          findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
    #       else
    #         if comingFrom isnt 0 then exports.Cell .findOne(qs[2]).populate('current').run (err, cell) ->
    #           if cell?.current
    #              console.log "  "+cell.current.contents
    #              edit.push(cell)
    #              findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
    #           else
    #             if comingFrom isnt 1 then exports.Cell .findOne(qs[3]).populate('current').run (err, cell) ->
    #               if cell?.current
    #                  console.log "  "+cell.current.contents
    #                  edit.push(cell)
    #                  findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
    #                  return
    #               else
    #                 return


  # findEditsRecurse = (seed,edit)->
  #   console.log 'Findingrecursively'
  #   qs = makeSeedQs(seed)
  #   exports.Cell .findOne(qs[0]).populate('current').run (err, cell) ->
  #     # console.log cell not in edit
  #     if cell?.current #and cell not in edit
  #        console.log "  "+cell.current.contents
  #        edit.push(cell)
  #        findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
  #     else
  #       exports.Cell .findOne(qs[1]).populate('current').run (err, cell) ->
  #         if cell?.current
  #            console.log "  "+cell.current.contents
  #            edit.push(cell)
  #            findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
  #         else
  #           exports.Cell .findOne(qs[2]).populate('current').run (err, cell) ->
  #             if cell?.current
  #                console.log "  "+cell.current.contents
  #                edit.push(cell)
  #                findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
  #             else
  #               exports.Cell .findOne(qs[3]).populate('current').run (err, cell) ->
  #                 if cell?.current
  #                    console.log "  "+cell.current.contents
  #                    edit.push(cell)
  #                    findEditsRecurse {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit
  #                    return
  #                 else
  #                   return
  #
  # findEditsRecurse(seed,edit)
  # callback(edit)
          
  # console.log seed, edit
  #top
  # exports.Cell .findOne({world: seed.worldId, x:seed.cellPoint.x, y: seed.cellPoint.y-1}) .populate('current')
  # .run (err, cell) ->
  #   if cell?.current
  #      console.log "  "+cell.current.contents
  #      edit.push(cell)
  #      findEdits {cellPoint: {x:cell.x, y:cell.y}, worldId: seed.worldId, rite: cell.current}, edit, ->
  #   # right
  #   exports.Cell .findOne({world: seed.worldId, x:seed.cellPoint.x+1, y: seed.cellPoint.y}) .populate('current')
  #   .run (err, cell) ->
  #     if cell?.current
  #        edit.push(cell)
  #     #below
  #     exports.Cell .findOne({world: seed.worldId, x:seed.cellPoint.x, y: seed.cellPoint.y+1}) .populate('current')
  #     .run (err, cell) ->
  #       if cell?.current
  #          edit.push(cell)
  #       exports.Cell .findOne({world: seed.worldId, x:seed.cellPoint.x-1, y: seed.cellPoint.y}) .populate('current')
  #       .run (err, cell) ->
  #         if cell?.current
  #            edit.push(cell)
  #         callback(edit)



exports.findEdits =findEdits

mongooseAuth=require('mongoose-auth')

UserSchema = new Schema
  totalRites: {type: Number, default: 0}
  activeRites: {type: Number, default:0}
  totalEchoes: {type: Number, default:0}
  color: {type: String, default: ''}
  personalWorld: ObjectId
  email: String
  powers:
    jumpDistance: {type: Number, default: 500000}
    lastLinkOn: {type: Date, default: new Date(0)} #epoch

UserSchema.plugin mongooseAuth,
    everymodule:
      everyauth:
        User: -> exports.User
    password:
      # loginWith: 'email',
      extraParams:
         email: String
      everyauth:
        getLoginPath: '/login'
        postLoginPath: '/login'
        loginView: 'login.jade'
        getRegisterPath: '/register'
        postRegisterPath: '/register'
        registerView: 'register.jade'
        loginSuccessRedirect: '/'
        registerSuccessRedirect: '/'

        respondToRegistrationSucceed: (res, user, data) ->
          # console.log user, data
          personal= new exports.World {personal:true, owner:user._id, name:"#{user.login}'s History", ownerlogin: user.login }
          personal.save (err, doc)->
            user.personalWorld = personal._id
            user.save (err) -> console.log err if err
          if data.session.redirectTo
            res.writeHead 303, {'Location': data.session.redirectTo}
          else
            res.writeHead 303, {'Location': '/'}  # data.session.redirectTo}
          res.end()

          true


exports.User= mongoose.model('User', UserSchema)


FeedbackSchema = new Schema
  contents: {type: String, default: ' '}
  t: {type: String, default: ' '}

exports.Feedback = mongoose.model('Feedback', FeedbackSchema)


#UTILITY
# Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

Array::filter = (func) -> x for x in @ when func(x)

# 
# exports.User.prototype.on 'receivedEcho', (rite) ->
#   console.log 'GOT AN ECHO EVENT !!!!!!!!!!!!!!!!!!!!!!!!!!!ADSFADSFASDFASDFADF'
#   console.log 'this: ', this
#   console.log details
#   return true


# rite = new Rite({contents: contents, owner:ownerId, props:props })

# aUser = new exports.User
# aUser.prototype = new events.EventEmitter

# util.inherits(exports.User, events.EventEmitter)
# console.log 'aUser! ',  aUser
# console.log util.inspect exports.User, true, 2, true

# console.log util.inspect exports.User, true, 2, true

exports.mongooseAuth= mongooseAuth



clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime()) 

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags) 

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance
