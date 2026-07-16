let currentAdminSession = null;

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
  window.location.href = "login.html?next=" + encodeURIComponent("reposicoes_admin.html");
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
    weekday: "long", day: "2-digit", month: "long", year: "numeric", timeZone: "America/Sao_Paulo"
  }).format(date);
  return formatted.charAt(0).toUpperCase() + formatted.slice(1);
}

function formatTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "--:--";
  return new Intl.DateTimeFormat("pt-BR", {
    hour: "2-digit", minute: "2-digit", hour12: false, timeZone: "America/Sao_Paulo"
  }).format(date);
}

function emailStatusLabel(status) {
  if (status === "sent") return "E-mail enviado";
  if (status === "failed") return "Falha no e-mail";
  return "E-mail pendente";
}

function renderBookingRow(booking) {
  const cancelled = booking.status === "cancelled";
  return '<div class="booking-row">' +
    '<div><p><strong>' + escapeHtml(booking.student_name) + '</strong> · ' + escapeHtml(booking.class_name) + '</p>' +
    '<p class="booking-email">' + escapeHtml(booking.student_email) + ' · ' + escapeHtml(emailStatusLabel(booking.email_status)) + '</p></div>' +
    (cancelled
      ? '<span class="status-pill danger">Reserva cancelada</span>'
      : '<button class="danger-button cancel-booking-button" type="button" data-booking-id="' + escapeHtml(booking.id) + '">CANCELAR RESERVA</button>') +
  '</div>';
}

function renderAdminSlot(slot, bookings) {
  const isPast = new Date(slot.ends_at).getTime() < Date.now();
  const active = slot.is_active && !isPast;
  const statusLabel = !slot.is_active ? "Cancelado" : (isPast ? "Encerrado" : "Publicado");
  const statusClass = active ? "success" : (!slot.is_active ? "danger" : "");
  const slotBookings = bookings.filter(function (booking) { return booking.slot_id === slot.id; });
  const confirmedCount = Number(slot.confirmed_bookings || 0);

  return '<article class="slot-card' + (active ? '' : ' is-inactive') + '">' +
    '<div class="card-heading"><div><h3>' + escapeHtml(formatDate(slot.starts_at)) + '</h3>' +
    '<div class="card-time">' + escapeHtml(formatTime(slot.starts_at)) + ' às ' + escapeHtml(formatTime(slot.ends_at)) + '</div></div>' +
    '<span class="status-pill ' + statusClass + '">' + escapeHtml(statusLabel) + '</span></div>' +
    '<div class="card-meta"><span class="status-pill">' + confirmedCount + ' de ' + Number(slot.capacity) + ' vagas reservadas</span></div>' +
    (slot.notes ? '<p>' + escapeHtml(slot.notes) + '</p>' : '') +
    (active ? '<button class="danger-button cancel-slot-button" type="button" data-slot-id="' + escapeHtml(slot.id) + '">CANCELAR HORÁRIO</button>' : '') +
    '<div class="booking-list">' + (slotBookings.length ? slotBookings.map(renderBookingRow).join("") : '<p class="empty">Nenhum aluno reservou este horário.</p>') + '</div>' +
  '</article>';
}

async function loadAdminSchedule() {
  const container = document.getElementById("adminSlots");
  container.innerHTML = '<p class="empty">Carregando horários...</p>';
  const client = Auth.getClient();
  const results = await Promise.all([
    client.rpc("get_teacher_makeup_slots"),
    client.rpc("get_teacher_makeup_bookings")
  ]);
  if (results[0].error) throw results[0].error;
  if (results[1].error) throw results[1].error;

  const slots = results[0].data || [];
  const bookings = results[1].data || [];
  container.innerHTML = slots.length
    ? slots.map(function (slot) { return renderAdminSlot(slot, bookings); }).join("")
    : '<p class="empty">Nenhum horário de reposição foi publicado.</p>';

  document.querySelectorAll(".cancel-slot-button").forEach(function (button) {
    button.addEventListener("click", function () { cancelSlot(button.dataset.slotId, button); });
  });
  document.querySelectorAll(".cancel-booking-button").forEach(function (button) {
    button.addEventListener("click", function () { cancelBooking(button.dataset.bookingId, button); });
  });
}

async function cancelSlot(slotId, button) {
  if (!window.confirm("Cancelar este horário e todas as reservas confirmadas nele?")) return;
  button.disabled = true;
  try {
    const response = await Auth.getClient().rpc("cancel_makeup_class_slot", { target_slot_id: slotId });
    if (response.error) throw response.error;
    document.getElementById("adminStatus").textContent = "Horário cancelado.";
    await loadAdminSchedule();
  } catch (error) {
    document.getElementById("adminStatus").textContent = "Não foi possível cancelar: " + (error.message || "tente novamente.");
    button.disabled = false;
  }
}

async function cancelBooking(bookingId, button) {
  if (!window.confirm("Cancelar a reserva deste aluno e liberar a vaga?")) return;
  button.disabled = true;
  try {
    const response = await Auth.getClient().rpc("cancel_makeup_class_booking", { target_booking_id: bookingId });
    if (response.error) throw response.error;
    document.getElementById("adminStatus").textContent = "Reserva cancelada e vaga liberada.";
    await loadAdminSchedule();
  } catch (error) {
    document.getElementById("adminStatus").textContent = "Não foi possível cancelar a reserva: " + (error.message || "tente novamente.");
    button.disabled = false;
  }
}

function setInitialFormValues() {
  const now = new Date();
  const saoPauloDate = new Intl.DateTimeFormat("en-CA", {
    year: "numeric", month: "2-digit", day: "2-digit", timeZone: "America/Sao_Paulo"
  }).format(now);
  document.getElementById("slotDate").min = saoPauloDate;
  if (!document.getElementById("slotDate").value) document.getElementById("slotDate").value = saoPauloDate;
  if (!document.getElementById("slotStartTime").value) document.getElementById("slotStartTime").value = "14:00";
  if (!document.getElementById("slotEndTime").value) document.getElementById("slotEndTime").value = "15:00";
}

document.getElementById("slotForm").addEventListener("submit", async function (event) {
  event.preventDefault();
  const button = document.getElementById("createSlotButton");
  const message = document.getElementById("formMessage");
  const startTime = document.getElementById("slotStartTime").value;
  const endTime = document.getElementById("slotEndTime").value;
  if (endTime <= startTime) {
    message.className = "form-message error";
    message.textContent = "O término precisa ser depois do início.";
    return;
  }

  button.disabled = true;
  button.textContent = "PUBLICANDO...";
  message.className = "form-message";
  message.textContent = "";

  try {
    const response = await Auth.getClient().rpc("create_makeup_class_slot", {
      target_date: document.getElementById("slotDate").value,
      target_start_time: startTime,
      target_end_time: endTime,
      target_capacity: Number(document.getElementById("slotCapacity").value),
      target_notes: document.getElementById("slotNotes").value.trim() || null
    });
    if (response.error) throw response.error;
    message.className = "form-message success";
    message.textContent = "Horário publicado para os alunos.";
    document.getElementById("slotNotes").value = "";
    await loadAdminSchedule();
  } catch (error) {
    message.className = "form-message error";
    message.textContent = error.message || "Não foi possível publicar o horário.";
  } finally {
    button.disabled = false;
    button.textContent = "PUBLICAR HORÁRIO";
  }
});

document.getElementById("refreshAdminButton").addEventListener("click", function () {
  loadAdminSchedule().catch(function (error) {
    document.getElementById("adminStatus").textContent = "Não foi possível atualizar: " + (error.message || "tente novamente.");
  });
});

async function guardAdminPage() {
  const status = document.getElementById("adminStatus");
  const ready = await waitForAuthResources();
  if (!ready) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentAdminSession = await Auth.getSession();
  if (!currentAdminSession || !currentAdminSession.user) {
    redirectToLogin();
    return;
  }

  const adminResponse = await Auth.getClient().rpc("is_teacher_admin");
  if (adminResponse.error || adminResponse.data !== true) {
    status.textContent = "Acesso negado. Esta página é exclusiva do administrador.";
    document.getElementById("slotForm").hidden = true;
    document.getElementById("adminSlots").innerHTML = '<p class="error">Você não tem permissão para visualizar esta agenda.</p>';
    document.body.classList.remove("auth-checking");
    return;
  }

  status.textContent = "Professor autenticado: " + currentAdminSession.user.email + ".";
  document.body.classList.remove("auth-checking");
  setInitialFormValues();

  try {
    await loadAdminSchedule();
  } catch (error) {
    document.getElementById("adminSlots").innerHTML = '<p class="error">' + escapeHtml(error.message || "Não foi possível carregar a agenda.") + '</p>';
  }
}

guardAdminPage();
