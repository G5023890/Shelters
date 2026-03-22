"use strict";

const {
  json,
  methodNotAllowed,
  notFound,
  parseJSONBody,
  serverError,
  validationFailed
} = require("../lib/http");
const { validatePhotoPayload } = require("../lib/validation");
const {
  loadReportByLocalID,
  loadReportByRemoteID,
  isRecognizedRemoteReportID,
  persistPhotoEvidence
} = require("../lib/storage");

exports.config = {
  path: "/.netlify/functions/reports/photo"
};

exports.handler = async function handler(event) {
  if (event.httpMethod !== "POST") {
    return methodNotAllowed(["POST"]);
  }

  try {
    const payload = parseJSONBody(event);
    const errors = validatePhotoPayload(payload);
    if (errors.length > 0) {
      return validationFailed(errors);
    }

    const linkedReport =
      (payload.remoteReportID
        ? await loadReportByRemoteID(payload.remoteReportID)
        : null) ?? (await loadReportByLocalID(payload.localReportID));

    const trustedRemoteReceipt =
      !linkedReport && isRecognizedRemoteReportID(payload.remoteReportID)
        ? { remoteReportID: payload.remoteReportID }
        : null;

    if (!linkedReport && !trustedRemoteReceipt) {
      return notFound(
        "report_not_found",
        "A matching uploaded report was not found for this photo evidence."
      );
    }

    const storedPhoto = await persistPhotoEvidence(payload);

    return json(202, {
      status: storedPhoto.status
    });
  } catch (error) {
    return serverError(error);
  }
};
