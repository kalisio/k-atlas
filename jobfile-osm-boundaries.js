import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const storePath = process.env.STORE_PATH || 'data/OSM'
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'

const files = ['https://download.geofabrik.de/europe/albania-latest.osm.pbf']
const level = process.env.LEVEL || 2
const collection = 'osm-boundaries'

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    files.forEach(file => {
      const id = `osm-boundaries/${level}/${path.basename(file)}`
      let task = {
        id,
        key: id.replace('-latest.osm.pbf', ''),
        type: 'http',
        options: {
          url: file
        }
      }
      console.log('Creating task for ' + file)
      tasks.push(task)  
    })
    hook.data.tasks = tasks
    return hook
  }
}
hooks.registerHook('generateTasks', generateTasks)

export default {
  id: 'osm-boundaries',
  store: 'fs',
  options: {
    workersLimit: 1
  },
  taskTemplate: {
    store: ''
  },
  hooks: {
    tasks: {
      after: {
        extractAdministrative: {
          hook: 'runCommand',
          command: `osmium tags-filter <%= id %> /boundary=administrative -t --overwrite --output <%= key %>-administrative.pbf`
        },
        filterLevelAdministrative: {
          hook: 'runCommand',
          command: `osmium tags-filter <%= id %> /admin_level=${level} -t --overwrite --output <%= key %>-administrative-${level}.pbf`
        },
        exportGEOjson: {
          hook: 'runCommand',
          command: `osmium export -f json <%= key %>-administrative-${level}.pbf --geometry-types=polygon --overwrite -o <%= key %>-administrative-${level}.geojson`
        },
        readJson: {
          key: `<%= key %>-administrative-${level}.geojson`
        },
        writeMongoCollection: {
          chunkSize: 256,
          collection,
        },
        /*copyToStore: {
          input: { key: `<%= key %>-administrative-${level}.geojson`, store: 'fs' },
          output: { key: `${storePath}/<%= key %>-${level}.geojson`, store: 's3',
            params: { ContentType: 'application/geo+json' }
          }
        },*/
        clearData: {}
      }
    },
    jobs: {
      before: {
        createStores: [{
          id: 'fs',
          options: {
            path: path.join(__dirname)
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
        generateTasks: {}
      },
      after: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs', 's3']
      },
      error: {
        disconnectMocdngo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs', 's3']
      }
    }
  }
}
