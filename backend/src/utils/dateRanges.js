// Business-day boundaries in the cafe's timezone (India, UTC+5:30, no DST),
// independent of the server's own timezone. Render runs in UTC, so using the
// server's local midnight would make "today" start at 05:30 IST and push
// late-night sales into the previous day.
const BUSINESS_TIME_ZONE = 'Asia/Kolkata';
const IST_OFFSET_MS = 330 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

// A Date whose UTC fields read as the IST wall-clock time of `date`.
function toIst(date) {
  return new Date(new Date(date).getTime() + IST_OFFSET_MS);
}

function startOfDay(date = new Date()) {
  const ist = toIst(date);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()) - IST_OFFSET_MS);
}

function endOfDay(date = new Date()) {
  return new Date(startOfDay(date).getTime() + DAY_MS - 1);
}

function daysAgo(n) {
  return new Date(Date.now() - n * DAY_MS);
}

function startOfWeek(date = new Date()) {
  const day = toIst(date).getUTCDay(); // 0 = Sunday
  return new Date(startOfDay(date).getTime() - day * DAY_MS);
}

function startOfMonth(date = new Date()) {
  const ist = toIst(date);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), 1) - IST_OFFSET_MS);
}

// YYYY-MM-DD business date in IST.
function businessDate(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: BUSINESS_TIME_ZONE }).format(new Date(date));
}

// Parses a date filter sent by a client. Older app builds send local
// wall-clock times without a zone ("2026-10-23T00:00:00.000"); on a UTC
// server that would mean 05:30 IST, shifting "Today" by five and a half
// hours. A value without an explicit zone is therefore read as IST.
function parseClientDate(value) {
  const text = String(value || '').trim();
  if (!text) return null;
  const hasZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(text);
  const isDateTime = /^\d{4}-\d{2}-\d{2}T/.test(text);
  const date = new Date(isDateTime && !hasZone ? text + '+05:30' : text);
  return Number.isNaN(date.getTime()) ? null : date;
}

module.exports = { BUSINESS_TIME_ZONE, startOfDay, endOfDay, daysAgo, startOfWeek, startOfMonth, businessDate, parseClientDate };
