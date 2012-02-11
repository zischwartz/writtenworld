var express = require('express');

var leaflet = require('./leaflet-custom-src.js');

var app = express.createServer();

app.configure( function() {
    });

app.configure('development', function(){
    app.use(express.static(__dirname + '/public'));
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
    });

// var everyone = require("now").initialize(app);
var nowjs = require("now");
var everyone = nowjs.initialize(app);

var connectedUsers={};
nowjs.on('connect', function(){
    connectedUsers[this.user.clientId] = {};
    console.log(this.user.clientId, 'connected!');
});

nowjs.on('disconnect', function(){
    delete connectedUsers[this.user.clientId];
    console.log('removing user that disconnected');
});

everyone.now.setBounds= function(bounds){
  // b = new leaflet.L.Bounds(this.now.bounds.max, this.now.bounds.min);
  b = new leaflet.L.Bounds(bounds.max, bounds.min);
  console.log('bounds are', b );
  connectedUsers[this.user.clientId].bounds = b;
};

everyone.now.setSelected = function(cellPoint) {
  connectedUsers[this.user.clientId].selected = cellPoint;
  console.log('set selected', cellPoint);
  // filter by if each connected users bounds contain the cell point, add that to a toUpdate obj
  for(var i in connectedUsers)
  {
    nowjs.getClient(i, function(err){
      this.now.drawCursors(connectedUsers); 
    });
  }
}


// app.get('/', function(req, res){
//       res.send('hello world');
//       });

app.listen(3000);
