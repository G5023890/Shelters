"use strict";

const {
  json,
  methodNotAllowed,
  parseJSONBody,
  serverError,
  validationFailed
} = require("../lib/http");
const reportPhotoFunction = require("./report-photo");
const { validateReportPayload } = require("../lib/validation");
const { persistReport } = require("../lib/storage");

exports.config = {
  path: "/.netlify/functions/reports"
};

exports.handler = async function handler(event) {
  if (event.path === "/.netlify/functions/reports/photo") {
    return reportPhotoFunction.handler(event);
  }

  if (event.httpMethod !== "POST") {
    return methodNotAllowed(["POST"]);
  }

  try {
    const payload = parseJSONBody(event);
    const errors = validateReportPayload(payload);
    if (errors.length > 0) {
      return validationFailed(errors);
    }

    const storedReport = await persistReport(payload);

    return json(202, {
      remoteReportID: storedReport.remoteReportID,
      status: storedReport.status
    });
  } catch (error) {
    return serverError(error);
  }
};
