import React from 'react'
import Modal from 'app/components/modal'
import Loading from 'app/components/loading'

let EditPerms=React.createClass({
  handleUpdatePermissions(){
    let current = $.makeArray($(this.refs.form)
      .find('input[type=checkbox]:checked'))
      .map( (f) => f.name )
    this.props.onUpdatePermissions(current)
  },
  componentDidMount(){
    let $form=$(this.refs.form)
    $form.form()
    $form.find('.ui.checkbox').checkbox()

    if (!this.props.all_perms)
      this.props.onLoadAllPerms()

  },
  render(){
    let props=this.props
    if (!props.all_perms){
      return (
        <Loading>
        Permission list
        </Loading>
      )
    }


    let perms=[]
    for (let p of props.all_perms){
      let checked=props.group.perms.indexOf(p) >= 0
      perms.push(
        <div key={p} className="field">
          <div className="ui checkbox">
            <input type="checkbox" defaultChecked={checked} name={p}/>
            <label>{p}</label>
          </div>
        </div>
      )
    }

    return (
      <Modal onClose={props.onClose}>
        <div className="header">
          Update perms at {props.group.name}
        </div>
        <div className="content">
          <label>Permissions</label>
          <form ref="form" className="ui form">
              {perms}
          </form>
        </div>
        <div className="actions">
          <div className="ui accept green button" onClick={this.handleUpdatePermissions}>Accept changes</div>
          <div className="ui cancel button" onClick={props.onClose}>Cancel</div>
        </div>
      </Modal>
    )
  }
})

export default EditPerms
