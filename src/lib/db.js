const {join} = require('path')

const OffsetLog = require('flumelog-offset')
const offsetCodecs = require('flumelog-offset/frame/offset-codecs')
const codec = require('flumecodec')
const Flume = require('flumedb')

module.exports = function makeDb(data_dir, opts) {
  opts = opts || {}
  const seqBits = opts.seqBits || 32
  return Flume(OffsetLog(join(data_dir, 'log.offset'), {
    codec: codec.json,
    offsetCodec: offsetCodecs[seqBits]
  }))
}

