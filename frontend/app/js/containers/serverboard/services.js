import ServicesView from 'app/components/serverboard/services'
import event from 'app/utils/event'
import { serverboard_reload_services, serverboard_attach_service } from 'app/actions/serverboard'
import { service_add, services_update_catalog } from 'app/actions/service'

var Services = event.subscribe_connect(
  (state) => ({
    services: state.serverboard.current_services,
    location: state.routing.locationBeforeTransitions,
    service_catalog: state.serverboard.catalog || []
  }),
  (dispatch) => ({
    onAttachService: (a,b) => dispatch( serverboard_attach_service(a,b) ),
    onAddService: (a,b) => dispatch( service_add(a,b) ),
  }),
  ["service.updated","serverboards.updated"],
  (props) => [() => (serverboard_reload_services(props.serverboard.shortname)), services_update_catalog]
)(ServicesView)

export default Services
