import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const storePath = process.env.STORE_PATH || 'data/OSM'

const files = ['https://download.geofabrik.de/europe/albania-latest.osm.pbf']

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    files.forEach(file => {
      const id = `osm-boundaries/${path.basename(file)}`
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
    store: 'fs'
  },
  hooks: {
    tasks: {
      after: {
        extractAdministrative: {
          hook: 'runCommand',
          command: `osmium tags-filter <%= id %> /boundary=administrative -t --overwrite --output <%= key %>-administrative.pbf`
        },
        /*copyToStore: {
          input: { key: '<%= key %>.geojson', store: 'fs' },
          output: { key: `${storePath}/<%= key %>.geojson`, store: 's3',
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
        generateTasks: {}
      },
      after: {
        removeStores: ['fs', 's3']
      },
      error: {
        removeStores: ['fs', 's3']
      }
    }
  }
}
