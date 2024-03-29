DEBUG = true
if 'prod' in process.argv
  DEBUG=false

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



RiteSchema = new Schema
  contents: {type: String, default: ' '} #conig TODO
  date: { type: Date, default: Date.now }
  owner: ObjectId
  props: {type:Schema.Types.Mixed, default:{} }

RiteSchema.methods.getOwner= (cb)->
  return this.db.model('User').findById(this.owner).run(cb)

Rite = mongoose.model('Rite', RiteSchema)
exports.Rite = Rite

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  current: { type: Schema.ObjectId, ref: 'Rite' }
  history: [{ type: Schema.ObjectId, ref: 'Rite' }]

CellSchema.index {world:1, x:1, y:1}, {unique:true}

exports.Cell = mongoose.model('Cell', CellSchema)

# asyncReal=(data, callback) ->
#   process.nextTick ->
#     callback(data)

NoteSchema = new Schema
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  contents: {type: String, default: ''}
  read:{type:Boolean, default: false}
  to: { type: Schema.ObjectId }
  from: { type: Schema.ObjectId}
  fromLogin: {type: String}
  type: {type: String}
  date: { type: Date, default: Date.now }
  world: ObjectId
  cellPoints: [
    x: {type: Number}
    y: {type: Number}
  ]

exports.Note = mongoose.model('Note', NoteSchema)


mongooseAuth=require('mongoose-auth')

UserSchema = new Schema
  totalRites: {type: Number, default: 0}
  activeRites: {type: Number, default:0}
  totalEchoes: {type: Number, default:0}
  color: {type: String, default: ''}
  personalWorld: ObjectId
  email: String
  name: String # we'll use this for display purposes, non unique
  inactive: {type:Boolean, default: true}
  initialPos: String
  powers:
    jumpDistance: {type: Number, default: 500000}
    lastLinkOn: {type: Date, default: new Date(0)} #epoch

UserSchema.plugin mongooseAuth,
    everymodule:
      everyauth:
        User: -> exports.User
    twitter:
      everyauth:
        myHostname: if DEBUG then 'http://0.0.0.0:3000' else 'http://writtenworld.org'
        consumerKey: if DEBUG then 'DEIaTcd5DQ7yceARLk6KLA' else 'CaOVgX2g6tJoJCHDoBUVg'
        consumerSecret: if DEBUG then 'NFKIDiVyQpRIXVu0T7nVEIylErrpdPcMFrewAgWDbjM' else 'pwC2JFsI96ApwCqtPwwU1HEqFwOGOAj0PcTmxpOjsfA'
        redirectPath: '/welcome'
    facebook:
      everyauth:
        myHostname: if DEBUG then 'http://0.0.0.0:3000' else 'http://writtenworld.org'
        appId: if DEBUG then '166126233512041' else '391056084275527'
        appSecret: if DEBUG then '272b9cb2b28698932dfca93aef9eee47' else '1e8690b4c88153a1626b3851ffe5f557'
        redirectPath: '/welcome'

    password:
      extraParams:
         email: String
      everyauth:
        getLoginPath: '/login'
        postLoginPath: '/login'
        loginView: 'login.jade'
        getRegisterPath: '/register'
        postRegisterPath: '/register'
        registerView: 'register.jade'
        loginSuccessRedirect: '/welcome'
        registerSuccessRedirect: '/welcome' # this was '/' as was above

        # respondToRegistrationSucceed: (res, user, data) ->
        #   personal= new exports.World {personal:true, owner:user._id, name:"#{user.login}'s History", ownerlogin: user.login }
        #   personal.save (err, doc)->
        #     user.personalWorld = personal._id
        #     user.save (err) -> console.log err if err
        #   if data.session.redirectTo
        #     res.writeHead 303, {'Location': data.session.redirectTo}
        #   else
        #     res.writeHead 303, {'Location': '/'}  # data.session.redirectTo}
        #   res.end()
        #   return true

exports.User= mongoose.model('User', UserSchema)


FeedbackSchema = new Schema
  contents: {type: String, default: ' '}
  t: {type: String, default: ' '}
  date: { type: Date, default: Date.now }

exports.Feedback = mongoose.model('Feedback', FeedbackSchema)


#UTILITY
# Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

Array::filter = (func) -> x for x in @ when func(x)

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
