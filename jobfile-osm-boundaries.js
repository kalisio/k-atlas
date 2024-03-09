import _ from 'lodash'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'
import centerOfMass from '@turf/center-of-mass'
import { hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const storePath = process.env.STORE_PATH || 'data/OSM'
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'

const baseUrl = 'https://download.geofabrik.de'
// Process whole world with 'africa;asia;australia-oceania;central-america;europe;north-america;south-america'
const regions = process.env.REGIONS || 'europe/france'
const fabrikSuffix = '-latest.osm.pbf'
// Level 2 = countries, it requires an additional job working with a planet extract not continent extracts
const minLevel = Number(process.env.MIN_LEVEL) || 3
const maxLevel = Number(process.env.MAX_LEVEL) || 8
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
        console.log(`Creating task ${task.key}`)
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
          match: { predicate: (item) => !fs.existsSync(item.id.replace('.pbf', '-administrative.pbf')) },
          command: `osmium tags-filter <%= id %> /boundary=administrative -t --overwrite --output <%= id.replace('.pbf', '-administrative.pbf') %>`
        },
        createLevelFolder: {
          hook: 'runCommand',
          command: `mkdir -p <%= dir %>`
        },
        filterLevel: {
          hook: 'runCommand',
          match: { predicate: (item) => !fs.existsSync(item.key) },
          command: `osmium tags-filter <%= id.replace('.pbf', '-administrative.pbf') %> /admin_level=<%= level %> -t --overwrite --output <%= key %>.pbf`
        },
        extract: {
          hook: 'runCommand',
          command: `osmium export -f jsonseq -x print_record_separator=false <%= key %>.pbf --geometry-types=polygon --overwrite -o <%= key %>-boundaries.geojsonseq`
        },
        filter: {
          hook: 'runCommand',
          command: `cat <%= key %>-boundaries.geojsonseq | grep 'name' | grep 'wikidata' | grep 'admin_level' > <%= key %>-boundaries.geojson && rm -f <%= key %>-boundaries.geojsonseq`
        },
        readGeoJson: {
          hook: 'readSequentialGeoJson',
          key: `<%= key %>-boundaries.geojson`
        },
        generateToponyms: {
          hook: 'apply',
          function: (item) => {
            let toponyms = []
            _.forEach(item.data, feature => {
              let toponym = centerOfMass(feature.geometry)
              toponym.properties = {
                name: feature.properties.name
              }
              if (_.has(feature, 'properties.name:en')) {
                _.set(toponym, 'properties.name:en', feature.properties['name:en'])
              }
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
          checkKeys: false,
          ordered : false,
          faultTolerant: true
        },
        // As we use geojson files to generate mbtiles we need to switch from sequential to standard GeoJSON
        asFeatureCollection: {
          hook: 'runCommand',
          command: `sed -i '$!s/$/,/' <%= key %>-boundaries.geojson && sed -i '1i{ "type": "FeatureCollection", "features": [' <%= key %>-boundaries.geojson && echo ']}' >> <%= key %>-boundaries.geojson`
        },
        /*copyToStore: {
          input: { key: `<%= key %>.geojson`, store: 'fs' },
          output: { key: `${storePath}/<%= key %>.geojson`, store: 's3',
            params: { ContentType: 'application/geo+json' }
          }
        },*/
        clearData: {},
        log: {
          hook: 'apply',
          function: (task) => console.log(`Terminating task ${task.key}`)
        }
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
            { geometry: '2dsphere' },
            { 'properties.admin_level': 1 },
            { geometry: '2dsphere', 'properties.admin_level': 1 },
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
