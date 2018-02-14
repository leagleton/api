import win from "core/window"
import { btoa } from "core/utils"

export default function authorize({ auth, authActions, errActions, configs, authConfigs = {} }) {
    let { schema, scopes, name, clientId, website } = auth
    let query = []

    query.push("response_type=code")

    if (typeof clientId === "string") {
        query.push("client_id=" + encodeURIComponent(clientId))
    }

    query.push("website=" + website)

    let redirectUrl = configs.oauth2RedirectUrl

    // todo move to parser
    if (typeof redirectUrl === "undefined") {
        errActions.newAuthErr({
            authId: name,
            source: "validation",
            level: "error",
            message: "oauth2RedirectUri configuration is not passed. Oauth2 authorization cannot be performed."
        })
        return
    }
    query.push("redirect_uri=" + encodeURIComponent(redirectUrl))

    if (Array.isArray(scopes) && 0 < scopes.length) {
        let scopeSeparator = authConfigs.scopeSeparator || " "

        query.push("scope=" + encodeURIComponent(scopes.join(scopeSeparator)))
    }

    let state = btoa(new Date())

    query.push("state=" + encodeURIComponent(state))

    if (typeof authConfigs.realm !== "undefined") {
        query.push("realm=" + encodeURIComponent(authConfigs.realm))
    }

    let { additionalQueryStringParams } = authConfigs

    for (let key in additionalQueryStringParams) {
        if (typeof additionalQueryStringParams[key] !== "undefined") {
            query.push([key, additionalQueryStringParams[key]].map(encodeURIComponent).join("="))
        }
    }

    let url = [schema.get("authorizationUrl"), query.join("&")].join("?")
    // pass action authorizeOauth2 and authentication data through window
    // to authorize with oauth2

    const callback = authActions.authorizeAccessCodeWithFormParams;

    win.swaggerUIRedirectOauth2 = {
        auth: auth,
        state: state,
        redirectUrl: redirectUrl,
        callback: callback,
        errCb: errActions.newAuthErr
    }

    win.open(url)
}
