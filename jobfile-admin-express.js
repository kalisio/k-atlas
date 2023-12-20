import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { sync } from 'glob'
import centroid from '@turf/centroid'
import { utils, hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dbUrl = process.env.DB_URL || 'mongodb://127.0.0.1:27017/atlas'
const storePath = process.env.STORE_PATH || 'data/IGN/Admin-Express'

// Geoplatform download service URL
const url = 'https://data.geopf.fr/telechargement/download/ADMIN-EXPRESS-COG-CARTO/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03.7z'

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    
    const store = await utils.getStoreFromHook(hook,'generateTasks')
    const pattern = path.join(store.path, '**/*.geojson')
    const files = sync(pattern)
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

export default {
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
                feature['centroid'] = centroid(feature.geometry).geometry
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
          ordered: false
        },
        writeJson: {
          store: 's3',
          key: path.posix.join(storePath, `<%= collection.replace('admin-express-', '') %>.geojson`)
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
              secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
              endpoint: process.env.S3_ENDPOINT
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
          command: './geoservices.sh ' + url + ' admin-express'
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
