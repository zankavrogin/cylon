/*
 * Linux IO DigitalPin
 * cylonjs.com
 *
 * Copyright (c) 2013-2014 The Hybrid Group
 * Licensed under the Apache 2.0 license.
*/

'use strict';

var FS = require('fs');
var EventEmitter = require('events').EventEmitter;
var namespace = require('node-namespace');

// DigitalPin class offers an interface with the Linux GPIO system present in
// single-board computers such as a Raspberry Pi, or a BeagleBone
namespace("Cylon.IO", function() {
  this.DigitalPin = (function(klass) {
    subclass(DigitalPin, klass);

    var GPIO_PATH = "/sys/class/gpio";
    var GPIO_READ = "in";
    var GPIO_WRITE = "out";
    var HIGH = 1;
    var LOW = 0;

    function DigitalPin(opts) {
      this.pinNum = opts.pin;
      this.status = 'low';
      this.ready = false;
      this.mode = opts.mode;
    }

    DigitalPin.prototype.connect = function(mode) {
      var _this = this;
      if (mode == null) {
        mode = null;
      }
      if (this.mode == null) {
        this.mode = mode;
      }
      return FS.exists(this._pinPath(), function(exists) {
        if (exists) {
          return _this._openPin();
        } else {
          return _this._createGPIOPin();
        }
      });
    };

    DigitalPin.prototype.close = function() {
      var _this = this;
      return FS.writeFile(this._unexportPath(), "" + this.pinNum, function(err) {
        return _this._closeCallback(err);
      });
    };

    DigitalPin.prototype.closeSync = function() {
      FS.writeFileSync(this._unexportPath(), "" + this.pinNum);
      return this._closeCallback(false);
    };

    DigitalPin.prototype.digitalWrite = function(value) {
      var _this = this;
      if (this.mode !== 'w') {
        this._setMode('w');
      }
      this.status = value === 1 ? 'high' : 'low';
      FS.writeFile(this._valuePath(), value, function(err) {
        if (err) {
          return _this.emit('error', "Error occurred while writing value " + value + " to pin " + _this.pinNum);
        } else {
          return _this.emit('digitalWrite', value);
        }
      });
      return value;
    };

    // Public: Reads the digial pin's value periodicly on a supplied interval,
    // and emits the result or an error
    //
    // interval - time (in milliseconds) to read from the pin at
    //
    // Returns the defined interval
    DigitalPin.prototype.digitalRead = function(interval) {
      var readData,
        _this = this;
      if (this.mode !== 'r') {
        this._setMode('r');
      }
      readData = null;
      return every(interval, function() {
        return FS.readFile(_this._valuePath(), function(err, data) {
          if (err) {
            return _this.emit('error', "Error occurred while reading from pin " + _this.pinNum);
          } else {
            readData = parseInt(data.toString());
            return _this.emit('digitalRead', readData);
          }
        });
      });
    };

    DigitalPin.prototype.setHigh = function() {
      return this.digitalWrite(1);
    };

    DigitalPin.prototype.setLow = function() {
      return this.digitalWrite(0);
    };

    DigitalPin.prototype.toggle = function() {
      if (this.status === 'low') {
        return this.setHigh();
      } else {
        return this.setLow();
      }
    };

    // Creates the GPIO file to read/write from
    DigitalPin.prototype._createGPIOPin = function() {
      var _this = this;
      return FS.writeFile(this._exportPath(), "" + this.pinNum, function(err) {
        if (err) {
          return _this.emit('error', 'Error while creating pin files');
        } else {
          return _this._openPin();
        }
      });
    };

    DigitalPin.prototype._openPin = function() {
      this._setMode(this.mode, true);
      return this.emit('open');
    };

    DigitalPin.prototype._closeCallback = function(err) {
      if (err) {
        return this.emit('error', 'Error while closing pin files');
      } else {
        return this.emit('close', this.pinNum);
      }
    };

    // Sets the mode for the GPIO pin by writing the correct values to the pin reference files
    DigitalPin.prototype._setMode = function(mode, emitConnect) {
      var _this = this;
      if (emitConnect == null) {
        emitConnect = false;
      }
      this.mode = mode;
      if (mode === 'w') {
        return FS.writeFile(this._directionPath(), GPIO_WRITE, function(err) {
          return _this._setModeCallback(err, emitConnect);
        });
      } else if (mode === 'r') {
        return FS.writeFile(this._directionPath(), GPIO_READ, function(err) {
          return _this._setModeCallback(err, emitConnect);
        });
      }
    };

    DigitalPin.prototype._setModeCallback = function(err, emitConnect) {
      if (err) {
        return this.emit('error', "Setting up pin direction failed");
      } else {
        this.ready = true;
        if (emitConnect) {
          return this.emit('connect', this.mode);
        }
      }
    };

    DigitalPin.prototype._directionPath = function() {
      return "" + (this._pinPath()) + "/direction";
    };

    DigitalPin.prototype._valuePath = function() {
      return "" + (this._pinPath()) + "/value";
    };

    DigitalPin.prototype._pinPath = function() {
      return "" + GPIO_PATH + "/gpio" + this.pinNum;
    };

    DigitalPin.prototype._exportPath = function() {
      return "" + GPIO_PATH + "/export";
    };

    DigitalPin.prototype._unexportPath = function() {
      return "" + GPIO_PATH + "/unexport";
    };

    return DigitalPin;

  })(EventEmitter);
});
