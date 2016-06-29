// Default status, put over current
const default_state={
  catalog: undefined,
  config: undefined,
  catalog_with_config: undefined
}

function fill_catalog(catalog, config){
  if (!catalog || !config)
    return undefined
  let newcatalog = catalog.map( (cat) => {
    let channel_config = config[cat.channel] || {}
    let fields = cat.fields.map( (f) => {
      let conf=channel_config.config || {}
      return $.extend({}, f, {value: conf[f.name]})
    })
    let ret= $.extend({}, cat, {fields: fields, is_active: channel_config.is_active})
    return ret
  })
  return newcatalog
}

export function notifications(state=default_state, action){
  switch(action.type){
    case "UPDATE_NOTIFICATIONS_CATALOG":
      return { catalog_with_config: fill_catalog(action.catalog, state.config), catalog: action.catalog, config: state.config }
      break;
    case "UPDATE_NOTIFICATIONS_CONFIG":
      return { catalog_with_config: fill_catalog(state.catalog, action.config), catalog: status.catalog, config: action.config }
      break;
  }
  return state
}

export default notifications