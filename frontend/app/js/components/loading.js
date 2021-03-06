import React from 'react'

function Loading(props){
  return (
    <div className="ui active inverted dimmer">
      <div className="ui text loader">
        <h1>Loading data</h1>
        {props.children}
      </div>
    </div>
  )
}

export default Loading
