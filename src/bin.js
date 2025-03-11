#!/usr/bin/node
require('./extra-modules-path')

const fs = require('fs')
const {join} = require('path')
const pull = require('pull-stream')
const defer = require('pull-defer')
const {DateTime} = require('luxon')

const sdNotify = require('sd-notify-lite')
//const journal = new (require('systemd-journald'))({syslog_identifier: 'tre-server'})

const client = require('./lib/tre-client')
const Retry = require('./lib/retry')
const DB = require('./lib/db')

const config = require('rc')('tre-backup')
const debug = require('debug')('tre-backup:bin')
debug('parsed command line arguments: %O', Object.assign({}, config, {keys: {}}))

if (!config.remote) {
  console.error('Please specofy --remote')
  process.exit(1)
}

if (!config.path) {
  console.error('Please specofy --path')
  process.exit(1)
}

if (!config.keys) {
  console.error('Please specofy --keys')
  process.exit(1)
}

if (!config.network) {
  console.error('Please specofy --network')
  process.exit(1)
}

const db = DB(config.path, {seqBits: 32})

let latestReported = null
function getLatest() {
  return new Promise( (resolve, reject)=>{
    pull(
      db.stream({reverse: true, limit: 1}),
      pull.collect( (err, data)=>{
        if (err) return reject(err)
        if (data.length == 0) return resolve(-1)
        const {seq, value} = data[0]
        if (seq !== latestReported) {
          latestReported = seq
          console.log(`Backup is at seq ${seq} (${DateTime.fromMillis(value.timestamp).toString()})`)
          debug('%O', value)
        }
        resolve(seq)
      })
    )
  })
}

function myClient(cb) {
  client(config.remote, {createRawLogStream: 'source'}, config, cb)
}

function main() {

  function source(ssb) {
    const ret = defer.source()
    getLatest().then(latest=>{
      debug('latest: %s', latest)
      ret.resolve(ssb.createRawLogStream({live: true, gt: latest}))
    }).catch(err=>{
      ret.resolve(pull.error(err))
    })
    return ret
  }

  pull(
    Retry(myClient, source),
    pull.filter(data=>{
      if (data.sync) return false
      return true
    }),
    pull.asyncMap( (data, cb) =>{
      //console.log(data)
      delete data.value.rts
      const {seq, value} = data
      db.append(value, (err, newSeq)=>{
        if (err) return cb(err)
        if (seq !== newSeq) return cb(new Error(`seqs differ. remote: ${seq}, local: ${newSeq}`))
        return cb(null, seq)
      })
    }),
    pull.drain(seq=>{
      //console.log(seq)
    }, err=>{
      if (err) {
        console.error(err.message)
        debug(err.stack)
        process.exit(1)
      }
    })
  )
}

main()
