// Reviews page: list, create, edit, delete.

renderNav("reviews");

let editingId = null; // null = the form adds a review; a number = it edits that review

// ---------- the table ----------
async function loadReviews() {
  const reviews = await api("GET", "/reviews");
  const header =
    "<tr><th>ID</th><th>Paper</th><th>Reviewer</th><th>Score</th><th>Recommendation</th>" +
    "<th>Comments for authors</th><th>Date</th><th></th></tr>";
  const rows = reviews
    .map(
      (r) => `
    <tr>
      <td>${r.review_id}</td>
      <td>${r.paper_id}: ${esc(r.paper_title)}</td>
      <td>${r.reviewer_id}: ${esc(r.reviewer_name)}</td>
      <td>${r.overall_score}</td>
      <td>${esc(r.recommendation)}</td>
      <td>${esc(r.comments_for_authors)}</td>
      <td>${esc(r.review_submission_date)}</td>
      <td>
        <button onclick="editReview(${r.review_id})">Edit</button>
        <button class="danger" onclick="deleteReview(${r.review_id})">Delete</button>
      </td>
    </tr>`
    )
    .join("");
  $("reviews-table").innerHTML = header + rows;
}

// ---------- the form ----------
function resetForm() {
  $("review-form").reset();
  editingId = null;
  $("form-title").textContent = "Add a review";
  $("save-button").textContent = "Add review";
  $("cancel-button").style.display = "none";
}

function readForm() {
  return {
    paper_id: numberOrNull($("f-paper").value),
    reviewer_id: numberOrNull($("f-reviewer").value),
    overall_score: numberOrNull($("f-score").value),
    recommendation: $("f-recommendation").value,
    comments_for_authors: $("f-comments").value,
    confidential_comments: $("f-confidential").value || null,
    review_submission_date: $("f-date").value || null,
  };
}

$("review-form").addEventListener("submit", (event) => {
  event.preventDefault();
  run(async () => {
    if (editingId === null) {
      const review = await api("POST", "/reviews", readForm());
      showMessage("Review " + review.review_id + " created.");
    } else {
      await api("PUT", "/reviews/" + editingId, readForm());
      showMessage("Review " + editingId + " updated.");
    }
    resetForm();
    await loadReviews();
  });
});

// ---------- buttons in the table ----------
function editReview(id) {
  run(async () => {
    const r = await api("GET", "/reviews/" + id);
    $("f-paper").value = r.paper_id;
    $("f-reviewer").value = r.reviewer_id;
    $("f-score").value = r.overall_score;
    $("f-recommendation").value = r.recommendation;
    $("f-comments").value = r.comments_for_authors;
    $("f-confidential").value = r.confidential_comments || "";
    $("f-date").value = r.review_submission_date;

    editingId = id;
    $("form-title").textContent = "Edit review " + id;
    $("save-button").textContent = "Save changes";
    $("cancel-button").style.display = "";
    $("message").className = "";
    $("message").textContent = "";
    window.scrollTo(0, 0);
  });
}

function deleteReview(id) {
  if (!confirm("Delete review " + id + "?")) return;
  run(async () => {
    await api("DELETE", "/reviews/" + id);
    showMessage("Review " + id + " deleted.");
    if (editingId === id) resetForm();
    await loadReviews();
  });
}

// ---------- start ----------
async function start() {
  const papers = await api("GET", "/papers");
  const users = await api("GET", "/users");
  fillSelect($("f-paper"), papers, (p) => p.paper_id, (p) => "#" + p.paper_id + " " + p.title);
  fillSelect(
    $("f-reviewer"),
    users.filter((u) => u.is_reviewer),
    (u) => u.user_id,
    (u) => "#" + u.user_id + " " + u.name + " " + u.surname
  );
  fillSelect($("f-score"), [1, 2, 3, 4, 5], (n) => n, (n) => n);
  fillSelect($("f-recommendation"), ["accept", "reject"], (s) => s, (s) => s);
  resetForm();
  await loadReviews();
}
run(start);
