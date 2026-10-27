const { BusinessSettings, Order } = require('../models');
const { ApiError, asyncHandler } = require('../utils/apiError');

// Takeaway (T1, T2...) and Delivery (D1, D2...) counters. A counter is just a
// number; a running order sits on it through its tableCustomerLabel ("T1" or
// "T1 · Rahul"), so occupancy comes from the open orders themselves.
const TYPES = {
  takeaway: { field: 'takeawayCounters', prefix: 'T' },
  delivery: { field: 'deliveryCounters', prefix: 'D' },
};

const ACTIVE_STATUSES = ['open', 'preparing', 'ready'];

function typeOf(req) {
  const type = TYPES[req.params.type];
  if (!type) throw new ApiError(400, 'Counter type must be takeaway or delivery.');
  return type;
}

function sorted(numbers) {
  return [...new Set(numbers)].sort((a, b) => a - b);
}

function payload(settings) {
  return {
    takeaway: sorted(settings.takeawayCounters || []),
    delivery: sorted(settings.deliveryCounters || []),
  };
}

const listCounters = asyncHandler(async (req, res) => {
  const settings = await BusinessSettings.getSettings();
  res.json({ success: true, data: payload(settings) });
});

// Adds the lowest free counter number (fills gaps left by a removed one).
const addCounter = asyncHandler(async (req, res) => {
  const { field } = typeOf(req);
  const settings = await BusinessSettings.getSettings();
  const taken = new Set(settings[field] || []);
  let number = 1;
  while (taken.has(number)) number += 1;

  // Saved through the document (not $addToSet) so a settings document from
  // before counters existed keeps its default T1-T4 / D1-D4.
  settings[field] = sorted([...taken, number]);
  await settings.save();
  res.status(201).json({ success: true, data: { ...payload(settings), added: number } });
});

// Removes a counter, unless an unbilled order is still running on it.
const removeCounter = asyncHandler(async (req, res) => {
  const { field, prefix } = typeOf(req);
  const number = Number.parseInt(req.params.number, 10);
  if (!Number.isInteger(number) || number < 1) throw new ApiError(400, 'Invalid counter number.');

  const settings = await BusinessSettings.getSettings();
  const counters = settings[field] || [];
  if (!counters.includes(number)) {
    return res.json({ success: true, data: payload(settings) });
  }
  if (counters.length <= 1) throw new ApiError(400, 'Keep at least one counter.');

  const busy = await Order.exists({
    orderType: req.params.type,
    status: { $in: ACTIVE_STATUSES },
    paymentStatus: { $ne: 'paid' },
    tableCustomerLabel: { $regex: `^${prefix}${number}( · |$)` },
  });
  if (busy) {
    throw new ApiError(409, `${prefix}${number} has a running order. Bill or cancel it first.`);
  }

  settings[field] = counters.filter((n) => n !== number);
  await settings.save();
  res.json({ success: true, data: payload(settings) });
});

module.exports = { listCounters, addCounter, removeCounter };
