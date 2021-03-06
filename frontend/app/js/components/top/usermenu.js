import React from 'react'
import {Link} from 'app/router'

function UserMenu(props){
  return (
    <div className="ui dropdown vertical menu" style={{position: "fixed", right: 0, top: 45}}>
      <a className="item" href="#/user/profile">
          {props.user.name}
        <i className="ui icon right user"></i>
      </a>
      <a className="item" href="#/settings/">
          Settings
        <i className="ui icon right settings"></i>
      </a>
      <a className="item" href="#/logs/">
          Logs
        <i className="ui icon right book"></i>
      </a>
      <a href="#!" className="item" onClick={props.onLogout}>
        Logout
      </a>
    </div>
  )
}

export default UserMenu
