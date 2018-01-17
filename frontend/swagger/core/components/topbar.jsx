import React from "react"
import PropTypes from "prop-types"

export default class Topbar extends React.Component {

  static propTypes = {
    getComponent: PropTypes.func.isRequired
  }

  onClick = () => {
    $('nav').toggleClass('nav-expanded');
  }

  render() {
    let { getComponent } = this.props
    const Link = getComponent("Link")

    return (
      <div className="topbar">
        <div className="wrapper">
          <div className="topbar-wrapper">
            <Link href="/" title="WinMan">
              <img className="logo" src="./img/WinMan.png" alt="WinMan" />
            </Link>
            <nav onClick={this.onClick}>
              <a href="/account">My Account</a>
              <a href="/logout">Log out</a>
            </nav>
          </div>
        </div>
      </div>
    )
  }
}

Topbar.propTypes = {
  getComponent: PropTypes.func.isRequired
}
