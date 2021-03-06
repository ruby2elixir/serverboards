import React from 'react'
import { connect } from 'react-redux'
import AddServiceView from 'app/components/serverboard/addservice'
import { services_update_catalog, services_update_all } from 'app/actions/service'

var AddService=connect(
  (state) => {
    return {
      catalog: state.serverboard.catalog,
      all_services: state.serverboard.all_services,
      location: state.routing.locationBeforeTransitions
    }
  },
  (dispatch) => ({
    updateServiceCatalog: () => dispatch( services_update_catalog() ),
    updateAllServiceCatalog: () => dispatch( services_update_all() )
  })
)(AddServiceView)

export default AddService
