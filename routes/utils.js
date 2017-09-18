'use strict';

const contentTypes = {
    json: "application/json; charset=utf-8",
    xml: "application/xml; charset=utf-8"
};

exports.reasons = {
    rejectHeader: 'This API produces XML or JSON only. Please alter your accept header accordingly.',
    requiredParam: 'A required parameter is missing.',
    invalidParam: 'One or more parameters are of the wrong type.',
    inadequateAccess: 'The client has not been granted adequate access to this resource.'
};

exports.reject = (res, reason) => {
    res.status(400);
    res.send(reason);
}

exports.setContentType = (res, contentType) => {
    res.set('Content-Type', contentType);

    if (contentType == contentTypes.xml) {
        res.write('<?xml version="1.0" encoding="UTF-8"?>');
    }
}

exports.executeSelect = (res, req, params) => {
    let qry = "DECLARE @results NVARCHAR(MAX) EXEC ";
    let type = "";

    params.args.push("@results = @results OUTPUT");

    if (req.accepts('application/xml')) {
        type += "XML ";
        this.setContentType(res, contentTypes.xml);
    } else if (req.accepts('application/json') || typeof req.headers.accept === 'undefined') {
        type += "JSON ";
        this.setContentType(res, contentTypes.json);
    } else {
        return this.reject(res, this.reasons.rejectHeader);
    }

    qry = qry + params.sp + type + params.args.concat();
    
    req.query(qry)
        .into(res);
}
