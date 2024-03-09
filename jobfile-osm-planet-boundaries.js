import path from 'path'
import { hooks } from '@kalisio/krawler'

// Initialize base job
import job from './jobfile-osm-boundaries.js'
// Avoid clearing DB as we come after main job
delete job.hooks.jobs.before.dropMongoCollection
// Avoid generating continent tasks
delete job.hooks.jobs.before.generateTasks
job.hooks.tasks.after = hooks.insertHookAfter('clearData', job.hooks.tasks.after, 'mbtiles', {
  hook: 'runCommand',
  command: `tippecanoe -o osm-boundaries.mbtiles -Llevel2:<(cat 2/*-boundaries.geojson) -Llevel3:<(cat 3/*-boundaries.geojson) -Llevel4:<(cat 4/*-boundaries.geojson)
            -Llevel5:<(cat 5/*-boundaries.geojson) -Llevel6:<(cat 6/*-boundaries.geojson) -Llevel7:<(cat 7/*-boundaries.geojson) -Llevel8:<(cat 8/*-boundaries.geojson)
            -Llevel2toponyms:<(cat 2/*-toponyms.geojson) -Llevel3toponyms:<(cat 3/*-toponyms.geojson) -Llevel4toponyms:<(cat 4/*-toponyms.geojson) -Llevel5toponyms:<(cat 5/*-toponyms.geojson)
            -Llevel6toponyms:<(cat 6/*-toponyms.geojson) -Llevel7toponyms:<(cat 7/*-toponyms.geojson) -Llevel8toponyms:<(cat 8/*-toponyms.geojson) -f --no-tile-size-limit`
})
// Set single task
const basename = 'planet'
const level = 2
const id = `osm-boundaries/${basename}.pbf`
const key = `osm-boundaries/${level}/${basename}`
const dir = path.dirname(key)
job.tasks = [{
  id,
  key,
  dir,
  basename,
  level,
  type: 'http',
  // Skip download if file already exists
  overwrite: false,
  options: {
    url: 'https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf'
  }
}]

export default job
