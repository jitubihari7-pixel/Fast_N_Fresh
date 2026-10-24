// Hand-over reset: makes the database "brand new" for the client.
// Usage: CONFIRM_FRESH_RESET=YES npm run reset:fresh
//
// Permanently deletes all business history -- orders/bills (with their KOTs),
// payments, refunds, credit, customers, expenses, cash movements, day
// closes, inventory movements, feedback and the audit log -- and restarts
// bill numbering, so the next order is #1. All tables are marked available.
//
// Kept: menu (categories/products and their images), tables, business
// settings and user accounts.
require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const {
  Order,
  Counter,
  Customer,
  PaymentTransaction,
  RefundTransaction,
  CreditTransaction,
  Expense,
  CashMovement,
  DayClose,
  InventoryTransaction,
  Feedback,
  AuditLog,
  Table,
} = require('../models');

const HISTORY = {
  Order,
  PaymentTransaction,
  RefundTransaction,
  CreditTransaction,
  Customer,
  Expense,
  CashMovement,
  DayClose,
  InventoryTransaction,
  Feedback,
  AuditLog,
};

async function resetFreshDatabase() {
  if (String(process.env.CONFIRM_FRESH_RESET || '') !== 'YES') {
    throw new Error('Set CONFIRM_FRESH_RESET=YES to permanently delete all business history.');
  }

  await connectDB();
  console.log(`Database: ${mongoose.connection.name}\n`);

  for (const [name, Model] of Object.entries(HISTORY)) {
    const { deletedCount } = await Model.deleteMany({});
    console.log(`Deleted ${String(deletedCount || 0).padStart(5)}  ${name}`);
  }

  // Every sequence (bill number, ...) restarts, so the next bill is #1.
  const { modifiedCount } = await Counter.updateMany({}, { $set: { seq: 0 } });
  await Counter.findByIdAndUpdate('orderNumber', { $set: { seq: 0 } }, { upsert: true });
  console.log(`\nReset ${modifiedCount} counter(s). The next order will be #1.`);

  await Table.updateMany({}, { $set: { status: 'available' } });
  console.log('All tables marked available.');
}

resetFreshDatabase()
  .catch((error) => {
    console.error('Reset failed:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    try { await mongoose.connection.close(); } catch (_) {}
  });
