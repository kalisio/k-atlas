import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { sync } from 'glob'
import centroid from '@turf/centroid'
import { utils, hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'

const layerFilter = ['ARRONDISSEMENT', 'CANTON', 'COLLECTIVITE_TERRITORIALE', 'COMMUNE', 'DEPARTEMENT', 'EPCI', 'REGION'] 
const storePath = process.env.STORE_PATH || 'data/IGN/Admin-Express'
const collection = 'admin-express'


// Geoplatform download service URL
const url = 'https://data.geopf.fr/telechargement/download/ADMIN-EXPRESS-COG-CARTO/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03/ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2023-05-03.7z'

let generateTasks = (options) => {
  return async (hook) => {
    //const data = 
    let tasks = []
    const store = await utils.getStoreFromHook(hook,'generateTasks')
    const pattern = path.join(store.path, '**/*.shp')
    const files = sync(pattern)
    files.forEach(file => {
      const layer = path.parse(file).name
      if (layerFilter.includes(layer)) {
        const key = _.replace(path.normalize(file), path.normalize(store.path), 'admin-express')
        let task = {
          id: _.kebabCase(layer),
          key: key.replace('.shp', ''),
          collection: 'admin-express-' + _.kebabCase(layer)
        }
        console.log('<i> processing', layer, key)
        tasks.push(task)  
      } else {
        console.log('<!> skipping', layer)
      }
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
        convertGeojson: {
          hook: 'runCommand',
          command: `mapshaper -i <%= key %>.shp -o format=geojson precision=0.000001 <%= key %>.geojson`
        },
        readJson: {
          key: '<%= key %>.geojson'
        },
        /*writeJson: {
          store: 's3',
          key: path.posix.join(storePath, `<%= collection.replace('admin-express-', '') %>.geojson`)
        },*/
        generateToponyms: {
          hook: 'apply',
          function: (item) => {
            let toponyms = []
            const features = item.data
            _.forEach(features, feature => {
              if (!_.get(feature, 'geometry') || !_.get(feature, 'properties.name')) return
              // If multiple geometry keep the largest one only
              const subfeatures = flatten(feature)
              let toponym
              let largestArea = 0
              _.forEach(subfeatures.features, subfeature => {
                const subfeatureArea = area(subfeature)
                if (subfeatureArea > largestArea) {
                  largestArea = subfeatureArea
                  toponym = centerOfMass(subfeature.geometry)
                  toponym.properties = {
                    name: feature.properties.name
                  }
                  if (_.has(feature, 'properties.name:en')) {
                    _.set(toponym, 'properties.name:en', feature.properties['name:en'])
                  }
                }
              })
              if (toponym) toponyms.push(toponym)
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
