
const _ = require('lodash')
const path = require('path')
const glob = require('glob')
const krawler = require('@kalisio/krawler')
const getStoreFromHook = krawler.utils.getStoreFromHook
const hooks = krawler.hooks

const dbUrl = process.env.DB_URL || 'mongodb://127.0.0.1:27017/atlas'

const archive = 'ADMIN-EXPRESS_2-2__SHP__FRA_WM_2020-02-24.7z.001'

let generateTasks = (options) => {
  return async (hook) => {
    let tasks = []
    
    const store = await getStoreFromHook(hook,'generateTasks')
    const pattern = path.join(store.path, '**/*.geojson')
    const files = glob.sync(pattern)
    files.forEach(file => {
      const key = _.replace(path.normalize(file), path.normalize(store.path), '.')
      let task = {
        id: 'france-' + _.kebabCase(path.parse(file).name),
        key: key
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
        dropMongoCollection: {
          collection: '<%= id %>'
        },
        createMongoCollection: {
          collection: '<%= id %>',
          indices: [
            { geometry: '2dsphere' }
          ]
        },
        writeMongoCollection: {
          chunkSize: 256,
          collection: '<%= id %>',
        },
        clearData: {}
      }
    },
    jobs: {
      before: {
        createStores: [{
          id: 'memory'
        }, {
          id: 'fs',
          options: {
            path: path.join(__dirname, 'admin-express')
          }
        }],
        connectMongo: {
          url: dbUrl,
          // Required so that client is forwarded from job to tasks
          clientPath: 'taskTemplate.client'
        },
        runCommand: {
          command: './admin-express.sh ' + archive
        },
        generateTasks: {}
      },
      after: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['memory', 'fs']
      },
      error: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['memory', 'fs']
      }
    }
  }
}
