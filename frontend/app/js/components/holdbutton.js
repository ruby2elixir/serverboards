import React from 'react'

require('sass/holdbutton.sass')

// Tweaks for speed, first milliseconds per tick
let hold_speed=100
// Second increment on each tick. At 100 it sends onClick.
let hold_speed2=5

let ProgressBar=function(props){
  return (
    <div className="ui bottom attached progress">
      <div className="bar" style={{width: `${props.fill}%`}}/>
    </div>
  )
}

let HoldButton = React.createClass({
  getInitialState(){
    return {
      count: 0
    }
  },
  handleClick(){
    this.props.onHoldClick && this.props.onHoldClick()
  },
  componentDidMount(){
    let $button=$(this.refs.button)
    $button
      .on('mousedown', this.startHold)
      .on('mouseup', this.stopHold)
      .on('mouseleave', this.stopHold)

    $button.find('.trash.icon').popup({
      position: "bottom left",
      on: 'click'
    })

  },
  startHold : function(ev){
    if (this.timer)
      return
    if (ev.which==1)
      this.timer=setTimeout(this.countHold, hold_speed)
  },
  countHold(){
    if (this.state.count>=100){
      this.stopHold()
      this.handleClick()
    }
    else{
      this.setState({count: this.state.count+hold_speed2})
      this.timer=setTimeout(this.countHold, hold_speed)
    }
  },
  stopHold(){
    this.setState({count: 0})
    clearTimeout(this.timer)
    this.timer=undefined
  },
  render(){
    if (this.props.className.includes("item"))
      return (
        <div ref="button" className={`hold ${this.props.className}`}>
          {this.props.children}
          <ProgressBar fill={this.state.count}/>
        </div>
      )
    if (this.props.className.includes("icon"))
    return (
      <a ref="button" className="hold icon">
        <i className={this.props.className}  {...this.props}/>
        {this.props.children}
        <ProgressBar fill={this.state.count}/>
      </a>
    )

    return (
      <div className="hold button">
        <button ref="button" className={this.props.className} type={this.props.type}>
          {this.props.children}
        </button>
        <ProgressBar fill={this.state.count}/>
      </div>
    )
  }
})

export default HoldButton
