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
			# **active** *Boolean* Configuration to (en/dis)abel the nsq topics
			active: false
			# **lookupdHTTPAddresses** *String|String[]* A single or multiple nsqlookupd hosts.
			lookupdHTTPAddresses: [ "127.0.0.1:4161", "127.0.0.1:4163" ]
			# **lookupdHTTPAddresses** *Number* Time in seconds to poll the nsqlookupd servers to sync the availible topics
			lookupdPollInterval: 5
			# **topicFilter** *Null|String|Array|RegExp|Function* A filter to reduce the returned topics
			topicFilter: null

	constructor: ->
		@ready = false
		
		super
		if not @config.active
			@warning "nsq topics disabled"
			return

		@filter( @config.topicFilter )
		
		@fetchTopics()
		setInterval( @fetchTopics, @config.lookupdPollInterval * 1000 )

		@list = @_waitUntil( @_list, "ready" )
		return

	_list: ( cb )=>
		cb( null, TOPICS )
		return 

	fetchTopics: =>
		if _.isString( @config.lookupdHTTPAddresses )
			aFns = [ @_fetch( @config.lookupdHTTPAddresses ) ]
		else
			aFns = for host in @config.lookupdHTTPAddresses
				@_fetch( host )
		
		async.parallel aFns, ( err, aTopics )=>
			if err
				@error "multi fetch", err
				return

			_topics = []
			for _tps in aTopics
				for _tp in _tps when _tp not in _topics and @_checkTopic( _tp )
					_topics.push( _tp )

			if not @ready
				# initial
				TOPICS = _topics
				@ready = true
				@emit "ready", @topics
				return

			@debug "topics", _topics

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
				@emit( "remove", _removedTopics )

			return
		return

	_checkTopic: ( testTopic )=>
		if not @topicFilter?
			return true

		return @topicFilter( testTopic )

	filter: ( filter )=>
		if not filter?
			# delete teh current filter
			@topicFilter = null
		
		if _.isString( filter )
			# if the string filter starts with "regexp:" interpret it as a regular expression
			if filter[0..6] is "regexp:"
				regexp = new RegExp(filter[7..])
				@topicFilter = ( testT )=>
					return regexp.test( testT )

			@topicFilter = ( testT )=>
				return testT is filter

		if _.isArray( filter )
			@topicFilter = ( testT )=>
				return testT in filter

		if _.isFunction( filter )
			@topicFilter = ( testT )=>
				return filter( testT )

		if _.isRegExp( filter )
			@topicFilter = ( testT )=>
				return filter.test( testT )

		return

	

	_prepareUrl: ( host )=>
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


module.exports = NsqTopics