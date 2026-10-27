const mongoose = require('mongoose');

// Singleton document holding cafe-wide configuration.
const businessSettingsSchema = new mongoose.Schema(
  {
    singletonKey: { type: String, default: 'MAIN', unique: true },

    cafeName: { type: String, default: 'PWP POS • PERSONALIZE WEB PAGE' },
    tagline: { type: String, default: 'Fresh • Fast • Delicious' },
    phone: { type: String, default: '' },
    address: { type: String, default: '' },
    gstNumber: { type: String, default: '' },
    logoUrl: { type: String, default: '' },
    upiId: { type: String, default: '' },

    receiptFooter: { type: String, default: 'Thank you for visiting!\nVisit Again' },
    taxEnabled: { type: Boolean, default: false },
    taxPercent: { type: Number, default: 0, min: 0, max: 100 },
    defaultDiscount: { type: Number, default: 0, min: 0 },
    currencySymbol: { type: String, default: '₹' },

    primaryColor: { type: String, default: '#0E7C5A' },

    // Takeaway (T1, T2...) and Delivery (D1, D2...) counters shown like
    // dine-in tables. Managed through /api/counters, not updateSettings.
    takeawayCounters: { type: [Number], default: [1, 2, 3, 4] },
    deliveryCounters: { type: [Number], default: [1, 2, 3, 4] },
  },
  { timestamps: true }
);

// Optional `session` lets order-pricing code read settings consistently
// within the same transaction it's pricing an order under.
businessSettingsSchema.statics.getSettings = async function getSettings(session) {
  const query = this.findOne({ singletonKey: 'MAIN' });
  if (session) query.session(session);
  let settings = await query;
  if (!settings) {
    const created = await this.create([{ singletonKey: 'MAIN' }], session ? { session } : undefined);
    settings = created[0];
  }
  return settings;
};

module.exports = mongoose.model('BusinessSettings', businessSettingsSchema);
