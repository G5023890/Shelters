"use strict";

const REPORT_TYPES = new Set([
  "wrong_location",
  "confirm_location",
  "moved_entrance",
  "new_place",
  "photo_evidence"
]);

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function validateReportPayload(payload) {
  const errors = [];

  if (!payload || typeof payload !== "object") {
    return [{ field: "body", message: "Body must be a JSON object." }];
  }

  assertUUID(payload.localReportID, "localReportID", errors);
  assertNullableUUID(payload.canonicalPlaceID, "canonicalPlaceID", errors);
  assertNonEmptyString(payload.datasetVersion, "datasetVersion", errors);
  assertOptionalString(payload.textNote, "textNote", errors);
  assertISODate(payload.localCreatedAt, "localCreatedAt", errors);

  if (!REPORT_TYPES.has(payload.reportType)) {
    errors.push({
      field: "reportType",
      message: "reportType must match the supported report contract."
    });
  }

  validateCoordinatePair(payload.userLat, payload.userLon, "user", errors);
  validateCoordinatePair(
    payload.suggestedEntranceLat,
    payload.suggestedEntranceLon,
    "suggestedEntrance",
    errors
  );

  return errors;
}

function validatePhotoPayload(payload) {
  const errors = [];

  if (!payload || typeof payload !== "object") {
    return [{ field: "body", message: "Body must be a JSON object." }];
  }

  assertUUID(payload.localPhotoID, "localPhotoID", errors);
  assertUUID(payload.localReportID, "localReportID", errors);
  assertNullableString(payload.remoteReportID, "remoteReportID", errors);
  assertNonEmptyString(payload.localFilePath, "localFilePath", errors);
  assertNullableString(payload.checksum, "checksum", errors);
  assertBoolean(payload.hasMetadata, "hasMetadata", errors);
  assertOptionalISODate(payload.capturedAt, "capturedAt", errors);
  validateCoordinatePair(payload.exifLat, payload.exifLon, "exif", errors);

  return errors;
}

function assertUUID(value, field, errors) {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    errors.push({ field, message: `${field} must be a UUID string.` });
  }
}

function assertNullableUUID(value, field, errors) {
  if (value == null) {
    return;
  }
  assertUUID(value, field, errors);
}

function assertNonEmptyString(value, field, errors) {
  if (typeof value !== "string" || value.trim().length === 0) {
    errors.push({ field, message: `${field} must be a non-empty string.` });
  }
}

function assertOptionalString(value, field, errors) {
  if (value == null) {
    return;
  }
  if (typeof value !== "string") {
    errors.push({ field, message: `${field} must be a string or null.` });
  }
}

function assertNullableString(value, field, errors) {
  if (value == null) {
    return;
  }
  assertNonEmptyString(value, field, errors);
}

function assertBoolean(value, field, errors) {
  if (typeof value !== "boolean") {
    errors.push({ field, message: `${field} must be a boolean.` });
  }
}

function assertISODate(value, field, errors) {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    errors.push({ field, message: `${field} must be an ISO-8601 date string.` });
  }
}

function assertOptionalISODate(value, field, errors) {
  if (value == null) {
    return;
  }
  assertISODate(value, field, errors);
}

function validateCoordinatePair(lat, lon, prefix, errors) {
  const latField = `${prefix}Lat`;
  const lonField = `${prefix}Lon`;

  if (lat == null && lon == null) {
    return;
  }

  if (typeof lat !== "number" || lat < -90 || lat > 90) {
    errors.push({ field: latField, message: `${latField} must be a valid latitude.` });
  }

  if (typeof lon !== "number" || lon < -180 || lon > 180) {
    errors.push({ field: lonField, message: `${lonField} must be a valid longitude.` });
  }
}

module.exports = {
  validateReportPayload,
  validatePhotoPayload
};
