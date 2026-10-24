// Idempotent menu sync for the 2026 printed menu (14 Canva pages).
// Usage: npm run sync:menu
//
// Reuses the existing Category/Product collections and never creates a
// duplicate:
//   - A product is matched by name (case-insensitive), then by any of its
//     listed aliases (older names from seedMenuFromPdf / migrateBreakfastBiryani).
//     A match found via alias is renamed to the new menu name.
//   - Matched products get the new selling price and category. Stock/cost
//     fields are never changed.
//   - Missing products are created with inventory tracking disabled, so the
//     script cannot invent a stock quantity.
//   - Categories are matched by name or alias the same way.
// Order history is unaffected: orders keep a name/price snapshot per item.
//
// Products that exist in the DB but are not on the new menu are only listed
// at the end; nothing is deleted or hidden.
//
// Pizzas have two prices on the menu, so each pizza is two products:
// "(Regular)" and "(Large)". The old single-price pizza is renamed to Regular.
//
// "Add Extra Cheese" is printed several times with different prices, so each
// add-on is named after the section it belongs to.

require('dotenv').config();
const mongoose = require('mongoose');
const dns = require('dns');
const connectDB = require('../config/db');
const { Category, Product } = require('../models');

dns.setServers(['8.8.8.8', '8.8.4.4']);

// Each category: [name, aliases, items]. Each item: [name, price, aliases?].
const MENU = [
  ['Breakfast', [], [
    ['Plain Dosa', 39],
    ['Plain Butter Dosa', 59],
    ['Plain Ghee Dosa', 69],
    ['Masala Dosa', 59],
    ['Cut Piece Dosa', 79],
    ['Butter Masala Dosa', 79],
    ['Ghee Masala Dosa', 99],
    ['Paneer Masala Dosa', 119],
    ['Cheese Masala Dosa', 129],
    ['Extra Cheese (Dosa)', 30],
    ['Idli Chutney', 49],
    ['Idli Fry', 69],
    ['Medu Vada', 59],
    ['Uttapam', 69],
    ['Onion Uttapam', 69],
    ['Sabudana Vada', 79],
    ['Aalu Paratha', 69],
    ['Methi Paratha', 69],
    ['Mix Veggies Paratha', 79, ['Mix Veg Paratha']],
    ['Paneer Paratha', 99],
    ['Extra Cheese (Paratha)', 20],
  ]],

  ['Biryani', ['Biryanis'], [
    ['Veg Biryani', 109, ['Mix Veg Biryani']],
    ['Paneer Biryani', 129],
  ]],

  ['French Fries', [], [
    ['Salted / Pepper Fries', 99],
    ['Peri Peri Fries', 119],
    ['Cheese Fries', 139],
    ['FNF Special Fries', 149],
  ]],

  ['Momos', ['Momos (Steam/Fried)'], [
    ['Veg Steam Momos', 90, ['Veg Momos']],
    ['Veg Fried Momos', 99],
    ['Paneer Steam Momos', 110, ['Paneer Momos']],
    ['Paneer Fried Momos', 119],
  ]],

  ['Kurkure Momos', [], [
    ['Veg Kurkure Momos', 109],
    ['Paneer Kurkure Momos', 129],
  ]],

  ['Penne Pasta', ['Pastas', 'Pasta'], [
    ['Red Sauce Pasta', 139],
    ['White Sauce Pasta', 149],
    ['Mixed Sauce Pasta', 159],
    ['Freshly Baked Pasta', 179],
  ]],

  ['Veg Appetizers', [], [
    ['Veg Fingers (6 Pieces)', 109],
    ['Chili Garlic Potato Pops (12 Pieces)', 99, ['Chili Garli Photato Pops (12 Pieces)']],
    ['Cheese Garlic Bread (4 Pieces)', 119],
  ]],

  ['Vocal For Local', [], [
    ['Hot Chocolate', 79],
    ['Hot Coffee', 30],
    ['Hot Tea', 20],
    ['Lemon Tea', 20],
  ]],

  ['Maggie Magic', [], [
    ['Plain Maggie', 59],
    ['Plain Cheese Maggie', 69],
    ['Masala Maggie', 79],
    ['Special Cheese Maggie', 79],
    ['Cheese Corn Maggie', 89],
    ['Vegetable Maggie', 99, ['Vegitable Maggie']],
    ['Vegetable Cheese Maggie', 119, ['Vegitable Cheese Maggie']],
    ['Vegetable Creamy Maggie', 129, ['Vegitable Creamy Maggie']],
  ]],

  ['Burger Menu', ['Burgers'], [
    ['Aloo Tikki Burger', 49],
    ['Veg Tikki Burger', 69],
    ['Double Cheese Burger', 99],
    ['Tandoori Paneer Burger', 109],
    ['Schezwan Paneer Burger', 109],
    ['Double Patty Burger', 129],
    ['Double Patty with Double Cheese Burger', 149],
    ['Extra Cheese Slice (Burger)', 20],
  ]],

  ['Desi Mocktails', [], [
    ['Lemon Ice Tea', 79],
    ['Peach Ice Tea', 79],
    ['Jal Jeera Mocktail', 79],
    ['Classic Virgin Mojito', 89],
    ['Green Apple Mojito', 89],
    ['Blue Lagoon Mocktail', 89],
    ['Raspberry Mocktail', 89],
    ['Mango Mocktail', 89],
    ['Paan Bahar Mocktail', 89],
  ]],

  ['Summer Special Drinks', [], [
    ['Plain Lassi', 69],
    ['Dryfruit Lassi', 89],
    ['Mango Lassi', 79],
    ['Paan Lassi', 79],
    ['Thandai Shake', 89],
  ]],

  ['Chinese Veg Starters', ['Veg Starters'], [
    ['Honey Chilli Potato', 169, ['Honey Chilli Photato']],
    ['Crispy Corn', 139, ['Cripy Corn']],
    ['Corn Chilli', 159],
    ['Paneer Chilli', 179, ['Paneer Chilly']],
    ['Paneer Crispy', 189],
    ['Chana Chilli', 179],
    ['Chana Crispy', 169],
    ['Veg Manchurian Dry', 169, ['Veg Manchurian']],
    ['Veg Manchurian Gravy', 179],
    ['Mushroom Chilli', 189],
  ]],

  ['Chinese Veg Soups', ['Veg Soups'], [
    ['Vegetable Soup', 99],
    ['Veg Manchow Soup', 129],
    ['Veg Schezwan Soup', 109],
    ['Sweet Corn Soup', 109],
    ['Cheesy Corn Soup', 109],
    ['Mushroom Soup', 129],
  ]],

  ['Veg Rolls', [], [
    ['Veg Roll', 89],
    ['Veg Manchurian Roll', 119],
    ['Veg Noodles Roll', 129],
    ['Paneer Roll', 129],
    ['Paneer Cheese Roll', 139],
  ]],

  ['Veg Wraps', [], [
    ['Veg Aloo Wrap', 99],
    ['Veg Aloo Cheese Wrap', 109],
    ['Cheese Corn Wrap', 109],
    ['Paneer Cheese Wrap', 119],
    ['Schezwan Paneer Wrap', 119],
    ['Schezwan Paneer Cheese Wrap', 129],
    ['Peri Peri Paneer Wrap', 119],
    ['Peri Peri Paneer Cheese Wrap', 129],
    ['Tandoori Paneer Wrap', 119],
    ['Tandoori Paneer Cheese Wrap', 129],
    ['Paneer Makhani Wrap', 119],
    ['Paneer Makhani Cheese Wrap', 129],
  ]],

  ['Desserts', [], [
    ['Choco-Lava Cake with Vanilla Ice Cream', 99],
    ['Choco-Lava Cake', 59],
    ['Chocolate Brownie with Vanilla Ice Cream', 119],
    ['Chocolate Brownie', 69, ['Chocoilate Brownie']],
    ['Mix Ice Cream', 109],
    ['Chocolate Ice Cream', 59, ['Chocolate Ice-Cream']],
    ['Butterscotch Ice Cream', 59],
    ['Vanilla Ice Cream', 59, ['Vanilla Ice-Cream']],
  ]],

  ['Veg Rice', [], [
    ['Veg Fried Rice', 129],
    ['Masala Rice', 129],
    ['Veg Schezwan Fried Rice', 139],
    ['Veg Manchurian Fried Rice', 159],
    ['Veg Schezwan Triple Fried Rice', 209, ['Veg Schezwan tripal fried rice']],
    ['Paneer Fried Rice', 179],
    ['Mushroom Fried Rice', 179],
  ]],

  ['Veg Noodles', [], [
    ['Veg Hakka Noodles', 129],
    ['Veg Schezwan Noodles', 139],
    ['Veg Manchurian Noodles', 149],
    ['Mushroom Noodles', 169],
    ['Triple Schezwan Noodles', 179, ['Tripal Schezwan Noodles']],
    ['Paneer Noodles', 169],
    ['Veg Chowmein', 119, ['Veg Chowmin']],
    ['Veg Schezwan Chowmein', 129, ['Veg Schezwan Chowmin']],
    ['Paneer Chowmein', 139, ['Panner Chowmin']],
    ['Paneer Schezwan Chowmein', 159, ['Paneer Schezwan Chowmin']],
  ]],

  ['Sandwiches', ['Sandwich'], [
    ['Veg Mayo Sandwich', 99],
    ['Veg Schezwan Sandwich', 99],
    ['Cheese Corn Sandwich', 109],
    ['Paneer Corn Cheese Sandwich', 129],
    ['Paneer Cheese Sandwich', 119],
    ['Peri Peri Paneer Sandwich', 119],
    ['Paneer Makhani Sandwich', 119],
    ['Tandoori Paneer Sandwich', 119],
    ['Schezwan Paneer Sandwich', 119],
  ]],

  ['Pizza', ['Pizzas'], [
    ['Margherita Pizza (Regular)', 129, ['Margrita pizza']],
    ['Margherita Pizza (Large)', 229],
    ['Single Topping Pizza (Regular)', 139, ['Single Topping Pizza']],
    ['Single Topping Pizza (Large)', 239],
    ['BBQ Mushroom Pizza (Regular)', 139, ['BBQ Mushroom Pizza']],
    ['BBQ Mushroom Pizza (Large)', 239],
    ["Farmer's Choice Pizza (Regular)", 159, ["Farmer's Choice Pizza"]],
    ["Farmer's Choice Pizza (Large)", 259],
    ['Veg Supreme Pizza (Regular)', 169, ['Veg Supreme Pizza']],
    ['Veg Supreme Pizza (Large)', 269],
    ['Cheesy Mushroom And Corn Pizza (Regular)', 179, ['Cheesy Mushroom And Corn Pizza']],
    ['Cheesy Mushroom And Corn Pizza (Large)', 279],
    ['BBQ Paneer and Onion Pizza (Regular)', 199, ['BBQ Paneer and Onion Pizza']],
    ['BBQ Paneer and Onion Pizza (Large)', 299],
    ['Schezwan Paneer Pizza (Regular)', 199, ['Schezwan Paneer Pizza']],
    ['Schezwan Paneer Pizza (Large)', 299],
    ['Tandoori Paneer Pizza (Regular)', 199, ['Tandoori Paneer Pizza']],
    ['Tandoori Paneer Pizza (Large)', 299],
    ['Peri Peri Paneer Pizza (Regular)', 199, ['Peri Peri Paneer Pizza']],
    ['Peri Peri Paneer Pizza (Large)', 299],
    ['Paneer Makhani Pizza (Regular)', 199, ['Paneer Makhani Pizza']],
    ['Paneer Makhani Pizza (Large)', 299],
    ['Cheese Burst Pizza (Regular)', 269, ['Cheese Burst Pizza']],
    ['Cheese Burst Pizza (Large)', 369],
    ['Extra Cheese (Pizza)', 40],
    ['Extra Veggie Toppings (Pizza)', 30],
    ['Extra Paneer (Pizza)', 40],
  ]],

  ['Chocolate Milkshake', [], [
    ['Chocolate Brownie Milkshake', 129],
    ['Chocolate Choco-Chip Milkshake', 109],
    ['Chocolate Oreo Milkshake', 109],
    ['Choco Crunchy Peanut', 109],
    ['Kit-Kat Milkshake', 109],
    ['Chocolate Caramel Milkshake', 109],
    ['Roasted Hazelnut Milkshake', 109],
  ]],

  ['Traditional Cold Coffee', [], [
    ['Regular Cold Coffee', 99],
    ['Vanilla Cold Coffee', 109, ['Vanila Cold Coffee']],
    ['Caramel Cold Coffee', 109],
    ['Chocolate Cold Coffee', 109],
    ['Cold Coffee With Ice Cream', 139],
  ]],

  ['Flavoured Milkshake', [], [
    ['Biscoff Milkshake', 129],
    ['Tutti Frutti Milkshake', 99],
    ['Butterscotch Milkshake', 99],
    ['Mango Milkshake', 99],
    ['Paan Delight Milkshake', 99],
    ['Tangy Kesar Milkshake', 99],
  ]],
];

const exactName = (name) =>
  new RegExp(`^${name.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i');

function assertNoDuplicates() {
  const seen = new Map();
  for (const [, , items] of MENU) {
    for (const [name, , aliases = []] of items) {
      for (const n of [name, ...aliases]) {
        const key = n.trim().toLowerCase();
        if (seen.has(key)) throw new Error(`Menu lists "${n}" twice (also as "${seen.get(key)}")`);
        seen.set(key, name);
      }
    }
  }
}

async function findOne(Model, names, extra = {}) {
  for (const n of names) {
    const matches = await Model.find({ name: exactName(n), ...extra }).sort({ createdAt: 1 });
    if (matches.length) return matches;
  }
  return [];
}

async function syncCategory(name, aliases, sortOrder) {
  let [category] = await findOne(Category, [name, ...aliases]);
  if (!category) {
    category = await Category.create({ name, sortOrder, status: 'active' });
    console.log(`Created category: ${name}`);
    return category;
  }
  const changes = [];
  if (category.name !== name) { category.name = name; changes.push('name'); }
  if (category.sortOrder !== sortOrder) { category.sortOrder = sortOrder; changes.push('sortOrder'); }
  if (category.status !== 'active') { category.status = 'active'; changes.push('status'); }
  if (changes.length) {
    await category.save();
    console.log(`Updated category ${name}: ${changes.join(', ')}`);
  }
  return category;
}

const stats = { created: 0, updated: 0, unchanged: 0 };

async function syncProduct(name, price, aliases, category) {
  const matches = await findOne(Product, [name, ...aliases], { isDeleted: false });

  if (!matches.length) {
    await Product.create({
      name,
      category: category._id,
      sellingPrice: price,
      costPrice: 0,
      trackInventory: false,
      stock: 0,
      lowStockThreshold: 10,
      status: 'available',
      isDeleted: false,
    });
    stats.created++;
    console.log(`Created: ${name} @ ₹${price} [${category.name}]`);
    return;
  }

  const product = matches[0];
  const changes = [];
  if (product.name !== name) { changes.push(`name "${product.name}" -> "${name}"`); product.name = name; }
  if (String(product.category) !== String(category._id)) { product.category = category._id; changes.push('category'); }
  if (Number(product.sellingPrice) !== price) { changes.push(`price ${product.sellingPrice} -> ${price}`); product.sellingPrice = price; }

  if (changes.length) {
    await product.save();
    stats.updated++;
    console.log(`Updated ${name}: ${changes.join(', ')}`);
  } else {
    stats.unchanged++;
  }

  if (matches.length > 1) {
    console.warn(`WARNING: ${matches.length} active products named "${matches[0].name}". Only the oldest was synced; review the others.`);
  }
}

async function run() {
  assertNoDuplicates();
  await connectDB();

  for (let i = 0; i < MENU.length; i++) {
    const [categoryName, categoryAliases, items] = MENU[i];
    const category = await syncCategory(categoryName, categoryAliases, i);
    for (const [name, price, aliases = []] of items) {
      await syncProduct(name, price, aliases, category);
    }
  }

  const menuNames = new Set(MENU.flatMap(([, , items]) => items.map(([n]) => n.toLowerCase())));
  const leftovers = (await Product.find({ isDeleted: false }).select('name'))
    .filter((p) => !menuNames.has(p.name.toLowerCase()));

  console.log(`\nMenu sync complete. Created ${stats.created}, updated ${stats.updated}, unchanged ${stats.unchanged}.`);
  if (leftovers.length) {
    console.log(`\nNot on the new menu (left untouched): ${leftovers.map((p) => p.name).join(', ')}`);
  }
}

run()
  .catch((error) => {
    console.error('Menu sync failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    try { await mongoose.connection.close(); } catch (_) {}
  });
