var express = require('express');

var app = express.createServer();

app.configure( function() {
    });

app.configure('development', function(){
    app.use(express.static(__dirname + '/public'));
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
    });


var everyone = require("now").initialize(app);

app.get('/', function(req, res){
      res.send('hello world');
      });

app.listen(3000);
