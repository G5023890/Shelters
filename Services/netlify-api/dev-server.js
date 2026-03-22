"use strict";

const http = require("node:http");
const path = require("node:path");
const { URL } = require("node:url");

const reportsFunction = require("./functions/reports");
const reportPhotoFunction = require("./functions/report-photo");
const { ensureStorageDirectories, resolveStorageRoot } = require("./lib/storage");

function parseArguments(argv) {
  const options = {
    port: 8888,
    host: "127.0.0.1",
    storageRoot: resolveStorageRoot()
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    const nextValue = argv[index + 1];

    if (argument === "--port" && nextValue) {
      options.port = Number.parseInt(nextValue, 10);
      index += 1;
    } else if (argument === "--host" && nextValue) {
      options.host = nextValue;
      index += 1;
    } else if (argument === "--data-dir" && nextValue) {
      options.storageRoot = path.resolve(nextValue);
      index += 1;
    }
  }

  return options;
}

function readRequestBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];

    request.on("data", (chunk) => {
      chunks.push(Buffer.from(chunk));
    });

    request.on("end", () => {
      resolve(Buffer.concat(chunks).toString("utf8"));
    });

    request.on("error", reject);
  });
}

function buildEvent(request, body) {
  const url = new URL(request.url, `http://${request.headers.host || "127.0.0.1"}`);

  return {
    rawUrl: url.toString(),
    path: url.pathname,
    httpMethod: request.method || "GET",
    headers: request.headers,
    body,
    isBase64Encoded: false
  };
}

async function dispatch(request, response) {
  const body = await readRequestBody(request);
  const event = buildEvent(request, body);

  if (event.path === "/health") {
    const payload = JSON.stringify({
      status: "ok",
      storageRoot: process.env.SHELTERS_REPORTING_DEV_STORAGE_DIR
    });
    response.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    response.end(payload);
    return;
  }

  let result;
  if (event.path === "/.netlify/functions/reports") {
    result = await reportsFunction.handler(event, {});
  } else if (event.path === "/.netlify/functions/reports/photo") {
    result = await reportPhotoFunction.handler(event, {});
  } else {
    result = {
      statusCode: 404,
      headers: { "content-type": "application/json; charset=utf-8" },
      body: JSON.stringify({
        error: {
          code: "not_found",
          message: "No local Netlify-compatible function matches this path."
        }
      })
    };
  }

  response.writeHead(result.statusCode || 200, result.headers || {});
  response.end(result.body || "");
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  process.env.SHELTERS_REPORTING_DEV_STORAGE_DIR = options.storageRoot;
  await ensureStorageDirectories(options.storageRoot);

  const server = http.createServer(async (request, response) => {
    try {
      await dispatch(request, response);
    } catch (error) {
      response.writeHead(500, { "content-type": "application/json; charset=utf-8" });
      response.end(
        JSON.stringify({
          error: {
            code: "internal_error",
            message: error instanceof Error ? error.message : "Unexpected server error."
          }
        })
      );
    }
  });

  server.listen(options.port, options.host, () => {
    process.stdout.write(
      `Local reporting backend listening on http://${options.host}:${options.port}\n`
    );
  });
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack || error.message : error}\n`);
  process.exitCode = 1;
});
