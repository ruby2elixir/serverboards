import React from 'react'
import {MarkdownPreview} from 'react-marked-markdown';
import Loading from 'app/components/loading'
import Modal from 'app/components/modal'
import rpc from 'app/rpc'
import {colorize} from 'app/utils'
import {pretty_ago} from 'app/utils'

const Notification=React.createClass({
  getInitialState(){
    return {
      notification: undefined
    }
  },
  componentDidMount(){
    this.load_notification(this.props.params.id)
  },
  load_notification(id){
    if (id == undefined)
      return
    this.setState({notification: undefined})
    rpc.call("notifications.details", [id]).then( (n) => {
      this.setState({notification: n})
      if (n.tags.indexOf("unread")>=0 || n.tags.indexOf("new")>=0){
        const tags = n.tags.filter( (t) => (t!="unread" && t!="new") )
        rpc.call("notifications.update", {id: n.id, tags})
      }
    })
  },
  render(){
    if (!this.state.notification)
      return (
        <Loading>Notification</Loading>
      )

    const n=this.state.notification

    return (
      <Modal>
        <div className="ui top secondary menu">
          <div className="right menu">
            <a
              className={`item ${n.last_id ? "" : "disabled"}`}
              title="Last message"
              onClick={() => this.load_notification(n.last_id)}
              ><i className="ui icon chevron left"/></a>
            <a
              className={`item ${n.next_id ? "" : "disabled"}`}
              title="Next message"
              onClick={() => this.load_notification(n.next_id)}
              ><i className="ui icon chevron right"/></a>
          </div>
        </div>
      <div className="ui meta">{pretty_ago(n.inserted_at)}</div>
        <h1 className="ui header" style={{margin: 0}}>{n.subject}</h1>
        <div className="ui labels">
          {n.tags.map( (t) => (
            <span className={`ui tiny plain basic label ${colorize(t)}`}>{t}</span>
          ))}
        </div>
        <div className="ui body">
          <MarkdownPreview value={n.body}/>
        </div>
      </Modal>
    )
  }
})

export default Notification
