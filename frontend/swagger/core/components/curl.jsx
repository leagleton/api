import React from "react"
import PropTypes from "prop-types"
import curlify from "core/curlify"

export default class Curl extends React.Component {
  static propTypes = {
    request: PropTypes.object.isRequired
  }

  handleFocus(e) {
    e.target.select()
    document.execCommand("copy")
  }

  render() {
    let { request } = this.props
    let curl = curlify(request)

    return (
      <div>
        <h5>Curl</h5>
        <div className="copy-paste">
          <textarea onFocus={this.handleFocus} readOnly="true" className="curl" style={{ whiteSpace: "normal" }} value={curl}></textarea>
        </div>
      </div>
    )
  }

}
