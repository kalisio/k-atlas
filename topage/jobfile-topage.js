import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { sync } from 'glob'
import { utils, hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'
const wantedLayer = 'BassinVersantTopographique'
const collection = 'topage-bassin-versant-topographique'


// Topage download service URL
const url = 'https://services.sandre.eaufrance.fr/telechargement/geo/ETH/BDTopage/2024/BD_Topage_FXX_2024-shp.zip'

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    console.log('<i> Generating Topage tasks')
    const store = await utils.getStoreFromHook(hook,'generateTasks')
    const pattern = path.join(store.path, '**/*shp*')
    const files = sync(pattern)

    console.log('<i> Found', files.length, 'files')
    files.forEach(file => {
      const layer = path.parse(file).name
      if (layer.includes(wantedLayer)) {
        let task = {
          id: _.kebabCase(layer),
          key: path.basename(file),
          collection: collection,  //TODO : check if we can't create multiple collections
        }
        console.log('<i> processing', layer)
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
  id: 'topage',
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
        extractShapefiles: {
          hook: 'runCommand',
          command: `./process-shapefile.sh output topage/archives/<%= key %> >topage/process-shapefile-<%= id %>.log 2>&1`
        },

        readJson: {
          key: 'geojson/<%= key.replace(/-shp\.zip$/, "") %>.geojson',
          store: "output",
        },

        writeMongoCollection: {
          chunkSize: 256,
          collection,
          checkKeys: false,
          ordered : false,
          faultTolerant: true,
        },
        log: {
          hook: 'apply',
          function: (task) => console.log(`<i> Imported ${task.data.features.length} features for layer ${task.id}`)
        },
        clearData: {},
      }
    },
    jobs: {
      before: {
        createStores: [{
          id: 'fs',
          options: {
            path: path.join(__dirname, 'topage')
          }, 
          
        },
        {
          id: 'output',
          type: 'fs',
          options: {
            path: path.join(__dirname, 'output')
          }, 
        }
        ],
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
          ]
        },
        fetchTopage: {
          hook: 'runCommand',
          command: './fetch-topage.sh ' + url + ' topage >topage/fetch-topage.log 2>&1',
        },
        generateTasks: {}
      },
      after: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs']
      },
      error: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs']
      }
    }
  }
}
