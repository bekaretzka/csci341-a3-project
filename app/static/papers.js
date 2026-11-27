// Papers page: list, create, edit, delete, and manage versions.

renderNav("papers");

const STATUSES = ["submitted", "under review", "accepted", "rejected", "withdrawn"];

let editingId = null;     // null = the form adds a paper; a number = it edits that paper
let conferences = [];     // read-only lists used for the dropdowns and the table
let tracks = [];
let sessions = [];
let currentVersions = []; // versions of the paper being edited

function conferenceAcronym(conferenceId) {
  const c = conferences.find((c) => c.conference_id === conferenceId);
  return c ? c.acronym : conferenceId;
}

function trackName(trackId) {
  const t = tracks.find((t) => t.track_id === trackId);
  return t ? t.name : trackId;
}

// ---------- the table of papers ----------
async function loadPapers() {
  const status = $("filter-status").value;
  const papers = await api("GET", "/papers" + (status ? "?status=" + encodeURIComponent(status) : ""));
  const header =
    "<tr><th>ID</th><th>Title</th><th>Status</th><th>Conference</th><th>Track</th>" +
    "<th>Session</th><th>Current version</th><th></th></tr>";
  const rows = papers
    .map(
      (p) => `
    <tr>
      <td>${p.paper_id}</td>
      <td>${esc(p.title)}</td>
      <td>${esc(p.status)}</td>
      <td>${esc(conferenceAcronym(p.conference_id))}</td>
      <td>${esc(trackName(p.track_id))}</td>
      <td>${p.session_id === null ? "-" : p.session_id}</td>
      <td>${p.current_version}</td>
      <td>
        <button onclick="editPaper(${p.paper_id})">Edit</button>
        <button class="danger" onclick="deletePaper(${p.paper_id})">Delete</button>
      </td>
    </tr>`
    )
    .join("");
  $("papers-table").innerHTML = header + rows;
}

// ---------- the form ----------
function resetForm() {
  $("paper-form").reset();
  editingId = null;
  $("form-title").textContent = "Add a paper";
  $("save-button").textContent = "Add paper";
  $("cancel-button").style.display = "none";
  $("first-version").style.display = "";
  $("f-file").required = true;
  $("versions-box").style.display = "none";
}

// Read the form into the object the server expects.
function readForm() {
  // "3, 4" means author 3 is first and author 4 is second.
  const authorIds = splitList($("f-authors").value).map(Number);
  const correspondingId = Number($("f-corresponding").value);
  return {
    track_id: numberOrNull($("f-track").value),
    title: $("f-title").value,
    abstract: $("f-abstract").value,
    status: $("f-status").value,
    session_id: numberOrNull($("f-session").value),
    authors: authorIds.map((id, index) => ({
      author_id: id,
      author_position: index + 1,
      is_corresponding: id === correspondingId,
    })),
    keywords: splitList($("f-keywords").value),
  };
}

$("paper-form").addEventListener("submit", (event) => {
  event.preventDefault();
  run(async () => {
    if (editingId === null) {
      const body = readForm();
      body.versions = [{ version_no: 1, file_location: $("f-file").value }];
      const paper = await api("POST", "/papers", body);
      showMessage("Paper " + paper.paper_id + " created.");
    } else {
      await api("PUT", "/papers/" + editingId, readForm());
      showMessage("Paper " + editingId + " updated.");
    }
    resetForm();
    await loadPapers();
  });
});

// ---------- buttons in the table ----------
function editPaper(id) {
  run(async () => {
    const p = await api("GET", "/papers/" + id);
    $("f-track").value = p.track_id;
    $("f-status").value = p.status;
    $("f-session").value = p.session_id === null ? "" : p.session_id;
    $("f-title").value = p.title;
    $("f-abstract").value = p.abstract;
    $("f-authors").value = p.authors.map((a) => a.author_id).join(", ");
    const corresponding = p.authors.find((a) => a.is_corresponding);
    $("f-corresponding").value = corresponding ? corresponding.author_id : "";
    $("f-keywords").value = p.keywords.join(", ");

    editingId = id;
    $("form-title").textContent = "Edit paper " + id;
    $("save-button").textContent = "Save changes";
    $("cancel-button").style.display = "";
    $("first-version").style.display = "none"; // versions are managed in the box below
    $("f-file").required = false;
    $("message").className = "";
    $("message").textContent = "";
    showVersions(p);
    window.scrollTo(0, 0);
  });
}

function deletePaper(id) {
  if (!confirm("Delete paper " + id + " with its versions, authors, keywords and reviews?")) return;
  run(async () => {
    await api("DELETE", "/papers/" + id);
    showMessage("Paper " + id + " deleted.");
    if (editingId === id) resetForm();
    await loadPapers();
  });
}

// ---------- versions of the paper being edited ----------
function showVersions(paper) {
  currentVersions = paper.versions;
  $("versions-box").style.display = "";
  $("versions-title").textContent = "Versions of paper " + paper.paper_id + " (highest number = current)";
  const header = "<tr><th>Version</th><th>File location</th><th>Uploaded</th><th>Note</th><th></th></tr>";
  const rows = paper.versions
    .map(
      (v, index) => `
    <tr>
      <td>${v.version_no}</td>
      <td>${esc(v.file_location)}</td>
      <td>${esc(v.uploaded_at)}</td>
      <td>${esc(v.change_note)}</td>
      <td>
        <button onclick="changeVersionFile(${index})">Change file</button>
        <button class="danger" onclick="deleteVersion(${v.version_no})">Delete</button>
      </td>
    </tr>`
    )
    .join("");
  $("versions-table").innerHTML = header + rows;
}

function addVersion() {
  run(async () => {
    const paper = await api("POST", "/papers/" + editingId + "/versions", {
      version_no: numberOrNull($("v-no").value),
      file_location: $("v-file").value,
      change_note: $("v-note").value || null,
    });
    showMessage("Version added.");
    $("v-no").value = "";
    $("v-file").value = "";
    $("v-note").value = "";
    showVersions(paper);
    await loadPapers();
  });
}

function changeVersionFile(index) {
  const version = currentVersions[index];
  const newLocation = prompt("New file location for version " + version.version_no + ":", version.file_location);
  if (newLocation === null) return; // the user pressed Cancel
  run(async () => {
    const paper = await api("PUT", "/papers/" + editingId + "/versions/" + version.version_no, {
      file_location: newLocation,
    });
    showMessage("Version " + version.version_no + " updated.");
    showVersions(paper);
  });
}

function deleteVersion(versionNo) {
  if (!confirm("Delete version " + versionNo + "?")) return;
  run(async () => {
    const paper = await api("DELETE", "/papers/" + editingId + "/versions/" + versionNo);
    showMessage("Version " + versionNo + " deleted.");
    showVersions(paper);
    await loadPapers();
  });
}

// ---------- start ----------
async function start() {
  [conferences, tracks, sessions] = await Promise.all([
    api("GET", "/conferences"),
    api("GET", "/tracks"),
    api("GET", "/sessions"),
  ]);
  const users = await api("GET", "/users");

  fillSelect($("f-track"), tracks, (t) => t.track_id, (t) => conferenceAcronym(t.conference_id) + " - " + t.name);
  fillSelect($("f-status"), STATUSES, (s) => s, (s) => s);
  fillSelect(
    $("f-session"),
    sessions,
    (s) => s.session_id,
    (s) => "#" + s.session_id + " " + s.title + " (" + s.acronym + ")",
    "(no session)"
  );
  fillSelect($("filter-status"), STATUSES, (s) => s, (s) => s, "all statuses");

  const authors = users.filter((u) => u.is_author);
  $("authors-hint").textContent =
    "Available authors: " + authors.map((u) => u.user_id + " " + u.name + " " + u.surname).join(", ");

  resetForm();
  await loadPapers();
}
run(start);
