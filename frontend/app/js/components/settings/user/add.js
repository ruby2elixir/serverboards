import React from 'react'
import Modal from 'app/components/modal'

let AddUser = React.createClass({
  handleAddUser : function(ev){
    ev.preventDefault()

    let $form = $(this.refs.form)
    this.props.onSubmit( {
      email: $form.find('[name=email]').val(),
      name: $form.find('[name=name]').val(),
      is_active: true,
    } )
  },
  componentDidMount(){
    $(this.refs.form).form({
      on:'blur',
      fields:{
        email: 'email'
      }
    })
  },
  render(){
    let props=this.props

    return (
      <Modal onClose={props.onClose}>
        <h2 className="ui header">
          Add a new user
        </h2>
        <div className="content">
          <form ref="form" className="ui form" onSubmit={this.handleAddUser}>
            <div className="field">
              <label>Email</label>
              <input type="email" name="email" placeholder="This will be used as the user identifier"/>
            </div>
            <div className="field">
              <label>First Name</label>
              <input type="text" name="name"/>
            </div>
            <div className="field">
              <div className="ui accept yellow button" onClick={this.handleAddUser}>Add user</div>
            </div>
          </form>
        </div>
      </Modal>
    )
  }
})

export default AddUser
