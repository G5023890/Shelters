"use strict";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store"
};

function json(statusCode, body) {
  return {
    statusCode,
    headers: JSON_HEADERS,
    body: JSON.stringify(body)
  };
}

function methodNotAllowed(allowedMethods) {
  return json(405, {
    error: {
      code: "method_not_allowed",
      message: `Use ${allowedMethods.join(", ")} for this endpoint.`
    }
  });
}

function validationFailed(errors) {
  return json(400, {
    error: {
      code: "validation_failed",
      message: "The request payload is invalid.",
      details: errors
    }
  });
}

function notFound(code, message) {
  return json(404, {
    error: {
      code,
      message
    }
  });
}

function serverError(error) {
  return json(500, {
    error: {
      code: "internal_error",
      message: error instanceof Error ? error.message : "Unexpected server error."
    }
  });
}

function parseJSONBody(event) {
  if (!event.body) {
    return null;
  }

  const body = event.isBase64Encoded
    ? Buffer.from(event.body, "base64").toString("utf8")
    : event.body;

  return JSON.parse(body);
}

module.exports = {
  json,
  methodNotAllowed,
  validationFailed,
  notFound,
  serverError,
  parseJSONBody
};
