mp = require 'mp3-parser'
AudioPiece = require '../AudioPiece'

module.exports = class MP3Format

	constructor: (@buffer) ->

		@data = new DataView @buffer

		@uint8View = new Uint8Array @buffer

	split: (pieceDuration = 10.0) ->

		firstFrame = @_findFirstFrame()

		pieces = []

		samplesPerFrame = firstFrame._section.sampleLength

		# console.log 'samples per frame', samplesPerFrame

		# console.log firstFrame

		# console.log 'sampling rate', firstFrame.header.samplingRate

		currentStartIndex = firstFrame._section.offset

		currentByteLength = 0

		currentDuration = 0

		currentStartTime = 0

		frame = firstFrame

		i = 0

		loop

			i++

			next =  mp.readFrame @data, frame._section.nextFrameIndex

			currentByteLength += frame._section.byteLength

			frameDuration = frame._section.sampleLength / frame.header.samplingRate

			# if i is 9

			# 	console.log 'frame duration of', i, frameDuration

			currentDuration += frameDuration

			if currentDuration >= pieceDuration or not next?

				a = @uint8View.subarray currentStartIndex, currentStartIndex + currentByteLength

				newArray = new Uint8Array currentByteLength

				piece = new AudioPiece newArray.buffer, currentDuration, currentStartTime

				pieces.push piece

				currentStartTime += currentDuration
				currentDuration = 0.0

				currentStartIndex += currentByteLength
				currentByteLength = 0

			break unless next?

			frame = next

		pieces

	_findFirstFrame: ->

		i = 0

		id3v2 = mp.readId3v2Tag @data

		if id3v2?

			i+= id3v2._section.byteLength

		loop

			i++

			break if i > @data.byteLength

			frame = mp.readFrame @data, i

			continue unless frame?

			return frame

		return

	_extractFrames: ->

