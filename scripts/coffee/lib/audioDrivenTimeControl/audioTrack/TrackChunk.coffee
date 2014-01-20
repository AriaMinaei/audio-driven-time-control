wn = require 'when'

module.exports = class TrackChunk

	constructor: (@audioTrack, data) ->

		@context = @audioTrack.context

		@data = data.forContext @context

		@from = @data.from

		@to = @data.to

		@duration = @data.duration

		@_skipInS = @data.skipInS | 0.0

		@queued = no

		@_currentSource = null

	decode:->

		@data.decode()

	_makeNewSource: ->

		@_currentSource = @context.createBufferSource()

		@_currentSource.buffer = @data.decodedBuffer

		@_currentSource.connect @audioTrack.timeControl.node

		@_currentSource

	_toLocalT: (trackT) ->

		trackT - @from

	queue: (trackT) ->

		if @queued

			throw Error "Chunk '#{@from}' is already queued"

		@queued = yes

		localT = @_toLocalT trackT

		console.log 'queueing', @from

		offset = @_skipInS

		if localT > 0

			offset += localT

		@_makeNewSource().start @context.currentTime - localT, offset

		return

	unqueue: ->

		unless @queued

			throw Error "Chunk '#{@from}' is not queued"

		@queued = no

		@_currentSource.stop 0

		return

	shouldUnqueue: (trackT) ->

		localT = @_toLocalT trackT

		return yes if localT > @duration

		return no