import 'babel-polyfill'
import 'isomorphic-fetch'
import 'source-map-support/register'

import mongoose from 'mongoose'

import signer from 'prism-signer'
import listener from 'prism-event-listener'
import { Prism as PrismSchema, urls } from 'prism-common'

import setup from './setup'

mongoose.Promise = Promise
mongoose.model('Prism', PrismSchema.obj)

let conn
let prismModel
try {
    conn = mongoose.createConnection(urls.mongo)
    conn.on('error', console.error)
    prismModel = conn.model('Prism', PrismSchema.schema)
} catch (e) {}

setup().then(() => {
    signer()
    listener(prismModel)
}).catch(console.error)
