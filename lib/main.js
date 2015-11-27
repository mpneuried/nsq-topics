(function() {
  var NsqTopics, TOPICS, _, async, request,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  async = require("async");

  _ = require("lodash");

  request = require("hyperrequest");

  TOPICS = [];

  NsqTopics = (function(superClass) {
    extend(NsqTopics, superClass);

    NsqTopics.prototype.defaults = function() {
      return this.extend(NsqTopics.__super__.defaults.apply(this, arguments), {
        active: false,
        lookupdHTTPAddresses: ["127.0.0.1:4161", "127.0.0.1:4163"],
        lookupdPollInterval: 5,
        topicFilter: null
      });
    };

    function NsqTopics() {
      this._fetch = bind(this._fetch, this);
      this._prepareUrl = bind(this._prepareUrl, this);
      this.filter = bind(this.filter, this);
      this._checkTopic = bind(this._checkTopic, this);
      this.fetchTopics = bind(this.fetchTopics, this);
      this._list = bind(this._list, this);
      this.defaults = bind(this.defaults, this);
      this.ready = false;
      NsqTopics.__super__.constructor.apply(this, arguments);
      if (!this.config.active) {
        this.warning("nsq topics disabled");
        return;
      }
      this.filter(this.config.topicFilter);
      this.fetchTopics();
      setInterval(this.fetchTopics, this.config.lookupdPollInterval * 1000);
      this.list = this._waitUntil(this._list, "ready");
      return;
    }

    NsqTopics.prototype._list = function(cb) {
      cb(null, TOPICS);
    };

    NsqTopics.prototype.fetchTopics = function() {
      var aFns, host;
      if (_.isString(this.config.lookupdHTTPAddresses)) {
        aFns = [this._fetch(this.config.lookupdHTTPAddresses)];
      } else {
        aFns = (function() {
          var i, len, ref, results;
          ref = this.config.lookupdHTTPAddresses;
          results = [];
          for (i = 0, len = ref.length; i < len; i++) {
            host = ref[i];
            results.push(this._fetch(host));
          }
          return results;
        }).call(this);
      }
      async.parallel(aFns, (function(_this) {
        return function(err, aTopics) {
          var _newTopics, _removedTopics, _rtp, _topics, _tp, _tps, i, j, k, l, len, len1, len2, len3;
          if (err) {
            _this.error("multi fetch", err);
            return;
          }
          _topics = [];
          for (i = 0, len = aTopics.length; i < len; i++) {
            _tps = aTopics[i];
            for (j = 0, len1 = _tps.length; j < len1; j++) {
              _tp = _tps[j];
              if (indexOf.call(_topics, _tp) < 0 && _this._checkTopic(_tp)) {
                _topics.push(_tp);
              }
            }
          }
          if (!_this.ready) {
            TOPICS = _topics;
            _this.ready = true;
            _this.emit("ready", _this.topics);
            return;
          }
          _this.debug("topics", _topics);
          _removedTopics = _.difference(TOPICS, _topics);
          _newTopics = _.difference(_topics, TOPICS);
          if (!_removedTopics.length && !_newTopics.length) {
            _this.debug("no topic change");
            return;
          }
          TOPICS = _topics;
          _this.emit("change", TOPICS);
          for (k = 0, len2 = _newTopics.length; k < len2; k++) {
            _rtp = _newTopics[k];
            _this.emit("add", _rtp);
          }
          for (l = 0, len3 = _removedTopics.length; l < len3; l++) {
            _rtp = _removedTopics[l];
            _this.emit("remove", _removedTopics);
          }
        };
      })(this));
    };

    NsqTopics.prototype._checkTopic = function(testTopic) {
      if (this.topicFilter == null) {
        return true;
      }
      return this.topicFilter(testTopic);
    };

    NsqTopics.prototype.filter = function(filter) {
      var regexp;
      if (filter == null) {
        this.topicFilter = null;
      }
      if (_.isString(filter)) {
        if (filter.slice(0, 7) === "regexp:") {
          regexp = new RegExp(filter.slice(7));
          this.topicFilter = (function(_this) {
            return function(testT) {
              return regexp.test(testT);
            };
          })(this);
        }
        this.topicFilter = (function(_this) {
          return function(testT) {
            return testT === filter;
          };
        })(this);
      }
      if (_.isArray(filter)) {
        this.topicFilter = (function(_this) {
          return function(testT) {
            return indexOf.call(filter, testT) >= 0;
          };
        })(this);
      }
      if (_.isFunction(filter)) {
        this.topicFilter = (function(_this) {
          return function(testT) {
            return filter(testT);
          };
        })(this);
      }
      if (_.isRegExp(filter)) {
        this.topicFilter = (function(_this) {
          return function(testT) {
            return filter.test(testT);
          };
        })(this);
      }
    };

    NsqTopics.prototype._prepareUrl = function(host) {
      return "http://" + host + "/topics";
    };

    NsqTopics.prototype._fetch = function(host) {
      return (function(_this) {
        return function(cb) {
          request({
            url: _this._prepareUrl(host)
          }, function(err, result) {
            var _body, ref;
            if (err) {
              _this.warning("fetch topics", err);
              cb(null, null);
              return;
            }
            if (_.isString(result.body)) {
              _body = JSON.parse(result.body);
            } else {
              _body = result.body;
            }
            if (_body.status_code === 200) {
              cb(null, (_body != null ? (ref = _body.data) != null ? ref.topics : void 0 : void 0) || []);
            }
          });
        };
      })(this);
    };

    return NsqTopics;

  })(require("mpbasic")());

  module.exports = NsqTopics;

}).call(this);
