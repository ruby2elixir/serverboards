import rpc from 'app/rpc'

export function update_process_list(){
  return function(dispatch){
    rpc.call('action.history',[]).then(function(list){
      dispatch({type:"PROCESS_LIST", list})
    })
  }
}

export function update_process(uuid){
  return function(dispatch){
    rpc.call('action.history',[uuid]).then(function(process){
      dispatch({type:"PROCESS_CURRENT", process})
    })
  }
}
