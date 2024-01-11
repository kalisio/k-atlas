import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import centerOfMass from '@turf/center-of-mass'
import { hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const storePath = process.env.STORE_PATH || 'data/OSM'
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'

const baseUrl = 'https://download.geofabrik.de'
const regions = process.env.REGIONS || 'europe/france'
const fabrikSuffix = '-latest.osm.pbf'
const minLevel = process.env.MIN_LEVEL || 2
const maxLevel = process.env.MAX_LEVEL || 6
const collection = 'osm-boundaries'

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    for (let level = minLevel; level <= maxLevel; level++) {
      _.forEach(regions.split(';'), region => {
        const basename = path.basename(region)
        const id = `osm-boundaries/${basename}.pbf`
        const key = `osm-boundaries/${level}/${basename}`
        const dir = path.dirname(key)
        let task = {
          id,
          key,
          dir,
          basename,
          level,
          type: 'http',
          // Skip download if file already exists
          overwrite: false,
          options: {
            url: `${baseUrl}/${region}${fabrikSuffix}`
          }
        }
        console.log(`<i> creating task for ${task.key} at level ${level} [${task.options.url}]`)
        tasks.push(task)  
      })
    }
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
        filterAdministrative: {
          hook: 'runCommand',
          command: `osmium tags-filter <%= id %> /boundary=administrative -t --overwrite --output <%= id.replace('.pbf', '-administrative.pbf') %>`
        },
        createLevelFolder: {
          hook: 'runCommand',
          command: `mkdir -p <%= dir %>`
        },
        filterLevel: {
          hook: 'runCommand',
          command: `osmium tags-filter <%= id.replace('.pbf', '-administrative.pbf') %> /admin_level=<%= level %> -t --overwrite --output <%= key %>.pbf`
        },
        filterName: {
          hook: 'runCommand',
          command: `osmium tags-filter <%= key %>.pbf name -t --overwrite --output <%= key %>-name.pbf`
        },
        extract: {
          hook: 'runCommand',
          command: `osmium export -f json <%= key %>-name.pbf --geometry-types=polygon --overwrite -o <%= key %>-boundaries.geojson`
        },
        readJson: {
          key: `<%= key %>-boundaries.geojson`
        },
        generateToponyms: {
          hook: 'apply',
          function: (item) => {
            let toponyms = []
            _.forEach(item.data.features, feature => {
              const toponym = centerOfMass(feature.geometry)
              toponym.properties = feature.properties
              toponyms.push(toponym)
            })
            item.toponyms = {
              type: 'FeatureCollection',
              features: toponyms
            }
          }
        },
        writeToponyms: {
          hook: 'writeJson',
          dataPath: 'data.toponyms',
          key: `<%= key %>-toponyms.geojson`
        },
        writeMongoCollection: {
          chunkSize: 256,
          collection,
          checkKeys: false
        },
        /*copyToStore: {
          input: { key: `<%= key %>.geojson`, store: 'fs' },
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
        connectMongo: {
          url: dbUrl,
          // Required so that client is forwarded from job to tasks
          clientPath: 'taskTemplate.client'
        },
        dropMongoCollection: {
          collection,
          clientPath: 'taskTemplate.client'
        },
        createMongoCollection: {
          collection,
          clientPath: 'taskTemplate.client',
          indices: [
            { geometry: '2dsphere' }
          ]
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
