/**
 * Mordecai's Maximus — same-origin API helper
 * CRITICAL: Never return paths with backslashes (would cause pi\permissions\workspace-path1 style bugs)
 */
(function (global) {
  global.apiUrl = function (path) {
    if (!path) path = "/";
    if (typeof path !== "string") path = String(path);
    path = path.replace(/\\/g, "/");
    if (path.charAt(0) !== "/") path = "/" + path;
    return path;
  };
})(typeof window !== "undefined" ? window : globalThis);
