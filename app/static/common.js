// Helpers shared by all pages. Every page talks to the JSON API (the same one shown at /docs).

// Short name for document.getElementById
function $(id) {
  return document.getElementById(id);
}

// Make text safe to put inside HTML, so a title like "<b>" cannot break the page.
function esc(value) {
  if (value === null || value === undefined) return "";
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Turn an error answer from the server into one readable sentence.
function errorText(data, status) {
  if (data && typeof data.detail === "string") return data.detail;
  if (data && Array.isArray(data.detail)) {
    // Format problems (for example a text where a number is expected)
    return data.detail.map((d) => d.loc.slice(1).join(".") + ": " + d.msg).join("; ");
  }
  return "Request failed (status " + status + ").";
}

// Send a request to the server. Returns the answer, or throws an Error with a clear message.
async function api(method, path, body) {
  const options = { method: method, headers: { "Content-Type": "application/json" } };
  if (body !== undefined) options.body = JSON.stringify(body);
  const response = await fetch(path, options);
  const data = await response.json().catch(() => null);
  if (!response.ok) throw new Error(errorText(data, response.status));
  return data;
}

// Run an action and show any error in the red message box.
async function run(action) {
  try {
    await action();
  } catch (error) {
    showMessage(error.message, true);
  }
}

// Show a green (ok) or red (error) message at the top of the page.
function showMessage(text, isError) {
  const box = $("message");
  box.className = isError ? "message error" : "message ok";
  box.textContent = text;
  window.scrollTo(0, 0);
}

// "a, b, c" -> ["a", "b", "c"]
function splitList(text) {
  return text.split(",").map((s) => s.trim()).filter((s) => s !== "");
}

// "" -> null, "5" -> 5
function numberOrNull(text) {
  return text === "" ? null : Number(text);
}

// Fill a <select> with options. emptyLabel adds a first option with an empty value.
function fillSelect(select, items, valueOf, labelOf, emptyLabel) {
  let html = emptyLabel ? '<option value="">' + esc(emptyLabel) + "</option>" : "";
  html += items
    .map((item) => '<option value="' + esc(valueOf(item)) + '">' + esc(labelOf(item)) + "</option>")
    .join("");
  select.innerHTML = html;
}

// The menu at the top of every page.
function renderNav(current) {
  const pages = [
    ["index", "Home", "/ui/"],
    ["users", "Users", "/ui/users.html"],
    ["papers", "Papers", "/ui/papers.html"],
    ["reviews", "Reviews", "/ui/reviews.html"],
    ["sessions", "Sessions", "/ui/sessions.html"],
    ["docs", "API docs", "/docs"],
  ];
  $("nav").innerHTML = pages
    .map((p) => '<a href="' + p[2] + '"' + (p[0] === current ? ' class="current"' : "") + ">" + p[1] + "</a>")
    .join("");
}
