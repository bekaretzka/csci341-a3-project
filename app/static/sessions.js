// Sessions page: list, create, edit, delete, and put papers into sessions.

renderNav("sessions");

let editingId = null; // null = the form adds a session; a number = it edits that session

// ---------- the table ----------
async function loadSessions() {
  const sessions = await api("GET", "/sessions");
  const papers = await api("GET", "/papers");
  const header =
    "<tr><th>ID</th><th>Conference</th><th>Title</th><th>Date</th><th>Time</th><th>Room</th>" +
    "<th>Chair</th><th>Papers in this session</th><th></th></tr>";
  const rows = sessions
    .map((s) => {
      const inSession = papers.filter((p) => p.session_id === s.session_id);
      const paperList = inSession.length
        ? inSession.map((p) => "#" + p.paper_id + " " + esc(p.title)).join("<br>")
        : "(empty)";
      return `
    <tr>
      <td>${s.session_id}</td>
      <td>${esc(s.acronym)}</td>
      <td>${esc(s.title)}</td>
      <td>${esc(s.session_date)}</td>
      <td>${esc(s.start_time)} - ${esc(s.end_time)}</td>
      <td>${esc(s.room_label)}</td>
      <td>${s.chair_id}: ${esc(s.chair_name)}</td>
      <td>${paperList}</td>
      <td>
        <button onclick="editSession(${s.session_id})">Edit</button>
        <button class="danger" onclick="deleteSession(${s.session_id})">Delete</button>
      </td>
    </tr>`;
    })
    .join("");
  $("sessions-table").innerHTML = header + rows;
}

// ---------- the form ----------
function resetForm() {
  $("session-form").reset();
  editingId = null;
  $("form-title").textContent = "Add a session";
  $("save-button").textContent = "Add session";
  $("cancel-button").style.display = "none";
}

function readForm() {
  return {
    conference_id: numberOrNull($("f-conference").value),
    title: $("f-title").value,
    session_date: $("f-date").value,
    start_time: $("f-start").value,
    end_time: $("f-end").value,
    room_label: $("f-room").value,
    chair_id: numberOrNull($("f-chair").value),
  };
}

$("session-form").addEventListener("submit", (event) => {
  event.preventDefault();
  run(async () => {
    if (editingId === null) {
      const session = await api("POST", "/sessions", readForm());
      showMessage("Session " + session.session_id + " created.");
    } else {
      await api("PUT", "/sessions/" + editingId, readForm());
      showMessage("Session " + editingId + " updated.");
    }
    resetForm();
    await refreshAll();
  });
});

// ---------- buttons in the table ----------
function editSession(id) {
  run(async () => {
    const s = await api("GET", "/sessions/" + id);
    $("f-conference").value = s.conference_id;
    $("f-chair").value = s.chair_id;
    $("f-title").value = s.title;
    $("f-date").value = s.session_date;
    $("f-start").value = s.start_time.slice(0, 5); // "09:00:00" -> "09:00"
    $("f-end").value = s.end_time.slice(0, 5);
    $("f-room").value = s.room_label;

    editingId = id;
    $("form-title").textContent = "Edit session " + id;
    $("save-button").textContent = "Save changes";
    $("cancel-button").style.display = "";
    $("message").className = "";
    $("message").textContent = "";
    window.scrollTo(0, 0);
  });
}

function deleteSession(id) {
  if (!confirm("Delete session " + id + "? Its papers stay, but become unscheduled.")) return;
  run(async () => {
    await api("DELETE", "/sessions/" + id);
    showMessage("Session " + id + " deleted.");
    if (editingId === id) resetForm();
    await refreshAll();
  });
}

// ---------- scheduling a paper (this is where the session check is applied) ----------
function schedulePaper() {
  run(async () => {
    const paperId = numberOrNull($("s-paper").value);
    const sessionId = numberOrNull($("s-session").value);
    if (paperId === null) throw new Error("Choose a paper first.");
    await api("PUT", "/papers/" + paperId, { session_id: sessionId });
    showMessage(
      sessionId === null
        ? "Paper " + paperId + " removed from its session."
        : "Paper " + paperId + " scheduled in session " + sessionId + "."
    );
    await refreshAll();
  });
}

// ---------- start ----------
// Reload the lists and the dropdowns that depend on the current data.
async function refreshAll() {
  const sessions = await api("GET", "/sessions");
  const papers = await api("GET", "/papers");
  fillSelect(
    $("s-paper"),
    papers,
    (p) => p.paper_id,
    (p) => "#" + p.paper_id + " " + p.title + " [" + p.status + "]"
  );
  fillSelect(
    $("s-session"),
    sessions,
    (s) => s.session_id,
    (s) => "#" + s.session_id + " " + s.title + " (" + s.acronym + ")",
    "(no session)"
  );
  await loadSessions();
}

async function start() {
  const conferences = await api("GET", "/conferences");
  const users = await api("GET", "/users");
  fillSelect($("f-conference"), conferences, (c) => c.conference_id, (c) => c.acronym + " - " + c.city);
  fillSelect(
    $("f-chair"),
    users.filter((u) => u.is_reviewer),
    (u) => u.user_id,
    (u) => "#" + u.user_id + " " + u.name + " " + u.surname
  );
  resetForm();
  await refreshAll();
}
run(start);
