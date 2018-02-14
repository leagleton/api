import React from "react"
import PropTypes from "prop-types"

export default class Footer extends React.Component {
  static propTypes = {
    url: PropTypes.string,
  }

  render() {
    let { url } = this.props

    return (
      <div className="footer">
      </div>
    )
  }
}
