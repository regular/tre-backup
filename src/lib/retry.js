const pull = require('pull-stream')

const next = require('pull-next')
const Catch = require('pull-catch')
const defer = require('pull-defer')

module.exports = function(client, source) {
  return pull(
    next( ()=>{
      const deferred = defer.source()
      client( (err, ssb) => {
        if (err) return deferred.resolve(pull.error(err))
        deferred.resolve(
          pull(
            source(ssb),
            Catch()
          )
        )
      })
      return deferred
    })
  )
}
