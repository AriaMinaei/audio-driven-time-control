ChunkDataForSampleRate = require './chunkData/ChunkDataForSampleRate'

module.exports = class ChunkData

	constructor: (@encodedBuffer, @duration, @from, @skipInS) ->

		@_bySampleRate = {}

	forContext: (context) ->

		unless @_bySampleRate[context.sampleRate]?

			data = new ChunkDataForSampleRate @, context

			@_bySampleRate[context.sampleRate] = data

		@_bySampleRate[context.sampleRate]._setContext context