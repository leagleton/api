import React from "react"
import PropTypes from "prop-types"
import oauth2Authorize from "core/oauth2-authorize"

const ACCESS_CODE = "accessCode"

export default class Oauth2 extends React.Component {
  static propTypes = {
    system: PropTypes.string,
    name: PropTypes.string,
    authorized: PropTypes.object,
    getComponent: PropTypes.func.isRequired,
    schema: PropTypes.object.isRequired,
    authSelectors: PropTypes.object.isRequired,
    authActions: PropTypes.object.isRequired,
    errSelectors: PropTypes.object.isRequired,
    errActions: PropTypes.object.isRequired,
    getConfigs: PropTypes.any
  }

  constructor(props, context) {
    super(props, context)
    let { system, name, schema, authorized, authSelectors } = this.props
    let auth = authorized && authorized.get(name)
    let authConfigs = authSelectors.getConfigs() || {}
    let username = auth && auth.get("username") || ""
    let clientId = auth && auth.get("clientId") || authConfigs.clientId || ""
    let website = auth && auth.get("website") || authConfigs.website || ""
    let clientSecret = auth && auth.get("clientSecret") || authConfigs.clientSecret || ""
    let passwordType = auth && auth.get("passwordType") || "request-body"

    this.state = {
      appName: authConfigs.appName,
      name: name,
      schema: schema,
      scopes: [],
      clientId: clientId,
      clientSecret: clientSecret,
      website: website,
      username: username,
      password: "",
      passwordType: passwordType,
      system: system,
    }
  }

  authorize = () => {
    let { authActions, errActions, getConfigs, authSelectors } = this.props
    let configs = getConfigs()
    let authConfigs = authSelectors.getConfigs()

    errActions.clear({ authId: name, type: "auth", source: "auth" })
    oauth2Authorize({ auth: this.state, authActions, errActions, configs, authConfigs })
  }

  onScopeChange = (e) => {
    let { target } = e
    let { checked } = target
    let scope = target.dataset.value

    if (checked && this.state.scopes.indexOf(scope) === -1) {
      let newScopes = this.state.scopes.concat([scope])
      this.setState({ scopes: newScopes })
    } else if (!checked && this.state.scopes.indexOf(scope) > -1) {
      this.setState({ scopes: this.state.scopes.filter((val) => val !== scope) })
    }
  }

  onInputChange = (e) => {
    let { target: { dataset: { name }, value } } = e
    let state = {
      [name]: value
    }

    this.setState(state)
  }

  close = () => {
    let { authActions } = this.props

    authActions.showDefinitions(false)
  }

  logout = (e) => {
    e.preventDefault()
    let { authActions, errActions, name } = this.props

    errActions.clear({ authId: name, type: "auth", source: "auth" })
    authActions.logout([name])
  }

  checkAll = () => {
    const checked = document.getElementById("checkall").checked
    const inputs = document.getElementsByClassName("scopebox")
    let scopes = [];

    for (let i = 0; i < inputs.length; i++) {
      if (inputs[i].type === "checkbox") {
        inputs[i].checked = checked

        const scope = inputs[i].getAttribute("data-value")

        if (checked) {
          scopes.push([scope])
        }
      }
    }

    this.setState({ scopes: scopes })
  }

  render() {
    let { schema, getComponent, authSelectors, errSelectors, name } = this.props
    const Input = getComponent("Input")
    const Row = getComponent("Row")
    const Col = getComponent("Col")
    const Button = getComponent("Button")
    const AuthError = getComponent("authError")

    let flow = schema.get("flow")
    let scopes = schema.get("allowedScopes") || schema.get("scopes")
    let authorizedAuth = authSelectors.authorized().get(name)
    let isAuthorized = !!authorizedAuth
    let errors = errSelectors.allErrors().filter(err => err.get("authId") === name)

    return (
      <div>
        <h5>OAuth2.0</h5>
        {isAuthorized && <h6>Authorised</h6>}
        {
          (flow === ACCESS_CODE && isAuthorized) ? null
            : <Row>
              <label htmlFor="website">Website:</label>
              <Col tablet={10} desktop={10}>
                <select id="website"
                  type="text"
                  value={this.state.website}
                  data-name="website"
                  onChange={this.onInputChange}>
                  <option value="0">Please select...</option>
                </select>
              </Col>
            </Row>
        }
        {
          (flow === ACCESS_CODE && isAuthorized) ? null
            : <Row>
              <label htmlFor="client_id">Client ID:</label>
              <Col tablet={10} desktop={10}>
                <input id="client_id"
                  type="text"
                  value={this.state.clientId}
                  data-name="clientId"
                  onChange={this.onInputChange} />
              </Col>
            </Row>
        }
        {
          (flow === ACCESS_CODE && isAuthorized) ? null
            : <Row>
              <label htmlFor="client_secret">Client Secret:</label>
              <Col tablet={10} desktop={10}>
                <input id="client_secret"
                  value={this.state.clientSecret}
                  type="text"
                  data-name="clientSecret"
                  onChange={this.onInputChange} />
              </Col>
            </Row>
        }
        {
          !isAuthorized && scopes && scopes.size ? <div className="scopes">
            <p>Please select the same scopes that you granted the client access to on your account page.</p>
            <Row>
              <div className="checkall checkbox">
                <Input id="checkall"
                  disabled={isAuthorized}
                  type="checkbox"
                  onChange={this.checkAll} />
                <label htmlFor="checkall">
                  <span className="item"></span>
                  <div className="text">
                    <p className="name">Check / Uncheck all</p>
                  </div>
                </label>
              </div>
            </Row>
            <Row><hr /></Row>
            {scopes.map((description, name) => {
              return (
                <Row key={name}>
                  <div className="checkbox">
                    <Input className="scopebox"
                      data-value={name}
                      id={`${name}-checkbox-${this.state.name}`}
                      disabled={isAuthorized}
                      type="checkbox"
                      onChange={this.onScopeChange} />
                    <label htmlFor={`${name}-checkbox-${this.state.name}`}>
                      <span className="item"></span>
                      <div className="text">
                        <p className="name">{name}</p>
                        <p className="description">{description}</p>
                      </div>
                    </label>
                  </div>
                </Row>
              )
            }).toArray()
            }
          </div>
            : null
        }
        {
          errors.valueSeq().map((error, key) => {
            return <AuthError error={error}
              key={key} />
          })
        }
        {
          isAuthorized ?
            <div className="auth-btn-wrapper">
              <Button className="btn btn-default" onClick={this.close}>Close</Button>
            </div>
            : <div className="auth-btn-wrapper">
              <Button className="btn btn-danger" onClick={this.close}>Cancel</Button>
              <Button className="btn btn-success" onClick={this.authorize}>Authorise</Button>
            </div>
        }
      </div>
    )
  }
}
