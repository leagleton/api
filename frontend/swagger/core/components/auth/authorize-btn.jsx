import React from "react"
import PropTypes from "prop-types"

export default class AuthorizeBtn extends React.Component {
  static propTypes = {
    className: PropTypes.string
  }

  componentDidMount() {
    $('.auth-wrapper button').on('click', function (e) {
      $.ajax({
        method: "GET",
        url: "userWebsites",
        cache: false
      })
        .done(function (results) {
          let websitesSelect = '';

          const dbWebsites = results.map((result) => {
            return new Promise((resolve) => {
              websitesSelect += '<option value="' + result.EcommerceWebsite + '">' + result.EcommerceWebsiteId + '</option>';
              resolve();
            });
          });

          Promise.all(dbWebsites).then(() => {
            $(websitesSelect).appendTo('#website');
          });
        });
    });
  }

  onClick = () => {
    let { authActions, authSelectors } = this.props
    let definitions = authSelectors.definitionsToAuthorize()

    authActions.showDefinitions(definitions)
  }

  render() {
    let { system, authSelectors, getComponent } = this.props
    //must be moved out of button component
    const AuthorizationPopup = getComponent("authorizationPopup", true)
    let showPopup = !!authSelectors.shownDefinitions()
    let isAuthorized = !!authSelectors.authorized().size

    return (
      <div className="auth-wrapper">
        <button className={isAuthorized ? "btn btn-success locked" : "btn btn-success unlocked"} onClick={this.onClick}>
          Authorise
          <svg width="20" height="20">
            <use xlinkHref={isAuthorized ? "#locked" : "#unlocked"} />
          </svg>
        </button>
        {showPopup && <AuthorizationPopup system={system} />}
      </div>
    )
  }


  static propTypes = {
    system: PropTypes.string,
    getComponent: PropTypes.func.isRequired,
    authSelectors: PropTypes.object.isRequired,
    errActions: PropTypes.object.isRequired,
    authActions: PropTypes.object.isRequired,
  }
}
