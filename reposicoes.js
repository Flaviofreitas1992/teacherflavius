let currentSession = null;
let bookingInProgress = false;
let cancellationInProgress = false;

function sleep(ms) {
  return new Promise(function (resolve) { setTimeout(resolve, ms); });
}

async function waitForAuthResources() {
  for (let index = 0; index < 10; index += 1) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("reposicoes.html");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Data não informada";
  const formatted = new Intl.DateTimeFormat("pt-BR", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
    timeZone: "America/Sao_Paulo"
  }).format(date);
  return formatted.charAt(0).toUpperCase() + formatted.slice(1);
}

function formatTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "--:--";
  return new Intl.DateTimeFormat("pt-BR", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "America/Sao_Paulo"
  }).format(date);
}

function translateEmailStatus(status, cancelled) {
  if (status === "not_queued") return { label: "Cancelamento registrado", css: "" };
  if (status === "sent") return { label: cancelled ? "E-mail de cancelamento enviado" : "E-mail enviado", css: "success" };
  if (status === "failed") return { label: cancelled ? "Falha no e-mail de cancelamento" : "Falha no e-mail", css: "danger" };
  return { label: cancelled ? "E-mail de cancelamento sendo enviado" : "E-mail sendo enviado", css: "warning" };
}

function renderAvailableSlot(slot) {
  const remaining = Number(slot.remaining_spots || 0);
  const spotsLabel = remaining === 1 ? "1 vaga disponível" : remaining + " vagas disponíveis";
  return '<article class="slot-card">' +
    '<div class="card-heading"><div>' +
      '<h3>' + escapeHtml(formatDate(slot.starts_at)) + '</h3>' +
      '<div class="card-time">' + escapeHtml(formatTime(slot.starts_at)) + ' às ' + escapeHtml(formatTime(slot.ends_at)) + '</div>' +
    '</div><span class="status-pill success">' + escapeHtml(spotsLabel) + '</span></div>' +
    '<p><strong>Turma:</strong> ' + escapeHtml(slot.class_name || ("Turma " + slot.class_number)) + '</p>' +
    (slot.notes ? '<p>' + escapeHtml(slot.notes) + '</p>' : '') +
    '<button class="primary-button book-slot-button" type="button" data-slot-id="' + escapeHtml(slot.id) + '" data-slot-label="' +
      escapeHtml((slot.class_name || ("Turma " + slot.class_number)) + ', ' + formatDate(slot.starts_at) + ', das ' + formatTime(slot.starts_at) + ' às ' + formatTime(slot.ends_at)) + '">AGENDAR REPOSIÇÃO</button>' +
  '</article>';
}

function renderBooking(booking) {
  const cancelled = booking.status === "cancelled";
  const hasStarted = new Date(booking.starts_at).getTime() <= Date.now();
  const isPast = new Date(booking.ends_at).getTime() < Date.now();
  const canCancel = !cancelled && !hasStarted;
  const bookingLabel = (booking.class_name || ("Turma " + booking.class_number)) + ", " +
    formatDate(booking.starts_at) + ", das " + formatTime(booking.starts_at) + " às " + formatTime(booking.ends_at);
  let bookingStatus = { label: "Agendada", css: "success" };
  if (cancelled) bookingStatus = { label: "Cancelada", css: "danger" };
  else if (isPast) bookingStatus = { label: "Data concluída", css: "" };
  const emailStatus = translateEmailStatus(booking.email_status, cancelled);

  return '<article class="booking-card' + (cancelled ? ' is-cancelled' : '') + '">' +
    '<div class="card-heading"><div>' +
      '<h3>' + escapeHtml(formatDate(booking.starts_at)) + '</h3>' +
      '<div class="card-time">' + escapeHtml(formatTime(booking.starts_at)) + ' às ' + escapeHtml(formatTime(booking.ends_at)) + '</div>' +
    '</div><span class="status-pill ' + bookingStatus.css + '">' + escapeHtml(bookingStatus.label) + '</span></div>' +
    '<p><strong>Turma:</strong> ' + escapeHtml(booking.class_name || ("Turma " + booking.class_number)) + '</p>' +
    '<div class="card-meta"><span class="status-pill ' + emailStatus.css + '">' + escapeHtml(emailStatus.label) + '</span></div>' +
    ((!cancelled && booking.meeting_url) || canCancel ? '<div class="booking-actions">' +
      (!cancelled && booking.meeting_url ? '<a class="link-button" href="' + escapeHtml(booking.meeting_url) + '" target="_blank" rel="noopener noreferrer">ABRIR LINK DA AULA</a>' : '') +
      (canCancel ? '<button class="danger-button cancel-my-booking-button" type="button" data-booking-id="' + escapeHtml(booking.id) + '" data-booking-label="' + escapeHtml(bookingLabel) + '">CANCELAR REPOSIÇÃO</button>' : '') +
    '</div>' : '') +
  '</article>';
}

async function loadSchedule() {
  const slotsContainer = document.getElementById("availableSlots");
  const bookingsContainer = document.getElementById("myBookings");
  slotsContainer.innerHTML = '<p class="empty">Carregando horários...</p>';
  bookingsContainer.innerHTML = '<p class="empty">Carregando agendamentos...</p>';

  const client = Auth.getClient();
  const results = await Promise.all([
    client.rpc("get_available_makeup_slots"),
    client.rpc("get_my_makeup_bookings")
  ]);

  if (results[0].error) throw results[0].error;
  if (results[1].error) throw results[1].error;

  const slots = results[0].data || [];
  const bookings = results[1].data || [];

  slotsContainer.innerHTML = slots.length
    ? slots.map(renderAvailableSlot).join("")
    : '<p class="empty">Não há horários de reposição com vaga no momento.</p>';
  bookingsContainer.innerHTML = bookings.length
    ? bookings.map(renderBooking).join("")
    : '<p class="empty">Você ainda não agendou nenhuma reposição.</p>';

  document.querySelectorAll(".book-slot-button").forEach(function (button) {
    button.addEventListener("click", function () {
      bookSlot(button.dataset.slotId, button.dataset.slotLabel, button);
    });
  });
  document.querySelectorAll(".cancel-my-booking-button").forEach(function (button) {
    button.addEventListener("click", function () {
      cancelMyBooking(button.dataset.bookingId, button.dataset.bookingLabel, button);
    });
  });
}

async function bookSlot(slotId, slotLabel, button) {
  if (bookingInProgress) return;
  const confirmed = window.confirm("Deseja agendar a reposição para " + slotLabel + "?");
  if (!confirmed) return;

  bookingInProgress = true;
  button.disabled = true;
  button.textContent = "AGENDANDO...";
  const status = document.getElementById("pageStatus");

  try {
    const response = await Auth.getClient().rpc("book_makeup_class", { target_slot_id: slotId });
    if (response.error) throw response.error;
    status.textContent = "Reposição agendada. A confirmação por e-mail está sendo enviada.";
    await loadSchedule();
  } catch (error) {
    status.textContent = "Não foi possível agendar: " + (error.message || "tente novamente.");
    button.disabled = false;
    button.textContent = "AGENDAR REPOSIÇÃO";
  } finally {
    bookingInProgress = false;
  }
}

async function cancelMyBooking(bookingId, bookingLabel, button) {
  if (cancellationInProgress || bookingInProgress) return;
  const confirmed = window.confirm(
    "Deseja cancelar a reposição de " + bookingLabel + "? A vaga será liberada para outro aluno."
  );
  if (!confirmed) return;

  cancellationInProgress = true;
  button.disabled = true;
  button.textContent = "CANCELANDO...";
  const status = document.getElementById("pageStatus");

  try {
    const response = await Auth.getClient().rpc("cancel_my_makeup_class_booking", {
      target_booking_id: bookingId
    });
    if (response.error) throw response.error;
    status.textContent = "Reposição cancelada. A confirmação por e-mail está sendo enviada.";
    await loadSchedule();
  } catch (error) {
    status.textContent = "Não foi possível cancelar: " + (error.message || "tente novamente.");
    button.disabled = false;
    button.textContent = "CANCELAR REPOSIÇÃO";
  } finally {
    cancellationInProgress = false;
  }
}

async function guardPage() {
  const status = document.getElementById("pageStatus");
  const ready = await waitForAuthResources();

  if (!ready) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentSession = await Auth.getSession();
  if (!currentSession || !currentSession.user) {
    redirectToLogin();
    return;
  }

  status.textContent = "Aluno conectado: " + currentSession.user.email + ".";
  document.body.classList.remove("auth-checking");

  try {
    await loadSchedule();
  } catch (error) {
    const message = error.message || "Erro ao carregar os horários.";
    document.getElementById("availableSlots").innerHTML = '<p class="error">' + escapeHtml(message) + '</p>';
    document.getElementById("myBookings").innerHTML = '<p class="error">Não foi possível carregar seus agendamentos.</p>';
  }
}

document.getElementById("refreshSlotsButton").addEventListener("click", function () {
  loadSchedule().catch(function (error) {
    document.getElementById("pageStatus").textContent = "Não foi possível atualizar: " + (error.message || "tente novamente.");
  });
});

guardPage();
