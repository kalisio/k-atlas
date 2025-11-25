import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { sync } from 'glob'
import { utils, hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'
const FILTERS = process.env.TOPAGE_LAYERS || ['BassinVersant','BassinHydrographique']


// Topage download service URL
const url = 'https://services.sandre.eaufrance.fr/telechargement/geo/ETH/BDTopage/2025/BD_Topage_FXX_2025-shp.zip'

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
      if (FILTERS.some(filter => layer.includes(filter))) {
        let task = {
          id: _.kebabCase(layer).replace(/-fxx-shp$/, ''),
          key: path.basename(file),
          collection: 'bdtopage-' + _.kebabCase(layer).replace(/-fxx-shp$/, ''),
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
  id: 'bdtopage',
  store: 'fs',
  options: {
    workersLimit: 3
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
          command: `./generate-bdtopage-geojson.sh bdtopage-output bdtopage-workdir/archives/<%= key %> >bdtopage-workdir/generate-bdtopage-geojson-<%= id %>.log 2>&1`
        },
        readJson: {
          key: 'geojson/<%= key.replace(/-shp\.zip$/, "") %>.geojson',
          store: "output",
        },

        createMongoCollection: {
          collection : "bdtopage-<%= _.kebabCase(id) %>",
          indices: [
            { geometry: '2dsphere' },
          ]
        },

        writeMongoCollection: {
          chunkSize: 256,
          collection : "bdtopage-<%= _.kebabCase(id) %>",
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
            path: path.join(__dirname, 'bdtopage-workdir')
          }, 
          
        },
        {
          id: 'output',
          type: 'fs',
          options: {
            path: path.join(__dirname, 'bdtopage-output')
          }, 
        }
        ],
        connectMongo: {
          url: dbUrl,
          clientPath: 'taskTemplate.client'
        },

        fetchTopage: {
          hook: 'runCommand',
          command: './fetch-bdtopage.sh ' + url + ' bdtopage-workdir >bdtopage-workdir/fetch-bdtopage.log 2>&1',
        },
        generateTasks: {}
      },
      after: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['fs'],
        deteleWorkdir: {
          hook: 'runCommand',
          command: 'rm -r ' + path.join(__dirname, 'bdtopage-workdir')
        }
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
