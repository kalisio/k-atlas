
const _ = require('lodash')
const path = require('path')
const glob = require('glob')
const turf = require('@turf/turf')
const krawler = require('@kalisio/krawler')
const getStoreFromHook = krawler.utils.getStoreFromHook
const hooks = krawler.hooks

const dbUrl = process.env.DB_URL || 'mongodb://127.0.0.1:27017/atlas'
const s3Path = process.env.S3_PATH || 'data/IGN/Admin-Express'

const archive = 'ADMIN-EXPRESS_2-3__SHP__FRA_WM_2020-03-16.7z.001'
const user = 'Admin_Express_ext'
const passwd = 'Dahnoh0eigheeFok'
const host = 'ftp3.ign.fr'

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    
    const store = await getStoreFromHook(hook,'generateTasks')
    const pattern = path.join(store.path, '**/*.geojson')
    const files = glob.sync(pattern)
    files.forEach(file => {
      const key = _.replace(path.normalize(file), path.normalize(store.path), '.')
      let task = {
        id: _.kebabCase(path.parse(file).name),
        key: key,
        collection: 'admin-express-' + _.kebabCase(path.parse(file).name)
      }
      console.log('creating task for ' + file)
      tasks.push(task)  
    })
    hook.data.tasks = tasks
    return hook
  }
}
hooks.registerHook('generateTasks', generateTasks)

module.exports = {
  id: 'admin-express',
  store: 'fs',
  options: {
    workersLimit: 1
  },
  taskTemplate: {
    type: 'noop',
    store: 'fs'
  },
  hooks: {
    tasks: {
      after: {
        readJson: {
          key: '<%= key %>'
        },
        apply: {
          function: (item) => {
            _.forEach(item.data.features, (feature) => {
              if (feature.geometry !== 'Point') {
                feature['centroid'] = turf.centroid(feature.geometry).geometry
              }
            })
          }
        },
        dropMongoCollection: {
          collection: '<%= collection %>'
        },
        createMongoCollection: {
          collection: '<%= collection %>',
          indices: [
            { geometry: '2dsphere' }
          ]
        },
        writeMongoCollection: {
          chunkSize: 256,
          collection: '<%= collection %>',
        },
        writeJson: {
          store: 's3',
          key: path.posix.join(s3Path, '<%= collection %>.geojson')
        },
        clearData: {}
      }
    },
    jobs: {
      before: {
        createStores: [{
          id: 'fs',
          options: {
            path: path.join(__dirname, 'admin-express')
          }, 
        },
        {
          id: 's3',
          type: 's3',
          options: {
            client: {
              accessKeyId: process.env.S3_ACCESS_KEY,
              secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
            },
            bucket: process.env.S3_BUCKET
          }
        }],
        connectMongo: {
          url: dbUrl,
          // Required so that client is forwarded from job to tasks
          clientPath: 'taskTemplate.client'
        },
        runCommand: {
          command: './geoservices.sh ' + archive + ' ' + host + ' ' + user + ' ' + passwd
        },
        generateTasks: {}
      },
      after: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs', 's3']
      },
      error: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs', 's3']
      }
    }
  }
}
