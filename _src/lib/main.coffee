# # NsqTopics Module
# ### extends [Basic](basic.coffee.html)
#
# Fetch all availibable tocis from the lookup servers and keep them in sync

# **npm modules**
async = require( "async" )
_ = require( "lodash" )

# **internal modules**
request = require( "hyperrequest" )

TOPICS = []

class NsqTopics extends require( "mpbasic" )()


	# ## defaults
	defaults: =>
		@extend super,
			# **lookupdHTTPAddresses** *String|String[]* A single or multiple nsqlookupd hosts.
			lookupdHTTPAddresses: [ "127.0.0.1:4161", "127.0.0.1:4163" ]
			# **lookupdHTTPAddresses** *Number* Time in seconds to poll the nsqlookupd servers to sync the availible topics
			lookupdPollInterval: 60
			# **topicFilter** *Null|String|Array|RegExp|Function* A filter to reduce the returned topics
			topicFilter: null
			# **active** *Boolean* Configuration to (de)activate the nsq topics
			active: true

	constructor: ->
		@ready = false
		
		super
		
		@list = @_waitUntil( @_list, "ready" )
		
		@_start()
		return
	
	_start: =>
		if not @config.active
			@warning "nsq topics disabled"
			return
			
		@filter( @config.topicFilter )
		@fetchTopics()
		@_interval = setInterval( @fetchTopics, @config.lookupdPollInterval * 1000 )
		return
	
	active: =>
		return @config.active
			
	activate: =>
		if @config.active
			return false
		@config.active = true
		clearInterval( @_interval )
		@start()
		return true
	
	deactivate: =>
		if not @config.active
			return false
		@config.active = false
		clearInterval( @_interval )
		return true
	
	_list: ( cb )->
		process.nextTick ->
			cb( null, TOPICS )
			return
		return @

	fetchTopics: =>
		if not @config.active
			@warning "nsq topics disabled"
			return
		
		if _.isString( @config.lookupdHTTPAddresses )
			aFns = [ @_fetch( @config.lookupdHTTPAddresses ) ]
		else
			aFns = for host in @config.lookupdHTTPAddresses
				@_fetch( host )
		
		async.parallel aFns, ( err, results )=>
			if err
				@error "multi fetch", err
				return
				
			aTopics = _.compact( results )
			if not aTopics.length
				_err = @_handleError( true, "EUNAVAILIBLE" )
				
				if @listeners( "error" )?.length
					@emit "error", _err
				else
					throw _err
				return
			
			_topics = []
			for _tps in aTopics when _tps?
				for _tp in _tps when _tp not in _topics and @_checkTopic( _tp )
					_topics.push( _tp )

			if not @ready
				# initial
				TOPICS = _topics
				@ready = true
				@emit "ready", @topics
				return

			@debug "topics", _topics

			@_setTopicList( _topics )

			return
		return
		
	_setTopicList: ( _topics )=>
		_removedTopics = _.difference( TOPICS, _topics )
		_newTopics = _.difference( _topics, TOPICS )
		
		if not _removedTopics.length and not _newTopics.length
			@debug "no topic change"
			return

		TOPICS = _topics

		@emit( "change", TOPICS )
		for _rtp in _newTopics
			@emit( "add", _rtp )
		for _rtp in _removedTopics
			@emit( "remove", _rtp )
		return

	_checkTopic: ( testTopic )=>
		if not @topicFilter?
			return true

		return @topicFilter( testTopic )

	filter: ( filter )=>
		if not filter?
			# delete teh current filter
			@topicFilter = null
		
		else if _.isString( filter )
			# if the string filter starts with "regexp:" interpret it as a regular expression
			if filter[0..6] is "regexp:"
				regexp = new RegExp(filter[7..])
				@topicFilter = ( testT )->
					return regexp.test( testT )

			@topicFilter = ( testT )->
				return testT is filter

		else if _.isArray( filter )
			@topicFilter = ( testT )->
				return testT in filter

		else if _.isFunction( filter )
			@topicFilter = ( testT )->
				return filter( testT )

		else if _.isRegExp( filter )
			@topicFilter = ( testT )->
				return filter.test( testT )
		
		else
			_err = @_handleError( true, "EINVALIDFILTER" )
			@emit "error", _err
			throw _err
			return
		
		# run filter on current list
		_topics = []
		for _tp in TOPICS when @_checkTopic( _tp )
			_topics.push( _tp )
		
		@_setTopicList( _topics )

		return @

	_prepareUrl: ( host )->
		return "http://" + host + "/topics"

	_fetch: ( host )=>
		return ( cb )=>
			request { url: @_prepareUrl( host ) }, ( err, result )=>
				if err
					@warning "fetch topics", err
					cb( null, null )
					return

				if _.isString( result.body )
					_body = JSON.parse( result.body )
				else
					_body = result.body

				if _body.status_code is 200
					cb( null, _body?.data?.topics or [] )
				return
			return
	
	ERRORS: =>
		@extend super,
			"EUNAVAILIBLE": [ 404, "No nsq-lookup servers availible" ]
			"EINVALIDFILTER": [ 500, "Only `null` valiables of type `String`, `Array`, `Function` or `RegExp` are allowed as filter" ]

module.exports = NsqTopics
