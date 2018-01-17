import React from "react"
import PropTypes from "prop-types"
import ImPropTypes from "react-immutable-proptypes"

export default class Auths extends React.Component {
  static propTypes = {
    system: PropTypes.string,
    definitions: PropTypes.object.isRequired,
    getComponent: PropTypes.func.isRequired,
    authSelectors: PropTypes.object.isRequired,
    authActions: PropTypes.object.isRequired,
    specSelectors: PropTypes.object.isRequired
  }

  constructor(props, context) {
    super(props, context)

    this.state = {}
  }

  onAuthChange = (auth) => {
    let { name } = auth

    this.setState({ [name]: auth })
  }

  submitAuth = (e) => {
    e.preventDefault()

    let { authActions } = this.props

    authActions.authorize(this.state)
  }

  logoutClick = (e) => {
    e.preventDefault()

    let { authActions, definitions } = this.props
    let auths = definitions.map((val, key) => {
      return key
    }).toArray()

    authActions.logout(auths)
  }

  render() {
    let { system, definitions, getComponent, authSelectors, errSelectors } = this.props
    const Oauth2 = getComponent("oauth2", true)
    const Button = getComponent("Button")

    let authorized = authSelectors.authorized()

    let authorizedAuth = definitions.filter((definition, key) => {
      return !!authorized.get(key)
    })

    let oauthDefinitions = definitions.filter(schema => schema.get("type") === "oauth2")

    return (
      <div className="auth-container">
        {
          oauthDefinitions && oauthDefinitions.size ? <div>
            {
              definitions.filter(schema => schema.get("type") === "oauth2")
                .map((schema, name) => {
                  return (<div key={name}>
                    <Oauth2 system={system}
                      authorized={authorized}
                      schema={schema}
                      name={name} />
                  </div>)
                }
                ).toArray()
            }
          </div> : null
        }

      </div>
    )
  }

  static propTypes = {
    errSelectors: PropTypes.object.isRequired,
    getComponent: PropTypes.func.isRequired,
    authSelectors: PropTypes.object.isRequired,
    specSelectors: PropTypes.object.isRequired,
    authActions: PropTypes.object.isRequired,
    definitions: ImPropTypes.iterable.isRequired
  }
}
