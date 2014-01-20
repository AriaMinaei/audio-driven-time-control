wn = require 'when'

module.exports = class ChunkDataBySampleRate

	constructor: (@chunkData, @context) ->

		@from = @chunkData.from

		@duration = @chunkData.duration

		@to = @from + @duration

		@skipInS = @chunkData.skipInS

		@encodedBuffer = @chunkData.encodedBuffer

		@decodedBuffer = new ArrayBuffer 1

		@_isDecoded = no

		@_scheduledToDecode = no

		@_decodeDeferred = wn.defer()

	_setContext: (@context) ->

		@

	isDecoded: ->

		@_isDecoded

	# It'll return an empty buffer if chunk is not already decoded.
	# Make sure to call isDecoded() first, or use decode() to get
	# a promise.
	getDecodedBuffer: ->

		@decodedBuffer

	decode:->

		unless @_scheduledToDecode

			@_scheduledToDecode = yes

			@context.decodeAudioData @encodedBuffer, (@decodedBuffer) =>

				@_isDecoded = yes

				@_decodeDeferred.resolve()

				return

			, (err) =>

				debugger

				@_decodeDeferred.reject "Unable to decode piece"

				return

		@_decodeDeferred.promise