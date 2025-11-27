import _ from 'lodash'
import path from 'path'
import { fileURLToPath } from 'url'
import { sync } from 'glob'
import { utils, hooks } from '@kalisio/krawler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dbUrl = process.env.DB_URL || 'mongodb://localhost:27017/atlas'

// Layers mapping
const LAYERS = {
  BassinHydrographique_FXX: 'hydrographic-basins',
  BassinVersantTopographique_FXX: 'topographic-watersheds'
}

const FILTERS = Object.keys(LAYERS)

// Topage download service URL
const url = 'https://services.sandre.eaufrance.fr/telechargement/geo/ETH/BDTopage/2025/BD_Topage_FXX_2025-shp.zip'

let generateTasks = () => {
  return async (hook) => {
    console.log('<i> Generating Topage tasks')

    const store = await utils.getStoreFromHook(hook, 'generateTasks')
    const files = sync(path.join(store.path, '**/*shp*')) 

    console.log(`<i> Found ${files.length} files`)

    const tasks = files.flatMap((file) => {
      const layer = path.parse(file).name
      if (!FILTERS.some(filter => layer.includes(filter))) {
        console.log(`<!> Skipping ${layer}`)
        return []
      }

      const baseLayer = layer.replace(/-shp$/, '')
      const outputName = LAYERS[baseLayer] || _.kebabCase(baseLayer)

      console.log(`<i> Processing ${layer} as ${outputName}`)

      return [{
        id: outputName,
        key: path.basename(file),
        collection: 'bdtopage-' + outputName
      }]
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
          command: `./generate-bdtopage-geojson.sh bdtopage-output bdtopage-workdir/archives/<%= key %> bdtopage-output/geojson/<%= id %>.geojson >bdtopage-workdir/generate-<%= id %>.log 2>&1`,
        },
        readJson: {
          key: 'geojson/<%= id %>.geojson',
          store: "output",
        },
        createMongoCollection: {
          collection : "bdtopage-<%= id %>",
          indices: [
            { geometry: '2dsphere' },
          ]
        },
        writeMongoCollection: {
          chunkSize: 256,
          collection : "bdtopage-<%= id %>",
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
