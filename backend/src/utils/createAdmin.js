// One-off admin account creation for a fresh database.
// Usage: npm run create:admin -- <username> <password> [<name>] [<phone>]
//
// Creates ONLY the admin user. Unlike `npm run seed`, it never adds sample
// categories/products or manager/staff accounts. Refuses to run when an
// admin already exists -- use `npm run set:admin` to change that one.
require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const { User } = require('../models');

async function main() {
  const [rawUsername, password, rawName, rawPhone] = process.argv.slice(2);
  const username = String(rawUsername || '').trim().toLowerCase();

  if (!username || !password) {
    throw new Error('Usage: npm run create:admin -- <username> <password> [<name>] [<phone>]');
  }
  if (password.length < 6) {
    throw new Error('Password must be at least 6 characters.');
  }

  await connectDB();

  const existingAdmin = await User.findOne({ role: 'admin' }).select('username');
  if (existingAdmin) {
    throw new Error(
      `An admin already exists (${existingAdmin.username}). Use "npm run set:admin" to change its login.`
    );
  }
  if (await User.exists({ username })) {
    throw new Error(`Username "${username}" is already taken by another account.`);
  }

  const admin = new User({
    name: String(rawName || 'Admin').trim(),
    username,
    phone: String(rawPhone || '0000000000').trim(),
    role: 'admin',
    status: 'active',
  });
  await admin.setPassword(password);
  await admin.save();

  console.log(`Admin account created: ${username}`);
}

main()
  .catch((error) => {
    console.error('Create admin failed:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    try { await mongoose.connection.close(); } catch (_) {}
  });
