// Generated by CoffeeScript 1.3.1
(function() {
  var Cell, cellKeyToXY, doNowInit, filter, getLayer, getNodeIndex, initializeInterface, moveCursor, pan, panIfAppropriate, removeLayerThenZoomAndReplace, removeLayerThenZoomOut, setTileStyle, switchToLayer, turnOffLayer, turnOnMainLayer,
    __slice = [].slice;

  window.state = {
    selectedCell: null,
    lastClickCell: null,
    color: null,
    geoPos: null,
    geoAccuracy: null,
    writeDirection: 'right',
    zoomDiff: function() {
      return config.maxZoom() - map.getZoom();
    },
    numRows: function() {
      var numRows;
      return numRows = Math.pow(2, state.zoomDiff());
    },
    numCols: function() {
      var numCols;
      return numCols = Math.pow(2, state.zoomDiff());
    },
    cellWidth: function() {
      return config.tileSize().x / state.numCols();
    },
    cellHeight: function() {
      return config.tileSize().y / state.numRows();
    },
    belowInputRateLimit: true,
    topLayerStamp: null,
    baseLayer: null,
    isTopLayerInteractive: true,
    cursors: {}
  };

  setTileStyle = function() {
    var fontSize, height, rules, width;
    width = state.cellWidth();
    height = state.cellHeight();
    fontSize = height * 0.9;
    rules = [];
    rules.push("div.leaflet-tile span { width: " + width + "px; height: " + height + "px; font-size: " + fontSize + "px;}");
    return $("#dynamicStyles").text(rules.join("\n"));
  };

  window.setCursor = function(cell) {
    if (state.selectedEl) {
      $(state.selectedEl).removeClass('selected');
    }
    state.selectedEl = cell.span;
    $(cell.span).addClass('selected');
    state.selectedCell = cell;
    now.setCursor(cellKeyToXY(cell.key));
    if (cell.props) {
      if (cell.props.decayed) {
        cell.animateTextRemove(1);
      }
    }
    return true;
  };

  moveCursor = function(direction, from, force) {
    var key, target, targetCell;
    if (from == null) {
      from = state.selectedCell;
    }
    if (force == null) {
      force = false;
    }
    target = cellKeyToXY(from.key);
    switch (direction) {
      case 'up':
        target.y = target.y - 1;
        break;
      case 'down':
        target.y = target.y + 1;
        break;
      case 'left':
        target.x = target.x - 1;
        break;
      case 'right':
        target.x = target.x + 1;
    }
    key = "c" + target.x + "x" + target.y;
    targetCell = Cell.all()[key];
    if (!targetCell) {
      return false;
    } else {
      if (config.autoPan() || force) {
        panIfAppropriate(direction);
      }
      setCursor(targetCell);
      return targetCell;
    }
  };

  window.centerCursor = function() {
    return $.doTimeout(400, function() {
      var key, layer, target, targetCell;
      layer = getLayer(state.topLayerStamp);
      if (!layer) {
        return true;
      }
      target = layer.getCenterTile();
      key = "c" + target.x + "x" + target.y;
      targetCell = Cell.all()[key];
      if (!targetCell) {
        return true;
      } else {
        setCursor(targetCell);
        state.lastClickCell = targetCell;
        return false;
      }
      return true;
    });
  };

  initializeInterface = function() {
    $("#map").click(function(e) {
      var cell;
      if ($(e.target).hasClass('cell')) {
        cell = Cell.all()[e.target.id];
        state.lastClickCell = cell;
        setCursor(cell);
        return inputEl.focus();
      } else {
        inputEl.focus();
        return false;
      }
    });
    window.inputEl = $("#input");
    inputEl.focus();
    map.on('zoomend', function() {
      return inputEl.focus();
    });
    map.on('viewreset', function(e) {
      $("#loadingIndicator").fadeIn('fast');
      if (map.getZoom() >= config.minLayerZoom() && !state.topLayerStamp) {
        return turnOnMainLayer();
      }
    });
    map.on('dblclick', function(e) {
      return $("#loadingIndicator").fadeIn('fast');
    });
    $(".leaflet-control-zoom-in, .leaflet-control-zoom-out").click(function(e) {
      return $("#loadingIndicator").fadeIn('fast');
    });
    inputEl.keypress(function(e) {
      var c, userTotalRites, _ref;
      if ((_ref = e.which) === 0 || _ref === 13 || _ref === 32 || _ref === 9 || _ref === 8) {
        return false;
      } else {
        c = String.fromCharCode(e.which);
        state.selectedCell.write(c);
        userTotalRites = parseInt($("#userTotalRites").text());
        $("#userTotalRites").text(userTotalRites + 1);
        return moveCursor(state.writeDirection);
      }
    });
    inputEl.keydown(function(e) {
      var t;
      if (!state.belowInputRateLimit) {
        return false;
      }
      state.belowInputRateLimit = false;
      $.doTimeout('keydownlimit', config.inputRateLimit(), function() {
        state.belowInputRateLimit = true;
        return false;
      });
      switch (e.which) {
        case 9:
          e.preventDefault();
          return false;
        case 38:
          return moveCursor('up', null, true);
        case 40:
          return moveCursor('down', null, true);
        case 39:
          return moveCursor('right', null, true);
        case 37:
          return moveCursor('left', null, true);
        case 8:
          moveCursor('left', null);
          state.selectedCell.clear();
          return setCursor(state.selectedCell);
        case 13:
          t = moveCursor('down', state.lastClickCell, true);
          return state.lastClickCell = t;
        case 32:
          state.selectedCell.clear();
          return moveCursor(state.writeDirection);
      }
    });
    $("#locationSearch").submit(function() {
      var locationString;
      locationString = $("#locationSearchInput").val();
      $.ajax({
        url: "http://where.yahooapis.com/geocode?location=" + locationString + "&flags=JC&appid=a6mq7d30",
        success: function(data) {
          var km, latlng, result;
          result = data['ResultSet']['Results'][0];
          latlng = new L.LatLng(parseFloat(result.latitude), parseFloat(result.longitude));
          km = latlng.distanceTo(state.geoPos) / 1000;
          if (km <= state.userPowers.jumpDistance) {
            map.panTo(latlng);
            state.geoPos = latlng;
          } else {
            insertMessage('Too Far!', "Sorry, you can't jump that far. Get some echoes to go further than " + state.userPowers.jumpDistance + "km.");
          }
          $('#locationSearch').modal('hide');
          return centerCursor();
        }
      });
      return false;
    });
    $(".modal").on('shown', function() {
      var _ref;
      return (_ref = $(this).find('input')[0]) != null ? _ref.focus() : void 0;
    });
    $(".modal").on('hidden', function() {
      return inputEl.focus();
    });
    $(".leaflet-control-zoom-in").click(function(e) {
      map.zoomIn();
    });
    $(".leaflet-control-zoom-out").click(function(e) {
      if (map.getZoom() <= config.minLayerZoom() && state.topLayerStamp) {
        removeLayerThenZoomAndReplace();
      } else {
        map.zoomOut();
      }
    });
    return $(".trigger").live('click', function() {
      var action, c, f, payload, t, text, type;
      action = $(this).data('action');
      type = $(this).data('type');
      payload = $(this).data('payload');
      text = $(this).text();
      $(this).parent().parent().find('.active').removeClass('active');
      $(this).parent().addClass('active');
      if (action === 'set') {
        state[type] = payload;
        now.setUserOption(type, payload);
      }
      if (action === 'setClientState') {
        state[type] = payload;
      }
      if (type === 'layer') {
        $("#worldLayer").html(text + '<b class="caret"></b>');
        if (payload === 'off' && state.topLayerStamp) {
          turnOffLayer();
        } else if (payload === 'main') {
          turnOnMainLayer();
        } else {
          switchToLayer(payload);
        }
      }
      if (type === 'color') {
        $("#color").addClass(payload);
      }
      if (type === 'writeDirection') {
        c = this.innerHTML;
        $('.direction-dropdown')[0].innerHTML = c;
        $('.direction-dropdown i').addClass('icon-white');
      }
      if (type === 'submitfeedback') {
        f = $('#feedback').val();
        t = $("#t").val();
        now.submitFeedback(f, t);
        $('#feedbackModal').modal('hide');
        inputEl.focus();
        return false;
      }
      inputEl.focus();
    });
  };

  panIfAppropriate = function(direction) {
    var panByDist, panOnDist, selectedPP;
    selectedPP = $(state.selectedEl).offset();
    panOnDist = 200;
    if (direction === 'left' || direction === 'right') {
      panByDist = state.cellWidth();
    } else {
      panByDist = state.cellHeight();
    }
    if (direction === 'up') {
      if (selectedPP.top < panOnDist) {
        pan(0, 0 - panByDist);
      }
    }
    if (direction === 'down') {
      if (selectedPP.top > document.body.clientHeight - panOnDist * 1.5) {
        pan(0, panByDist);
      }
    }
    if (direction === 'right') {
      if (selectedPP.left > document.body.clientWidth - panOnDist) {
        pan(panByDist, 0);
      }
    }
    if (direction === 'left') {
      if (selectedPP.left < panOnDist) {
        return pan(0 - panByDist, 0);
      }
    }
  };

  jQuery(function() {
    var centerPoint, mapOptions, tileServeLayer;
    tileServeLayer = new L.TileLayer(config.tileServeUrl(), {
      maxZoom: config.maxZoom()
    });
    state.baseLayer = tileServeLayer;
    centerPoint = new L.LatLng(40.714269, -74.005972);
    mapOptions = {
      center: centerPoint,
      zoomControl: false,
      attributionControl: false,
      zoom: config.defZoom(),
      scrollWheelZoom: config.scrollWheelZoom(),
      minZoom: config.minZoom(),
      maxZoom: config.maxZoom() - window.MapBoxBadZoomOffset
    };
    window.map = new L.Map('map', mapOptions).addLayer(tileServeLayer);
    initializeGeo();
    now.ready(function() {
      doNowInit(now);
    });
    return true;
  });

  doNowInit = function(now) {
    var domTiles;
    domTiles = new L.DomTileLayer({
      tileSize: config.tileSize()
    });
    state.topLayerStamp = L.Util.stamp(domTiles);
    now.setCurrentWorld(initialWorldId, personalWorldId);
    map.addLayer(domTiles);
    setTileStyle();
    map.on('zoomend', function() {
      return setTileStyle();
    });
    initializeInterface();
    $("#loadingIndicator").fadeOut('slow');
    now.setBounds(domTiles.getTilePointAbsoluteBounds());
    now.core.socketio.on('disconnect', function() {
      $("#errorIndicator").fadeIn('fast');
      return $.doTimeout(2000, function() {
        return location.reload();
      });
    });
    map.on('moveend', function(e) {
      if (state.topLayerStamp) {
        now.setBounds(getLayer(state.topLayerStamp).getTilePointAbsoluteBounds());
      }
      return $("#loadingIndicator").fadeOut('slow');
    });
    map.on('zoomend', function(e) {
      if (state.topLayerStamp) {
        now.setBounds(getLayer(state.topLayerStamp).getTilePointAbsoluteBounds());
      }
      if (map.getZoom() === config.minLayerZoom() && state.topLayerStamp && !state.isTopLayerInteractive) {
        turnOffLayer();
        turnOnMainLayer();
        return $("#loadingIndicator").fadeOut('slow');
      }
    });
    now.setClientStateFromServer(function(s) {
      var color_ops;
      state.userPowers = s.powers;
      if (s.color) {
        return state.color = s.color;
      } else {
        color_ops = ['c0', 'c1', 'c2', 'c3'];
        state.color = color_ops[Math.floor(Math.random() * 4)];
        return now.setUserOption('color', state.color);
      }
    });
    centerCursor();
    now.updateCursors = function(updatedCursor) {
      var cursor, selectedCell;
      if (state.cursors[updatedCursor.cid]) {
        cursor = state.cursors[updatedCursor.cid];
        selectedCell = Cell.get(cursor.x, cursor.y);
        $(selectedCell.span).removeClass("c" + cursor.color + " otherSelected");
      }
      state.cursors[updatedCursor.cid] = updatedCursor;
      cursor = updatedCursor;
      if (cursor.x && cursor.y) {
        selectedCell = Cell.get(cursor.x, cursor.y);
        return $(selectedCell.span).addClass("c" + cursor.color + " otherSelected");
      } else {
        return delete state.cursors[cursor.cid];
      }
    };
    $("#getNearby").click(function() {
      return now.getCloseUsers(function(closeUsers) {
        var cellPoint, user, _i, _len;
        $("#nearby").empty();
        if (closeUsers.length === 0) {
          $("ul#nearby").append(function() {
            return $('<li> <a>Sorry, no one is nearby. </a></li>');
          });
          return false;
        }
        cellPoint = cellKeyToXY(state.selectedCell.key);
        for (_i = 0, _len = closeUsers.length; _i < _len; _i++) {
          user = closeUsers[_i];
          user.radians = Math.atan2(cellPoint.y - user.cursor.y, cellPoint.x - user.cursor.x);
          user.degrees = user.radians * (180 / Math.PI);
          if (user.radians < 0) {
            user.degrees = 360 + user.degrees;
          }
          if (!user.login) {
            user.login = 'Someone';
          }
          $("ul#nearby").append(function() {
            var arrow;
            return arrow = $("<li><a><i class='icon-arrow-left' style='-moz-transform: rotate(" + user.degrees + "deg);-webkit-transform: rotate(" + user.degrees + "deg);'></i> " + user.login + "</a></li>");
          });
        }
        return true;
      });
    });
    now.drawRite = function(commandType, rite, cellPoint, cellProps) {
      var c;
      c = Cell.get(cellPoint.x, cellPoint.y);
      return c[commandType](rite, cellProps);
    };
    return now.insertMessage = function(heading, message, cssclass) {
      return insertMessage(heading, message, cssclass);
    };
  };

  window.insertMessage = function(heading, message, cssclass, timing) {
    var html;
    if (cssclass == null) {
      cssclass = "";
    }
    if (timing == null) {
      timing = 6;
    }
    html = "<div class='alert alert-block fade  " + cssclass + " '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>" + heading + "</h4>" + message + "</div>";
    if (timing > 0) {
      return $("#messages").append(html).children().doTimeout(100, 'addClass', 'in').doTimeout(timing * 1000, function() {
        return $(this).removeClass('in').doTimeout(300, function() {
          return $(this).alert('close').remove();
        });
      });
    } else {
      return $("#messages").append(html).children().doTimeout(100, 'addClass', 'in');
    }
  };

  window.clearMessages = function() {
    $("#messages").children().removeClass('in').doTimeout(300, function() {
      return $(this).alert('close').remove();
    });
    return true;
  };

  $().alert();

  window.Cell = Cell = (function() {
    var all;

    Cell.name = 'Cell';

    all = {};

    Cell.all = function() {
      return all;
    };

    Cell.get = function(x, y) {
      return all["c" + x + "x" + y];
    };

    Cell.killAll = function() {
      return all = {};
    };

    Cell.count = function() {
      var c, i;
      i = 0;
      for (c in all) {
        i++;
      }
      return i;
    };

    Cell.prototype.generateKey = function() {
      this.x = this.tile._tilePoint.x * Math.pow(2, state.zoomDiff()) + this.col;
      this.y = this.tile._tilePoint.y * Math.pow(2, state.zoomDiff()) + this.row;
      return "c" + this.x + "x" + this.y;
    };

    function Cell(row, col, tile, contents, props, events) {
      var $span;
      this.row = row;
      this.col = col;
      this.tile = tile;
      this.contents = contents != null ? contents : config.defaultChar();
      this.props = props != null ? props : {};
      this.events = events != null ? events : null;
      this.key = this.generateKey();
      all[this.key] = this;
      this.span = document.createElement('span');
      this.span.innerHTML = this.contents;
      this.span.id = this.key;
      $(this.span).addClass('cell');
      if (!this.props.color) {
        this.props.color = 'c0';
      }
      $(this.span).addClass(this.props.color);
      if (this.props.echoes) {
        $(this.span).addClass("e" + this.props.echoes);
      }
      this.watch("contents", function(id, oldval, newval) {
        this.span.innerHTML = newval;
        return newval;
      });
      $span = $(this.span);
      this.props.watch("echoes", function(id, oldval, newval) {
        $span.removeClass('e' + oldval);
        $span.addClass('e' + newval);
        return newval;
      });
      this.props.watch("color", function(id, oldval, newval) {
        $span.removeClass(oldval);
        $span.addClass(newval);
        return newval;
      });
    }

    Cell.prototype.write = function(c) {
      var cellPoint;
      cellPoint = cellKeyToXY(this.key);
      return now.writeCell(cellPoint, c);
    };

    Cell.prototype.normalRite = function(rite) {
      this.contents = rite.contents;
      return this.props.color = rite.props.color;
    };

    Cell.prototype.echo = function(rite, cellProps) {
      this.props.echoes = cellProps.echoes;
      this.animateText(1);
      return this.props.color = cellProps.color;
    };

    Cell.prototype.overrite = function(rite, cellProps) {
      this.animateTextRemove(1);
      this.contents = rite.contents;
      this.props.echoes = 0;
      return this.props.color = rite.props.color;
    };

    Cell.prototype.downrote = function(rite, cellProps) {
      $(this.span).removeClass('e' + this.props.echoes);
      this.props.echoes -= 1;
      this.props.color = cellProps.color;
      return shakeWindow(1);
    };

    Cell.prototype.kill = function() {
      this.span = null;
      return delete all[this.key];
    };

    Cell.prototype.clear = function() {
      return this.write(config.defaultChar());
    };

    Cell.prototype.animateTextInsert = function(animateWith, c) {
      var clone, offset, span;
      if (animateWith == null) {
        animateWith = 0;
      }
      if (!prefs.animate.writing) {
        this.span.innerHTML = c;
        return;
      }
      clone = document.createElement('SPAN');
      clone.className = 'cell ' + state.color;
      clone.innerHTML = c;
      span = this.span;
      $(clone).css('position', 'absolute').insertBefore('body').addClass('ai' + animateWith);
      offset = $(this.span).offset();
      $(clone).css({
        'opacity': '1 !important',
        'font-size': '1em'
      });
      $(clone).css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      });
      return $(clone).doTimeout(200, function() {
        span.innerHTML = c;
        $(clone).remove();
        return false;
      });
    };

    Cell.prototype.animateText = function(animateWith) {
      var clone, offset, span;
      if (animateWith == null) {
        animateWith = 0;
      }
      span = this.span;
      clone = $(this.span).clone();
      offset = $(this.span).position();
      $(this.span).after(clone);
      $(clone).removeClass('selected');
      $(clone).addClass('aa').css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      }).hide();
      $(clone).queue(function() {
        $(this).show().css({
          'fontSize': '+=90',
          'marginTop': "-=45",
          'marginLeft': "-=45"
        });
        return $(this).dequeue();
      });
      return $(clone).doTimeout(400, function() {
        $(this).css({
          'fontSize': '-=90',
          'marginTop': 0,
          'marginLeft': 0
        });
        this.doTimeout(400, function() {
          $(span).show();
          return $(clone).remove();
        });
        return false;
      });
    };

    Cell.prototype.animateTextRemove = function(animateWith) {
      var clone, offset, span;
      if (animateWith == null) {
        animateWith = 0;
      }
      span = this.span;
      clone = $(this.span).clone();
      this.span.innerHTML = config.defaultChar();
      offset = $(this.span).position();
      $(this.span).after(clone);
      $(clone).removeClass('selected');
      $(clone).css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      }).hide();
      $(clone).queue(function() {
        $(this).show();
        if (animateWith) {
          $(this).addClass('ar' + animateWith);
        }
        return $(this).dequeue();
      });
      return $(clone).doTimeout(800, function() {
        $(clone).remove();
        return false;
      });
    };

    Cell.getOrCreate = function(row, col, tile, contents, props) {
      var cell, x, y;
      if (contents == null) {
        contents = null;
      }
      if (props == null) {
        props = {};
      }
      x = tile._tilePoint.x * Math.pow(2, state.zoomDiff()) + col;
      y = tile._tilePoint.y * Math.pow(2, state.zoomDiff()) + row;
      cell = Cell.get(x, y);
      if (cell) {
        return cell;
      } else {
        cell = new Cell(row, col, tile, contents, props);
        return cell;
      }
    };

    return Cell;

  })();

  removeLayerThenZoomOut = function() {
    var $layer, layer;
    Cell.killAll();
    layer = map._layers[state.topLayerStamp];
    $layer = $(".layer-" + state.topLayerStamp);
    $layer.fadeOut('slow');
    if (state.topLayerStamp) {
      map.removeLayer(layer);
    }
    state.topLayerStamp = 0;
    now.setCurrentWorld(null);
    map.zoomOut();
  };

  removeLayerThenZoomAndReplace = function() {
    var $layer, canvasTiles, layer, stamp;
    Cell.killAll();
    layer = map._layers[state.topLayerStamp];
    $layer = $(".layer-" + state.topLayerStamp);
    $layer.fadeOut('slow');
    if (state.topLayerStamp) {
      map.removeLayer(layer);
    }
    map.zoomOut();
    canvasTiles = new L.TileLayer.Canvas({
      tileSize: {
        x: 192,
        y: 256
      }
    });
    canvasTiles.drawTile = function(canvas, tilePoint, zoom) {
      var absTilePoint, ctx;
      console.log('drawTile');
      absTilePoint = {
        x: tilePoint.x * Math.pow(2, state.zoomDiff()),
        y: tilePoint.y * Math.pow(2, state.zoomDiff())
      };
      ctx = canvas.getContext('2d');
      return now.getZoomedOutTile(absTilePoint, state.numRows(), function(tileData, atp) {
        var density, densityOffset, x, y, _results;
        densityOffset = state.numRows() * state.numRows();
        density = 100 - (tileData.density / densityOffset) * 500;
        if (density <= 1) {
          return;
        }
        ctx.fillStyle = "rgba(095, 145, 125, 1.6 )";
        ctx.font = "" + (state.cellHeight() * 0.9) + "pt Calibri";
        x = 0;
        y = 0;
        _results = [];
        while (!(x >= 192)) {
          y = 0;
          while (!(y >= 256)) {
            ctx.fillText('z', x, y);
            y = y + state.cellHeight();
          }
          _results.push(x = x + state.cellWidth());
        }
        return _results;
      });
    };
    canvasTiles.getTilePointAbsoluteBounds = function() {
      var bounds, nwTilePoint, offset, seTilePoint, tileBounds, tileSize;
      if (this._map) {
        bounds = this._map.getPixelBounds();
        tileSize = this.options.tileSize;
        offset = Math.pow(2, state.zoomDiff());
        nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x) * offset, Math.floor(bounds.min.y / tileSize.y) * offset);
        seTilePoint = new L.Point(Math.ceil(bounds.max.x / tileSize.x) * offset, Math.ceil(bounds.max.y / tileSize.y) * offset);
        tileBounds = new L.Bounds(nwTilePoint, seTilePoint);
        return tileBounds;
      } else {
        return false;
      }
    };
    map.addLayer(canvasTiles);
    state.isTopLayerInteractive = false;
    stamp = L.Util.stamp(canvasTiles);
    now.setBounds(canvasTiles.getTilePointAbsoluteBounds());
    state.topLayerStamp = stamp;
    return true;
  };

  turnOffLayer = function() {
    var $layer, layer;
    Cell.killAll();
    layer = map._layers[state.topLayerStamp];
    $layer = $(".layer-" + state.topLayerStamp);
    $layer.fadeOut('slow');
    $.doTimeout(500, function() {
      if (state.topLayerStamp) {
        map.removeLayer(layer);
      }
      return false;
    });
  };

  turnOnMainLayer = function() {
    var domTiles, stamp;
    Cell.killAll();
    now.setCurrentWorld(mainWorldId, personalWorldId);
    domTiles = new L.DomTileLayer({
      tileSize: config.tileSize()
    });
    map.addLayer(domTiles);
    stamp = L.Util.stamp(domTiles);
    state.topLayerStamp = stamp;
    now.setBounds(domTiles.getTilePointAbsoluteBounds());
    inputEl.focus();
    return centerCursor();
  };

  switchToLayer = function(worldId) {
    var domTiles;
    Cell.killAll();
    if (state.topLayerStamp) {
      map.removeLayer(getLayer(state.topLayerStamp));
    }
    now.setCurrentWorld(worldId);
    domTiles = new L.DomTileLayer({
      tileSize: config.tileSize()
    });
    map.addLayer(domTiles);
    state.topLayerStamp = L.Util.stamp(domTiles);
    now.setBounds(domTiles.getTilePointAbsoluteBounds());
    inputEl.focus();
    return centerCursor();
  };

  getLayer = function(stamp) {
    return map._layers[stamp];
  };

  window.shakeWindow = function(s) {
    var b, options;
    if (s == null) {
      s = 1;
    }
    b = $('body');
    options = {
      x: 2 + s / 2,
      y: 2 + s / 2,
      rotation: s / 2,
      speed: 18 - s * 3
    };
    b.jrumble(options);
    b.trigger('startRumble');
    b.doTimeout(500, function() {
      b.trigger('stopRumble');
      return false;
    });
    return true;
  };

  pan = function(x, y) {
    var p;
    p = new L.Point(x, y);
    map.panBy(p);
    return map;
  };

  cellKeyToXY = function(key) {
    var target, _ref;
    target = {};
    _ref = key.slice(1).split('x'), target.x = _ref[0], target.y = _ref[1];
    target.x = parseInt(target.x, 10);
    target.y = parseInt(target.y, 10);
    return target;
  };

  window.cellXYToKey = function(target) {
    return "c" + target.x + "x" + target.y;
  };

  filter = function(list, func) {
    var x, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = list.length; _i < _len; _i++) {
      x = list[_i];
      if (func(x)) {
        _results.push(x);
      }
    }
    return _results;
  };

  Array.prototype.remove = function(e) {
    var t, _ref;
    if ((t = this.indexOf(e)) > -1) {
      return ([].splice.apply(this, [t, t - t + 1].concat(_ref = [])), _ref);
    }
  };

  getNodeIndex = function(node) {
    return $(node).parent().children().index(node);
  };

  window.dbg = function() {
    var message, more;
    message = arguments[0], more = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    if (DEBUG) {
      console.log(message);
      return true;
    }
    if (DEBUG && more) {
      console.log(message, more);
      return true;
    }
    return true;
  };

}).call(this);
