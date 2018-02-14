import React from "react"
import PropTypes from "prop-types"

export default class BaseLayout extends React.Component {

  static propTypes = {
    errSelectors: PropTypes.object.isRequired,
    errActions: PropTypes.object.isRequired,
    specActions: PropTypes.object.isRequired,
    specSelectors: PropTypes.object.isRequired,
    layoutSelectors: PropTypes.object.isRequired,
    layoutActions: PropTypes.object.isRequired,
    getComponent: PropTypes.func.isRequired
  }

  onFilterChange = (e) => {
    let { target: { value } } = e
    this.props.layoutActions.updateFilter(value)
  }

  render() {
    let { specSelectors, specActions, getComponent, layoutSelectors } = this.props

    let info = specSelectors.info()
    let url = specSelectors.url()
    let basePath = specSelectors.basePath()
    let host = specSelectors.host()
    let mode = specSelectors.mode()
    let system = specSelectors.system()
    let securityDefinitions = specSelectors.securityDefinitions()
    let externalDocs = specSelectors.externalDocs()
    let schemes = specSelectors.schemes()

    let Topbar = getComponent("topBar", true)
    let Info = getComponent("info")
    let Operations = getComponent("operations", true)
    let Models = getComponent("Models", true)
    let Footer = getComponent("footer", true)
    let AuthorizeBtn = getComponent("authorizeBtn", true)
    let OnlineValidatorBadge = getComponent("onlineValidatorBadge", true)
    let Container = getComponent("Container")
    let Row = getComponent("Row")
    let Col = getComponent("Col")
    let Errors = getComponent("errors", true)

    const loadingStatus = specSelectors.loadingStatus()
    let isLoading = specSelectors.loadingStatus() === "loading"
    let isFailed = specSelectors.loadingStatus() === "failed"
    let filter = layoutSelectors.currentFilter()

    let inputStyle = {}
    if (isFailed) inputStyle.color = "red"
    if (isLoading) inputStyle.color = "#aaa"

    const Schemes = getComponent("schemes")

    const isSpecEmpty = !specSelectors.specStr()

    if (isSpecEmpty && (!loadingStatus || loadingStatus === "success")) {
      return <h4>No spec provided.</h4>
    }

    return (
      <Container className='swagger-ui'>
        <Topbar getComponent={getComponent} />
        {loadingStatus === "loading" &&
          <div className="information-container wrapper">
            <div className="info">
              <h4 className="title">Loading...</h4>
            </div>
          </div>
        }
        {loadingStatus === "failed" &&
          <div className="information-container wrapper">
            <div className="info">
              <h4 className="title">Failed to load spec.</h4>
            </div>
          </div>
        }
        {loadingStatus === "failedConfig" &&
          <div className="information-container wrapper">
            <div className="info">
              <h4 className="title">Failed to load config.</h4>
            </div>
          </div>
        }
        {!loadingStatus || loadingStatus === "success" &&
          <div className='swagger-ui'>
            <div>
              <Errors />
              <Row className="information-container">
                <Col mobile={12}>
                  {info.count() ? (
                    <Info info={info} url={url} host={host} mode={mode} system={system} basePath={basePath}
                      externalDocs={externalDocs} getComponent={getComponent} />
                  ) : null}
                </Col>
              </Row>
              {schemes && schemes.size || securityDefinitions ? (
                <div className="scheme-container">
                  <Col className="schemes wrapper" mobile={12}>
                    {schemes && schemes.size ? (
                      <Schemes schemes={schemes} specActions={specActions} />
                    ) : null}

                    {securityDefinitions ? (
                      <AuthorizeBtn system={system} />
                    ) : null}
                  </Col>
                </div>
              ) : null}
              {
                filter === null || filter === false ? null :
                  <div className="filter-container">
                    <Col className="filter wrapper" mobile={12}>
                      <input className="operation-filter-input" placeholder="Filter by tag" type="text"
                        onChange={this.onFilterChange} value={filter === true || filter === "true" ? "" : filter}
                        disabled={isLoading} style={inputStyle} />
                    </Col>
                  </div>
              }
              <Row>
                <Col mobile={12} desktop={12}>
                  <Operations />
                </Col>
              </Row>
              <Row>
                <Col mobile={12} desktop={12}>
                  <Models />
                </Col>
              </Row>
              <Row>
                <Col mobile={12} desktop={12}>
                  <Footer url={url} />
                </Col>
              </Row>
            </div>
          </div>
        }
        <Row>
          <Col>
            <OnlineValidatorBadge />
          </Col>
        </Row>
      </Container>
    )
  }
}
