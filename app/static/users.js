// Users page: list, create, edit, delete.

renderNav("users");

let editingId = null; // null = the form adds a new user; a number = the form edits that user

// ---------- the table ----------
async function loadUsers() {
  const users = await api("GET", "/users");
  const header =
    "<tr><th>ID</th><th>Name</th><th>Email</th><th>Affiliation</th><th>Phone</th><th>Roles</th><th></th></tr>";
  const rows = users
    .map(
      (u) => `
    <tr>
      <td>${u.user_id}</td>
      <td>${esc(u.name)} ${esc(u.surname)}</td>
      <td>${esc(u.email)}</td>
      <td>${esc(u.affiliation)}, ${esc(u.country)}</td>
      <td>${esc(u.phone)}</td>
      <td>${u.is_author ? "author " : ""}${u.is_reviewer ? "reviewer" : ""}</td>
      <td>
        <button onclick="editUser(${u.user_id})">Edit</button>
        <button class="danger" onclick="deleteUser(${u.user_id})">Delete</button>
      </td>
    </tr>`
    )
    .join("");
  $("users-table").innerHTML = header + rows;
}

// ---------- the form ----------
function resetForm() {
  $("user-form").reset();
  editingId = null;
  $("form-title").textContent = "Add a user";
  $("save-button").textContent = "Add user";
  $("cancel-button").style.display = "none";
}

// Read the form into the object the server expects.
function readForm() {
  return {
    name: $("f-name").value,
    surname: $("f-surname").value,
    email: $("f-email").value,
    affiliation: $("f-affiliation").value,
    country: $("f-country").value,
    phone: $("f-phone").value.trim(),
    // A profile is sent only when its checkbox is ticked.
    author: $("f-is-author").checked
      ? { orcid: $("f-orcid").value || null, research_areas: splitList($("f-areas").value) }
      : null,
    reviewer: $("f-is-reviewer").checked
      ? { years_experience: numberOrNull($("f-years").value), expertise: splitList($("f-expertise").value) }
      : null,
  };
}

$("user-form").addEventListener("submit", (event) => {
  event.preventDefault();
  run(async () => {
    if (editingId === null) {
      const user = await api("POST", "/users", readForm());
      showMessage("User " + user.user_id + " created.");
    } else {
      await api("PUT", "/users/" + editingId, readForm());
      showMessage("User " + editingId + " updated.");
    }
    resetForm();
    await loadUsers();
  });
});

// ---------- buttons in the table ----------
function editUser(id) {
  run(async () => {
    const u = await api("GET", "/users/" + id);
    $("f-name").value = u.name;
    $("f-surname").value = u.surname;
    $("f-email").value = u.email;
    $("f-affiliation").value = u.affiliation;
    $("f-country").value = u.country;
    $("f-phone").value = u.phone || "";
    $("f-is-author").checked = u.author !== null;
    $("f-orcid").value = u.author ? u.author.orcid || "" : "";
    $("f-areas").value = u.author ? u.author.research_areas.join(", ") : "";
    $("f-is-reviewer").checked = u.reviewer !== null;
    $("f-years").value = u.reviewer ? u.reviewer.years_experience : "";
    $("f-expertise").value = u.reviewer ? u.reviewer.expertise.join(", ") : "";

    editingId = id;
    $("form-title").textContent = "Edit user " + id;
    $("save-button").textContent = "Save changes";
    $("cancel-button").style.display = "";
    $("message").className = "";
    $("message").textContent = "";
    window.scrollTo(0, 0);
  });
}

function deleteUser(id) {
  if (!confirm("Delete user " + id + "?")) return;
  run(async () => {
    await api("DELETE", "/users/" + id);
    showMessage("User " + id + " deleted.");
    if (editingId === id) resetForm();
    await loadUsers();
  });
}

// ---------- start ----------
resetForm();
run(loadUsers);
