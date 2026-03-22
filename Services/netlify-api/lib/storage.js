"use strict";

const fs = require("node:fs/promises");
const path = require("node:path");
let getStore = null;

try {
  ({ getStore } = require("@netlify/blobs"));
} catch (error) {
  getStore = null;
}

const REPORTS_STORE_NAME = "shelters-reports";
const PHOTOS_STORE_NAME = "shelters-report-photos";

function resolveStorageRoot() {
  if (process.env.SHELTERS_REPORTING_DEV_STORAGE_DIR) {
    return path.resolve(process.env.SHELTERS_REPORTING_DEV_STORAGE_DIR);
  }

  if (process.env.NETLIFY || process.env.SITE_ID || process.env.DEPLOY_ID) {
    return path.resolve("/tmp", "shelters-reporting-runtime");
  }

  return path.resolve(__dirname, "..", "dev-data");
}

function useNetlifyBlobs() {
  return Boolean(getStore && process.env.NETLIFY_BLOBS_CONTEXT);
}

function reportsDirectory(storageRoot = resolveStorageRoot()) {
  return path.join(storageRoot, "reports");
}

function photosDirectory(storageRoot = resolveStorageRoot()) {
  return path.join(storageRoot, "photos");
}

async function ensureStorageDirectories(storageRoot = resolveStorageRoot()) {
  if (useNetlifyBlobs()) {
    return;
  }
  await fs.mkdir(reportsDirectory(storageRoot), { recursive: true });
  await fs.mkdir(photosDirectory(storageRoot), { recursive: true });
}

function remoteReportID(localReportID) {
  return `dev-report-${localReportID}`;
}

function isRecognizedRemoteReportID(value) {
  return typeof value === "string" && value.startsWith("dev-report-");
}

function reportFilePath(localReportID, storageRoot = resolveStorageRoot()) {
  return path.join(reportsDirectory(storageRoot), `${localReportID}.json`);
}

function photoFilePath(localPhotoID, storageRoot = resolveStorageRoot()) {
  return path.join(photosDirectory(storageRoot), `${localPhotoID}.json`);
}

function reportsStore() {
  return getStore(REPORTS_STORE_NAME);
}

function photosStore() {
  return getStore(PHOTOS_STORE_NAME);
}

async function persistReport(payload, storageRoot = resolveStorageRoot()) {
  const record = {
    localReportID: payload.localReportID,
    remoteReportID: remoteReportID(payload.localReportID),
    status: "accepted",
    receivedAt: new Date().toISOString(),
    payload
  };

  if (useNetlifyBlobs()) {
    await reportsStore().setJSON(payload.localReportID, record);
    return record;
  }

  await ensureStorageDirectories(storageRoot);
  await fs.writeFile(
    reportFilePath(payload.localReportID, storageRoot),
    JSON.stringify(record, null, 2),
    "utf8"
  );

  return record;
}

async function loadReportByLocalID(localReportID, storageRoot = resolveStorageRoot()) {
  if (useNetlifyBlobs()) {
    return reportsStore().get(localReportID, { consistency: "strong", type: "json" });
  }

  try {
    const data = await fs.readFile(reportFilePath(localReportID, storageRoot), "utf8");
    return JSON.parse(data);
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

async function loadReportByRemoteID(remoteID, storageRoot = resolveStorageRoot()) {
  if (typeof remoteID !== "string" || !remoteID.startsWith("dev-report-")) {
    return null;
  }

  const localReportID = remoteID.replace(/^dev-report-/, "");
  return loadReportByLocalID(localReportID, storageRoot);
}

async function persistPhotoEvidence(payload, storageRoot = resolveStorageRoot()) {
  const record = {
    localPhotoID: payload.localPhotoID,
    localReportID: payload.localReportID,
    remoteReportID: payload.remoteReportID ?? remoteReportID(payload.localReportID),
    status: "accepted",
    receivedAt: new Date().toISOString(),
    payload
  };

  if (useNetlifyBlobs()) {
    await photosStore().setJSON(payload.localPhotoID, record);
    return record;
  }

  await ensureStorageDirectories(storageRoot);
  await fs.writeFile(
    photoFilePath(payload.localPhotoID, storageRoot),
    JSON.stringify(record, null, 2),
    "utf8"
  );

  return record;
}

module.exports = {
  ensureStorageDirectories,
  resolveStorageRoot,
  persistReport,
  loadReportByLocalID,
  loadReportByRemoteID,
  persistPhotoEvidence,
  remoteReportID,
  isRecognizedRemoteReportID
};
