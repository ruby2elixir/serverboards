import React from 'react';
import UserMenuView from '../../components/top/usermenu'
import { logout } from '../../actions/auth'
import { connect } from 'react-redux'

var UserMenu = connect(
  (state) => ({
    user : state.auth.user
  }),
  (dispatch) => ({
    onLogout: (params) => dispatch(logout())
  })
)(UserMenuView)

export default UserMenu
