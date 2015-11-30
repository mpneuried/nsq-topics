utils = require( "./utils" )

genTopic = ->
	return utils.randomString( 5, 0 )
	
topics = []
for idx in [ 0..3 ]
	topics.push genTopic()

_data = [
	 utils.clone( ( topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics.push( genTopic() ); topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics.push( genTopic() ); topics ) ),
	 utils.clone( ( topics.splice(0,1); topics ) ),
	 utils.clone( ( topics.splice(0,2); topics ) ),
	 utils.clone( ( topics.splice(0,2); topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics.push( genTopic() ); topics.splice(0,2); topics ) ),
	 utils.clone( ( topics.push( "_" + genTopic() ); topics.push( genTopic() + "_" ); topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics.push( genTopic() ); topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics ) ),
	 utils.clone( ( topics.push( genTopic() ); topics ) )
]
_len = _data.length

idx = 0
_current = ->
	if idx >= _len
		return _data[ _len - 1 ]
	return _data[ idx ]
	
fn = ->
	_resp =
		"status_code": 200
		"status_txt": "OK"
		"data":
			"topics": _current()
	return _resp
	
	
fn.next = ->
	idx++
	return @

fn.len = ->
	return _current().length
	

fn.list = ->
	return _current()
	
module.exports = fn
