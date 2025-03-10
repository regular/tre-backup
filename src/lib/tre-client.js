const ssbClient = require('ssb-client')
const debug = require('debug')('tre-backup:tre-client')

module.exports = function(remote, manifest, config, cb) {
  debug(`remote: ${remote}`)
  const keys = config.keys || {
    public: 'foobaz',
    private: 'foobaz'
  }
  const conf = {
    remote,
    caps: {shs: config.network ? capsFromNetwork(config.network) : 'foobar'},
    manifest
  }

  ssbClient(keys, conf, (err, ssb) => {
    if (err) return cb(err)
    cb(null, ssb, conf)
  })
}

// --

function capsFromNetwork(n) {
  if (n[0] !== '*') throw new Error('Malformed natwork')
  n = n.slice(1)
  const [caps, postfix] = n.split('.')
  if (Buffer.from(caps, 'base64').length !== 32) throw new Error('Malformed network')
  return caps
}
